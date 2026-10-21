import XCTest
@testable import FishtankCore

final class BackupTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)
    private func fixture() throws -> Data { try Data(contentsOf: Bundle.module.url(forResource: "web-save", withExtension: "json", subdirectory: "Fixtures")!) }
    func testOriginalWebExportMigratesEveryFishAndSettings() throws {
        let data = try fixture(), imported = try AquariumBackup.parse(data)
        let object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let web = object["state"] as! [String: Any]
        let fish = web["fish"] as! [[String: Any]]
        XCTAssertEqual(imported.fish.count, fish.count)
        for (native, web) in zip(imported.fish, fish) {
            XCTAssertEqual(native.speciesID, web["speciesId"] as? String)
            XCTAssertEqual(native.grade, web["grade"] as? Int)
            XCTAssertEqual(native.uses, web["uses"] as? Int)
            XCTAssertEqual(native.expBanked, web["expBanked"] as? Bool)
        }
        XCTAssertEqual(imported.exp, 57760)
        XCTAssertEqual(imported.tankIDs.count, 12)
        XCTAssertEqual(imported.lighting, .night)
        XCTAssertEqual(imported.audio.track, "tide")
        XCTAssertFalse(imported.audio.sfxEnabled)
        XCTAssertEqual(imported.audio.sfxVolume, 0.3)
        XCTAssertFalse(imported.railLights.animated)
        XCTAssertEqual(imported.railLights.frequency, 1.2)
        XCTAssertEqual(imported.decorations.map(\.id), ["kelp", "arch", "fairylights"])
        XCTAssertEqual(imported.decorations[1].flip, -1)
        XCTAssertTrue(imported.fish[3].locked)
        let snapshot = try JSONSerialization.jsonObject(with: imported.webSourceSnapshot!) as! [String: Any]
        XCTAssertEqual((snapshot["fish"] as! [[String: Any]])[3]["nickname"] as? String, "保留的旧昵称")
        XCTAssertEqual(try AquariumBackup.parse(AquariumBackup.export(imported)), imported)
        XCTAssertEqual(try AquariumSave.decode(JSONEncoder().encode(imported)), imported)
    }
    func testMalformedImportsRejectedWithoutNormalizingAwayFish() throws {
        let fixture = try JSONSerialization.jsonObject(with: fixture()) as! [String: Any]
        let original = fixture["state"] as! [String: Any]
        let mutations: [(inout [String: Any]) -> Void] = [
            { $0["version"] = 99 }, { $0["hearts"] = true }, { $0["exp"] = 1.5 },
            { $0["locale"] = 4 }, { $0["tankUids"] = ["missing-fish"] },
            { var f = $0["fish"] as! [[String: Any]]; f.append(f[0]); $0["fish"] = f },
            { var f = $0["fish"] as! [[String: Any]]; f[0]["speciesId"] = "unknown"; $0["fish"] = f },
            { var f = $0["fish"] as! [[String: Any]]; f[0]["maturesAt"] = -1; $0["fish"] = f },
            { $0["discovered"] = ["not-a-species"] }, { $0["railLights"] = ["animated":true,"frequency":20] },
            { $0["audio"] = ["sfxEnabled":true,"sfxVolume":true,"bgmEnabled":true,"bgmVolume":0.4,"bgmTrack":"lofi"] }
        ]
        for mutate in mutations {
            var value = original; mutate(&value)
            XCTAssertThrowsError(try AquariumBackup.parse(JSONSerialization.data(withJSONObject: value)))
        }
        XCTAssertThrowsError(try AquariumBackup.parse(Data(repeating: 65, count: AquariumBackup.maximumBytes + 1)))
    }
    func testExplicitEmptyWebTankRemainsEmptyAndLegacyVariantsBackfill() throws {
        let fixture = try JSONSerialization.jsonObject(with: fixture()) as! [String: Any]
        var value = fixture["state"] as! [String: Any]
        value["tankUids"] = []; value.removeValue(forKey: "discoveredVariants")
        let state = try AquariumBackup.parse(JSONSerialization.data(withJSONObject: value))
        XCTAssertTrue(state.tankIDs.isEmpty)
        XCTAssertTrue(state.discoveredVariants.contains("copperband:5"))
    }
    func testAtomicRepositoryRotatesAndPreservesPreRestoreBytes() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = AquariumRepository(primary: directory.appendingPathComponent("save.json"))
        let first = AquariumState.newGame(at: date)
        try repo.persist(first)
        var second = first; second.hearts = 4
        try repo.persist(second)
        XCTAssertEqual(try AquariumSave.decode(repo.read(repo.primary)), second)
        XCTAssertEqual(try AquariumSave.decode(repo.read(repo.recent)), first)
        let bad = Data("broken save, retain these bytes".utf8)
        try bad.write(to: repo.primary)
        XCTAssertThrowsError(try repo.persist(first, at: date.addingTimeInterval(3600)))
        XCTAssertEqual(try repo.read(repo.primary), bad)
        XCTAssertEqual(try AquariumSave.decode(repo.read(repo.recent)), first)
        try repo.persist(first, replacing: true)
        XCTAssertEqual(try repo.read(repo.preRestore), bad)
        XCTAssertEqual(try AquariumSave.decode(repo.read(repo.primary)), first)
    }
    func testFailedRecoverySnapshotNeverReplacesPrimary() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = AquariumRepository(primary: directory.appendingPathComponent("save.json"))
        let first = AquariumState.newGame(at: date)
        try repo.persist(first)
        try FileManager.default.createDirectory(at: repo.preRestore, withIntermediateDirectories: true)
        var replacement = first; replacement.hearts = 1
        XCTAssertThrowsError(try repo.persist(replacement, replacing: true))
        XCTAssertEqual(try AquariumSave.decode(repo.read(repo.primary)), first)
    }
    func testOversizedCorruptPrimaryCanBePreservedBeforeRecovery() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = AquariumRepository(primary: directory.appendingPathComponent("save.json"))
        let oversized = Data(repeating: 65, count: AquariumBackup.maximumBytes + 1)
        try oversized.write(to: repo.primary)
        let valid = AquariumState.newGame(at: date)
        try repo.persist(valid, replacing: true)
        XCTAssertEqual(try Data(contentsOf: repo.preRestore), oversized)
        XCTAssertEqual(try AquariumSave.decode(repo.read(repo.primary)), valid)
        var replacement = valid; replacement.hearts = 3
        try repo.persist(replacement, replacing: true)
        XCTAssertEqual(try AquariumSave.decode(repo.read(repo.preRestore)), valid)
    }

}
