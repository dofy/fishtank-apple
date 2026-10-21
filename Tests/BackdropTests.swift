import XCTest
@testable import FishtankCore

final class BackdropTests: XCTestCase {
    func testTwoBackgroundSchoolsMoveAndTurnWithoutCreatingInventoryFish() {
        let start = AquariumBackdrop.fish(at: 0)
        XCTAssertEqual(start.count, 13)
        XCTAssertEqual(start.filter { !$0.round }.count, 7)
        XCTAssertEqual(start.filter(\.round).count, 6)
        XCTAssertNotEqual(start, AquariumBackdrop.fish(at: 10))
        XCTAssertTrue(AquariumBackdrop.fish(at: 25).filter(\.round).allSatisfy { $0.heading < 0 })
        XCTAssertEqual(start, AquariumBackdrop.fish(at: .nan))
        for time in stride(from: 0.0, through: 120, by: 0.25) {
            for fish in AquariumBackdrop.fish(at: time) {
                XCTAssertTrue(fish.x.isFinite && fish.y.isFinite)
                XCTAssertTrue((0..<4).contains(fish.frame))
                XCTAssertTrue((65...145).contains(fish.y))
            }
        }
    }

    func testRaisedSandAndDecorationsHaveContactAcrossTheirFootprint() {
        for center in stride(from: 19.2, through: 300.8, by: 2) {
            XCTAssertTrue((19...29).contains(AquariumFloor.height(at: center)))
            for width in [18.0, 28, 48, 64] {
                let base = AquariumFloor.decorationBase(at: center, width: width)
                let samples = stride(from: center - width / 2, through: center + width / 2, by: 1)
                    .map { AquariumFloor.height(at: $0) }
                XCTAssertTrue(samples.allSatisfy { base < $0 }, "Floating base at \(center)")
                XCTAssertEqual(samples.min()! - base, 1, accuracy: 0.001, "Decoration buried at \(center)")
            }
        }
    }
}
