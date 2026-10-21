#if os(macOS)
import AppKit
import SpriteKit
import Combine
import SwiftUI

@MainActor
final class AquariumApplicationDelegate: NSObject, NSApplicationDelegate {
    let store: AquariumStore

    override init() {
        // Build products may share the installed app's identity. A second copy
        // must never start another store or schedule notifications for that save.
        if let id = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            exit(0)
        }
        if ProcessInfo.processInfo.arguments.contains("--migrate-installation-state") {
            do {
                guard Bundle.main.bundleIdentifier == AquariumInstallation.macBundleID else { throw AquariumError.invalidSave }
                let data = try FileHandle.standardInput.read(upToCount: AquariumInstallation.maximumBytes + 1) ?? Data()
                let snapshot = try AquariumInstallation.decode(data)
                let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("FishtankApplePrototype", isDirectory: true)
                try snapshot.install(into: directory, defaults: .standard)
            } catch {
                FileHandle.standardError.write(Data("Installation transfer refused: \(error.localizedDescription)\n".utf8))
                exit(1)
            }
        }
        // Establish the runtime app icon before the notification center creates
        // its sender record (the store registers reminders during initialization).
        if let url = Bundle.main.url(forResource: "FishtankIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = icon
        }
        store = AquariumStore()
        super.init()
        store.restoreMigratedPlacementOnce()
    }
    lazy var aquarium = FloatingAquariumController(store: store)
    private var statusMenu: AquariumStatusMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if ProcessInfo.processInfo.arguments.contains("--export-installation-state") {
            do {
                let data = try JSONEncoder().encode(store.installationSnapshot())
                store.stopRemindersForTransfer()
                FileHandle.standardOutput.write(data)
            } catch {
                FileHandle.standardError.write(Data("Installation export failed: \(error.localizedDescription)\n".utf8))
            }
            NSApp.terminate(nil)
            return
        }
        aquarium.show()
        statusMenu = AquariumStatusMenu(store: store, aquarium: aquarium)
        if ProcessInfo.processInfo.arguments.contains("--test-notification") {
            Task { await store.testNotification() }
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--show-management") { aquarium.showManagement() }
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        aquarium.showManagement()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.refresh()
        store.save()
    }
}

/// A desktop companion, independent of app activation and ordinary document windows.
@MainActor
final class FloatingAquariumController: NSObject, ObservableObject, NSWindowDelegate {
    @Published var isPinned: Bool {
        didSet {
            UserDefaults.standard.set(isPinned, forKey: "aquarium.pinned")
            applyWindowLevel()
        }
    }
    @Published var waterOpacity: Double {
        didSet {
            UserDefaults.standard.set(waterOpacity, forKey: "aquarium.waterOpacity")
            scene.setWaterOpacity(CGFloat(waterOpacity))
        }
    }
    @Published var pixelScale: Int {
        didSet {
            UserDefaults.standard.set(pixelScale, forKey: "aquarium.pixelScale")
            resize()
        }
    }
    @Published private(set) var isVisible = false
    private let store: AquariumStore
    private let scene = AquariumScene()
    private let panel: AquariumPanel
    private let spriteView: AquariumDesktopView
    private var motionObserver: NSObjectProtocol?
    private var renderRecoveryObservers: [NSObjectProtocol] = []
    private var stateObserver: AnyCancellable?
    private var animationWatchdog: AnyCancellable?
    private var renderingSuspended = false
    private var lastRenderRecovery = ProcessInfo.processInfo.systemUptime
    private var managementWindow: NSWindow?
    private var displayRecoveryTask: Task<Void, Never>?

