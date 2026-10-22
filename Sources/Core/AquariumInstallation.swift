import Foundation

/// Explicit transfer between the original prototype identity and the Mac product.
/// The original sandbox remains intact; installation never overwrites a destination.
struct AquariumInstallation: Codable {
    static let legacyBundleID = "net.yahaha.fishtank.apple.mac"
    static let macBundleID = "net.yahaha.fishtank.mac"
    static let maximumBytes = AquariumBackup.maximumBytes * 6
    static let recoveryNames: Set<String> = [
        "aquarium-v1.json.recent.json", "aquarium-v1.json.pre-restore.json",
        "aquarium-v1.json.prototype-backup", "aquarium-v1.json.schema-2-backup"
    ]
    struct Preferences: Codable, Equatable {
        var pinned: Bool?
        var waterOpacity: Double?
        var pixelScale: Int?
        var floatingFrame: String?
        var remindersEnabled: Bool
        var languagePreference: String?

        init(defaults: UserDefaults) {
            pinned = defaults.object(forKey: "aquarium.pinned") as? Bool
            waterOpacity = defaults.object(forKey: "aquarium.waterOpacity") as? Double
            pixelScale = defaults.object(forKey: "aquarium.pixelScale") as? Int
            floatingFrame = defaults.string(forKey: "NSWindow Frame FishtankFloatingAquarium")
            remindersEnabled = defaults.bool(forKey: "remindersEnabled")
            languagePreference = defaults.string(forKey: L10n.preferenceKey)
                .flatMap(L10n.Preference.init(rawValue:))?.rawValue
        }
        var isValid: Bool {
            (waterOpacity.map { $0.isFinite && (0...1).contains($0) } ?? true)
            && (pixelScale.map { (1...3).contains($0) } ?? true)
            && (floatingFrame.map { $0.count <= 1024 } ?? true)
            && (languagePreference.map { L10n.Preference(rawValue: $0) != nil } ?? true)
        }
        func apply(to defaults: UserDefaults) {
            if let pinned { defaults.set(pinned, forKey: "aquarium.pinned") }
            if let waterOpacity { defaults.set(waterOpacity, forKey: "aquarium.waterOpacity") }
            if let pixelScale { defaults.set(pixelScale, forKey: "aquarium.pixelScale") }
            if let floatingFrame { defaults.set(floatingFrame, forKey: "NSWindow Frame FishtankFloatingAquarium") }
            defaults.set(remindersEnabled, forKey: "remindersEnabled")
            if let languagePreference { defaults.set(languagePreference, forKey: L10n.preferenceKey) }
        }
    }
    var format = "fishtank-installation-transfer"
    var version = 1
    var sourceBundleID: String
    var state: AquariumState
    var preferences: Preferences
    var recovery: [String: Data]

    static func decode(_ data: Data) throws -> Self {
        guard data.count <= maximumBytes else { throw AquariumError.invalidSave }
        let value = try JSONDecoder().decode(Self.self, from: data)
        guard value.format == "fishtank-installation-transfer", value.version == 1,
              value.sourceBundleID == legacyBundleID, value.state.isValid, value.preferences.isValid,
              Set(value.recovery.keys).isSubset(of: recoveryNames),
              value.recovery.values.allSatisfy({ $0.count <= AquariumBackup.maximumBytes }) else { throw AquariumError.invalidSave }
        return value
    }

    func install(into directory: URL, defaults: UserDefaults) throws {
        // Revalidate even when constructed in-process rather than decoded.
        _ = try Self.decode(JSONEncoder().encode(self))
        let manager = FileManager.default
        guard !manager.fileExists(atPath: directory.path) else { throw AquariumError.invalidSave }
        let parent = directory.deletingLastPathComponent()
        try manager.createDirectory(at: parent, withIntermediateDirectories: true)
        let staging = parent.appendingPathComponent("fishtank-transfer-" + UUID().uuidString)
        defer { try? manager.removeItem(at: staging) }
        try manager.createDirectory(at: staging, withIntermediateDirectories: false)
        try JSONEncoder().encode(state).write(to: staging.appendingPathComponent("aquarium-v1.json"), options: .atomic)
        for (name, data) in recovery { try data.write(to: staging.appendingPathComponent(name), options: .atomic) }
        // Preserve the full transfer for recovery and independent verification.
        try JSONEncoder().encode(self).write(to: staging.appendingPathComponent("installation-transfer.json"), options: .atomic)
        try manager.moveItem(at: staging, to: directory)
        preferences.apply(to: defaults)
        defaults.synchronize()
    }
}
