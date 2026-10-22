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
            error = L10n.text("图标资源未能读取，请重新打开应用后再试。"); return
        }
        guard AppIconCatalog.isUnlocked(design, discovered: discovered()) else {
            error = L10n.text("发现对应品种后解锁此图标。"); return
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
            panel.title = L10n.text("允许更换图标"); panel.prompt = L10n.text("允许")
            panel.message = L10n.text("请选择当前的 \(target.lastPathComponent)，允许更换访达中的应用图标。应用内容保持不变。")
            panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
            panel.canCreateDirectories = false; panel.treatsFilePackagesAsDirectories = false
            panel.allowedContentTypes = [.applicationBundle]; panel.directoryURL = target.deletingLastPathComponent()
            panel.nameFieldStringValue = target.lastPathComponent
            guard panel.runModal() == .OK, let url = panel.url else { return }
            guard url.standardizedFileURL.resolvingSymlinksInPath() == target else {
                error = L10n.text("请选择正在运行的 \(target.lastPathComponent)。"); return
            }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard NSWorkspace.shared.setIcon(finderImage, forFile: target.path) else {
                error = L10n.text("未能更新应用图标。请确认应用可写，然后再试。"); return
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
