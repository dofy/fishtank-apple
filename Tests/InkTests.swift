import XCTest
@testable import FishtankCore

final class InkTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func fish(_ species: String, _ index: Int = 1) -> AquariumFish {
        var f = AquariumFish.make(species: FishCatalog.byID[species]!, at: now, adult: true)
        f.id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
        return f
    }
    private func zap(_ scene: inout AquariumEcology, eel: AquariumFish) {
        for _ in 0..<6 { scene.tap(eel.id, x: 1) }
    }
    private func inkedScene() -> (AquariumEcology, AquariumFish, AquariumFish) {
        let cuttle = fish("cuttlefish", 2), eel = fish("volteel")
        var scene = AquariumEcology(seed: 73); scene.sync([eel, cuttle], decorations: [])
        for _ in 0..<100 where scene.inkClouds.isEmpty { scene.shake() }
        XCTAssertEqual(scene.inkClouds.count, 1)
        return (scene, cuttle, eel)
    }

    func testShakeAndShockSometimesReleaseInkAndSometimesDoNot() {
        for shock in [false, true] {
            var releases = 0
            for seed in 1...200 {
                let cuttle = fish("cuttlefish", 2), eel = fish("volteel")
                var scene = AquariumEcology(seed: UInt32(seed));scene.sync([eel,cuttle],decorations:[])
                if shock { zap(&scene, eel: eel) } else { scene.shake() }
                if !scene.inkClouds.isEmpty { releases += 1 }
                else { XCTAssertEqual(scene.swimmers[cuttle.id]!.inkCooldown,0) }
                XCTAssertEqual(scene.swimmers[cuttle.id]?.fish, cuttle)
                XCTAssertTrue(scene.inkClouds.allSatisfy { $0.sourceID == cuttle.id })
            }
            XCTAssertGreaterThan(releases, 15)
            XCTAssertLessThan(releases, 160, "A threat must not always trigger ink")
        }
    }

    func testEveryTriggerSharesTheCooldownAndSyncDoesNotResetIt() {
        var (scene,cuttle,eel) = inkedScene()
        let cooldown = scene.swimmers[cuttle.id]!.inkCooldown
        XCTAssertTrue((300...480).contains(cooldown))
        let cloudID = scene.inkClouds[0].id
        for _ in 0..<50 { scene.shake();zap(&scene,eel:eel) }
        XCTAssertEqual(scene.inkClouds.map(\.id),[cloudID])
        XCTAssertEqual(scene.swimmers[cuttle.id]!.inkCooldown,cooldown)
        scene.sync([eel,cuttle],decorations:[])
        XCTAssertEqual(scene.swimmers[cuttle.id]!.inkCooldown,cooldown)
        scene.sync([eel],decorations:[])
        for _ in 0..<10 { scene.update(0.1) }
        scene.sync([eel,cuttle],decorations:[])
        XCTAssertGreaterThanOrEqual(scene.swimmers[cuttle.id]!.inkCooldown,cooldown-1.01,"Returning a fish to the tank must not bypass its cooldown")
        for _ in 0..<2990 {
            scene.update(0.1)
            XCTAssertFalse(scene.events.contains("ink"),"Spontaneous ink bypassed the cooldown")
        }
        XCTAssertGreaterThan(scene.swimmers[cuttle.id]!.inkCooldown,0)
        // Quietly age the remaining timer without another spontaneous roll.
        scene.reducedMotion = true
        for _ in 0..<Int(ceil(cooldown*10)) { scene.update(0.1) }
        XCTAssertEqual(scene.swimmers[cuttle.id]!.inkCooldown,0)
        scene.reducedMotion = false
        for _ in 0..<100 where scene.inkClouds.isEmpty { scene.shake() }
        XCTAssertFalse(scene.inkClouds.isEmpty,"Ink should recover after the shared timer expires")
    }

    func testSpontaneousInkIsRareButPossibleAndDoesNotRequireAnotherAnimal() {
        let cuttle = fish("cuttlefish")
        var released = 0
        for seed in 1...200 {
            var scene = AquariumEcology(seed: UInt32(seed));scene.sync([cuttle],decorations:[])
            for _ in 0..<200 {
                scene.update(0.1)
                if !scene.inkClouds.isEmpty { released += 1;break }
            }
        }
        XCTAssertGreaterThan(released,0)
        XCTAssertLessThan(released,40,"Spontaneous spray is too frequent")
        let p = AquariumInk.probability(.spontaneous,elapsed:0.1)
        let q = AquariumInk.probability(.spontaneous,elapsed:0.01)
        XCTAssertEqual(pow(1-p,10),exp(-AquariumInk.spontaneousRate),accuracy:1e-12)
        XCTAssertEqual(pow(1-p,10),pow(1-q,100),accuracy:1e-12)
    }

    func testCloudsExpireStayBoundedAndReducedMotionRemovesThem() {
        var (scene,_,_) = inkedScene()
        for _ in 0..<60 { scene.update(0.1) }
        XCTAssertTrue(scene.inkClouds.isEmpty)
        let population=(1...80).map { fish("cuttlefish",$0) }
        scene=AquariumEcology(seed:94);scene.sync(population,decorations:[]);scene.shake()
        XCTAssertFalse(scene.inkClouds.isEmpty)
        XCTAssertLessThanOrEqual(scene.inkClouds.count,AquariumInk.maximumClouds)
        scene.resize(height:426)
        for _ in 0..<10 { scene.update(0.1) }
        XCTAssertTrue(scene.inkClouds.allSatisfy { $0.x.isFinite && $0.y.isFinite && (0...426).contains($0.y) })
        scene.reducedMotion=true;scene.update(0.1);scene.shake()
        XCTAssertTrue(scene.inkClouds.isEmpty)
    }

    func testWithdrawnAnimalsCannotSprayAndInkDoesNotChangeProgress() throws {
        let cuttle=fish("cuttlefish")
        var scene=AquariumEcology(seed:55);scene.sync([cuttle],decorations:[]);scene.sync([],decorations:[])
        for _ in 0..<50 { scene.shake();scene.update(0.1) }
        XCTAssertTrue(scene.inkClouds.isEmpty);XCTAssertTrue(scene.swimmers.isEmpty)
        var state=AquariumState.newGame(at:now);state.fish.append(cuttle)
        state.syncAchievements()
        let before=try JSONEncoder().encode(state)
        scene.sync([cuttle],decorations:[])
        for _ in 0..<300 { scene.shake();scene.update(0.1) }
        XCTAssertEqual(try AquariumSave.decode(before),state)
    }

    func testCuttlefishIsRegularFiveStarAndItsIconUnlocksOnDiscovery() throws {
        let species=FishCatalog.byID["cuttlefish"]!
        XCTAssertEqual(species.tier,5);XCTAssertTrue(species.spraysInk);XCTAssertFalse(species.hidden)
        XCTAssertTrue(FishCatalog.pool(tier:5).contains { $0.id==species.id })
        XCTAssertEqual(species.swimProfile.family,.cuttlefish)
        let icon=AppIconCatalog.design("cuttlefish")
        XCTAssertEqual(icon.speciesID,species.id)
        XCTAssertFalse(AppIconCatalog.isUnlocked(icon,discovered:[]))
        XCTAssertTrue(AppIconCatalog.isUnlocked(icon,discovered:[species.id]))
        var state=AquariumState.newGame(at:now)
        state.discovered=Set(FishCatalog.regular.filter { $0.id != species.id }.map(\.id))
        state.earnedAchievements.insert("reef-explorer")
        let old=try AquariumSave.decode(JSONEncoder().encode(state))
        XCTAssertTrue(old.earnedAchievements.contains("reef-explorer"),"An existing medal remains permanent")
        XCTAssertEqual(old.discovered,state.discovered)
        XCTAssertEqual(AchievementCatalog.all.first { $0.id=="reef-explorer" }?.total,30)
    }
}
