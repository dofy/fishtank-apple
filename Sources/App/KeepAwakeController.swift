#if os(macOS)
import SwiftUI
import IOKit.pwr_mgt

/// Assertions only prevent idle sleep. Explicit sleep and lid policy remain system-owned.
@MainActor
final class KeepAwakeController: ObservableObject {
    typealias Mode = KeepAwakeSession.Mode
    static let shared = KeepAwakeController()
    @Published private(set) var mode: Mode = .off
    @Published private(set) var failed = false
    private let session = KeepAwakeSession(create: { kind in
        let type = kind == .system ? kIOPMAssertionTypePreventUserIdleSystemSleep : kIOPMAssertionTypePreventUserIdleDisplaySleep
        var id: IOPMAssertionID = 0
        let status = IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                "Fishtank Keep Awake" as CFString, &id)
        return status == kIOReturnSuccess ? id : nil
    }, release: { IOPMAssertionRelease($0) })
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        select(Mode(rawValue: defaults.string(forKey: "power.keepAwake") ?? "") ?? .off)
    }
    func select(_ next: Mode) {
        guard session.select(next) else { failed = true; return }
        mode = session.mode; failed = false
        defaults.set(next.rawValue, forKey: "power.keepAwake")
    }
    func releaseAssertions() { session.stop() }

}

extension KeepAwakeSession.Mode {
    var title: String {
        switch self {
        case .off: return L10n.text("关闭")
        case .system: return L10n.text("保持电脑运行")
        case .display: return L10n.text("同时保持屏幕常亮")
        }
    }
}

struct KeepAwakeSettingsView: View {
    @ObservedObject private var wake = KeepAwakeController.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text("保持唤醒")).font(PixelTheme.font(24)).foregroundStyle(PixelTheme.gold)
            PixelChoiceField(id: "settings.keepAwake", label: L10n.text("保持唤醒"),
                selection: Binding(get: { wake.mode.rawValue }, set: { if let m = KeepAwakeController.Mode(rawValue: $0) { wake.select(m) } }),
                choices: KeepAwakeController.Mode.allCases.map { PixelChoice(id: $0.rawValue, title: $0.title) })
                .frame(maxWidth: 440)
            Text(L10n.text("允许熄屏和锁屏；屏幕常亮模式也会阻止自动熄屏。手动睡眠和合盖不受影响，退出 App 后停止保持唤醒。"))
                .foregroundStyle(PixelTheme.muted).fixedSize(horizontal: false, vertical: true)
            if wake.failed {
                Text(L10n.text("无法更改保持唤醒，已保留原模式。请重试。"))
                    .foregroundStyle(PixelTheme.gold).fixedSize(horizontal: false, vertical: true)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
