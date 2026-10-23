import XCTest
@testable import FishtankCore

final class BreedRecommendationTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func parent(_ id: String, _ grade: Int = 1) -> AquariumFish {
        AquariumFish.make(species: FishCatalog.byID[id]!, grade: grade, at: now, adult: true)
    }
    func complete(_ fish: [AquariumFish]) -> AquariumState {
        var s = AquariumState.newGame(at: now); s.fish = fish; s.tankIDs = []
        s.discovered = Set(FishCatalog.all.map(\.id))
        s.discoveredVariants = Set(FishCatalog.all.flatMap { sp in (1...5).map { "\(sp.id):\($0)" } })
        return s
    }
    func testExactSpeciesProbabilityAndLowTierPriority() {
        let high = [parent("astraljelly"), parent("astraljelly")]
        let low = [parent("goldfin"), parent("greyminnow")]
        var s = complete(high + low); s.discovered.remove("prismkoi")
        let r = s.breedRecommendation(at: now)
        XCTAssertEqual(Set(r.parentIDs), Set(high.map(\.id)))
        XCTAssertEqual(r.newSpeciesProbability, 0.55 / 3, accuracy: 1e-12)
        s.discovered.insert("prismkoi"); s.discovered.remove("copperband")
        let l = s.breedRecommendation(at: now)
        XCTAssertEqual(Set(l.parentIDs), Set(low.map(\.id)))
        XCTAssertEqual(l.newSpeciesProbability, 1.0 / 7, accuracy: 1e-12)
    }
    func testVariantProbabilityAndSpeciesLexicographicPriority() {
        let species = FishCatalog.pool(tier: 1).first { $0.id != "copperband" }!.id
        let low = [parent(species), parent(species)]
        var s = complete(low + [parent(species,5),parent(species,5)])
        s.discoveredVariants.remove("copperband:1")
        let r = s.breedRecommendation(at: now)
        XCTAssertEqual(r.reason,.newVariant)
        XCTAssertEqual(Set(r.parentIDs),Set(low.map(\.id)))
        XCTAssertEqual(r.newVariantProbability,0.76 * 0.56 / 7,accuracy:1e-12)
        s.fish += [parent("astraljelly"),parent("astraljelly")]
        s.discovered.remove("prismkoi")
        s.discoveredVariants = s.discoveredVariants.filter { !$0.hasPrefix("copperband:") }
        XCTAssertEqual(s.breedRecommendation(at: now).reason,.newSpecies)
        XCTAssertEqual(s.breedRecommendation(at: now).newSpeciesProbability,0.55/3,accuracy:1e-12)
    }
    func testFallbacksEligibilityAndManualLock() throws {
        var s = complete([parent("goldfin"),parent("greyminnow")])
        XCTAssertEqual(s.breedRecommendation(at: now).reason,.complete)
        s.discovered.remove("prismkoi")
        s.discoveredVariants = s.discoveredVariants.filter { !$0.hasPrefix("prismkoi:") }
        XCTAssertEqual(s.breedRecommendation(at: now).reason,.unreachable)
        s.discoveredVariants.remove("copperband:2")
        XCTAssertEqual(s.breedRecommendation(at: now).reason,.newVariant)
        s.fish[0].locked = true
        XCTAssertTrue(s.fish[0].canBreed(at:now))
        XCTAssertEqual(s.breedRecommendation(at:now).reason,.unavailable)
        s.fish[0].locked = false; s.fish[0].maturesAt = now.addingTimeInterval(100)
        XCTAssertTrue(s.recommendedPair(at:now).isEmpty)
        s.fish = [parent("copperband"),parent("copperband")]; s.fish[0].uses = 0
        XCTAssertTrue(s.recommendedPair(at:now).isEmpty)
    }
    func testHistoryStabilityAndPurity() {
        var s = complete([parent("goldfin"),parent("goldfin"),parent("goldfin")])
        s.discoveredVariants = []; s.hearts = 0
        let before = s, r = s.breedRecommendation(at:now)
        XCTAssertEqual(s,before)
        XCTAssertEqual(r.reason,.newVariant)
        XCTAssertEqual(r.missingSpeciesCount,0)
        XCTAssertEqual(r.parentIDs.count,2)
        XCTAssertEqual(Set(r.parentIDs).count,2)
        s.fish.reverse()
        XCTAssertEqual(s.breedRecommendation(at:now),r)
    }
    func testBucketSelectionMatchesIndependentExhaustiveOracle() {
        var random = FishRandom()
        for trial in 0..<20 {
            let fish = (0..<8).map { i in parent(FishCatalog.all[(trial * 7 + i * 3) % FishCatalog.all.count].id,1 + i % 5) }
            var s = complete(fish)
            s.discovered = Set(FishCatalog.all.filter { _ in random.next() < 0.5 }.map(\.id))
            s.discoveredVariants = Set(FishCatalog.all.flatMap { sp in (1...5).filter { _ in random.next() < 0.5 }.map { "\(sp.id):\($0)" } })
            let known = s.discovered.union(fish.map(\.speciesID))
            var variants = s.discoveredVariants.union(fish.map { "\($0.speciesID):\($0.grade)" })
            for id in known where !variants.contains(where: { $0.hasPrefix(id + ":") }) { variants.insert(id + ":1") }
            var best = (0.0,0.0)
            for i in fish.indices { for j in fish.indices where j > i {
                let a = fish[i], b = fish[j]
                let tiers = FishBalance.matrix["\(min(a.tier,b.tier))+\(max(a.tier,b.tier))"]!
                let weights = FishBalance.gradeWeights(average:Double(a.grade+b.grade)/2)
                var value = (0.0,0.0)
                for t in 1...5 { let pool = FishCatalog.pool(tier:t)
                    for sp in pool {
                        let chance = tiers[t-1]/100/Double(pool.count)
                        if !known.contains(sp.id) { value.0 += chance }
                        for g in 1...5 where !variants.contains("\(sp.id):\(g)") { value.1 += chance * weights[g-1]/weights.reduce(0,+) }
                    }
                }
                if value.0 > best.0 + 1e-12 || (abs(value.0-best.0) <= 1e-12 && value.1 > best.1) { best = value }
            } }
            let r = s.breedRecommendation(at:now)
            XCTAssertEqual(r.newSpeciesProbability,best.0,accuracy:1e-12)
            XCTAssertEqual(r.newVariantProbability,best.1,accuracy:1e-12)
        }
    }
    func testLargeInventoryRemainsBounded() {
        var s = complete([])
        s.fish = (0..<20_000).map { i in parent(FishCatalog.all[i % FishCatalog.all.count].id,1+i%5) }
        s.discoveredVariants = []
        let start = Date()
        XCTAssertEqual(s.recommendedPair(at:now).count,2)
        XCTAssertLessThan(Date().timeIntervalSince(start),5)
    }
}
