#if os(macOS)
import AppKit
import Combine

/// Native menu instances stay intact throughout tracking, including submenus.
@MainActor
final class AquariumStatusMenu: NSObject, NSMenuDelegate {
    private let store: AquariumStore
    private let aquarium: FloatingAquariumController
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var observer: AnyCancellable?
    private var localizationObserver: AnyCancellable?
    private var indicatorObserver: AnyCancellable?
    private var indicator = AgentMenuIndicator.Presentation.idle
    private var tracking = false
    private var latestTitle = ""

    init(store: AquariumStore, aquarium: FloatingAquariumController) {
        self.store = store
        self.aquarium = aquarium
        super.init()
        menu.autoenablesItems = false
        menu.delegate = self
        item.autosaveName = "FishtankStatusMenu"
        item.isVisible = true
        item.menu = menu
        item.button?.image = MenuFishArt.image(.idle)
        item.button?.imagePosition = .imageLeading
        item.button?.toolTip = L10n.text("Fishtank · Pocket Ocean")
        observer = store.$state.combineLatest(store.$now).map { state, now in
            "\(state.fish.count) · \(state.hearts)"
        }.removeDuplicates().sink { [weak self] title in
            self?.latestTitle = title
            if self?.tracking == false { self?.item.button?.title = title }
            self?.updateTooltip()
        }
        indicatorObserver = store.$now.combineLatest(aquarium.$menuIndicatorRevision).sink { [weak self] _, _ in
            guard let self else { return }
            let next = self.aquarium.menuIndicator(now: Date())
            guard next != self.indicator else { return }
            if next.state != self.indicator.state { self.item.button?.image = MenuFishArt.image(next.state) }
            self.indicator = next; self.updateTooltip()
        }
        localizationObserver = NotificationCenter.default.publisher(for: .aquariumLanguageDidChange).sink { [weak self] _ in
            guard let self else { return }
            self.indicator = self.aquarium.menuIndicator(now: Date())
            self.updateTooltip()
            if !self.tracking { self.rebuild() }
        }
        rebuild()
    }
    private func updateTooltip() {
        item.button?.toolTip = L10n.text("\(indicator.detail)\n\(store.state.fish.count) fish · \(store.state.hearts) breeding hearts available (one per breeding)")
        item.button?.setAccessibilityLabel("Fishtank，" + indicator.detail)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard !tracking else { return }
        store.refresh()
        rebuild()
    }
    func menuWillOpen(_ menu: NSMenu) { tracking = true }
    func menuDidClose(_ menu: NSMenu) {
        tracking = false
        item.button?.title = latestTitle
    }

    private final class ActionBox: NSObject {
        let run: () -> Void
        init(_ run: @escaping () -> Void) { self.run = run }
    }
    @objc private func runMenuAction(_ sender: NSMenuItem) { (sender.representedObject as? ActionBox)?.run() }

    private func action(_ title: String, icon: String? = nil, checked: Bool = false,
                        key: String = "", in parent: NSMenu? = nil, _ run: @escaping () -> Void) {
        let row = NSMenuItem(title: title, action: #selector(runMenuAction(_:)), keyEquivalent: key)
        row.target = self
        row.representedObject = ActionBox(run)
        row.state = checked ? .on : .off
        if let icon { setIcon(icon, on: row) }
        (parent ?? menu).addItem(row)
    }
    private func caption(_ title: String) {
        let row = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        row.isEnabled = false
        menu.addItem(row)
    }
    private func submenu(_ title: String, icon: String, enabled: Bool = true) -> NSMenu {
        let row = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        setIcon(icon, on: row)
        row.isEnabled = enabled
        let child = NSMenu(title: title); child.autoenablesItems = false
        row.submenu = child; menu.addItem(row)
        return child
    }
    private func setIcon(_ name: String, on row: NSMenuItem) {
        row.image = PixelIcon.menuImage(name)
        // macOS 27 may suppress images under its automatic menu policy.
        if #available(macOS 27.0, *) { row.preferredImageVisibility = .visible }
    }
    private func rebuild() {
        menu.removeAllItems()
        let aquarium = self.aquarium, store = self.store
        caption(L10n.text("Fish \(store.state.fish.count) · Hearts \(store.state.hearts)/5"))
        if let date = store.state.nextMaturity(after: store.now) { caption(L10n.text("Next ready in \(date.formatted(date: .omitted, time: .shortened))")) }
        menu.addItem(.separator())
        action(L10n.text("Care Guide"), icon: "book", key: "o") { aquarium.showManagement() }
        action(aquarium.isVisible ? L10n.text("Hide Aquarium") : L10n.text("Show Aquarium"), icon: "eye") {
            aquarium.isVisible ? aquarium.hide() : aquarium.show()
        }
        action(L10n.text("Always on Top"), icon: "pin", checked: aquarium.isPinned) { aquarium.isPinned.toggle() }
        let opacity = submenu(L10n.text("Opacity"), icon: "drop")
        for (title, value) in [(L10n.text("50% · Default"), 0.5), (L10n.text("75% · Darker"), 0.75), (L10n.text("100% · Opaque"), 1.0)] {
            action(title, checked: aquarium.waterOpacity == value, in: opacity) { aquarium.waterOpacity = value }
        }
        let size = submenu(L10n.text("Size"), icon: "size")
        for (title, value) in [(L10n.text("Small · 320 × 180"), 1), (L10n.text("Medium · 640 × 360"), 2), (L10n.text("Large · 960 × 540"), 3)] {
            action(title, checked: aquarium.pixelScale == value, in: size) { aquarium.pixelScale = value }
        }
        let wake = KeepAwakeController.shared
        let wakeMenu = submenu(L10n.text("Keep Awake"), icon: "power")
        menu.items.last?.state = wake.mode == .off ? .off : .on
        for mode in KeepAwakeController.Mode.allCases {
            action(mode.title, checked: wake.mode == mode, in: wakeMenu) { wake.select(mode) }
        }
        if wake.failed { caption(L10n.text("Could not change Keep Awake. The previous mode is still active. Try again.")) }
        action(L10n.text("Move Back On-Screen"), icon: "move") { aquarium.moveToCurrentScreen() }
        action(L10n.text("Feed"), icon: "food") { aquarium.feed() }
        action(L10n.text("Care Alerts"), icon: "bell", checked: store.remindersEnabled) {
            store.setReminders(!store.remindersEnabled)
        }
        menu.addItem(.separator())
        action(L10n.text("Settings…"), icon: "gearshape", key: ",") { aquarium.showAgentSettings() }
        action(L10n.text("Pause Agent Alerts"), icon: "bell", checked: aquarium.agentSettings.paused) { aquarium.agentSettings.paused.toggle() }
        action(L10n.text("Alert Sounds"), icon: "bell", checked: aquarium.agentSoundsEnabled) { aquarium.agentSoundsEnabled.toggle() }
        menu.addItem(.separator())
        action(L10n.text("Quit Fishtank"), icon: "power", key: "q") { NSApp.terminate(nil) }
    }
}
#endif
