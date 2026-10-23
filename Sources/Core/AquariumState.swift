import Foundation

struct AquariumFish: Codable, Identifiable, Equatable {
    var id = UUID()
    var speciesID: String
    var grade: Int = 1
    var uses: Int
    var maxUses: Int
    var bornAt: Date
    var maturesAt: Date?
    var birthExp = 0
    var expBanked = false
    var locked = false

    var species: FishSpecies { FishCatalog.byID[speciesID]! }
    var name: String { species.name }
    var tier: Int { species.tier }
    var palette: Int { tier % 3 }
    func isAdult(at date: Date) -> Bool { maturesAt.map { $0 <= date } ?? true }
    func canBreed(at date: Date) -> Bool { isAdult(at: date) && (tier == 0 || uses > 0) }

    static func make(species: FishSpecies, grade: Int = 1, at now: Date, adult: Bool = false, uses: Int? = nil) -> Self {
        let count = uses ?? FishBalance.uses[species.tier]
        return Self(speciesID: species.id, grade: grade, uses: count, maxUses: count, bornAt: now,
                    maturesAt: adult ? nil : now.addingTimeInterval(FishBalance.growth[species.tier]), expBanked: adult)
    }
}

struct MergePreferences: Codable, Equatable {
    var zeroUsesOnly = true
    var excludeInTank = false
    var tiers: Set<Int> = [1, 2, 3, 4]
}

struct FishOutcome: Equatable {
    var child: AquariumFish
    var novel: Bool
    var novelVariant: Bool
    var expGained: Int
}

enum AquariumError: String, LocalizedError {
    case needsTwo, noHearts, notAdult, noUses, wrongCount, starterMaterial, maxTier, lockedMaterial
    case tankFull, protectedFish, inventoryFull, invalidSave

    var errorDescription: String? {
        switch self {
        case .needsTwo: return L10n.text("请选择两条不同的亲代鱼。")
        case .noHearts: return L10n.text("爱心不足，每 7 分钟恢复一颗。")
        case .notAdult: return L10n.text("幼鱼或冷却中的初始鱼暂时不能繁育。")
        case .noUses: return L10n.text("所选亲代的繁育次数已用尽。")
        case .wrongCount: return L10n.text("合成需要 10 条不同的鱼。")
        case .starterMaterial: return L10n.text("初始鱼不能作为合成材料。")
        case .maxTier: return L10n.text("5 星鱼不能继续合成。")
        case .lockedMaterial: return L10n.text("请先解锁被保护的材料鱼。")
        case .tankFull: return L10n.text("鱼缸展示位已满，升级或先收回一条鱼。")
        case .protectedFish: return L10n.text("初始鱼和锁定鱼不能放生。")
        case .inventoryFull: return L10n.text("背包已达到 20,000 条鱼的上限。")
        case .invalidSave: return L10n.text("存档格式或内容无效。")
        }
    }
}

/// The same xorshift32 and draw order as the web game; persisted to continue after reload.
struct FishRandom: Codable, Equatable {
    var seed: UInt32
    init(seed: UInt32 = UInt32.random(in: 1...UInt32.max)) { self.seed = seed == 0 ? 0x9e3779b9 : seed }
    mutating func next() -> Double {
        var x = seed
        x ^= x << 13; x ^= x >> 17; x ^= x << 5
        seed = x
        return Double(x) / 4_294_967_296
    }
    mutating func int(_ count: Int) -> Int { Int(floor(next() * Double(count))) }
    mutating func weighted(_ weights: [Double]) -> Int {
        var roll = next() * weights.reduce(0, +)
        for (index, weight) in weights.enumerated() {
            roll -= weight
            if roll < 0 { return index }
        }
        return weights.count - 1
    }
    mutating func uses(tier: Int) -> Int {
        if tier == 0 { return 999 }
        let center = FishBalance.uses[tier]
        return weighted((1...5).map { Double(max(1, 6 - abs($0 - center) * 2)) }) + 1
    }
}

