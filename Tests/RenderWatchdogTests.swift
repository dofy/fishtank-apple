import XCTest
@testable import FishtankCore

final class RenderWatchdogTests: XCTestCase {
    func testMissedWakeCannotPermanentlyDisableRecovery() {
        var watchdog = AquariumRenderWatchdog()
        watchdog.recovered(at: 1)
        watchdog.suspend(at: 5)
        XCTAssertNil(watchdog.action(at: 7, visible: true, consoleAvailable: true, lastFrame: 4, paused: true, attached: true))
        XCTAssertEqual(watchdog.action(at: 20, visible: true, consoleAvailable: true, lastFrame: 4, paused: true, attached: true), .rebuild)
    }
    func testFailedRebindEscalatesAndSuccessfulFramesResetEscalation() {
        var watchdog = AquariumRenderWatchdog()
        XCTAssertEqual(watchdog.action(at: 10, visible: true, consoleAvailable: true, lastFrame: nil, paused: false, attached: true), .rebind)
        watchdog.recovered(at: 10)
        XCTAssertNil(watchdog.action(at: 12, visible: true, consoleAvailable: true, lastFrame: nil, paused: false, attached: true))
        XCTAssertEqual(watchdog.action(at: 15, visible: true, consoleAvailable: true, lastFrame: nil, paused: false, attached: true), .rebuild)
        watchdog.recovered(at: 15)
        XCTAssertNil(watchdog.action(at: 20, visible: true, consoleAvailable: true, lastFrame: 19, paused: false, attached: true))
        XCTAssertEqual(watchdog.action(at: 25, visible: true, consoleAvailable: true, lastFrame: 19, paused: false, attached: true), .rebind)
    }
    func testHiddenOrLockedSessionDoesNotRecreateSurface() {
        var watchdog = AquariumRenderWatchdog()
        watchdog.suspend(at: 0)
        XCTAssertNil(watchdog.action(at: 10000, visible: false, consoleAvailable: true, lastFrame: 1, paused: true, attached: false))
        XCTAssertNil(watchdog.action(at: 10000, visible: true, consoleAvailable: false, lastFrame: 1, paused: true, attached: false))
        XCTAssertNotNil(watchdog.action(at: 10000, visible: true, consoleAvailable: true, lastFrame: 1, paused: true, attached: false))
    }
}
