import Foundation

struct BreedRecommendation: Equatable {
    enum Reason { case newSpecies, newVariant, complete, unreachable, unavailable }
    let parentIDs: [UUID]
    let reason: Reason
    let newSpeciesProbability: Double
    let newVariantProbability: Double
    let missingSpeciesCount: Int
}

extension AquariumState {
    func breedRecommendation(at now: Date) -> BreedRecommendation {
        let eligible = fish.filter { !$0.locked && $0.canBreed(at: now) }
        let known = discovered.union(fish.map(\.speciesID))
        var variants = discoveredVariants.union(fish.map { "\($0.speciesID):\($0.grade)" })
        let recordedSpecies = Set(variants.compactMap { $0.split(separator: ":").first.map(String.init) })
        for id in known where !recordedSpecies.contains(id) { variants.insert("\(id):1") }
        let targets = (1...5).map { tier -> (Double, [Double]) in
            let pool = FishCatalog.pool(tier: tier)
            guard !pool.isEmpty else { return (0, Array(repeating: 0, count: 5)) }
            let size = Double(pool.count)
            return (Double(pool.filter { !known.contains($0.id) }.count) / size,
                    (1...5).map { grade in Double(pool.filter { !variants.contains("\($0.id):\(grade)") }.count) / size })
        }
        let missing = FishCatalog.regular.filter { $0.tier > 0 && !known.contains($0.id) }.count
        func result(_ pair: [AquariumFish], _ reason: BreedRecommendation.Reason, _ score: (Double, Double) = (0, 0)) -> BreedRecommendation {
            BreedRecommendation(parentIDs: pair.sorted(by: Self.legacyBreedOrder).map(\.id), reason: reason,
                                newSpeciesProbability: score.0, newVariantProbability: score.1, missingSpeciesCount: missing)
        }
        guard eligible.count >= 2 else { return result([], .unavailable) }
        func score(_ a: AquariumFish, _ b: AquariumFish) -> (Double, Double) {
            guard let tiers = FishBalance.matrix["\(min(a.tier,b.tier))+\(max(a.tier,b.tier))"] else { return (0,0) }
            let grades = FishBalance.gradeWeights(average: Double(a.grade + b.grade) / 2)
            let total = grades.reduce(0,+)
            var species = 0.0, variant = 0.0
            for t in 0..<5 {
                species += tiers[t] / 100 * targets[t].0
                for g in 0..<5 { variant += tiers[t] / 100 * grades[g] / total * targets[t].1[g] }
            }
            return (species, variant)
        }
        func representativeOrder(_ a: AquariumFish, _ b: AquariumFish) -> Bool {
            if a.uses != b.uses { return a.uses > b.uses }
            if a.bornAt != b.bornAt { return a.bornAt < b.bornAt }
            return a.id.uuidString < b.id.uuidString
        }
        var buckets: [String: [AquariumFish]] = [:]
        for f in eligible {
            let key = "\(f.tier):\(f.grade)"
            buckets[key] = Array(((buckets[key] ?? []) + [f]).sorted(by: representativeOrder).prefix(2))
        }
        let candidates = buckets.values.flatMap { $0 }
        func resourceOrder(_ a: [AquariumFish], _ b: [AquariumFish]) -> Bool {
            let at = a[0].tier + a[1].tier, bt = b[0].tier + b[1].tier
            if at != bt { return at < bt }
            let am = max(a[0].tier,a[1].tier), bm = max(b[0].tier,b[1].tier)
            if am != bm { return am < bm }
            let au = a[0].uses + a[1].uses, bu = b[0].uses + b[1].uses
            if au != bu { return au > bu }
            let ad = a[0].bornAt.timeIntervalSince1970 + a[1].bornAt.timeIntervalSince1970
            let bd = b[0].bornAt.timeIntervalSince1970 + b[1].bornAt.timeIntervalSince1970
            if ad != bd { return ad < bd }
            return a.map { $0.id.uuidString }.sorted().joined() < b.map { $0.id.uuidString }.sorted().joined()
        }
        var best: [AquariumFish] = [], bestScore = (-1.0,-1.0)
        for i in candidates.indices { for j in candidates.indices where j > i {
            let pair = [candidates[i], candidates[j]], value = score(candidates[i], candidates[j])
            let ds = value.0 - bestScore.0, dv = value.1 - bestScore.1
            if best.isEmpty || ds > 1e-12 || (abs(ds) <= 1e-12 && (dv > 1e-12 || (abs(dv) <= 1e-12 && resourceOrder(pair,best)))) {
                best = pair; bestScore = value
            }
        } }
        if bestScore.0 == 0 && bestScore.1 == 0 {
            let complete = targets.allSatisfy { $0.0 == 0 && $0.1.allSatisfy { $0 == 0 } }
            return result(Array(eligible.sorted(by: Self.legacyBreedOrder).prefix(2)), complete ? .complete : .unreachable)
        }
        return result(best, bestScore.0 > 0 ? .newSpecies : .newVariant, bestScore)
    }

    private static func legacyBreedOrder(_ a: AquariumFish, _ b: AquariumFish) -> Bool {
        if a.tier != b.tier { return a.tier > b.tier }
        if a.grade != b.grade { return a.grade > b.grade }
        if a.uses != b.uses { return a.uses > b.uses }
        if a.bornAt != b.bornAt { return a.bornAt < b.bornAt }
        return a.id.uuidString < b.id.uuidString
    }
}
