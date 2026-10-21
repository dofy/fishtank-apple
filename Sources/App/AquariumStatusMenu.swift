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
        item.button?.image = PixelArt.menuIcon
        item.button?.imagePosition = .imageLeading
        item.button?.toolTip = "Fishtank · 口袋海洋"
        observer = store.$state.combineLatest(store.$now).map { state, now in
            "\(state.fish.count) · \(state.hearts)"
        }.removeDuplicates().sink { [weak self] title in
            self?.latestTitle = title
            if self?.tracking == false { self?.item.button?.title = title }
            if let self { self.item.button?.toolTip = "\(self.store.state.fish.count) 条鱼 · 可用繁育爱心 \(self.store.state.hearts) 颗（每次繁育消耗一颗）" }
        }
        rebuild()
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
    private func submenu(_ title: String, icon: String) -> NSMenu {
        let row = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        setIcon(icon, on: row)
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
        caption("FISHTANK")
        caption("鱼群 \(store.state.fish.count) 条 · 可配对 \(store.state.fish.filter { $0.canBreed(at: store.now) }.count) 条")
        let growing = store.state.fish.filter { !$0.expBanked && !$0.isAdult(at: store.now) }.count
        let cooling = store.state.fish.filter { $0.expBanked && !$0.isAdult(at: store.now) }.count
        caption("成长中 \(growing) 条 · 冷却中 \(cooling) 条")
        caption("繁育爱心 " + String(repeating: "♥", count: store.state.hearts) + String(repeating: "♡", count: 5 - store.state.hearts))
        if let date = store.state.nextMaturity(after: store.now) {
            caption("下次就绪 \(date.formatted(date: .omitted, time: .shortened))")
        }
        menu.addItem(.separator())
        action("打开养成手册", icon: "book", key: "o") { aquarium.showManagement() }
        action(aquarium.isVisible ? "隐藏鱼缸" : "显示鱼缸", icon: "eye") {
            aquarium.isVisible ? aquarium.hide() : aquarium.show()
        }
        action("鱼缸全局置顶", icon: "pin", checked: aquarium.isPinned) { aquarium.isPinned.toggle() }
        let opacity = submenu("水体不透明度", icon: "drop")
        for (title, value) in [("50% · 默认", 0.5), ("75% · 更深", 0.75), ("100% · 不透明", 1.0)] {
            action(title, checked: aquarium.waterOpacity == value, in: opacity) { aquarium.waterOpacity = value }
        }
        let size = submenu("鱼缸大小", icon: "size")
        for (title, value) in [("小 · 320 × 180", 1), ("中 · 640 × 360", 2), ("大 · 960 × 540", 3)] {
            action(title, checked: aquarium.pixelScale == value, in: size) { aquarium.pixelScale = value }
        }
        action("移回当前屏幕", icon: "move") { aquarium.moveToCurrentScreen() }
        action("投喂", icon: "food") { aquarium.feed() }
        action("成长 / 冷却 / 爱心回满提醒", icon: "bell", checked: store.remindersEnabled) {
            store.setReminders(!store.remindersEnabled)
        }
        menu.addItem(.separator())
        caption("拖动水面移动鱼缸 · 拖造景布置 · 双击投喂")
        action("退出 Fishtank", icon: "power", key: "q") { NSApp.terminate(nil) }
    }
}
#endif
