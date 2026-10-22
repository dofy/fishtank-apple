import XCTest
@testable import FishtankCore

final class SpeciesMotionTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)
    private func fish(_ species: String, _ index: Int) -> AquariumFish {
        var result = AquariumFish.make(species: FishCatalog.byID[species]!, at: date, adult: true)
        result.id = UUID(uuidString: String(format: "12345678-1234-4321-ABCD-%012d", index))!
        return result
    }
    private func advanceToRest(_ scene: inout AquariumEcology, id: UUID) -> Bool {
        for _ in 0..<1200 {
            scene.update(0.1)
            if (scene.swimmers[id]?.resting ?? 0) > 2 { return true }
        }
        return false
    }
    func testSpeciesHabitsAndIndividualityAreStableAndDistinct() {
        let profiles = FishCatalog.all.map(\.swimProfile)
        XCTAssertEqual(Set(profiles.map(\.family)), Set(FishSwimProfile.Family.allCases))
        XCTAssertTrue(profiles.allSatisfy { $0.speed > 0 && $0.tempo > 0 && (0...1).contains($0.depth) })
        XCTAssertNotEqual(FishCatalog.byID["bandedkrait"]!.swimProfile, FishCatalog.byID["ambereel"]!.swimProfile)
        XCTAssertNotEqual(FishCatalog.byID["ambereel"]!.swimProfile, FishCatalog.byID["volteel"]!.swimProfile)
        XCTAssertGreaterThan(FishCatalog.byID["neonstreak"]!.swimProfile.schoolingRate, 0)
        XCTAssertEqual(FishCatalog.byID["creampuff"]!.swimProfile.schoolingRate, 0)
        let a = fish("goldfin", 1), b = fish("goldfin", 2)
        XCTAssertEqual(FishIndividuality(id: a.id), FishIndividuality(id: a.id))
        XCTAssertNotEqual(FishIndividuality(id: a.id), FishIndividuality(id: b.id))
        var scene = AquariumEcology(seed: 41); scene.sync([a, b], decorations: [])
        XCTAssertNotEqual(scene.swimmers[a.id]!.motionTime, scene.swimmers[b.id]!.motionTime)
        XCTAssertNotEqual(scene.swimmers[a.id]!.individuality.pace, scene.swimmers[b.id]!.individuality.pace)
    }
    func testFishAutonomouslyRestAndFoodTapAndShakeWakeThem() {
        let puffer = fish("creampuff", 1)
        var scene = AquariumEcology(seed: 8); scene.sync([puffer], decorations: [])
        // Age the idle timer without creating food: observe rest independently of foraging.
        scene.reducedMotion = true
        for _ in 0..<100 { scene.update(0.1) }
        scene.reducedMotion = false
        XCTAssertTrue(advanceToRest(&scene, id: puffer.id))
        let resting = scene.swimmers[puffer.id]!
        XCTAssertEqual(abs(resting.facing), 1)
        for _ in 0..<10 { scene.update(0.1) }
        let after = scene.swimmers[puffer.id]!
        XCTAssertLessThan(hypot(after.x - resting.x, after.y - resting.y), 1.5)
        XCTAssertGreaterThan(after.resting, 0)
        scene.feed(x: after.x, y: after.y + 3)
        scene.update(0.1)
        XCTAssertEqual(scene.swimmers[puffer.id]!.resting, 0)
        XCTAssertTrue(advanceToRest(&scene, id: puffer.id))
        scene.tap(puffer.id, x: scene.swimmers[puffer.id]!.x)
        XCTAssertEqual(scene.swimmers[puffer.id]!.resting, 0)
        XCTAssertGreaterThan(scene.swimmers[puffer.id]!.scared, 0)
        XCTAssertTrue(advanceToRest(&scene, id: puffer.id))
        scene.shake()
        XCTAssertEqual(scene.swimmers[puffer.id]!.resting, 0)
        XCTAssertGreaterThanOrEqual(scene.swimmers[puffer.id]!.scared, 3)
    }
    func testOnlySocialSpeciesSchoolAndGroupsStaySmallAndUnchained() {
        let population = (1...8).map { fish("neonstreak", $0) }
            + (9...10).map { fish("creampuff", $0) } + (11...12).map { fish("moonjelly", $0) }
        var scene = AquariumEcology(seed: 912); scene.sync(population, decorations: [])
        var observed = false
        for _ in 0..<3000 {
            scene.update(0.1)
            let groups = Dictionary(grouping: scene.swimmers.values.filter { $0.school != nil }, by: { $0.school! })
            for (leaderID, followers) in groups {
                observed = true
                XCTAssertLessThanOrEqual(followers.count, 4)
                let leader = scene.swimmers[leaderID]!
                XCTAssertNil(leader.school)
                for follower in followers {
                    XCTAssertEqual(follower.fish.speciesID, leader.fish.speciesID)
                    XCTAssertGreaterThan(follower.fish.species.swimProfile.schoolingRate, 0)
                    XCTAssertNotEqual(follower.fish.id, leaderID)
                }
            }
        }
        XCTAssertTrue(observed)
    }
    func testCreatureFamiliesUseDifferentTrajectoriesAndKeepProgressUntouched() {
        let names = ["goldfin", "bandedkrait", "ambereel", "moonjelly", "coralseahorse", "jadeturtle", "voidray"]
        var distances: [String: (x: Double, y: Double)] = [:]
        for (index, species) in names.enumerated() {
            let animal = fish(species, index + 1)
            var scene = AquariumEcology(seed: 18); scene.sync([animal], decorations: [])
            var dx = 0.0, dy = 0.0
            for _ in 0..<80 {
                let old = scene.swimmers[animal.id]!
                scene.update(0.1)
                let next = scene.swimmers[animal.id]!
                dx += abs(next.x - old.x); dy += abs(next.y - old.y)
                XCTAssertEqual(next.fish, animal)
                XCTAssertTrue(next.pitch.isFinite && next.motionTime.isFinite)
            }
            distances[species] = (dx, dy)
        }
        XCTAssertGreaterThan(distances["moonjelly"]!.y, distances["moonjelly"]!.x * 1.5)
        XCTAssertLessThan(distances["jadeturtle"]!.x, distances["goldfin"]!.x * 0.8)
        XCTAssertLessThan(distances["coralseahorse"]!.x, distances["goldfin"]!.x * 0.6)
        XCTAssertGreaterThan(distances["bandedkrait"]!.y, distances["ambereel"]!.y)
    }
    func testEverySpeciesStaysInWaterAcrossViewportChangesAndReducedMotionFreezesAnimation() {
        let animals = FishCatalog.all.enumerated().map { fish($0.element.id, $0.offset + 1) }
        var scene = AquariumEcology(seed: 51); scene.sync(animals, decorations: [])
        for height in [180.0, 426, 120, 180] {
            scene.resize(height: height)
            for tick in 0..<600 {
                if height == 120 && tick == 300 {
                    let eel = animals.first { $0.speciesID == "ambereel" }!
                    for _ in 0..<6 { scene.tap(eel.id, x: 1) }
                }
                scene.update(0.1)
                for a in scene.swimmers.values {
                    XCTAssertTrue((23...297).contains(a.x), a.fish.speciesID)
                    XCTAssertGreaterThanOrEqual(a.y, AquariumFloor.height(at: a.x) + 12 - 0.0001, a.fish.speciesID)
                    XCTAssertLessThanOrEqual(a.y, height - 29, a.fish.speciesID)
                }
            }
        }
        scene.reducedMotion = true; scene.update(0.1)
        let before = scene.swimmers
        for _ in 0..<100 { scene.update(0.1) }
        for (id, a) in scene.swimmers {
            XCTAssertEqual(a.x, before[id]!.x); XCTAssertEqual(a.y, before[id]!.y)
            XCTAssertEqual(a.motionTime, before[id]!.motionTime)
            XCTAssertEqual(a.resting, 0); XCTAssertNil(a.school)
        }
    }
    func testVelocityEasesThroughAccelerationBrakingAndReversalForEverySpecies() {
        for species in FishCatalog.all {
            let profile = species.swimProfile
            var a = AquariumEcology.Swimmer(fish: fish(species.id, 1), x: 160, y: 80, baseY: 80)
            a.easeVelocity(x: 30, y: 0, response: profile.accelerationTime, dt: 1.0 / 60)
            XCTAssertGreaterThan(a.velocityX, 0)
            XCTAssertLessThan(a.velocityX, 4)
            for _ in 0..<180 { a.easeVelocity(x: 30, y: 0, response: profile.accelerationTime, dt: 1.0 / 60) }
            XCTAssertGreaterThan(a.velocityX, 29)
            let moving = a.velocityX
            a.easeVelocity(x: 0, y: 0, response: profile.stoppingTime, dt: 1.0 / 60)
            XCTAssertGreaterThan(a.velocityX, moving * 0.8)
            XCTAssertLessThan(a.velocityX, moving)
            a.easeVelocity(x: -30, y: 0, response: profile.accelerationTime, dt: 1.0 / 60)
            XCTAssertGreaterThan(a.velocityX, 0, "Reversal must brake before swimming backward")
            for _ in 0..<180 { a.easeVelocity(x: -30, y: 0, response: profile.accelerationTime, dt: 1.0 / 60) }
            XCTAssertLessThan(a.velocityX, -29)
        }
    }
    func testTurnCompletesSmoothlyEvenWhenRestingAndIsFrameRateIndependent() {
        for species in FishCatalog.all {
            var samples: [AquariumEcology.Swimmer] = []
            for fps in [30, 60, 120] {
                var a = AquariumEcology.Swimmer(fish: fish(species.id, 1), x: 160, y: 80, baseY: 80)
                a.direction = -1; a.resting = 4
                for _ in 0..<(fps * 2) {
                    let old = a.facing
                    a.easeFacing(duration: species.swimProfile.turningTime, dt: 1 / Double(fps))
                    a.easeVelocity(x: 20, y: 5, response: species.swimProfile.accelerationTime, dt: 1 / Double(fps))
                    XCTAssertLessThanOrEqual(abs(a.facing - old), 0.2)
                    XCTAssertLessThanOrEqual(a.facing, old)
                }
                XCTAssertEqual(a.facing, -1, accuracy: 0.000001)
                samples.append(a)
            }
            for a in samples { XCTAssertEqual(a.velocityX, samples[0].velocityX, accuracy: 0.000001) }
        }
        XCTAssertGreaterThan(FishCatalog.byID["jadeturtle"]!.swimProfile.turningTime,
                             FishCatalog.byID["neonstreak"]!.swimProfile.turningTime)
    }
    func testStartleChangesMotionTempoGradually() {
        let animal = fish("goldfin", 1)
        var scene = AquariumEcology(seed: 8); scene.sync([animal], decorations: [])
        scene.shake(); scene.update(1.0 / 60)
        let first = scene.swimmers[animal.id]!
        XCTAssertGreaterThan(first.motionRate, 1)
        XCTAssertLessThan(first.motionRate, 1.2)
        for _ in 0..<60 { scene.update(1.0 / 60) }
        XCTAssertGreaterThan(scene.swimmers[animal.id]!.motionRate, 2)
    }

}