    init(store: AquariumStore) {
        self.store = store
        let defaults = UserDefaults.standard
        let savedFrame = defaults.string(forKey: "NSWindow Frame FishtankFloatingAquarium")
        isPinned = defaults.object(forKey: "aquarium.pinned") as? Bool ?? true
        let savedOpacity = defaults.object(forKey: "aquarium.waterOpacity") as? Double ?? 0.5
        // Map earlier presets to the nearest current level; keep stronger water
        // coverage on an exact tie and preserve supported choices unchanged.
        let migratedOpacity = [0.5, 0.75, 1.0].min {
            let left = abs($0 - savedOpacity), right = abs($1 - savedOpacity)
            return left == right ? $0 > $1 : left < right
        } ?? 0.5
        waterOpacity = migratedOpacity
        defaults.set(migratedOpacity, forKey: "aquarium.waterOpacity")
        let savedScale = defaults.integer(forKey: "aquarium.pixelScale")
        let initialScale = (1...3).contains(savedScale) ? savedScale : 2
        pixelScale = initialScale
        let size = NSSize(width: 320 * initialScale, height: 180 * initialScale)
        panel = AquariumPanel(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        spriteView = AquariumDesktopView(frame: NSRect(origin: .zero, size: size))
        super.init()

        panel.title = "Fishtank · 悬浮鱼缸"
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // The view routes water drags to desktop bounds and decoration drags to the
        // scene. AppKit's automatic background dragging would move the panel at
        // the same time as a decoration, cancelling its movement within the tank.
        panel.isMovableByWindowBackground = false
        panel.contentView = spriteView
        panel.setFrameAutosaveName("FishtankFloatingAquarium")
        // Restore position, but keep exact integer multiples of the logical pixel canvas.
        panel.setContentSize(size)
        let displays = NSScreen.screens.map { AquariumDisplayGeometry(frame: $0.frame, visibleFrame: $0.visibleFrame) }
        if let origin = AquariumWindowPlacement.restoredOrigin(from: savedFrame, size: size, displays: displays) {
            panel.setFrameOrigin(origin)
        }
        spriteView.allowsTransparency = true
        spriteView.autoresizingMask = [.width, .height]
        spriteView.preferredFramesPerSecond = 30
        spriteView.toolTip = "拖动水面移动鱼缸，拖造景布置，双击投喂；菜单栏可调透明度、大小与置顶。"
        spriteView.feed = { [weak self] in self?.feed() }
        spriteView.setAccessibilityLabel("半透明悬浮像素鱼缸")
        scene.setWaterOpacity(CGFloat(waterOpacity))
        spriteView.presentScene(scene)
        scene.populate(with: store.state.tankFish)
        scene.syncExtras(from: store.state, at: store.now)
        scene.effect = { [weak store] in store?.sound.play($0) }
        scene.reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        scene.decorationMoved = { [weak store] id, x in store?.moveDecoration(id, to: x) }
        stateObserver = store.$state.sink { [weak self] state in
            self?.scene.populate(with: state.tankFish)
            self?.scene.syncExtras(from: state, at: Date())
        }
        applyWindowLevel()
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }) {
            moveToCurrentScreen()
        }
        motionObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateAnimation() }
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            renderRecoveryObservers.append(NSWorkspace.shared.notificationCenter.addObserver(
                forName: name, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.recoverRendering() }
            })
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            renderRecoveryObservers.append(NSWorkspace.shared.notificationCenter.addObserver(
                forName: name, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.renderingSuspended = true }
            })
        }
        animationWatchdog = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.checkAnimationProgress() }
        NotificationCenter.default.addObserver(self, selector: #selector(displayConfigurationChanged(_:)),
                                              name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func show() {
        store.sound.setSuspended(false)
        store.refresh()
        panel.orderFrontRegardless()
        isVisible = true
        recoverRendering()
    }

    func hide() {
        spriteView.cancelDragging()
        panel.orderOut(nil)
        isVisible = false
        updateAnimation()
        store.save()
        store.rescheduleReminders()
        if managementWindow?.isVisible != true { store.sound.setSuspended(true) }
    }

    func feed() {
        store.sound.play("feed")
        scene.feed(reducedMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    func showManagement() {
        if managementWindow == nil {
            let window = AquariumManagementWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 900),
                                  styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
            window.title = "Fishtank · 养成手册"
            window.isReleasedWhenClosed = false
            window.hasShadow = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hidesOnDeactivate = false
            window.becomesKeyOnlyIfNeeded = false
            window.delegate = self
            window.minSize = NSSize(width: 600, height: 540)
            window.level = .normal
            window.contentView = NSHostingView(rootView: AquariumView(store: store))
            window.center()
            managementWindow = window
        }
        store.sound.setSuspended(false)
        store.sound.interact()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        managementWindow?.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak self] in self?.managementWindow?.makeKeyAndOrderFront(nil) }
    }

    func moveToCurrentScreen() {
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main else { return }
        let area = screen.visibleFrame
        let margin: CGFloat = 20
        panel.setFrameOrigin(NSPoint(x: max(area.minX, area.maxX - panel.frame.width - margin),
                                     y: area.minY + min(margin, max(0, area.height - panel.frame.height))))
    }

    private func applyWindowLevel() {
        panel.level = isPinned ? .floating : .normal
        panel.collectionBehavior = isPinned
            ? [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            : [.moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]
    }

    private func resize() {
        let old = panel.frame
        let size = NSSize(width: 320 * pixelScale, height: 180 * pixelScale)
        panel.setFrame(NSRect(x: old.minX, y: old.maxY - size.height, width: size.width, height: size.height), display: true)
        if let screen = panel.screen {
            let area = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: max(area.minX, min(panel.frame.minX, area.maxX - size.width)),
                                         y: max(area.minY, min(panel.frame.minY, area.maxY - size.height))))
        }
    }

    private func updateAnimation() {
        // Transparent companion windows can receive stale occlusion state after
        // display/session transitions. Only explicit hiding stops their renderer.
        spriteView.isPaused = !isVisible
        scene.isPaused = !isVisible
        scene.reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        spriteView.preferredFramesPerSecond = scene.reducedMotion ? 10 : 30
    }

    private func checkAnimationProgress() {
        guard isVisible, panel.isVisible, !renderingSuspended else { return }
        let uptime = ProcessInfo.processInfo.systemUptime
        let lastProgress = max(scene.lastFrameUptime ?? lastRenderRecovery, lastRenderRecovery)
        guard spriteView.isPaused || scene.isPaused || spriteView.scene !== scene || uptime - lastProgress > 4 else { return }
        recoverRendering()
    }

    private func recoverRendering() {
        renderingSuspended = false
        guard isVisible else { return }
        lastRenderRecovery = ProcessInfo.processInfo.systemUptime
        spriteView.restorePresentation(of: scene)
        updateAnimation()
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === managementWindow {
            NSApp.setActivationPolicy(.accessory)
            if !isVisible { store.sound.setSuspended(true) }
        }
    }

    // A window's screen-change notification also fires during ordinary dragging.
    // Recentring there changes the grab point, especially at staggered screen edges.
    // Recover an unreachable window only after an actual display configuration change.
    @objc private func displayConfigurationChanged(_ notification: Notification) {
        displayRecoveryTask?.cancel()
        displayRecoveryTask = Task { @MainActor [weak self] in
            // Wait without consuming or generating events, including when a display is
            // disconnected while the user is still holding the tank.
            do {
                repeat { try await Task.sleep(nanoseconds: 250_000_000) }
                while NSEvent.pressedMouseButtons != 0
            } catch { return }
            guard !Task.isCancelled, let self else { return }
            self.recoverRendering()
            if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(self.panel.frame) }) {
                self.moveToCurrentScreen()
            }
        }
    }
}

