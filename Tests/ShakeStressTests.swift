import XCTest
@testable import FishtankCore

final class ShakeStressTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1_000_000)

    private func burst(_ stress: inout AquariumShakeStress, count: Int, from offset: Double, step: Double) -> Int {
        var triggered = 0
        for index in 0..<count where stress.register(at: start.addingTimeInterval(offset + Double(index) * step)) {
            triggered += 1
        }
        return triggered
    }

    func testOneFishIsLostOnlyAfterThirtyThreeShakesInOneBurst() {
        var stress = AquariumShakeStress()
        XCTAssertEqual(burst(&stress, count: AquariumShakeStress.limit - 1, from: 0, step: 0.25), 0)
        XCTAssertTrue(stress.register(at: start.addingTimeInterval(8)))
        // The counter restarts, so the next shake does not cost a second fish.
        XCTAssertFalse(stress.register(at: start.addingTimeInterval(8.25)))
    }

    func testAPauseLongerThanTheGapStartsTheCountOver() {
        var stress = AquariumShakeStress()
        XCTAssertEqual(burst(&stress, count: 32, from: 0, step: 0.25), 0)
        XCTAssertEqual(stress.count, 32)
        XCTAssertFalse(stress.register(at: start.addingTimeInterval(20)))
        XCTAssertEqual(stress.count, 1)
        XCTAssertEqual(burst(&stress, count: 100, from: 21, step: 0.25), 3)
    }

    func testBackwardsClockDoesNotBankShakes() {
        var stress = AquariumShakeStress()
        XCTAssertEqual(burst(&stress, count: 32, from: 0, step: 0.25), 0)
        XCTAssertFalse(stress.register(at: start.addingTimeInterval(-60)))
        XCTAssertEqual(stress.count, 1)
    }

    func testOnlyDisplayedUnlockedNonStarterFishCanBeLost() {
        var state = AquariumState.newGame(at: start)
        let grown = AquariumFish.make(species: FishCatalog.byID["copperband"]!, at: start)
        var locked = AquariumFish.make(species: FishCatalog.byID["moonjelly"]!, at: start)
        locked.locked = true
        let benched = AquariumFish.make(species: FishCatalog.byID["neonstreak"]!, at: start)
        state.fish.append(contentsOf: [grown, locked, benched])
        state.tankIDs = state.fish.filter { $0.id != benched.id }.map(\.id)

        let casualties = Set(state.shakeCasualties.map(\.id))
        XCTAssertEqual(casualties, [grown.id])
        XCTAssertFalse(casualties.contains(benched.id))
        XCTAssertFalse(casualties.contains(locked.id))
        XCTAssertTrue(state.fish.filter { $0.tier == 0 }.allSatisfy { !casualties.contains($0.id) })

        let starter = state.fish.first { $0.tier == 0 }!
        state.removeShakeCasualty(starter.id)
        XCTAssertTrue(state.fish.contains { $0.id == starter.id })
        state.removeShakeCasualty(locked.id)
        XCTAssertTrue(state.fish.contains { $0.id == locked.id })

        let records = state.discovered
        state.removeShakeCasualty(grown.id)
        XCTAssertFalse(state.fish.contains { $0.id == grown.id })
        XCTAssertFalse(state.tankIDs.contains(grown.id))
        XCTAssertEqual(state.discovered, records)
    }
}
