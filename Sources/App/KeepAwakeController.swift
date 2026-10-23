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
        case .off: return L10n.text("Off")
        case .system: return L10n.text("Keep Computer Awake")
        case .display: return L10n.text("Keep Screen On Too")
        }
    }
}

struct KeepAwakeSettingsView: View {
    @ObservedObject private var localization = AppLocalization.shared
    @ObservedObject private var wake = KeepAwakeController.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text("Keep Awake")).font(PixelTheme.font(24)).foregroundStyle(PixelTheme.gold)
            PixelChoiceField(id: "settings.keepAwake", label: L10n.text("Keep Awake"),
                selection: Binding(get: { wake.mode.rawValue }, set: { if let m = KeepAwakeController.Mode(rawValue: $0) { wake.select(m) } }),
                choices: KeepAwakeController.Mode.allCases.map { PixelChoice(id: $0.rawValue, title: $0.title) })
                .frame(maxWidth: 440)
            Text(L10n.text("Allows the display to sleep and the screen to lock. Screen-on mode also prevents idle display sleep. Manual sleep and lid closing still work. Quitting the app ends Keep Awake."))
                .foregroundStyle(PixelTheme.muted).fixedSize(horizontal: false, vertical: true)
            if wake.failed {
                Text(L10n.text("Could not change Keep Awake. The previous mode is still active. Try again."))
                    .foregroundStyle(PixelTheme.gold).fixedSize(horizontal: false, vertical: true)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
