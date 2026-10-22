import AppKit
import CryptoKit

/// Compile with AppIconCatalog + AppIconStore into an isolated QA .app containing icon resources.
/// Uses only the QA app's icon metadata and a temporary preferences suite.
@main struct VerifyAppIcons {
    @MainActor static func main() throws {
        guard Bundle.main.bundleIdentifier?.hasPrefix("net.yahaha.fishtank.renderqa.") == true else {
            FileHandle.standardError.write(Data("Requires an isolated QA bundle\n".utf8)); exit(2)
        }
        func require(_ condition: Bool, _ message: String = "Icon verification failed") {
            guard condition else { FileHandle.standardError.write(Data(("FAIL " + message + "\n").utf8)); exit(2) }
        }
        _ = NSApplication.shared
        let suite = "net.yahaha.fishtank.renderqa.icons." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var discovered: Set<String> = []
        let icons = AppIconStore(defaults: defaults, discovered: { discovered })
        icons.apply(AppIconCatalog.design("astraljelly"))
        require(icons.currentID == "classic" && defaults.string(forKey: AppIconCatalog.preferenceKey) == nil, "Locked icon changed saved selection")
        require(icons.error != nil, "Model must reject undiscovered species even outside the settings view")
        discovered = Set(FishCatalog.all.map(\.id))
        let contents = Bundle.main.bundleURL.appendingPathComponent("Contents")
        func manifest() throws -> [String: Data] {
            let urls = FileManager.default.enumerator(at: contents, includingPropertiesForKeys: [.isRegularFileKey])!
            var result: [String: Data] = [:]
            for case let url as URL in urls where try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                result[url.path] = Data(SHA256.hash(data: try Data(contentsOf: url)))
            }
            return result
        }
        func raster(_ image: NSImage) -> Data {
            let c = CGContext(data: nil, width: 512, height: 512, bitsPerComponent: 8, bytesPerRow: 2048,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: c, flipped: false)
            image.draw(in: NSRect(x: 0, y: 0, width: 512, height: 512)); NSGraphicsContext.restoreGraphicsState()
            return Data(bytes: c.data!, count: 512 * 512 * 4)
        }
        let before = try manifest()
        for design in AppIconCatalog.variants {
            require(AppIconStore.image(design) != nil)
            icons.apply(design)
            require(icons.currentID == design.id, icons.error ?? "Failed to apply icon")
            require(AppIconStore(defaults: defaults).currentID == design.id)
        }
        NSApp.applicationIconImage = nil
        AppIconStore.restoreRuntime(defaults: defaults)
        let expected = raster(AppIconStore.image(icons.current)!)
        let actual = raster(NSApp.applicationIconImage!)
        // macOS may add Dock material highlights. A wrong fish produces a much larger difference.
        let delta = zip(actual, expected).reduce(0.0) { $0 + abs(Double($1.0) - Double($1.1)) } / Double(actual.count)
        require(delta < 5, "Restored icon differs from the selected artwork")
        icons.apply(AppIconCatalog.original)
        require(icons.currentID == "classic" && defaults.string(forKey: AppIconCatalog.preferenceKey) == nil)
        defaults.set("removed-icon", forKey: AppIconCatalog.preferenceKey)
        require(AppIconStore(defaults: defaults).currentID == "classic")
        let after = try manifest()
        require(before == after, "Icon changes must not mutate signed Contents resources")
        print("PASS \(AppIconCatalog.variants.count) icon applications, persistent selection, runtime restoration, default reset, unknown ID fallback and unchanged signed resources")
    }
}
