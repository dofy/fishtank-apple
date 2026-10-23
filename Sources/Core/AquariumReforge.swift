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
        case .wrongCount: return L10n.text("Choose 3 different five-star creatures.")
        case .notMythic: return L10n.text("Only five-star creatures can be reforged.")
        case .hasUses: return L10n.text("Exhaust the materials’ breeding uses first.")
        case .locked: return L10n.text("Locked creatures cannot be reforged.")
        case .displayed: return L10n.text("Return displayed materials to the inventory first.")
        case .young: return L10n.text("Wait for the reforge materials to mature.")
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
        return fish.filter { reforgeExclusionReason(for: $0, at: now, inTank: displayed.contains($0.id)) == nil }
    }

    func reforgeExclusionReason(for fish: AquariumFish, at now: Date, inTank: Bool) -> MaterialExclusionReason? {
        if fish.locked { return .locked }
        if fish.tier != 5 { return .notFiveStar }
        if !fish.isAdult(at: now) { return .young }
        if fish.uses > 0 { return .hasUses }
        if inTank { return .displayed }
        return nil
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
