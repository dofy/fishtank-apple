import XCTest
@testable import FishtankCore

final class DecorDisplayGeometryTests: XCTestCase {
    func testChestDoublesBothDimensionsWithoutChangingCatalogOrOtherProps() {
        let chest = DecorCatalog.byID["chest"]!
        XCTAssertEqual(chest.displayWidth, 59.52, accuracy: 0.001)
        XCTAssertEqual(chest.displayHeight, 35.2, accuracy: 0.001)
        XCTAssertEqual(chest.width, 62)
        XCTAssertEqual(chest.height, 44)
        let arch = DecorCatalog.byID["arch"]!
        XCTAssertEqual(arch.displayWidth, 47.04, accuracy: 0.001)
        XCTAssertEqual(arch.displayHeight, 50.4, accuracy: 0.001)
        let lights = DecorCatalog.byID["fairylights"]!
        XCTAssertEqual(lights.displayWidth, 64)
        XCTAssertEqual(lights.displayHeight, 32)
    }
    func testWideThumbnailUsesDisplayAspectInsteadOfSquareTextureAspect() {
        XCTAssertGreaterThan(DecorCatalog.byID["rocks"]!.displayAspectRatio, 2)
        XCTAssertGreaterThan(DecorCatalog.byID["shell"]!.displayAspectRatio, 1.8)
        XCTAssertLessThan(DecorCatalog.byID["kelp"]!.displayAspectRatio, 0.5)
    }
}
