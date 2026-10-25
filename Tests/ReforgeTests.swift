import XCTest
@testable import FishtankCore

final class ReforgeTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func material(_ grade: Int = 1, species: String = "prismkoi") -> AquariumFish {
        var f = AquariumFish.make(species: FishCatalog.byID[species]!, grade: grade, at: now, adult: true)
        f.uses = 0
        return f
    }
    private func setup() -> (AquariumState, [UUID]) {
        var s = AquariumState.newGame(at: now)
        let input = [1,2,5].map { material($0) }
        s.fish += input
        return (s, input.map(\.id))
    }

    func testSeededReforgesMatch72ExpandedCatalogReferenceCases() throws {
        struct Sample: Decodable {
            var seed: UInt32; var history: [String]; var misses: Int
            var species: String; var grade: Int; var uses: Int
            var novel: Bool; var guaranteed: Bool; var afterMisses: Int
        }
        struct Fixtures: Decodable { var reforges: [Sample] }
        let url = Bundle.module.url(forResource: "cuttlefish-catalog-parity", withExtension: "json", subdirectory: "Fixtures")!
        let samples = try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url)).reforges
        XCTAssertEqual(samples.count, 72)
        for sample in samples {
            var (s, ids) = setup()
            s.discovered.formUnion(sample.history); s.reforgeMisses = sample.misses
            var random = FishRandom(seed: sample.seed)
            let result = try s.reforge(ids, at: now, random: &random)
            XCTAssertEqual(result.child.speciesID, sample.species)
            XCTAssertEqual(result.child.grade, sample.grade)
            XCTAssertEqual(result.child.uses, sample.uses)
            XCTAssertEqual(result.novel, sample.novel)
            XCTAssertEqual(result.guaranteed, sample.guaranteed)
            XCTAssertEqual(s.reforgeMisses, sample.afterMisses)
            XCTAssertTrue(s.isValid)
        }
    }

    func testReforgeConsumesThreeRetainsProgressAndBanksGrowthOnlyOnce() throws {
        var (s, ids) = setup(); s.hearts = 0
        let before = s
        var random = FishRandom(seed: 0x12345678)
        let result = try s.reforge(ids, at: now, random: &random)
        XCTAssertEqual(s.fish.count, before.fish.count - 2)
        XCTAssertTrue(Set(ids).isDisjoint(with: s.fish.map(\.id)))
        XCTAssertEqual(s.hearts, before.hearts); XCTAssertEqual(s.exp, before.exp)
        XCTAssertEqual(s.tankIDs, before.tankIDs)
        XCTAssertEqual(s.decorations, before.decorations); XCTAssertEqual(s.audio, before.audio)
        XCTAssertEqual(result.child.grade, 5); XCTAssertFalse(result.child.locked)
        XCTAssertTrue((1...5).contains(result.child.uses))
        XCTAssertEqual(result.child.birthExp, 0)
        XCTAssertEqual(result.child.maturesAt, now.addingTimeInterval(1200))
        s.advance(to: now.addingTimeInterval(1200))
        XCTAssertEqual(s.exp, before.exp + 5120)
        s.advance(to: now.addingTimeInterval(1300)); XCTAssertEqual(s.exp, before.exp + 5120)
        XCTAssertTrue(s.isValid)
    }

    func testEveryRejectedInputPreservesInventoryPityProgressAndRNG() {
        for kind in 0..<9 {
            var (s, ids) = setup()
            let first = s.fish.firstIndex { $0.id == ids[0] }!
            switch kind {
            case 0: ids[1] = ids[0]
            case 1: ids[1] = UUID()
            case 2: ids.removeLast()
            case 3: ids.append(UUID())
            case 4: s.fish[first].locked = true
            case 5: s.tankIDs = [ids[0]]
            case 6: s.fish[first].maturesAt = now.addingTimeInterval(1)
            case 7: s.fish[first].uses = 1
            default: s.fish[first].speciesID = "jadeturtle"
            }
            s.reforgeMisses = 9
            let before = s
            var random = FishRandom(seed: 7)
            XCTAssertThrowsError(try s.reforge(ids, at: now, random: &random), "case \(kind)")
            XCTAssertEqual(s, before); XCTAssertEqual(random.seed, 7)
        }
    }

    // Invert xorshift32 to place its first draw on either side of the 20% boundary.
    private func seed(output: UInt32) -> UInt32 {
        func left(_ value: UInt32, _ shift: Int) -> UInt32 {
            var x = value; for _ in 0..<32 { x = value ^ (x << shift) }; return x
        }
        func right(_ value: UInt32, _ shift: Int) -> UInt32 {
            var x = value; for _ in 0..<32 { x = value ^ (x >> shift) }; return x
        }
        return left(right(left(output, 5), 17), 13)
    }

    func testChanceBoundaryDuplicateAndNewDiscoveryPity() throws {
        for (draw, hidden) in [(UInt32(858_993_459),true),(UInt32(858_993_460),false)] {
            var (s, ids) = setup(); var random = FishRandom(seed: seed(output: draw))
            let result = try s.reforge(ids, at: now, random: &random)
            XCTAssertEqual(result.child.species.hidden, hidden)
            XCTAssertEqual(s.reforgeMisses, hidden ? 0 : 1)
        }
        var (s, ids) = setup(); var random = FishRandom(seed: 1)
        let original = s
        let first = try s.reforge(ids, at: now, random: &random)
        XCTAssertTrue(first.child.species.hidden)
        s = original; s.discovered.insert(first.child.speciesID); s.reforgeMisses = 6
        random = FishRandom(seed: 1)
        let duplicate = try s.reforge(ids, at: now, random: &random)
        XCTAssertFalse(duplicate.novel); XCTAssertEqual(s.reforgeMisses, 7)
        s = original; s.reforgeMisses = 9
        s.discovered.formUnion(FishCatalog.hidden.prefix(2).map(\.id))
        random = FishRandom(seed: 0xffffffff)
        let guaranteed = try s.reforge(ids, at: now, random: &random)
        XCTAssertTrue(guaranteed.guaranteed); XCTAssertEqual(guaranteed.child.speciesID, "starnautilus")
        XCTAssertEqual(s.reforgeMisses, 0); XCTAssertTrue(s.earnedAchievements.contains("secret-trio"))
    }

    func testThirtyMissesGuaranteeAllThreeAndCompletionStopsPity() throws {
        var s = AquariumState.newGame(at: now)
        for n in 1...30 {
            let input = [material(),material(),material()];s.fish += input
            // A fresh high first roll forces a regular result except for guarantees.
            var random = FishRandom(seed: seed(output: UInt32.max))
            let result = try s.reforge(input.map(\.id), at: now, random: &random)
            XCTAssertEqual(result.guaranteed, n % 10 == 0)
            XCTAssertEqual(s.hiddenDiscoveredCount, n / 10)
        }
        XCTAssertTrue(s.earnedAchievements.contains("secret-encounter"))
        XCTAssertTrue(s.earnedAchievements.contains("secret-trio"))
        let input = [material(),material(),material()];s.fish += input;s.reforgeMisses = 9
        var random = FishRandom(seed: seed(output: UInt32.max))
        let result = try s.reforge(input.map(\.id), at: now, random: &random)
        XCTAssertFalse(result.guaranteed);XCTAssertEqual(s.reforgeMisses, 0)
        for id in FishCatalog.hidden.map(\.id) {
            for f in s.fish.filter({ $0.speciesID == id }) { try s.release(f.id) }
        }
        s.syncAchievements()
        XCTAssertTrue(s.earnedAchievements.contains("secret-trio"))
    }

    func testHiddenCreaturesCannotLeakIntoOrdinaryPoolsOrProgress() throws {
        let before = AquariumState.newGame(at: now)
        XCTAssertEqual(FishCatalog.regular.count, 30);XCTAssertEqual(FishCatalog.hidden.count, 3)
        for tier in 0...5 { XCTAssertTrue(FishCatalog.pool(tier: tier).allSatisfy { !$0.hidden }) }
        var s = before
        for sp in FishCatalog.hidden { s.discovered.insert(sp.id);s.discoveredVariants.insert("\(sp.id):5") }
        XCTAssertEqual(s.regularDiscoveredCount, before.regularDiscoveredCount)
        XCTAssertEqual(s.regularVariantCount, before.regularVariantCount)
        XCTAssertEqual(Array(s.achievementProgress.prefix(14)), before.achievementProgress.prefix(14).map { $0 })
        s.fish = FishCatalog.hidden.prefix(2).map { AquariumFish.make(species: $0, at: now, adult: true) }
        s.tankIDs = []
        var random = FishRandom(seed: 7)
        for _ in 0..<1000 {
            s.hearts = 5;for i in 0..<2 { s.fish[i].uses = 5; s.fish[i].maxUses = 5 }
            let result = try s.breed(Array(s.fish.prefix(2).map(\.id)), at: now, random: &random)
            XCTAssertFalse(result.child.species.hidden);s.fish.removeLast(); s.tankIDs = []
        }
        s.discovered = Set(FishCatalog.regular.map(\.id))
        s.discoveredVariants = Set(FishCatalog.regular.flatMap { sp in (1...5).map { "\(sp.id):\($0)" } })
        XCTAssertEqual(s.breedRecommendation(at: now).reason, .complete)
    }

    func testCatalogVisibilityAndAutoSelectionProtectFish() {
        let prepared = setup()
        var s = prepared.0
        let ids = prepared.1
        XCTAssertEqual(s.catalogSpecies.count, 30)
        XCTAssertFalse(s.catalogSpecies.contains(where: \.hidden))
        s.discovered.insert("glassangel")
        XCTAssertEqual(s.catalogSpecies.filter(\.hidden).map(\.id), ["glassangel"])
        var extras = [material(5),material(5),material(5),material(5)]
        extras[0].locked = true;extras[1].uses = 1;extras[2].maturesAt = now.addingTimeInterval(1)
        s.fish += extras;s.tankIDs = [extras[3].id]
        let picked = s.autoReforgeSelection(at: now)
        XCTAssertEqual(Set(picked), Set(ids))
        XCTAssertEqual(picked.first, ids[2])
        XCTAssertEqual(s.reforgeCandidates(at: now).count, 3)
    }

    func testSavePityMigrationRoundTripAndMalformedValues() throws {
        var (s, _) = setup();s.reforgeMisses = 9
        s.discovered.insert("glassangel");s.discoveredVariants.insert("glassangel:5");s.syncAchievements()
        XCTAssertEqual(try AquariumSave.decode(JSONEncoder().encode(s)),s)
        XCTAssertEqual(try AquariumBackup.parse(AquariumBackup.export(s)),s)
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(s)) as! [String:Any]
        object.removeValue(forKey:"reforgeMisses")
        let migrated = try AquariumSave.decode(JSONSerialization.data(withJSONObject:object))
        XCTAssertEqual(migrated.reforgeMisses,0);XCTAssertEqual(migrated.fish,s.fish)
        for invalid: Any in [-1,10,1.2,"9",NSNull()] {
            object["reforgeMisses"] = invalid
            XCTAssertThrowsError(try AquariumSave.decode(JSONSerialization.data(withJSONObject:object)))
        }
    }

    func testWebBackupPreservesHiddenFishAndPityAndRejectsMalformedCounters() throws {
        let url = Bundle.module.url(forResource: "web-save", withExtension: "json", subdirectory: "Fixtures")!
        var envelope = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        var web = envelope["state"] as! [String: Any]
        var fish = web["fish"] as! [[String: Any]]
        fish[3]["speciesId"] = "glassangel"; fish[3]["tier"] = 5
        fish[3]["grade"] = 5; fish[3]["uses"] = 0; fish[3]["maxUses"] = 2
        web["fish"] = fish; web["reforgeMisses"] = 7; envelope["state"] = web
        let imported = try AquariumBackup.parse(JSONSerialization.data(withJSONObject: envelope))
        XCTAssertEqual(imported.reforgeMisses, 7)
        XCTAssertEqual(imported.fish[3].speciesID, "glassangel")
        XCTAssertTrue(imported.earnedAchievements.contains("secret-encounter"))
        for invalid: Any in [-1,10,1.2,"9",NSNull()] {
            web["reforgeMisses"] = invalid; envelope["state"] = web
            XCTAssertThrowsError(try AquariumBackup.parse(JSONSerialization.data(withJSONObject: envelope)))
        }
    }

    func testFixedSeedSamplingIsCloseToEightyTwentyAndUniformSecrets() throws {
        var (s, ids) = setup();s.discovered.formUnion(FishCatalog.hidden.map(\.id))
        let original = s
        var random = FishRandom(seed:0x98765432),counts:[String:Int] = [:]
        for _ in 0..<12000 {
            s = original
            let result = try s.reforge(ids,at:now,random:&random)
            counts[result.child.speciesID, default:0] += 1
        }
        for sp in FishCatalog.hidden { XCTAssertEqual(Double(counts[sp.id,default:0])/12000,0.2/3,accuracy:0.012) }
        for sp in FishCatalog.pool(tier:5) { XCTAssertEqual(Double(counts[sp.id,default:0])/12000,0.8/4,accuracy:0.018) }
    }
}
