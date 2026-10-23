import XCTest
@testable import FishtankCore

final class KeepAwakeTests: XCTestCase {
    func testDefaultOffIdempotenceSwitchOffAndTeardown() {
        var created: [KeepAwakeSession.Kind] = [], released: [UInt32] = []
        var session: KeepAwakeSession? = KeepAwakeSession(create: { kind in
            created.append(kind); return UInt32(created.count)
        }, release: { released.append($0) })
        XCTAssertEqual(session?.mode,.off); XCTAssertTrue(created.isEmpty)
        XCTAssertTrue(session!.select(.system)); XCTAssertEqual(created,[.system])
        XCTAssertTrue(session!.select(.system)); XCTAssertEqual(created.count,1)
        XCTAssertTrue(session!.select(.display)); XCTAssertEqual(created,[.system,.system,.display])
        XCTAssertEqual(released,[1])
        session!.stop(); XCTAssertEqual(released,[1,2,3]); XCTAssertEqual(session?.mode,.off)
        session!.select(.system); session = nil
        XCTAssertEqual(released,[1,2,3,4])
    }
    func testFailedUpgradeReleasesPartialAllocationAndKeepsOriginal() {
        var count: UInt32 = 0, released: [UInt32] = []
        let session = KeepAwakeSession(create: { kind in
            if kind == .display { return nil }
            count += 1; return count
        }, release: { released.append($0) })
        XCTAssertTrue(session.select(.system))
        XCTAssertFalse(session.select(.display))
        XCTAssertEqual(session.mode,.system); XCTAssertEqual(released,[2])
        XCTAssertTrue(session.select(.off)); XCTAssertEqual(released,[2,1])
    }
    func testFailedInitialRequestRemainsOff() {
        let session = KeepAwakeSession(create: { _ in nil }, release: { _ in XCTFail("No allocation to release") })
        XCTAssertFalse(session.select(.system)); XCTAssertEqual(session.mode,.off)
    }
}
