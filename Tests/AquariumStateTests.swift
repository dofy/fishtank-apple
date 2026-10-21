import XCTest
@testable import FishtankCore

final class AquariumStateTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1_000_000)

    func fixture() -> AquariumState {
        var state = AquariumState.newGame(at: start)
        state.hearts = 3
        state.fish[2] = .make(species: FishCatalog.byID["copperband"]!, at: start)
        state.tankIDs = state.fish.map(\.id)
        return state
    }

    func testOfflineHeartsRespectBoundaryAndCap() {
        var state = fixture()
        state.advance(to: start.addingTimeInterval(419))
        XCTAssertEqual(state.hearts, 3)
        state.advance(to: start.addingTimeInterval(420))
        XCTAssertEqual(state.hearts, 4)
        state.advance(to: start.addingTimeInterval(86_400 * 365))
        XCTAssertEqual(state.hearts, 5)
        XCTAssertNil(state.heartsFullAt)
        XCTAssertGreaterThan(state.nextHeartAt, state.lastUpdated)
    }

    func testReloadDoesNotAwardTwice() throws {
        var state = fixture()
        let later = start.addingTimeInterval(420)
        state.advance(to: later)
        let data = try JSONEncoder().encode(state)
        var loaded = try JSONDecoder().decode(AquariumState.self, from: data)
        loaded.advance(to: later)
        XCTAssertEqual(loaded, state)
    }

    func testMaturityIsBasedOnDeadlineWhileAppIsClosed() {
        let fish = fixture().fish[2]
        XCTAssertFalse(fish.isAdult(at: start.addingTimeInterval(299)))
        XCTAssertTrue(fish.isAdult(at: start.addingTimeInterval(300)))
    }

    func testNotificationDeadlines() {
        var state = fixture()
        XCTAssertEqual(state.heartsFullAt, start.addingTimeInterval(840))
        XCTAssertEqual(state.nextMaturity(after: start), start.addingTimeInterval(300))
        state.advance(to: start.addingTimeInterval(420))
        XCTAssertEqual(state.heartsFullAt, start.addingTimeInterval(840))
        XCTAssertNil(state.nextMaturity(after: start.addingTimeInterval(420)))
    }

    func testBackwardsClockDoesNotRewindState() {
        var state = fixture()
        let original = state
        state.advance(to: start.addingTimeInterval(-100))
        XCTAssertEqual(state, original)
    }

    func testInvalidSaveIsRejected() {
        var state = fixture()
        XCTAssertTrue(state.isValid)
        state.fish.append(state.fish[0])
        XCTAssertFalse(state.isValid)
    }
}
