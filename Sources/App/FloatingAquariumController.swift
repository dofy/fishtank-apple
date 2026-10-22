#if os(macOS)
import AppKit
import SpriteKit
import Combine
import SwiftUI

@MainActor
final class AquariumApplicationDelegate: NSObject, NSApplicationDelegate {
    let store: AquariumStore

    override init() {
        // CLI-only credential discovery runs before the store and duplicate-instance
        // guard. The signed app reads its own sandbox; callers capture stdout privately.
        if ProcessInfo.processInfo.arguments.contains("--export-claude-bridge") || ProcessInfo.processInfo.arguments.contains("--export-agent-bridge") {
            let url = ClaudeHookBridge.defaultConfigurationURL
            guard let data = try? Data(contentsOf: url), data.count <= 4096 else { exit(1) }
            FileHandle.standardOutput.write(data)
            exit(0)
        }
        #if DEBUG
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--validate-claude-hooks"),
           ProcessInfo.processInfo.arguments.count > index + 1 {
            runClaudeHookValidation(directory: URL(fileURLWithPath: ProcessInfo.processInfo.arguments[index + 1]))
        }
        #endif
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
        AppIconStore.restoreRuntime()
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
        aquarium.startClaudeHooks()
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
    @Published private(set) var claudeSummary = L10n.text("Claude Code · 正在启动接收器")
    let agentSettings = AgentSettingsStore()
    lazy var appIcons = AppIconStore(discovered: { [weak self] in self?.store.state.discovered ?? [] })
    var claudeHooksEnabled: Bool {
        get { agentSettings.agent("claude-code")?.enabled == true }
        set { if var agent = agentSettings.agent("claude-code") { agent.enabled = newValue; agentSettings.update(agent) } }
    }
    var codexHooksEnabled: Bool {
        get { agentSettings.agent("codex")?.enabled == true }
        set { if var agent = agentSettings.agent("codex") { agent.enabled = newValue; agentSettings.update(agent) } }
    }
    @Published var agentSoundVolume = UserDefaults.standard.object(forKey: "agentSounds.volume") as? Double ?? 0.32 {
        didSet {
            UserDefaults.standard.set(agentSoundVolume, forKey: "agentSounds.volume")
            agentAlertSound.setVolume(Float(agentSoundVolume))
        }
    }
    @Published var agentSoundsEnabled = UserDefaults.standard.object(forKey: "agentSounds.enabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(agentSoundsEnabled, forKey: "agentSounds.enabled")
            agentAlertSound.setEnabled(agentSoundsEnabled)
        }
    }
    @Published private(set) var agentSoundError: String?
    private lazy var agentAlertSound: AgentAlertSound = {
        let sound = AgentAlertSound()
        sound.setEnabled(agentSoundsEnabled)
        sound.setVolume(Float(agentSoundVolume))
        sound.reportError = { [weak self] message in self?.agentSoundError = message }
        return sound
    }()
    func previewAgentSound(status: ClaudeHookEvent.Status) {
        guard agentSoundsEnabled else { return }
        agentAlertSound.preview(status: status)
    }

