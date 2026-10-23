import Foundation

enum ReforgeRules {
    static let inputCount = 3
    static let hiddenChance = 0.2
    static let pity = 10
}

enum ReforgeError: LocalizedError {
    case wrongCount, notMythic, hasUses, locked, displayed, young
    var errorDescription: String? {
        switch self {
        case .wrongCount: return L10n.text("重铸需要 3 条不同的五星生物。")
        case .notMythic: return L10n.text("只有五星生物可以重铸。")
        case .hasUses: return L10n.text("请先用完材料的繁育次数。")
        case .locked: return L10n.text("锁定的生物不能重铸。")
        case .displayed: return L10n.text("请先手动收回展示中的材料。")
        case .young: return L10n.text("请等待重铸材料成年。")
        }
    }
}

extension AquariumState {
    var regularDiscoveredCount: Int { discovered.intersection(Set(FishCatalog.regular.map(\.id))).count }
    var regularVariantCount: Int {
        discoveredVariants.filter { key in
            key.split(separator: ":").first.flatMap { FishCatalog.byID[String($0)] }?.hidden == false
        }.count
    }
    var hiddenDiscoveredCount: Int { FishCatalog.hidden.filter { discovered.contains($0.id) }.count }
    var catalogSpecies: [FishSpecies] { FishCatalog.all.filter { !$0.hidden || discovered.contains($0.id) } }

    func reforgeCandidates(at now: Date) -> [AquariumFish] {
        let displayed = Set(tankIDs)
        return fish.filter { $0.tier == 5 && $0.uses == 0 && !$0.locked && !displayed.contains($0.id) && $0.isAdult(at: now) }
    }

    func autoReforgeSelection(at now: Date) -> [UUID] {
        let sorted = reforgeCandidates(at: now).sorted {
            if $0.grade != $1.grade { return $0.grade > $1.grade }
            if $0.bornAt != $1.bornAt { return $0.bornAt < $1.bornAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        guard let lead = sorted.first else { return [] }
        let rest = sorted.dropFirst().sorted {
            if $0.grade != $1.grade { return $0.grade < $1.grade }
            if $0.bornAt != $1.bornAt { return $0.bornAt < $1.bornAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        return [lead.id] + rest.prefix(2).map(\.id)
    }

    /// Web parity: validate everything before consuming materials or drawing RNG.
    mutating func reforge(_ ids: [UUID], at now: Date, random: inout FishRandom) throws -> FishOutcome {
        guard ids.count == ReforgeRules.inputCount, Set(ids).count == ids.count else { throw ReforgeError.wrongCount }
        let lookup = Dictionary(uniqueKeysWithValues: fish.map { ($0.id, $0) })
        let materials = ids.compactMap { lookup[$0] }
        guard materials.count == ReforgeRules.inputCount else { throw ReforgeError.wrongCount }
        guard !materials.contains(where: \.locked) else { throw ReforgeError.locked }
        guard materials.allSatisfy({ $0.tier == 5 }) else { throw ReforgeError.notMythic }
        guard materials.allSatisfy({ $0.uses == 0 }) else { throw ReforgeError.hasUses }
        guard Set(ids).isDisjoint(with: tankIDs) else { throw ReforgeError.displayed }
        guard materials.allSatisfy({ $0.isAdult(at: now) }) else { throw ReforgeError.young }
        let missing = FishCatalog.hidden.filter { !discovered.contains($0.id) }
        let guaranteed = !missing.isEmpty && reforgeMisses >= ReforgeRules.pity - 1
        let pool = guaranteed ? missing : (random.next() < ReforgeRules.hiddenChance ? FishCatalog.hidden : FishCatalog.pool(tier: 5))
        let species = pool[random.int(pool.count)]
        let grade = materials.map(\.grade).max()!
        let child = AquariumFish.make(species: species, grade: grade, at: now, uses: random.uses(tier: 5))
        let novel = !discovered.contains(species.id)
        let novelVariant = !discoveredVariants.contains("\(species.id):\(grade)")
        let consumed = Set(ids)
        fish.removeAll { consumed.contains($0.id) }
        reforgeMisses = missing.isEmpty || (species.hidden && novel) ? 0 : reforgeMisses + 1
        append(child)
        return FishOutcome(child: child, novel: novel, novelVariant: novelVariant, expGained: 0, guaranteed: guaranteed)
    }
}
