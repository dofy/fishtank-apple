import XCTest
@testable import FishtankCore

final class ReminderTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func testHeartsWaitForAllFiveAndOldFullReminderIsRejectedAfterSpending() throws {
        var state = AquariumState.newGame(at: now)
        state.hearts = 1
        state.nextHeartAt = now.addingTimeInterval(30)
        let plan = try XCTUnwrap(AquariumReminder.scheduled(in: state, at: now).first { $0.kind == .hearts })
        XCTAssertEqual(plan.date, now.addingTimeInterval(30 + 3 * AquariumState.heartInterval))
        XCTAssertFalse(plan.isSatisfied(in: state, at: now.addingTimeInterval(30)))
        XCTAssertFalse(plan.isSatisfied(in: state, at: plan.date.addingTimeInterval(-0.1)))
        XCTAssertTrue(plan.isSatisfied(in: state, at: plan.date))
        state.advance(to: plan.date)
        state.hearts -= 1
        XCTAssertFalse(plan.isSatisfied(in: state, at: plan.date))
        let replacement = try XCTUnwrap(AquariumReminder.scheduled(in: state, at: plan.date).first { $0.kind == .hearts })
        XCTAssertGreaterThan(replacement.date, plan.date)
    }
    func testFullHeartsHaveNoPendingFullReminder() {
        let state = AquariumState.newGame(at: now)
        XCTAssertNil(AquariumReminder.scheduled(in: state, at: now).first { $0.kind == .hearts })
    }
    func testRemovedFishCannotDeliverMaturityAndCooldownNeedsCurrentAdult() throws {
        var state = AquariumState.newGame(at: now)
        var child = AquariumFish.make(species: FishCatalog.byID["copperband"]!, at: now)
        child.maturesAt = now.addingTimeInterval(10)
        state.fish.append(child)
        let plan = try XCTUnwrap(AquariumReminder.scheduled(in: state, at: now).first { $0.kind == .mature })
        XCTAssertFalse(plan.isSatisfied(in: state, at: now))
        XCTAssertTrue(plan.isSatisfied(in: state, at: plan.date))
        state.fish.removeAll { $0.id == child.id }
        XCTAssertFalse(plan.isSatisfied(in: state, at: plan.date))
        state.fish[0].maturesAt = now.addingTimeInterval(20)
        let cooldown = try XCTUnwrap(AquariumReminder.scheduled(in: state, at: now).first { $0.kind == .cooldown })
        XCTAssertTrue(cooldown.isSatisfied(in: state, at: cooldown.date))
        state.fish[0].maturesAt = now.addingTimeInterval(40)
        XCTAssertFalse(cooldown.isSatisfied(in: state, at: cooldown.date))
    }
}