    var codexMenuSummary: String { claudeLedger.summary(source: .codex) }
    private var claudeLedger = ClaudeHookLedger()
    @Published private(set) var menuIndicatorRevision = 0
    private var menuPreview: AgentMenuIndicator.Presentation?
    private var menuPreviewTask: Task<Void, Never>?
    func menuIndicator(now: Date) -> AgentMenuIndicator.Presentation {
        menuPreview ?? AgentMenuIndicator.presentation(ledger: claudeLedger, agents: agentSettings.agents,
            paused: agentSettings.paused, disabledStates: agentSettings.disabledStates, now: now)
    }
    private func clearMenuPreview() {
        menuPreviewTask?.cancel(); menuPreviewTask = nil; menuPreview = nil
    }
    private func previewMenuIcon(_ event: ClaudeHookEvent) {
        guard let status = event.status else { return }
        clearMenuPreview()
        menuPreview = .init(state: .init(status), detail: L10n.text("预览 · \(event.agentTitle) · \(status.title)"))
        menuIndicatorRevision += 1
        menuPreviewTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !Task.isCancelled, let self else { return }
            self.menuPreview = nil; self.menuIndicatorRevision += 1
        }
    }

    private let claudeToast = ClaudeToastPresenter()
    private lazy var claudeBridge = ClaudeHookBridge(receive: { [weak self] event in
        Task { @MainActor in self?.receiveClaude(event) }
    }, report: { [weak self] status in
        Task { @MainActor in
            self?.receiverStatus = status
            self?.claudeSummary = status.message
            self?.agentSettings.receiverReady = status.isReady
        }
    })

    var claudeMenuSummary: String {
        claudeLedger.sessions.isEmpty ? claudeSummary : claudeLedger.summary()
    }

    func startClaudeHooks() { claudeBridge.start() }

    private func receiveClaude(_ input: ClaudeHookEvent) {
        guard let agent = agentSettings.agent(input.agent.rawValue) else { return }
        var event = input; event.displayName = agent.name; event.displayColor = agent.colorHex
        guard let notify = claudeLedger.accept(event) else { return }
        if !event.isPreview { clearMenuPreview(); menuIndicatorRevision += 1 }
        agentSettings.record(event)
        claudeSummary = claudeLedger.summary()
        guard agent.enabled, !agentSettings.paused else { return }
        let show = notify && !agentSettings.disabledStates.contains(event.status?.rawValue ?? "")
        claudeToast.receive(event, notify: show && agent.bubbles)
        if show, isVisible, agent.aquariumResponse { scene.showAgentSignal(event) }
        agentAlertSound.submit(event, notify: show && agent.sound && consoleAvailable)
    }

    func previewAgent(_ id: String, status: ClaudeHookEvent.Status, multiple: Bool, sound: Bool) {
        guard let selected = agentSettings.agent(id) else { return }
        if !isVisible { show() }
        let list = multiple ? Array(([selected] + agentSettings.agents.filter { $0.id != id } + [selected, selected]).prefix(3)) : [selected]
        let states: [ClaudeHookEvent.Status] = [status, .permission, .responded]
        for (index, agent) in list.enumerated() {
            let state = multiple ? states[index] : status
            let eventName: String
            let kind: String?
            switch state {
            case .ready: eventName = "SessionStart"; kind = nil
            case .working: eventName = "UserPromptSubmit"; kind = nil
            case .permission: eventName = "PermissionRequest"; kind = nil
            case .input: eventName = "Notification"; kind = "agent_needs_input"
            case .responded: eventName = "Stop"; kind = nil
            case .failed: eventName = "StopFailure"; kind = nil
            case .interrupted: eventName = agent.source == .claudeCode ? "Stop" : "Interrupt"; kind = nil
            case .ended: eventName = "SessionEnd"; kind = nil
            }
            var event = ClaudeHookEvent(id: UUID().uuidString, sessionID: "fishtank-preview:settings-\(index)", project: L10n.text("效果预览"),
                event: eventName, notificationType: kind, sentAt: Date(), source: agent.source)
            event.previewStatus = state
            event.displayName = agent.name; event.displayColor = agent.colorHex
            if index == 0 { previewMenuIcon(event) }
            claudeToast.receive(event, notify: true)
            if agent.aquariumResponse { scene.showAgentSignal(event) }
            if sound { agentAlertSound.submit(event, notify: true) }
        }
    }

    func previewClaudeToast() {
        let samples: [(ClaudeHookEvent.Source, String, String)] = [
            (.codex, "UserPromptSubmit", L10n.text("Codex · 处理预览")),
            (.claudeCode, "PermissionRequest", L10n.text("Claude · 授权预览")),
            (.codex, "Stop", L10n.text("Codex · 结束预览"))
        ]
        for (index, sample) in samples.enumerated() {
            let event = ClaudeHookEvent(id: UUID().uuidString, sessionID: "fishtank-preview:\(index)",
                project: sample.2, event: sample.1, notificationType: nil, sentAt: Date(), source: sample.0)
            if index == 0 { previewMenuIcon(event) }
            claudeToast.receive(event, notify: true)
            if isVisible { scene.showAgentSignal(event) }
            agentAlertSound.submit(event, notify: true)
        }
    }

    func windowDidMove(_ notification: Notification) { claudeToast.position() }
    func windowDidResize(_ notification: Notification) { claudeToast.position() }
    private let store: AquariumStore
    private let scene = AquariumScene()
    private let panel: AquariumPanel
    private var spriteView: AquariumDesktopView
    private var motionObserver: NSObjectProtocol?
    private var renderRecoveryObservers: [NSObjectProtocol] = []
    private var stateObserver: AnyCancellable?
    private var localizationObserver: AnyCancellable?
    private var receiverStatus: ClaudeHookBridge.Status?
    private var animationWatchdog: AnyCancellable?
    private var renderWatchdog = AquariumRenderWatchdog()
    private var wakeRecoveryTask: Task<Void, Never>?
    private var managementWindow: NSWindow?
    private var agentSettingsWindow: NSWindow?
    private var knownAgentSources: Set<ClaudeHookEvent.Source> = Set(ClaudeHookEvent.Source.allCases)
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
        knownAgentSources = Set(agentSettings.agents.map(\.source))
        agentSettings.changed = { [weak self] in
            guard let self else { return }
            self.objectWillChange.send()
            self.agentAlertSound.discardDisabledStates(self.agentSettings.disabledStates)
            let active = Set(self.agentSettings.agents.filter { $0.enabled && !self.agentSettings.paused }.map(\.source))
            for source in self.knownAgentSources.union(self.agentSettings.agents.map(\.source)) {
                let agent = self.agentSettings.agent(source.rawValue)
                if !active.contains(source) || agent?.bubbles == false { self.claudeToast.remove(source: source) }
                if !active.contains(source) || agent?.sound == false { self.agentAlertSound.remove(source: source) }
            }
            for event in self.claudeToast.visibleEvents where !event.isPreview && self.agentSettings.disabledStates.contains(event.status?.rawValue ?? "") {
                self.claudeToast.dismiss(id: event.id)
            }
            let registered = Set(self.agentSettings.agents.map(\.source))
            for removed in self.knownAgentSources.subtracting(registered) { self.claudeLedger.remove(source: removed) }
            self.knownAgentSources = registered
            self.clearMenuPreview(); self.menuIndicatorRevision += 1
        }

        panel.title = L10n.text("Fishtank · 悬浮鱼缸")
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
        claudeToast.attach(to: panel)
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
        spriteView.toolTip = L10n.text("拖动水面移动鱼缸，拖造景布置，单击空白处投喂，右键晃动惊鱼；菜单栏可调透明度、大小与置顶。")
        spriteView.feed = { [weak self] x in self?.feed(at: x) }
        spriteView.setAccessibilityLabel(L10n.text("半透明悬浮像素鱼缸"))
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
        localizationObserver = NotificationCenter.default.publisher(for: .aquariumLanguageDidChange).sink { [weak self] _ in
            guard let self else { return }
            self.panel.title = L10n.text("Fishtank · 悬浮鱼缸")
            self.managementWindow?.title = L10n.text("Fishtank · 养成手册")
            self.agentSettingsWindow?.title = L10n.text("Fishtank · 设置")
            self.spriteView.toolTip = L10n.text("拖动水面移动鱼缸，拖造景布置，单击空白处投喂，右键晃动惊鱼；菜单栏可调透明度、大小与置顶。")
            self.spriteView.setAccessibilityLabel(L10n.text("半透明悬浮像素鱼缸"))
            self.scene.refreshLocalizedFont()
            self.claudeToast.refreshLocalization()
            self.clearMenuPreview()
            self.claudeSummary = self.claudeLedger.sessions.isEmpty
                ? (self.receiverStatus?.message ?? L10n.text("Claude Code · 正在启动接收器")) : self.claudeLedger.summary()
            self.menuIndicatorRevision += 1
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
                Task { @MainActor in self?.resumeRendering() }
            })
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            renderRecoveryObservers.append(NSWorkspace.shared.notificationCenter.addObserver(
                forName: name, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.wakeRecoveryTask?.cancel()
                    self.renderWatchdog.suspend(at: ProcessInfo.processInfo.systemUptime)
                }
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
        claudeToast.setVisible(true)
        recoverRendering()
    }

    func hide() {
        spriteView.cancelDragging()
        claudeToast.setVisible(false)
        panel.orderOut(nil)
        isVisible = false
        updateAnimation()
        store.save()
        store.rescheduleReminders()
        if managementWindow?.isVisible != true { store.sound.setSuspended(true) }
    }

    func feed(at x: CGFloat? = nil) {
        store.sound.play("feed")
        scene.feed(reducedMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, x: x.map(Double.init) ?? 160)
    }

    func showManagement() {
        if managementWindow == nil {
            let size = AquariumManagementWindow.contentSize
            let window = AquariumManagementWindow(contentRect: NSRect(origin: .zero, size: size),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.title = L10n.text("Fishtank · 养成手册")
            window.isReleasedWhenClosed = false
            window.hasShadow = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hidesOnDeactivate = false
            window.becomesKeyOnlyIfNeeded = false
            window.delegate = self
            window.level = .normal
            let content = NSHostingView(rootView: AquariumView(store: store, openAgentSettings: { [weak self] in self?.showAgentSettings() })
                .frame(width: size.width, height: size.height))
            content.sizingOptions = [.minSize, .maxSize]
            window.contentView = content
            window.lockContentSize()
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

    func showAgentSettings() {
        if agentSettingsWindow == nil {
            let size = AquariumManagementWindow.contentSize
            let window = AquariumManagementWindow(contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless], backing: .buffered, defer: false)
            window.title = L10n.text("Fishtank · 设置"); window.isReleasedWhenClosed = false
            window.hasShadow = true; window.isOpaque = false; window.backgroundColor = .clear
            window.hidesOnDeactivate = false; window.becomesKeyOnlyIfNeeded = false; window.level = .normal
            window.delegate = self
            let content = NSHostingView(rootView: AgentSettingsView(aquarium: self, model: agentSettings, store: store)
                .frame(width: size.width, height: size.height))
            content.sizingOptions = [.minSize, .maxSize]
            window.contentView = content
            // A fixed root gives SwiftUI the same minimum and maximum after every layout pass.
            window.lockContentSize()
            window.center(); agentSettingsWindow = window
        }
        NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true)
        agentSettingsWindow?.makeKeyAndOrderFront(nil)
    }

    func closeAgentSettings() { agentSettingsWindow?.close() }

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
        claudeToast.position()
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

    private var consoleAvailable: Bool {
        guard let info = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        // The public on-console key handles user switching. The optional lock hint
        // avoids surface retries behind the lock screen; its absence never blocks wake.
        return info[kCGSessionOnConsoleKey as String] as? Bool == true &&
            info["CGSSessionScreenIsLocked"] as? Bool != true
    }

    private func checkAnimationProgress() {
        guard let action = renderWatchdog.action(at: ProcessInfo.processInfo.systemUptime,
            visible: isVisible && panel.isVisible, consoleAvailable: consoleAvailable,
            lastFrame: scene.lastFrameUptime, paused: spriteView.isPaused || scene.isPaused,
            attached: spriteView.scene === scene) else { return }
        recoverRendering(rebuildSurface: action == .rebuild)
    }

    private func resumeRendering() {
        wakeRecoveryTask?.cancel()
        wakeRecoveryTask = Task { @MainActor [weak self] in
            // AppKit can deliver wake before the compositor's surface is usable.
            do { try await Task.sleep(nanoseconds: 350_000_000) } catch { return }
            guard let self, !Task.isCancelled, self.consoleAvailable else { return }
            self.recoverRendering(rebuildSurface: true)
        }
    }

    private func recoverRendering(rebuildSurface: Bool = false) {
        guard isVisible else { return }
        renderWatchdog.recovered(at: ProcessInfo.processInfo.systemUptime)
        scene.resetFrameClock()
        if rebuildSurface {
            spriteView.cancelDragging()
            spriteView.isPaused = true
            spriteView.presentScene(nil)
            let replacement = AquariumDesktopView(frame: spriteView.frame)
            replacement.allowsTransparency = true
            replacement.autoresizingMask = [.width, .height]
            replacement.toolTip = spriteView.toolTip
            replacement.feed = { [weak self] x in self?.feed(at: x) }
            replacement.setAccessibilityLabel(L10n.text("半透明悬浮像素鱼缸"))
            replacement.presentScene(scene)
            spriteView = replacement
            panel.contentView = replacement
        } else { spriteView.restorePresentation(of: scene) }
        updateAnimation()
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === managementWindow || window === agentSettingsWindow {
            let other = window === managementWindow ? agentSettingsWindow : managementWindow
            if other?.isVisible != true { NSApp.setActivationPolicy(.accessory) }
            if !isVisible && (window === managementWindow || managementWindow?.isVisible != true) { store.sound.setSuspended(true) }
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

final class AquariumManagementWindow: NSPanel {
    static let contentSize = NSSize(width: 880, height: 660)
    private var lockedFrameSize: NSSize?

    func lockContentSize() {
        contentMinSize = Self.contentSize
        contentMaxSize = Self.contentSize
        setContentSize(Self.contentSize)
        lockedFrameSize = frame.size
        collectionBehavior.insert(.fullScreenNone)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        var target = frameRect
        if let size = lockedFrameSize { target.size = size }
        super.setFrame(target, display: flag)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool, animate: Bool) {
        var target = frameRect
        if let size = lockedFrameSize { target.size = size }
        super.setFrame(target, display: flag, animate: animate)
    }

    override func setContentSize(_ size: NSSize) {
        super.setContentSize(lockedFrameSize == nil ? size : Self.contentSize)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .window }
    override func accessibilitySubrole() -> NSAccessibility.Subrole? { .standardWindow }
    override func isAccessibilityElement() -> Bool { true }
}

private final class AquariumDesktopView: AquariumRenderView {
    var feed: ((CGFloat) -> Void)?
    private var clickAnchor: CGPoint?
    private var didDrag = false
    private var draggingDecoration = false
    private var windowDrag: AquariumWindowDrag?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        cancelDragging()
        guard let aquarium = scene as? AquariumScene else { return }
        let local = convert(event.locationInWindow, from: nil)
        let point = aquarium.convertPoint(fromView: local)
        guard aquarium.containsTankPoint(point) else { return }
        if aquarium.tapFish(at: point) { return }
        if aquarium.beginDecorationDrag(at: point) {
            draggingDecoration = true
        } else if let panel = window as? AquariumPanel {
            clickAnchor = local
            windowDrag = AquariumWindowDrag(initialFrame: panel.frame,
                mouseDown: panel.convertPoint(toScreen: event.locationInWindow))
        }
    }
    override func rightMouseDown(with event: NSEvent) {
        cancelDragging()
        guard let aquarium = scene as? AquariumScene else { return }
        let point = aquarium.convertPoint(fromView: convert(event.locationInWindow, from: nil))
        guard aquarium.containsTankPoint(point) else { return }
        aquarium.reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        aquarium.shake()
    }
    override func rightMouseUp(with event: NSEvent) {}

    override func mouseDragged(with event: NSEvent) {
        if let drag = windowDrag, let panel = window as? AquariumPanel {
            let mouse = panel.convertPoint(toScreen: event.locationInWindow)
            guard didDrag || hypot(mouse.x - drag.mouseDown.x, mouse.y - drag.mouseDown.y) >= 4 else { return }
            didDrag = true; panel.isDraggingAquarium = true
            let displays = NSScreen.screens.map { AquariumDisplayGeometry(frame: $0.frame, visibleFrame: $0.visibleFrame) }
            panel.setFrame(drag.frame(at: mouse, displays: displays), display: true)
            return
        }
        guard draggingDecoration, let scene = scene as? AquariumScene else { return }
        scene.dragDecoration(to: scene.convertPoint(fromView: convert(event.locationInWindow, from: nil)))
    }
    override func mouseUp(with event: NSEvent) {
        if let anchor = clickAnchor, !didDrag, let aquarium = scene as? AquariumScene {
            let local = convert(event.locationInWindow, from: nil)
            let point = aquarium.convertPoint(fromView: local)
            if hypot(local.x - anchor.x, local.y - anchor.y) < 4, aquarium.containsTankPoint(point) {
                feed?(point.x)
            }
        }
        cancelDragging()
    }

    func cancelDragging() {
        if draggingDecoration { (scene as? AquariumScene)?.endDecorationDrag(); draggingDecoration = false }
        windowDrag = nil; clickAnchor = nil; didDrag = false
        (window as? AquariumPanel)?.isDraggingAquarium = false
    }
}
#endif