struct AquariumState: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case version, fish, tankIDs, hearts, nextHeartAt, lastUpdated, exp, discovered, discoveredVariants
        case mergePreferences, random, decorations, earnedAchievements, displayedAchievements, audio, lighting, railLights, webSourceSnapshot
    }
    static let heartInterval = FishBalance.heartInterval
    static let heartLimit = 5
    var version = 3
    var fish: [AquariumFish]
    var tankIDs: [UUID]
    var hearts: Int = 5
    var nextHeartAt: Date
    var lastUpdated: Date
    var exp = 0
    var discovered: Set<String>
    var discoveredVariants: Set<String>
    var mergePreferences = MergePreferences()
    var random = FishRandom()
    var decorations: [PlacedDecoration] = PlacedDecoration.starter
    var earnedAchievements: Set<String> = []
    var displayedAchievements: [String] = []
    var audio = AquariumAudio()
    var lighting = AquariumLighting.auto
    var railLights = AquariumRailLights()
    var webSourceSnapshot: Data? = nil

    var level: Int { FishBalance.level(exp: exp) }
    var capacity: Int { level + 2 }
    var tankFish: [AquariumFish] { let ids = Set(tankIDs); return fish.filter { ids.contains($0.id) } }
    var nextLevelExp: Int? { level < 10 ? FishBalance.levelThresholds[level] : nil }

    static func newGame(at now: Date) -> Self {
        let fish = ["goldfin", "goldfin", "greyminnow"].enumerated().map { index, id in
            AquariumFish.make(species: FishCatalog.byID[id]!, at: now.addingTimeInterval(Double(index) / 1000), adult: true)
        }
        return Self(fish: fish, tankIDs: fish.map(\.id), nextHeartAt: now.addingTimeInterval(heartInterval),
                    lastUpdated: now, discovered: Set(fish.map(\.speciesID)),
                    discoveredVariants: Set(fish.map { "\($0.speciesID):1" }))
    }

    mutating func advance(to now: Date) {
        guard now >= lastUpdated else { return }
        if hearts < Self.heartLimit {
            while hearts < Self.heartLimit && now >= nextHeartAt {
                hearts += 1
                nextHeartAt.addTimeInterval(Self.heartInterval)
            }
            if hearts >= Self.heartLimit { nextHeartAt = now.addingTimeInterval(Self.heartInterval) }
        } else {
            nextHeartAt = now.addingTimeInterval(Self.heartInterval)
        }
        for index in fish.indices where fish[index].isAdult(at: now) {
            fish[index].maturesAt = nil
            if !fish[index].expBanked {
                exp += FishBalance.totalExperience(tier: fish[index].tier, grade: fish[index].grade) - fish[index].birthExp
                fish[index].expBanked = true
            }
        }
        syncTank()
        syncDecorations()
        syncAchievements()
        lastUpdated = now
    }

    mutating func breed(_ ids: [UUID], at now: Date, random: inout FishRandom) throws -> FishOutcome {
        guard ids.count == 2, ids[0] != ids[1],
              let ai = fish.firstIndex(where: { $0.id == ids[0] }),
              let bi = fish.firstIndex(where: { $0.id == ids[1] }) else { throw AquariumError.needsTwo }
        guard hearts > 0 else { throw AquariumError.noHearts }
        let a = fish[ai], b = fish[bi]
        guard a.isAdult(at: now), b.isAdult(at: now) else { throw AquariumError.notAdult }
        guard (a.tier == 0 || a.uses > 0), (b.tier == 0 || b.uses > 0) else { throw AquariumError.noUses }
        guard fish.count < 20_000 else { throw AquariumError.inventoryFull }
        let key = "\(min(a.tier, b.tier))+\(max(a.tier, b.tier))"
        guard let odds = FishBalance.matrix[key] else { throw AquariumError.invalidSave }
        let tier = random.weighted(odds) + 1
        let pool = FishCatalog.pool(tier: tier)
        let species = pool[random.int(pool.count)]
        let grade = random.weighted(FishBalance.gradeWeights(average: Double(a.grade + b.grade) / 2)) + 1
        let uses = random.uses(tier: tier)
        var child = AquariumFish.make(species: species, grade: grade, at: now, uses: uses)
        let gain = max(2, FishBalance.totalExperience(tier: tier, grade: grade) / 2)
        child.birthExp = gain
        hearts -= 1
        if a.tier > 0 { fish[ai].uses -= 1 } else { fish[ai].maturesAt = now.addingTimeInterval(FishBalance.parentCooldown) }
        if b.tier > 0 { fish[bi].uses -= 1 } else { fish[bi].maturesAt = now.addingTimeInterval(FishBalance.parentCooldown) }
        exp += gain
        let novel = !discovered.contains(species.id)
        let novelVariant = !discoveredVariants.contains("\(child.speciesID):\(child.grade)")
        append(child)
        return FishOutcome(child: child, novel: novel, novelVariant: novelVariant, expGained: gain)
    }

    mutating func merge(_ ids: [UUID], at now: Date, random: inout FishRandom) throws -> FishOutcome {
        guard ids.count == 10, Set(ids).count == 10 else { throw AquariumError.wrongCount }
        let lookup = Dictionary(uniqueKeysWithValues: fish.map { ($0.id, $0) })
        let picked = ids.compactMap { lookup[$0] }
        guard picked.count == 10 else { throw AquariumError.wrongCount }
        guard !picked.contains(where: \.locked) else { throw AquariumError.lockedMaterial }
        guard !picked.contains(where: { $0.tier == 0 }) else { throw AquariumError.starterMaterial }
        guard !picked.contains(where: { $0.tier >= 5 }) else { throw AquariumError.maxTier }
        let tier = picked[random.int(10)].tier + 1
        let grade = picked.map(\.grade).max()!
        let pool = FishCatalog.pool(tier: tier)
        let species = pool[random.int(pool.count)]
        let child = AquariumFish.make(species: species, grade: grade, at: now, uses: random.uses(tier: tier))
        let novel = !discovered.contains(species.id)
        let novelVariant = !discoveredVariants.contains("\(child.speciesID):\(child.grade)")
        let removed = Set(ids)
        fish.removeAll { removed.contains($0.id) }
        append(child)
        return FishOutcome(child: child, novel: novel, novelVariant: novelVariant, expGained: 0)
    }

    private mutating func append(_ child: AquariumFish) {
        fish.append(child)
        discovered.insert(child.speciesID)
        discoveredVariants.insert("\(child.speciesID):\(child.grade)")
        syncAchievements()
        syncTank()
        if tankIDs.count < capacity { tankIDs.append(child.id) }
    }

    mutating func syncTank() {
        let valid = Set(fish.map(\.id))
        var seen = Set<UUID>()
        tankIDs = Array(tankIDs.filter { valid.contains($0) && seen.insert($0).inserted }.prefix(capacity))
    }

    mutating func toggleTank(_ id: UUID) throws {
        guard fish.contains(where: { $0.id == id }) else { throw AquariumError.invalidSave }
        syncTank()
        if tankIDs.contains(id) { tankIDs.removeAll { $0 == id } }
        else if tankIDs.count < capacity { tankIDs.append(id) }
        else { throw AquariumError.tankFull }
    }

    mutating func setLocked(_ id: UUID, _ locked: Bool) {
        if let index = fish.firstIndex(where: { $0.id == id }) { fish[index].locked = locked }
    }

    mutating func release(_ id: UUID) throws {
        guard let target = fish.first(where: { $0.id == id }), target.tier > 0, !target.locked else {
            throw AquariumError.protectedFish
        }
        fish.removeAll { $0.id == id }
        syncTank()
    }

    var mergeCandidates: [AquariumFish] {
        let tank = Set(tankIDs)
        return fish.filter { (1...4).contains($0.tier) && !$0.locked && mergePreferences.tiers.contains($0.tier)
            && (!mergePreferences.zeroUsesOnly || $0.uses == 0)
            && (!mergePreferences.excludeInTank || !tank.contains($0.id)) }
    }

    func recommendedPair(at now: Date) -> [UUID] {
        breedRecommendation(at: now).parentIDs
    }

    func autoMergeSelection() -> [UUID] {
        let candidates = mergeCandidates
        let group = mergePreferences.tiers.sorted().map { tier in candidates.filter { $0.tier == tier } }
            .first { $0.count >= 10 } ?? candidates
        guard let lead = group.sorted(by: {
            if $0.grade != $1.grade { return $0.grade > $1.grade }
            if $0.uses != $1.uses { return $0.uses < $1.uses }
            if $0.tier != $1.tier { return $0.tier < $1.tier }
            return $0.bornAt < $1.bornAt
        }).first else { return [] }
        let rest = group.filter { $0.id != lead.id }.sorted {
            if $0.uses != $1.uses { return $0.uses < $1.uses }
            if $0.tier != $1.tier { return $0.tier < $1.tier }
            if $0.grade != $1.grade { return $0.grade < $1.grade }
            return $0.bornAt < $1.bornAt
        }
        return [lead.id] + rest.prefix(9).map(\.id)
    }

    var heartsFullAt: Date? {
        hearts < Self.heartLimit ? nextHeartAt.addingTimeInterval(Double(Self.heartLimit - hearts - 1) * Self.heartInterval) : nil
    }
    func nextMaturity(after now: Date) -> Date? { fish.compactMap(\.maturesAt).filter { $0 > now }.min() }

    var isValid: Bool {
        guard version == 3, extrasAreValid, fish.count <= 20_000, Set(fish.map(\.id)).count == fish.count,
              (0...5).contains(hearts), exp >= 0, exp <= 1_000_000_000,
              nextHeartAt.timeIntervalSince1970.isFinite, lastUpdated.timeIntervalSince1970.isFinite,
              mergePreferences.tiers.isSubset(of: [1, 2, 3, 4]),
              tankIDs.count <= capacity, Set(tankIDs).count == tankIDs.count,
              Set(tankIDs).isSubset(of: Set(fish.map(\.id))),
              discovered.allSatisfy({ FishCatalog.byID[$0] != nil }),
              discoveredVariants.allSatisfy({ key in
                  let parts = key.split(separator: ":")
                  return parts.count == 2 && FishCatalog.byID[String(parts[0])] != nil
                      && ["1", "2", "3", "4", "5"].contains(String(parts[1]))
              }) else { return false }
        return fish.allSatisfy { item in
            guard let species = FishCatalog.byID[item.speciesID] else { return false }
            return (1...5).contains(item.grade) && (species.tier != 0 || item.grade == 1) && (0...999).contains(item.uses)
                && (1...999).contains(item.maxUses) && item.uses <= item.maxUses
                && item.birthExp >= 0 && item.birthExp <= FishBalance.totalExperience(tier: species.tier, grade: item.grade)
                && item.bornAt.timeIntervalSince1970.isFinite && (item.maturesAt?.timeIntervalSince1970.isFinite ?? true)
        }
    }
}
