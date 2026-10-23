#if os(macOS)
import AppKit
import Combine
import UniformTypeIdentifiers

@MainActor
final class AppIconStore: ObservableObject {
    @Published private(set) var currentID: String
    @Published private(set) var error: String?
    private let defaults: UserDefaults
    private let bundle: Bundle
    private let discovered: @MainActor () -> Set<String>
    private static let bookmarkKey = "appearance.appIconBookmark"
    var current: AppIconDesign { AppIconCatalog.design(currentID) }

    init(defaults: UserDefaults = .standard, bundle: Bundle = .main, discovered: @escaping @MainActor () -> Set<String> = { [] }) {
        self.defaults = defaults; self.bundle = bundle; self.discovered = discovered
        currentID = AppIconCatalog.design(defaults.string(forKey: AppIconCatalog.preferenceKey)).id
    }
    static func image(_ design: AppIconDesign, bundle: Bundle = .main) -> NSImage? {
        guard let url = bundle.url(forResource: design.resourceName, withExtension: "icns") else { return nil }
        return NSImage(contentsOf: url)
    }
    /// Runtime presentation is restored before the store initializes notifications.
    static func restoreRuntime(defaults: UserDefaults = .standard, bundle: Bundle = .main) {
        let design = AppIconCatalog.design(defaults.string(forKey: AppIconCatalog.preferenceKey))
        if let icon = image(design, bundle: bundle) { NSApplication.shared.applicationIconImage = icon }
    }
    func apply(_ design: AppIconDesign) {
        error = nil
        guard AppIconCatalog.all.contains(where: { $0.id == design.id }), let image = Self.image(design, bundle: bundle) else {
            error = L10n.text("The icon asset could not be read. Reopen the app and try again."); return
        }
        guard AppIconCatalog.isUnlocked(design, discovered: discovered()) else {
            error = L10n.text("Discover the matching species to unlock this icon."); return
        }
        let target = bundle.bundleURL.standardizedFileURL.resolvingSymlinksInPath()
        // Finder's custom icon metadata lives outside Contents. Never replace signed resources.
        let finderImage: NSImage? = design.id == AppIconCatalog.original.id ? nil : image
        var scope: URL?
        defer { scope?.stopAccessingSecurityScopedResource() }
        if let data = defaults.data(forKey: Self.bookmarkKey) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale),
               url.standardizedFileURL.resolvingSymlinksInPath() == target,
               url.startAccessingSecurityScopedResource() {
                scope = url
                if stale, let refreshed = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
                    defaults.set(refreshed, forKey: Self.bookmarkKey)
                }
            }
        }
        if !NSWorkspace.shared.setIcon(finderImage, forFile: target.path) {
            let panel = NSOpenPanel()
            panel.title = L10n.text("Allow Icon Change"); panel.prompt = L10n.text("Allow")
            panel.message = L10n.text("Select the current \(target.lastPathComponent) to allow changing its icon in Finder. The app's contents will remain unchanged.")
            panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
            panel.canCreateDirectories = false; panel.treatsFilePackagesAsDirectories = false
            panel.allowedContentTypes = [.applicationBundle]; panel.directoryURL = target.deletingLastPathComponent()
            panel.nameFieldStringValue = target.lastPathComponent
            guard panel.runModal() == .OK, let url = panel.url else { return }
            guard url.standardizedFileURL.resolvingSymlinksInPath() == target else {
                error = L10n.text("Select the running \(target.lastPathComponent)."); return
            }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard NSWorkspace.shared.setIcon(finderImage, forFile: target.path) else {
                error = L10n.text("Could not update the app icon. Make sure the app is writable and try again."); return
            }
            if let data = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
                defaults.set(data, forKey: Self.bookmarkKey)
            }
        }
        NSApplication.shared.applicationIconImage = image
        currentID = design.id
        if design.id == AppIconCatalog.original.id { defaults.removeObject(forKey: AppIconCatalog.preferenceKey) }
        else { defaults.set(design.id, forKey: AppIconCatalog.preferenceKey) }
    }
}
#endif
