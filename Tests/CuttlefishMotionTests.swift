import XCTest
@testable import FishtankCore

final class CuttlefishMotionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func fish(_ index: Int, species: String = "cuttlefish") -> AquariumFish {
        var f = AquariumFish.make(species: FishCatalog.byID[species]!, at: now, adult: true)
        f.id = UUID(uuidString: String(format: "12345678-4321-4321-ABCD-%012d", index))!
        return f
    }

    func testInkEscapeKeepsMantleLeadingOnBothSidesAndBrakesAtGlass() {
        var escapes = 0, leftEdge = false, rightEdge = false
        for seed in 1...20 {
            let animals = (0..<20).map { fish($0) }
            var scene = AquariumEcology(seed: UInt32(seed))
            scene.sync(animals, decorations: []); scene.shake()
            let escaping = scene.swimmers.values.filter { $0.inkJet > 0 }
            for a in escaping {
                escapes += 1
                if a.x < 60 && a.inkJetDirection < 0 { leftEdge = true }
                if a.x > 260 && a.inkJetDirection > 0 { rightEdge = true }
                XCTAssertLessThan(a.inkJetDirection * a.facing, 0)
            }
            for _ in 0..<120 {
                let before = scene.swimmers
                scene.update(1.0 / 60)
                for original in escaping {
                    let a = scene.swimmers[original.fish.id]!
                    let old = before[original.fish.id]!
                    XCTAssertTrue((23...297).contains(a.x))
                    XCTAssertLessThanOrEqual(abs(a.velocityX - old.velocityX), 3)
                    if a.inkJet > 0 {
                        XCTAssertEqual(a.facing, original.facing, accuracy: 1e-10, "Escape must not mirror at the glass")
                        XCTAssertLessThanOrEqual((a.x - old.x) * a.facing, 0.000001, "Tentacles must trail the mantle")
                    }
                }
            }
        }
        XCTAssertGreaterThan(escapes, 50)
        XCTAssertTrue(leftEdge && rightEdge, "Exercise outward-facing escapes at both walls")
    }

    func testRepeatedStartlesAndShockCannotTurnAnActiveInkEscape() {
        let eel = fish(1, species: "volteel"), cuttle = fish(2)
        var exercised = false
        for seed in 1...30 where !exercised {
            var scene = AquariumEcology(seed: UInt32(seed))
            scene.sync([eel, cuttle], decorations: [])
            for _ in 0..<6 { scene.tap(eel.id, x: 1) }
            guard let start = scene.swimmers[cuttle.id], start.inkJet > 0 else { continue }
            exercised = true
            let cloud = scene.inkClouds.first!.id
            for i in 0..<270 {
                if i == 195 { scene.shake(); scene.tap(cuttle.id, x: 320) }
                scene.update(1.0 / 60)
                let a = scene.swimmers[cuttle.id]!
                if a.inkJet > 0 { XCTAssertGreaterThan(a.facing * start.facing, 0, "A second threat changed escape facing") }
                XCTAssertLessThan(a.inkJetDirection * start.facing, 0)
                XCTAssertTrue(scene.inkClouds.allSatisfy { $0.id == cloud }, "Startle bypassed ink cooldown")
            }
            let end = scene.swimmers[cuttle.id]!
            XCTAssertLessThan((end.x - start.x) * start.facing, -10, "Cuttlefish must escape backward after its shock wears off")
            XCTAssertEqual(end.fish, cuttle)
        }
        XCTAssertTrue(exercised)
    }

    func testSprayWhileTurningFinishesInTheSameFacingHemisphere() {
        let animal = fish(8)
        var exercised = false
        for seed in 1...10 where !exercised {
            var scene = AquariumEcology(seed: UInt32(seed)); scene.sync([animal], decorations: [])
            for _ in 0..<3600 {
                scene.update(1.0 / 60)
                let a = scene.swimmers[animal.id]!
                guard a.inkCooldown <= 0 && abs(a.facing) > 0.1 && abs(a.facing) < 0.9 else { continue }
                for _ in 0..<30 where scene.inkClouds.isEmpty { scene.shake() }
                guard !scene.inkClouds.isEmpty else { continue }
                exercised = true
                for _ in 0..<85 {
                    let old = scene.swimmers[animal.id]!
                    scene.update(1.0 / 60)
                    let next = scene.swimmers[animal.id]!
                    XCTAssertGreaterThan(next.facing * a.facing, 0, "A half-completed turn crossed sides during ink escape")
                    XCTAssertLessThan(abs(next.facing - old.facing), 0.06, "Escape must not snap a turning sprite to full width")
                }
                break
            }
        }
        XCTAssertTrue(exercised, "Exercise a real in-progress turn")
    }

    func testQuietSwimmingIncludesForwardBackwardAndStableHoverWithoutFlippingOnReversal() {
        let animal = fish(8)
        var scene = AquariumEcology(seed: 37); scene.sync([animal], decorations: [])
        var forward = 0, backward = 0, hover = 0, reversals = 0, hoverAge = 0.0
        for _ in 0..<7200 {
            let old = scene.swimmers[animal.id]!
            scene.update(1.0 / 60)
            let a = scene.swimmers[animal.id]!
            if a.inkJet > 0 { continue }
            if a.velocityX * a.facing > 2 { forward += 1 }
            if a.velocityX * a.facing < -2 { backward += 1 }
            if a.cuttlefishGait == .hover && old.cuttlefishGait == .hover {
                hoverAge += 1.0 / 60
                if hoverAge > 1 && a.eatCooldown > 0 {
                    XCTAssertLessThan(hypot(a.x - a.restX, a.y - a.restY), 2)
                    XCTAssertLessThan(hypot(a.velocityX, a.velocityY), 2)
                    XCTAssertGreaterThan(a.motionTime, old.motionTime, "Hovering fins must stay animated")
                    hover += 1
                }
            } else { hoverAge = 0 }
            if old.cuttlefishGait != a.cuttlefishGait && a.scared <= 0 {
                XCTAssertEqual(a.direction, old.direction, "Changing travel direction should not turn the body")
                XCTAssertLessThan(abs(a.facing - old.facing), 0.06)
                reversals += 1
            }
            XCTAssertLessThan(abs(a.velocityX - old.velocityX), 3)
            XCTAssertEqual(a.fish, animal)
        }
        XCTAssertGreaterThan(forward, 100); XCTAssertGreaterThan(backward, 100)
        XCTAssertGreaterThan(hover, 30); XCTAssertGreaterThan(reversals, 4)
    }

    func testHoverRespondsToFoodAndReducedMotionStopsTheNewBehaviors() {
        let animal = fish(4)
        var scene = AquariumEcology(seed: 2); scene.sync([animal], decorations: [])
        var hovering = false
        for _ in 0..<1000 {
            scene.update(0.1)
            if scene.swimmers[animal.id]!.cuttlefishGait == .hover { hovering = true; break }
        }
        XCTAssertTrue(hovering)
        let a = scene.swimmers[animal.id]!
        scene.feed(x: a.x, y: a.y + 3); scene.update(0.1)
        XCTAssertTrue(scene.events.contains("eat"))
        scene.reducedMotion = true; scene.update(0.1)
        let still = scene.swimmers[animal.id]!
        for _ in 0..<200 { scene.update(0.1); scene.shake() }
        let after = scene.swimmers[animal.id]!
        XCTAssertEqual(after.x, still.x); XCTAssertEqual(after.y, still.y)
        XCTAssertEqual(after.motionTime, still.motionTime)
        XCTAssertEqual(after.inkJet, 0); XCTAssertTrue(scene.inkClouds.isEmpty)
    }
}
