import XCTest
import CoreGraphics
@testable import FishtankCore

final class WindowDragTests: XCTestCase {
    private func display(x: CGFloat = 0, y: CGFloat = 0, width: CGFloat = 1440,
                         height: CGFloat = 900) -> AquariumDisplayGeometry {
        AquariumDisplayGeometry(frame: CGRect(x: x, y: y, width: width, height: height),
                                visibleFrame: CGRect(x: x, y: y + 64, width: width, height: height - 88))
    }

    func testRestoredPositionKeepsNegativeCoordinatesOnSecondaryDisplays() {
        let displays = [display(), display(x: 1440, y: -500, width: 2560, height: 1440)]
        let size = CGSize(width: 320, height: 180)
        XCTAssertEqual(AquariumWindowPlacement.restoredOrigin(from: "3500 -300 320 180 1440 -500 2560 1440", size: size, displays: displays), CGPoint(x: 3500, y: -300))
        XCTAssertEqual(AquariumWindowPlacement.restoredOrigin(from: "1400 200 320 180", size: size, displays: displays), CGPoint(x: 1400, y: 200))
    }
    func testRemovedDisplayAndMalformedFrameUseNormalFallback() {
        let size = CGSize(width: 320, height: 180)
        for saved in ["3500 -300 320 180", "nan 100 320 180", "1 2", "10 20 -320 180", "invalid"] {
            XCTAssertNil(AquariumWindowPlacement.restoredOrigin(from: saved, size: size, displays: [display()]))
        }
    }

    func testSingleDisplayStopsAtDockAndKeepsSizeAndHorizontalMovement() {
        let drag = AquariumWindowDrag(initialFrame: CGRect(x: 100, y: 200, width: 320, height: 180),
                                      mouseDown: CGPoint(x: 130, y: 300))
        let frame = drag.frame(at: CGPoint(x: 180, y: 0), displays: [display()])
        XCTAssertEqual(frame, CGRect(x: 150, y: 64, width: 320, height: 180))
        XCTAssertEqual(drag.frame(at: CGPoint(x: 130, y: 900), displays: [display()]).maxY, 876)
    }

    func testTouchingVerticalDisplaysHaveNoInternalDockOrMenuBarrierAtAnyScale() {
        let screens = [display(), display(y: 900)]
        for scale in 1...3 {
            let height = CGFloat(180 * scale)
            let drag = AquariumWindowDrag(initialFrame: CGRect(x: 200, y: 1100, width: 320 * scale, height: 180 * scale),
                                          mouseDown: CGPoint(x: 300, y: 1200))
            // Both directions, including while the tank straddles the seam and
            // while its bottom crosses the upper display's Dock inset.
            let path = stride(from: CGFloat(180), through: 1750 - height, by: 7).map { $0 }
            for y in path + path.reversed() {
                let frame = drag.frame(at: CGPoint(x: 300, y: y), displays: screens)
                XCTAssertEqual(frame.minY, y - 100, accuracy: 0.001)
                XCTAssertEqual(y - frame.minY, 100, accuracy: 0.001)
            }
        }
    }

    func testUpwardDragCanEnterDisplayAboveWithoutBeingClampedToLowerTop() {
        let drag = AquariumWindowDrag(initialFrame: CGRect(x: 200, y: 300, width: 640, height: 360),
                                      mouseDown: CGPoint(x: 300, y: 400))
        let frame = drag.frame(at: CGPoint(x: 300, y: 1100), displays: [display(), display(y: 900)])
        XCTAssertEqual(frame.minY, 1000)
        XCTAssertEqual(frame.maxY, 1360)
    }

    func testStaggeredNegativeCoordinateDisplaysAllowTheirSharedPortal() {
        let screens = [display(width: 1600), display(x: 600, y: -900)]
        let drag = AquariumWindowDrag(initialFrame: CGRect(x: 700, y: 300, width: 320, height: 180),
                                      mouseDown: CGPoint(x: 730, y: 350))
        for y in stride(from: CGFloat(-700), through: 700, by: 5) {
            XCTAssertEqual(drag.frame(at: CGPoint(x: 730, y: y), displays: screens).minY, y - 50)
        }
        XCTAssertEqual(drag.frame(at: CGPoint(x: 730, y: -900), displays: screens).minY, -836)
    }

    func testExposedBottomOutsidePortalStillStopsAtUpperScreenBottom() {
        let screens = [display(width: 1600), display(x: 600, y: -900)]
        let drag = AquariumWindowDrag(initialFrame: CGRect(x: 100, y: 200, width: 960, height: 540),
                                      mouseDown: CGPoint(x: 300, y: 300))
        XCTAssertEqual(drag.frame(at: CGPoint(x: 300, y: 10), displays: screens).minY, 64)
    }

    func testLowerSideMonitorCannotRemoveUnrelatedScreenFloor() {
        let screens = [display(), display(x: 1440, y: -600)]
        let drag = AquariumWindowDrag(initialFrame: CGRect(x: 200, y: 200, width: 320, height: 180),
                                      mouseDown: CGPoint(x: 230, y: 300))
        XCTAssertEqual(drag.frame(at: CGPoint(x: 230, y: 10), displays: screens).minY, 64)
    }

    func testPhysicalGapDoesNotBecomeAVerticalPortal() {
        let screens = [display(), display(y: -1000)]
        let drag = AquariumWindowDrag(initialFrame: CGRect(x: 100, y: 200, width: 320, height: 180),
                                      mouseDown: CGPoint(x: 130, y: 300))
        XCTAssertEqual(drag.frame(at: CGPoint(x: 130, y: 20), displays: screens).minY, 64)
    }

    func testReturningFromFloorDoesNotRebaseMouseDownAnchor() {
        let drag = AquariumWindowDrag(initialFrame: CGRect(x: -1300, y: 200, width: 320, height: 180),
                                      mouseDown: CGPoint(x: -1250, y: 300))
        let screens = [display(x: -1440)]
        XCTAssertEqual(drag.frame(at: CGPoint(x: -1250, y: 0), displays: screens).minY, 64)
        XCTAssertEqual(drag.frame(at: CGPoint(x: -1250, y: 350), displays: screens).minY, 250)
        XCTAssertEqual(drag.frame(at: drag.mouseDown, displays: screens), drag.initialFrame)
    }

    func testOversizedCanvasKeepsItsBottomVisibleWithoutResizing() {
        let drag = AquariumWindowDrag(initialFrame: CGRect(x: 100, y: 200, width: 960, height: 540),
                                      mouseDown: CGPoint(x: 130, y: 300))
        let frame = drag.frame(at: CGPoint(x: 130, y: 350), displays: [display(height: 400)])
        XCTAssertEqual(frame.minY, 64)
        XCTAssertEqual(frame.height, 540)
    }

    func testMissingDisplaysPreserveRawDesktopPointTranslation() {
        let drag = AquariumWindowDrag(initialFrame: CGRect(x: 100, y: 200, width: 320, height: 180),
                                      mouseDown: CGPoint(x: 130, y: 300))
        XCTAssertEqual(drag.frame(at: CGPoint(x: 150, y: 250), displays: []),
                       CGRect(x: 120, y: 150, width: 320, height: 180))
    }
}
