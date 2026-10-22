import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct FishtankApp: App {
    @ObservedObject private var localization = AppLocalization.shared
    init() { PixelTheme.registerFont() }
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AquariumApplicationDelegate.self) private var delegate
    #else
    @StateObject private var store = AquariumStore()
    #endif

    var body: some Scene {
        #if os(macOS)
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button(L10n.text("设置…")) { delegate.aquarium.showAgentSettings() }.keyboardShortcut(",", modifiers: .command)
                }
            }
        #else
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.environment["FISHTANK_UI_TEST_WIDTH"] == "320",
               ProcessInfo.processInfo.environment["FISHTANK_UI_TEST_ID"].flatMap(UUID.init(uuidString:)) != nil {
                AquariumView(store: store).frame(width: 320)
            } else { AquariumView(store: store) }
            #else
            AquariumView(store: store)
            #endif
        }
        #endif
    }
}
