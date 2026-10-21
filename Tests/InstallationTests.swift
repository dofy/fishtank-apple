import XCTest
@testable import FishtankCore

final class InstallationTests: XCTestCase {
    func fixture(_ defaults: UserDefaults) -> AquariumInstallation {
        defaults.set(true, forKey: "aquarium.pinned")
        defaults.set(0.75, forKey: "aquarium.waterOpacity")
        defaults.set(2, forKey: "aquarium.pixelScale")
        defaults.set("100 200 640 360 0 0 1920 1080", forKey: "NSWindow Frame FishtankFloatingAquarium")
        defaults.set(true, forKey: "remindersEnabled")
        return AquariumInstallation(sourceBundleID: AquariumInstallation.legacyBundleID,
            state: .newGame(at: Date(timeIntervalSince1970: 1_800_000_000)),
            preferences: .init(defaults: defaults), recovery: ["aquarium-v1.json.recent.json": Data("raw previous save".utf8)])
    }
    func withDefaults(_ action: (UserDefaults, UserDefaults) throws -> Void) rethrows {
        let a = "fishtank-transfer-source-" + UUID().uuidString
        let b = "fishtank-transfer-destination-" + UUID().uuidString
        let source = UserDefaults(suiteName: a)!, target = UserDefaults(suiteName: b)!
        defer { source.removePersistentDomain(forName: a); target.removePersistentDomain(forName: b) }
        try action(source, target)
    }
    func testTransferPreservesCompleteStatePreferencesAndRawRecoveryFile() throws {
        try withDefaults { source, target in
            let snapshot = fixture(source)
            let decoded = try AquariumInstallation.decode(JSONEncoder().encode(snapshot))
            let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: parent) }
            let directory = parent.appendingPathComponent("tank")
            try decoded.install(into: directory, defaults: target)
            XCTAssertEqual(try AquariumSave.decode(Data(contentsOf: directory.appendingPathComponent("aquarium-v1.json"))), snapshot.state)
            XCTAssertEqual(AquariumInstallation.Preferences(defaults: target), snapshot.preferences)
            XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("aquarium-v1.json.recent.json")), snapshot.recovery.values.first)
            XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("installation-transfer.json").path))
        }
    }
    func testExistingDestinationCannotBeOverwrittenOrPreferencesChanged() throws {
        try withDefaults { source, target in
            let snapshot = fixture(source)
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let primary = directory.appendingPathComponent("aquarium-v1.json")
            let valuable = Data("existing valuable save".utf8)
            try valuable.write(to: primary)
            let before = AquariumInstallation.Preferences(defaults: target)
            XCTAssertThrowsError(try snapshot.install(into: directory, defaults: target))
            XCTAssertEqual(try Data(contentsOf: primary), valuable)
            XCTAssertEqual(AquariumInstallation.Preferences(defaults: target), before)
        }
    }
    func testTransferRejectsUnexpectedIdentityAndRecoveryPaths() throws {
        try withDefaults { source, _ in
            var snapshot = fixture(source)
            snapshot.sourceBundleID = "another.app"
            XCTAssertThrowsError(try AquariumInstallation.decode(JSONEncoder().encode(snapshot)))
            snapshot.sourceBundleID = AquariumInstallation.legacyBundleID
            snapshot.recovery["../outside.json"] = Data()
            XCTAssertThrowsError(try AquariumInstallation.decode(JSONEncoder().encode(snapshot)))
        }
    }
    func testInvalidSettingsAndCorruptTransferCannotCreateDestination() throws {
        try withDefaults { source, target in
            var snapshot = fixture(source)
            snapshot.preferences.pixelScale = 99
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            XCTAssertThrowsError(try snapshot.install(into: directory, defaults: target))
            XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
            XCTAssertThrowsError(try AquariumInstallation.decode(Data("corrupt".utf8)))
        }
    }
}
