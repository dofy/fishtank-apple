import SwiftUI
import Combine

extension Notification.Name {
    static let aquariumLanguageDidChange = Notification.Name("FishtankLanguageDidChange")
    static let aquariumWindowWillDrag = Notification.Name("FishtankWindowWillDrag")
}

/// Change text and its embedded font before publishing a single UI refresh.
/// Observing views keep their identity, navigation, selections and drafts.
@MainActor final class AppLocalization: ObservableObject {
    static let shared = AppLocalization()
    @Published private(set) var preference = L10n.selectedPreference()
    @Published private(set) var revision = 0
    private var systemObserver: AnyCancellable?

    private init() {
        systemObserver = NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)
            .receive(on: DispatchQueue.main).sink { [weak self] _ in
                guard let self, self.preference == .system else { return }
                self.select(.system)
            }
    }

    func select(_ preference: L10n.Preference) {
        UserDefaults.standard.set(preference.rawValue, forKey: L10n.preferenceKey)
        let next = preference.language(preferredLanguages: Locale.preferredLanguages)
        let changed = next != L10n.language
        if changed {
            L10n.activate(next)
            PixelTheme.registerFont()
        }
        self.preference = preference
        if changed {
            revision += 1
            NotificationCenter.default.post(name: .aquariumLanguageDidChange, object: nil)
        }
    }
}
