import XCTest
@testable import FishtankCore

final class GameplayTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private struct Fixtures: Decodable {
        struct Breed: Decodable {
            struct Parent: Decodable { var uses: Int; var cooldown: Double }
            var a: Int; var b: Int; var seed: UInt32; var species: String; var tier: Int
            var grade: Int; var uses: Int; var birthExp: Int; var exp: Int; var level: Int
            var matureExp: Int; var parents: [Parent]
        }
        struct Merge: Decodable {
            var tiers: [Int]; var seed: UInt32; var species: String; var tier: Int
            var grade: Int; var uses: Int; var matureExp: Int
        }
        var breeds: [Breed]; var merges: [Merge]
    }

    private func fixtures() throws -> Fixtures {
        let url = Bundle.module.url(forResource: "cuttlefish-catalog-parity", withExtension: "json", subdirectory: "Fixtures")!
        return try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url))
    }

    private func fish(tier: Int, grade: Int = 1, uses: Int? = nil) -> AquariumFish {
        .make(species: FishCatalog.pool(tier: tier)[0], grade: grade, at: now, adult: true, uses: uses)
    }

    func testAll105SeededBreedsMatchExpandedReferenceCatalog() throws {
        let samples = try fixtures().breeds
        XCTAssertEqual(samples.count, 105)
        for sample in samples {
            var state = AquariumState.newGame(at: now)
            state.fish = [fish(tier: sample.a, grade: 2), fish(tier: sample.b, grade: 4)]
            state.tankIDs = []
            var rng = FishRandom(seed: sample.seed)
            let result = try state.breed(state.fish.map(\.id), at: now, random: &rng)
            let child = result.child
            let context = "\(sample.a)+\(sample.b) seed=\(sample.seed)"
            XCTAssertEqual(child.speciesID, sample.species, context)
            XCTAssertEqual(child.tier, sample.tier, context)
            XCTAssertEqual(child.grade, sample.grade, context)
            XCTAssertEqual(child.uses, sample.uses, context)
            XCTAssertEqual(child.birthExp, sample.birthExp, context)
            XCTAssertEqual(state.exp, sample.exp, context)
            XCTAssertEqual(state.level, sample.level, context)
            XCTAssertEqual(state.hearts, 4, context)
            for i in 0..<2 {
                XCTAssertEqual(state.fish[i].uses, sample.parents[i].uses, context)
                XCTAssertEqual(state.fish[i].maturesAt?.timeIntervalSince(now) ?? 0, sample.parents[i].cooldown / 1000, context)
            }
            state.advance(to: now.addingTimeInterval(FishBalance.growth[child.tier]))
            XCTAssertEqual(state.exp, sample.matureExp, context)
            let banked = state.exp
            state.advance(to: now.addingTimeInterval(3600))
            XCTAssertEqual(state.exp, banked, "Maturation must bank only once")
        }
    }

    func test15SameAndMixedTierMergesMatchExpandedReferenceCatalog() throws {
        for sample in try fixtures().merges {
            var state = AquariumState.newGame(at: now)
            state.fish = sample.tiers.enumerated().map { fish(tier: $0.element, grade: $0.offset == 0 ? 5 : 1) }
            state.tankIDs = []
            var rng = FishRandom(seed: sample.seed)
            let result = try state.merge(state.fish.map(\.id), at: now, random: &rng)
            XCTAssertEqual(result.child.speciesID, sample.species)
            XCTAssertEqual(result.child.tier, sample.tier)
            XCTAssertEqual(result.child.grade, sample.grade)
            XCTAssertEqual(result.child.uses, sample.uses)
            XCTAssertEqual(state.fish.count, 1)
            XCTAssertEqual(state.exp, 0)
            state.advance(to: now.addingTimeInterval(FishBalance.growth[sample.tier]))
            XCTAssertEqual(state.exp, sample.matureExp)
        }
    }

    func testRejectedOperationsNeverConsumeMaterialsHeartsOrRNG() throws {
        var state = AquariumState.newGame(at: now)
        state.fish = (0..<10).map { _ in fish(tier: 1) }
        state.fish[0].locked = true
        state.tankIDs = []
        let before = state
        var rng = FishRandom(seed: 7)
        XCTAssertThrowsError(try state.merge(state.fish.map(\.id), at: now, random: &rng))
        XCTAssertEqual(state, before)
        XCTAssertEqual(rng.seed, 7)
        XCTAssertThrowsError(try state.merge(Array(repeating: state.fish[1].id, count: 10), at: now, random: &rng))
        XCTAssertEqual(state, before)
        state.hearts = 0
        let noHearts = state
        XCTAssertThrowsError(try state.breed(Array(state.fish.prefix(2).map(\.id)), at: now, random: &rng))
        XCTAssertEqual(state, noHearts)
    }

    func testStarterCooldownAndNonStarterUses() throws {
        var state = AquariumState.newGame(at: now)
        var rng = FishRandom(seed: 7)
        let ids = Array(state.fish.prefix(2).map(\.id))
        let result = try state.breed(ids, at: now, random: &rng)
        XCTAssertFalse(state.fish[0].canBreed(at: now.addingTimeInterval(179)))
        state.advance(to: now.addingTimeInterval(180))
        XCTAssertTrue(state.fish[0].canBreed(at: now.addingTimeInterval(180)))
        XCTAssertEqual(state.fish[0].uses, 999)
        XCTAssertEqual(state.exp, result.expGained, "Starter cooldown grants no growth EXP")
        state.fish = [fish(tier: 1, uses: 1), fish(tier: 2, uses: 1)]
        _ = try state.breed(state.fish.map(\.id), at: now, random: &rng)
        XCTAssertEqual(state.fish[0].uses, 0)
        XCTAssertNil(state.fish[0].maturesAt)
        XCTAssertFalse(state.fish[0].canBreed(at: now))
    }

    func testTankProtectionAndPermanentCollectionHistory() throws {
        var state = AquariumState.newGame(at: now)
        let extra = fish(tier: 1)
        state.fish.append(extra)
        state.discovered.insert(extra.speciesID)
        state.discoveredVariants.insert("\(extra.speciesID):1")
        XCTAssertThrowsError(try state.toggleTank(extra.id))
        try state.toggleTank(state.tankIDs[0])
        try state.toggleTank(extra.id)
        state.setLocked(extra.id, true)
        XCTAssertThrowsError(try state.release(extra.id))
        state.setLocked(extra.id, false)
        try state.release(extra.id)
        XCTAssertFalse(state.tankIDs.contains(extra.id))
        XCTAssertTrue(state.discovered.contains(extra.speciesID))
        XCTAssertTrue(state.discoveredVariants.contains("\(extra.speciesID):1"))
        XCTAssertThrowsError(try state.release(state.fish[0].id))
    }

    func testAutoMergeUsesSameTierAndPreservesHighestGrade() {
        var state = AquariumState.newGame(at: now)
        state.fish = (0..<10).map { fish(tier: 1, grade: $0 == 0 ? 5 : 1, uses: 0) }
        state.fish += (0..<10).map { _ in fish(tier: 2, uses: 0) }
        state.fish.append(fish(tier: 1, grade: 5))
        let selected = state.autoMergeSelection()
        XCTAssertEqual(selected.count, 10)
        XCTAssertEqual(selected.first, state.fish[0].id)
        XCTAssertTrue(selected.allSatisfy { id in state.fish.first { $0.id == id }!.tier == 1 })
        state.setLocked(state.fish[0].id, true)
        XCTAssertFalse(state.autoMergeSelection().contains(state.fish[0].id))
    }

    func testPrototypeMigrationPreservesIDsHeartsAndRejectsUnknownVersions() throws {
        let id = UUID()
        let legacy: [String: Any] = ["version": 1, "fish": [["id": id.uuidString, "palette": 2]],
                                   "hearts": 3, "nextHeartAt": now.addingTimeInterval(420).timeIntervalSinceReferenceDate,
                                   "lastUpdated": now.timeIntervalSinceReferenceDate]
        let migrated = try AquariumSave.decode(JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(migrated.version, 3)
        XCTAssertEqual(migrated.fish[0].id, id)
        XCTAssertEqual(migrated.fish[0].speciesID, "greyminnow")
        XCTAssertEqual(migrated.hearts, 3)
        XCTAssertTrue(migrated.isValid)
        XCTAssertThrowsError(try AquariumSave.decode(Data("{\"version\":99}".utf8)))
    }

    func testSavedGameRoundTripRetainsRandomAndHistoricalVariants() throws {
        var state = AquariumState.newGame(at: now)
        var random = state.random
        _ = try state.breed(Array(state.fish.prefix(2).map(\.id)), at: now, random: &random)
        state.random = random
        let restored = try AquariumSave.decode(JSONEncoder().encode(state))
        XCTAssertEqual(restored, state)
    }

    func testIneligibleParentsAndMaterialsAreRejectedAtomically() {
        var state = AquariumState.newGame(at: now)
        var rng = FishRandom(seed: 42)
        state.fish = [fish(tier: 1, uses: 0), fish(tier: 2)]
        state.tankIDs = []
        var before = state
        XCTAssertThrowsError(try state.breed(state.fish.map(\.id), at: now, random: &rng))
        XCTAssertEqual(state, before)
        state.fish[0].uses = 1
        state.fish[0].maturesAt = now.addingTimeInterval(100)
        before = state
        XCTAssertThrowsError(try state.breed(state.fish.map(\.id), at: now, random: &rng))
        XCTAssertEqual(state, before)
        for invalidTier in [0, 5] {
            state.fish = (0..<9).map { _ in fish(tier: 1) } + [fish(tier: invalidTier)]
            before = state
            XCTAssertThrowsError(try state.merge(state.fish.map(\.id), at: now, random: &rng))
            XCTAssertEqual(state, before)
        }
        XCTAssertEqual(rng.seed, 42)
    }

    func testLevelUnlocksAndOddGradeExperienceSplit() throws {
        var state = AquariumState.newGame(at: now)
        state.exp = 9
        var juvenile = AquariumFish.make(species: FishCatalog.pool(tier: 1)[0], grade: 2, at: now)
        juvenile.birthExp = 6 // round(10 * 1.25) = 13, birth floor(13 / 2) = 6.
        state.exp += 6
        state.fish.append(juvenile)
        XCTAssertEqual(state.level, 2)
        XCTAssertEqual(state.capacity, 4)
        state.advance(to: now.addingTimeInterval(300))
        XCTAssertEqual(state.exp, 22)
        state.advance(to: now.addingTimeInterval(301))
        XCTAssertEqual(state.exp, 22)
        state.exp = 57_760
        XCTAssertEqual(state.level, 10)
        XCTAssertEqual(state.capacity, 12)
        XCTAssertNil(state.nextLevelExp)
    }
}