private final class AquariumPanel: NSPanel {
    // The desktop companion has no text input; clicking it must not capture typing
    // from the user's foreground app. The separate management panel can become key.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    var isDraggingAquarium = false
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        // Our drag geometry applies the outer desktop bounds. AppKit's per-screen
        // top constraint would otherwise block an internal vertical seam.
        isDraggingAquarium ? frameRect : super.constrainFrameRect(frameRect, to: screen)
    }

}

private final class AquariumManagementWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .window }
    override func accessibilitySubrole() -> NSAccessibility.Subrole? { .standardWindow }
    override func isAccessibilityElement() -> Bool { true }
}

private final class AquariumDesktopView: AquariumRenderView {
    var feed: (() -> Void)?
    private var draggingDecoration = false
    private var windowDrag: AquariumWindowDrag?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        cancelDragging()
        if let aquarium = scene as? AquariumScene,
           aquarium.tapFish(at: aquarium.convertPoint(fromView: convert(event.locationInWindow, from: nil))) {
            return
        }
        if event.clickCount == 2 {
            feed?()
        } else if let scene = scene as? AquariumScene,
                  scene.beginDecorationDrag(at: scene.convertPoint(fromView: convert(event.locationInWindow, from: nil))) {
            draggingDecoration = true
        } else if let panel = window as? AquariumPanel {
            windowDrag = AquariumWindowDrag(initialFrame: panel.frame, mouseDown: NSEvent.mouseLocation)
            panel.isDraggingAquarium = true
        }
    }
    override func mouseDragged(with event: NSEvent) {
        if let drag = windowDrag, let panel = window as? AquariumPanel {
            let displays = NSScreen.screens.map { AquariumDisplayGeometry(frame: $0.frame, visibleFrame: $0.visibleFrame) }
            panel.setFrame(drag.frame(at: NSEvent.mouseLocation, displays: displays), display: true)
            return
        }
        guard draggingDecoration, let scene = scene as? AquariumScene else { return }
        scene.dragDecoration(to: scene.convertPoint(fromView: convert(event.locationInWindow, from: nil)))
    }
    override func mouseUp(with event: NSEvent) {
        cancelDragging()
    }

    func cancelDragging() {
        if draggingDecoration { (scene as? AquariumScene)?.endDecorationDrag(); draggingDecoration = false }
        windowDrag = nil
        (window as? AquariumPanel)?.isDraggingAquarium = false
    }
}
#endif
