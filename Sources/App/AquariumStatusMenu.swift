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
        item.button?.toolTip = "Fishtank · 口袋海洋"
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
        rebuild()
    }
    private func updateTooltip() {
        item.button?.toolTip = "\(indicator.detail)\n\(store.state.fish.count) 条鱼 · 可用繁育爱心 \(store.state.hearts) 颗（每次繁育消耗一颗）"
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
        caption("鱼 \(store.state.fish.count) · 爱心 \(store.state.hearts)/5")
        if let date = store.state.nextMaturity(after: store.now) { caption("下次就绪 \(date.formatted(date: .omitted, time: .shortened))") }
        menu.addItem(.separator())
        action("养成手册", icon: "book", key: "o") { aquarium.showManagement() }
        action(aquarium.isVisible ? "隐藏鱼缸" : "显示鱼缸", icon: "eye") {
            aquarium.isVisible ? aquarium.hide() : aquarium.show()
        }
        action("置顶", icon: "pin", checked: aquarium.isPinned) { aquarium.isPinned.toggle() }
        let opacity = submenu("透明度", icon: "drop")
        for (title, value) in [("50% · 默认", 0.5), ("75% · 更深", 0.75), ("100% · 不透明", 1.0)] {
            action(title, checked: aquarium.waterOpacity == value, in: opacity) { aquarium.waterOpacity = value }
        }
        let size = submenu("大小", icon: "size")
        for (title, value) in [("小 · 320 × 180", 1), ("中 · 640 × 360", 2), ("大 · 960 × 540", 3)] {
            action(title, checked: aquarium.pixelScale == value, in: size) { aquarium.pixelScale = value }
        }
        action("移回屏幕", icon: "move") { aquarium.moveToCurrentScreen() }
        action("投喂", icon: "food") { aquarium.feed() }
        action("养成提醒", icon: "bell", checked: store.remindersEnabled) {
            store.setReminders(!store.remindersEnabled)
        }
        menu.addItem(.separator())
        action("设置…", icon: "gearshape", key: ",") { aquarium.showAgentSettings() }
        action("暂停 Agent 提醒", icon: "bell", checked: aquarium.agentSettings.paused) { aquarium.agentSettings.paused.toggle() }
        action("提醒声音", icon: "bell", checked: aquarium.agentSoundsEnabled) { aquarium.agentSoundsEnabled.toggle() }
        menu.addItem(.separator())
        action("退出 Fishtank", icon: "power", key: "q") { NSApp.terminate(nil) }
    }
}
#endif
