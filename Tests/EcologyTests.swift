import XCTest
@testable import FishtankCore

final class EcologyTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)
    private func fish(_ species: String) -> AquariumFish { .make(species: FishCatalog.byID[species]!, at: date, adult: true) }
    private func advanceWithoutAutomaticDischarges(_ scene: inout AquariumEcology, seconds: Double) {
        let original = scene.reducedMotion
        scene.reducedMotion = true
        for _ in 0..<Int(ceil(seconds / 0.1)) { scene.update(0.1) }
        scene.reducedMotion = original
    }
    private func makeElectricReady(_ scene: inout AquariumEcology, id: UUID) {
        advanceWithoutAutomaticDischarges(&scene, seconds: scene.swimmers[id]!.zapCooldown + 0.1)
    }
    func testTankShakeStartlesEveryFishForThreeToFiveSecondsThenRecovers() {
        let population = [fish("goldfin"), fish("greyminnow"), fish("ambereel"), fish("jadeturtle")]
        var scene = AquariumEcology(seed: 35); scene.sync(population, decorations: [])
        let initial = scene.swimmers
        scene.shake()
        for a in scene.swimmers.values {
            XCTAssertTrue((3...5).contains(a.scared))
            XCTAssertEqual(a.shocked, 0); XCTAssertEqual(a.discharging, 0)
            XCTAssertNil(a.school); XCTAssertNil(a.visit)
            XCTAssertEqual(a.fish, initial[a.fish.id]?.fish)
        }
        scene.update(0.1)
        for a in scene.swimmers.values {
            XCTAssertGreaterThan(abs(a.x - initial[a.fish.id]!.x), 7)
        }
        for _ in 0..<28 { scene.update(0.1) }
        XCTAssertTrue(scene.swimmers.values.allSatisfy { $0.scared > 0 })
        scene.shake() // Repeated clicks refresh the interval instead of accumulating it.
        XCTAssertTrue(scene.swimmers.values.allSatisfy { (3...5).contains($0.scared) })
        for _ in 0..<51 { scene.update(0.1) }
        XCTAssertTrue(scene.swimmers.values.allSatisfy { $0.scared == 0 && $0.available })
        XCTAssertEqual(scene.lampColors, [1,4,1])
    }
    func testTankShakeRespectsReducedMotionAndDoesNotReviveWithdrawingFish() {
        let population = [fish("goldfin"), fish("greyminnow")]
        var scene = AquariumEcology(seed: 12); scene.sync(population, decorations: [])
        scene.sync([population[0]], decorations: [])
        scene.shake()
        XCTAssertEqual(scene.swimmers[population[1].id]?.scared, 0)
        XCTAssertNotNil(scene.swimmers[population[1].id]?.withdrawal)
        scene.reducedMotion = true
        let x = scene.swimmers[population[0].id]!.x
        for _ in 0..<51 { scene.update(0.1) }
        scene.shake();scene.update(0.1)
        XCTAssertEqual(scene.swimmers[population[0].id]?.scared, 0)
        XCTAssertEqual(scene.swimmers[population[0].id]?.x, x)
    }
    func testViewportResizePreservesFishAndKeepsFoodAndSwimmersInsideWater() {
        let population = [fish("goldfin"), fish("greyminnow"), fish("ambereel")]
        var scene = AquariumEcology(seed: 35)
        scene.sync(population, decorations: [])
        let originals = scene.swimmers
        scene.resize(height: 426)
        XCTAssertEqual(Set(scene.swimmers.keys), Set(originals.keys))
        scene.feed()
        XCTAssertEqual(scene.foods.last?.y, 410)
        for _ in 0..<200 { scene.update(0.1) }
        XCTAssertTrue(scene.swimmers.values.allSatisfy { $0.y >= AquariumFloor.height(at: $0.x) + 12 && $0.y <= 397 })
        scene.resize(height: 180)
        for id in originals.keys {
            XCTAssertEqual(scene.swimmers[id]!.baseY, originals[id]!.baseY, accuracy: 0.001)
            XCTAssertEqual(scene.swimmers[id]!.fish, originals[id]!.fish)
        }
        scene.resize(height: .nan)
        XCTAssertEqual(scene.height, 180)
    }

    func testOnlyElectricSpeciesDischargeAtSixClicksAndNightLampChanges() {
        XCTAssertEqual(Set(FishCatalog.all.filter(\.electric).map(\.id)), ["ambereel", "volteel"])
        let eel = fish("ambereel"), other = fish("goldfin")
        var scene = AquariumEcology(seed: 35); scene.night = true
        XCTAssertEqual(scene.lampColors, [1, 4, 1])
        scene.sync([eel, other], decorations: [])
        let lamps = scene.lampColors
        for _ in 0..<5 { XCTAssertEqual(scene.tap(eel.id, x: 1), "scare") }
        XCTAssertEqual(scene.tap(eel.id, x: 1), "zap")
        XCTAssertEqual(scene.swimmers[other.id]?.shocked, 3)
        XCTAssertEqual(scene.swimmers[eel.id]?.discharging, 0.85)
        XCTAssertEqual(zip(lamps, scene.lampColors).filter { $0 != $1 }.count, 1)
        let ribbon = fish("auroraeel")
        var ribbonScene = AquariumEcology(seed: 12)
        ribbonScene.sync([ribbon], decorations: [])
        for _ in 0..<8 { XCTAssertEqual(ribbonScene.tap(ribbon.id, x: 1), "scare") }
    }
    func testDischargeLeavesSourceSwimmingAndVictimsRecover() {
        let eel = fish("volteel"), other = fish("goldfin")
        var scene = AquariumEcology(seed: 35)
        scene.sync([eel, other], decorations: [])
        for _ in 0..<6 { scene.tap(eel.id, x: 1) }
        let source = scene.swimmers[eel.id]!
        let victim = scene.swimmers[other.id]!
        XCTAssertEqual(source.shocked, 0)
        XCTAssertEqual(source.scared, 0)
        scene.update(0.1)
        XCTAssertNotEqual(scene.swimmers[eel.id]!.x, source.x)
        XCTAssertEqual(scene.swimmers[other.id]!.x, victim.x)
        XCTAssertGreaterThan(scene.swimmers[eel.id]!.discharging, 0)
        for _ in 0..<31 { scene.update(0.1) }
        XCTAssertEqual(scene.swimmers[other.id]!.shocked, 0)
        XCTAssertNotEqual(scene.swimmers[other.id]!.x, victim.x)
    }

    func testAutomaticDischargesRespectFiveMinuteCooldownAfterEveryZap() {
        let eel = fish("volteel"), other = fish("goldfin")
        var scene = AquariumEcology(seed: 35); scene.sync([eel, other], decorations: [])
        XCTAssertTrue((300...480).contains(scene.swimmers[eel.id]!.zapCooldown))
        for _ in 0..<3 {
            for _ in 0..<5 { XCTAssertEqual(scene.tap(eel.id, x: 1), "scare") }
            XCTAssertEqual(scene.tap(eel.id, x: 1), "zap")
            let cooldown = scene.swimmers[eel.id]!.zapCooldown
            XCTAssertTrue((300...480).contains(cooldown))
            for _ in 0..<2990 {
                scene.update(0.1)
                XCTAssertFalse(scene.events.contains("zap"), "Automatic discharge bypassed cooldown")
            }
            XCTAssertEqual(scene.swimmers[eel.id]!.discharging, 0)
            XCTAssertEqual(scene.swimmers[other.id]!.shocked, 0)
        }
    }
    func testManualDischargeBypassesAndResetsAutomaticCooldown() {
        let eel = fish("ambereel"), other = fish("goldfin")
        var scene = AquariumEcology(seed: 42); scene.sync([eel, other], decorations: [])
        for _ in 0..<3 {
            XCTAssertGreaterThan(scene.swimmers[eel.id]!.zapCooldown, 0)
            for _ in 0..<5 { XCTAssertEqual(scene.tap(eel.id, x: 1), "scare") }
            XCTAssertEqual(scene.tap(eel.id, x: 1), "zap")
            XCTAssertEqual(scene.swimmers[other.id]!.shocked, 3)
            XCTAssertTrue((300...480).contains(scene.swimmers[eel.id]!.zapCooldown))
        }
    }
    func testAutomaticDischargesAreRareAfterCooldown() {
        var eel = fish("volteel"), other = fish("goldfin")
        eel.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        other.id = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        var discharges = 0
        // Independent fixed seeds test a ten-second eligible window per tank.
        // The old rate discharged in roughly a third of these windows.
        for seed in 1...120 {
            var scene = AquariumEcology(seed: UInt32(seed)); scene.sync([eel, other], decorations: [])
            makeElectricReady(&scene, id: eel.id)
            for _ in 0..<100 {
                scene.update(0.1)
                if scene.events.contains("zap") { discharges += 1; break }
            }
        }
        XCTAssertGreaterThan(discharges, 0, "Automatic discharge should remain possible")
        XCTAssertLessThanOrEqual(discharges, 18, "Automatic discharges are too frequent")
    }

    func testPufferTimingAndReducedMotion() {
        let puffer = fish("creampuff")
        var scene = AquariumEcology(seed: 1); scene.sync([puffer], decorations: [])
        scene.tap(puffer.id, x: 1)
        scene.update(0.1); scene.update(0.1)
        XCTAssertEqual(scene.swimmers[puffer.id]!.puffAmount, 1, accuracy: 0.001)
        for _ in 0..<17 { scene.update(0.1) }
        XCTAssertEqual(scene.swimmers[puffer.id]?.puff, 0)
        scene.reducedMotion = true; scene.tap(puffer.id, x: 1); scene.update(0.1)
        XCTAssertEqual(scene.swimmers[puffer.id]?.puffAmount, 0)
    }
    func testEachDefaultFeedAddsExactlyOnePelletWithoutChangingProgress() {
        var scene = AquariumEcology(seed: 1)
        scene.feed()
        XCTAssertEqual(scene.foods.count, 1)
        XCTAssertEqual(scene.foods.first?.x, 160)
        scene.feed()
        XCTAssertEqual(scene.foods.count, 2)
        XCTAssertNotEqual(scene.foods[0].id, scene.foods[1].id)
    }
    func testWithdrawalExcludedFromHitsFoodAndShockAndReplacementCancels() {
        let eel = fish("volteel"), other = fish("goldfin")
        var scene = AquariumEcology(seed: 5); scene.sync([eel, other], decorations: [])
        scene.sync([eel], decorations: [])
        XCTAssertNil(scene.tap(other.id, x: 1))
        for _ in 0..<6 { scene.tap(eel.id, x: 1) }
        XCTAssertEqual(scene.swimmers[other.id]?.shocked, 0)
        scene.update(0.1); scene.sync([eel, other], decorations: [])
        XCTAssertNil(scene.swimmers[other.id]?.withdrawal)
        scene.sync([eel], decorations: [])
        for _ in 0..<6 { scene.update(0.1) }
        XCTAssertNil(scene.swimmers[other.id])
        scene.sync([eel, other], decorations: [])
        scene.sync([eel], decorations: [])
        scene.discardMissingFish(in: [eel.id])
        XCTAssertNil(scene.swimmers[other.id])
    }
    func testVisualActivityNeverChangesSavedProgressAndTemporaryFoodBounded() {
        let state = AquariumState.newGame(at: date)
        let encoded = try! JSONEncoder().encode(state)
        var scene = AquariumEcology(seed: 17); scene.sync(state.tankFish, decorations: state.decorations)
        for _ in 0..<200 { scene.feed() }
        XCTAssertLessThanOrEqual(scene.foods.count, 80)
        for _ in 0..<6000 {
            scene.update(0.1)
            XCTAssertLessThanOrEqual(scene.foods.filter(\.plankton).count, 3)
            XCTAssertTrue(scene.swimmers.values.allSatisfy { $0.x.isFinite && $0.y.isFinite && (23...297).contains($0.x) })
            for (id, a) in scene.swimmers where a.school != nil {
                XCTAssertNotEqual(id, a.school)
                XCTAssertNil(scene.swimmers[a.school!]?.school)
            }
        }
        XCTAssertEqual(try! AquariumSave.decode(encoded), state)
    }
    func testRailLightOriginalWaveAndBounds() {
        var config = AquariumRailLights()
        XCTAssertEqual(config.brightness(time: 0, index: 0), 1)
        XCTAssertEqual(config.brightness(time: 1, index: 0), 0.25, accuracy: 0.0001)
        XCTAssertEqual(config.brightness(time: 1, index: 0, reducedMotion: true), 1)
        config.frequency = .infinity; XCTAssertFalse(config.isValid)
    }
    func testElectricClickWindowExpiresAndDaylightKeepsLampColors() {
        let eel = fish("volteel")
        var scene = AquariumEcology(seed: 55); scene.sync([eel], decorations: [])
        for _ in 0..<5 { scene.tap(eel.id, x: 1) }
        for _ in 0..<310 { scene.update(0.1) }
        XCTAssertEqual(scene.tap(eel.id, x: 1), "scare")
        let colors = scene.lampColors
        for _ in 0..<4 { XCTAssertEqual(scene.tap(eel.id, x: 1), "scare") }
        XCTAssertEqual(scene.tap(eel.id, x: 1), "zap")
        XCTAssertEqual(scene.lampColors, colors)
    }
    func testSceneryVisitsAreInterruptibleAndSchoolsNeverExceedFive() {
        let horse = fish("coralseahorse"), small = fish("goldfin")
        let members = (0..<6).map { _ in fish("neonstreak") }
        var scene = AquariumEcology(seed: 912)
        let all = [horse, small] + members
        let decor = [PlacedDecoration(id: "kelp", x: 0.3), PlacedDecoration(id: "arch", x: 0.65)]
        scene.sync(all, decorations: decor)
        var resting = false, passing = false, schooling = false
        for _ in 0..<6000 {
            scene.update(0.1)
            resting = resting || scene.swimmers[horse.id]?.visit == "kelp"
            passing = passing || scene.swimmers[small.id]?.visit == "arch"
            let followers = Dictionary(grouping: scene.swimmers.values.compactMap(\.school), by: { $0 })
            schooling = schooling || !followers.isEmpty
            XCTAssertTrue(followers.values.allSatisfy { $0.count <= 4 })
        }
        XCTAssertTrue(resting); XCTAssertTrue(passing); XCTAssertTrue(schooling)
        scene.setActiveDecoration("kelp")
        for _ in 0..<300 {
            scene.update(0.1)
            XCTAssertNotEqual(scene.swimmers[horse.id]?.visit, "kelp")
        }
        scene.setActiveDecoration(nil)
        scene.sync(all, decorations: [])
        XCTAssertTrue(scene.swimmers.values.allSatisfy { $0.visit == nil })
        scene.tap(horse.id, x: 1)
        XCTAssertNil(scene.swimmers[horse.id]?.visit)
        XCTAssertNil(scene.swimmers[horse.id]?.school)
    }

}
