#if DEBUG && os(macOS)
import AppKit
import SwiftUI
import SpriteKit
import AVFoundation

/// Explicit CLI validation path: no personal save, no visible windows, no shared bridge config.
@MainActor
func runClaudeHookValidation(directory: URL) -> Never {
    do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
    catch { exit(1) }
    for status in ClaudeHookEvent.Status.allCases {
        let tone = AgentAlertTone(status: status)
        do {
            let player = try AVAudioPlayer(data: tone.wave, fileTypeHint: AVFileType.wav.rawValue)
            precondition(abs(player.duration - tone.duration) < 0.001, "WAV must decode with expected duration")
            try tone.wave.write(to: directory.appendingPathComponent("sound-\(status.rawValue).wav"))
        } catch { fatalError("Alert WAV decode failed: \(error)") }
    }
    let presenter = ClaudeToastPresenter()
    func sample(_ event: String, session: String = "a") -> ClaudeHookEvent {
        ClaudeHookEvent(id: UUID().uuidString, sessionID: session, project: L10n.text("fishtank-apple-长项目名称和状态在最小尺寸下也需要清晰可读"), event: event,
                        notificationType: nil, sentAt: Date())
    }
    let a = sample("PermissionRequest")
    let b = sample("UserPromptSubmit", session: "b")
    let c = sample("Stop", session: "c")
    for event in [a,b,c] { presenter.receive(event, notify: true) }
    precondition(presenter.visibleEvents.count == 3, "Independent sessions must have three simultaneous bubbles")
    presenter.receive(sample("Stop", session: "b"), notify: true)
    precondition(presenter.visibleEvents.count == 3, "Same-session updates coalesce")
    presenter.dismiss(id: a.id)
    precondition(presenter.visibleEvents.count == 2 && presenter.visibleEvents.contains { $0.id == c.id })
    presenter.receive(sample("PostToolUse", session: "b"), notify: false)
    precondition(presenter.visibleEvents.count == 1 && presenter.current?.id == c.id)
    presenter.clear()
    let timed = ClaudeToastPresenter(duration: { $0.status?.holdsToast == true ? 0.03 : 0.2 })
    timed.receive(a, notify: true)
    timed.receive(c, notify: true)
    let deadline = Date().addingTimeInterval(2)
    while timed.visibleEvents.contains(where: { $0.id == a.id }) && Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.005))
    }
    precondition(timed.visibleEvents.count == 1 && timed.current?.id == c.id, "Bubble timers must be independent")
    while !timed.visibleEvents.isEmpty && Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.005))
    }
    precondition(timed.visibleEvents.isEmpty)
    try? Data("PASS simultaneous bubbles, independent timers, coalescing, silent resolution, new-prompt preemption, waiting expiry and source isolation".utf8)
        .write(to: directory.appendingPathComponent("presenter-checks.txt"))
    var codexEvent = sample("PermissionRequest", session: "same-session"); codexEvent.source = .codex
    presenter.receive(sample("PermissionRequest", session: "same-session"), notify: true)
    presenter.receive(codexEvent, notify: true)
    presenter.receive(sample("PostToolUse", session: "same-session"), notify: false)
    precondition(presenter.visibleEvents.count == 1 && presenter.current?.agent == .codex)
    presenter.remove(source: .claudeCode)
    precondition(presenter.current?.agent == .codex)
    presenter.remove(source: .codex)
    precondition(presenter.current == nil)
    let scene = AquariumScene()
    let renderView = SKView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
    renderView.presentScene(scene)
    let state = AquariumState.newGame(at: Date())
    scene.populate(with: state.tankFish); scene.syncExtras(from: state, at: Date())
    let rootIDs = scene.children.map(ObjectIdentifier.init)
    scene.showAgentSignal(codexEvent)
    let signalRoot = Mirror(reflecting: scene).children.first { $0.label == "agentSignalRoot" }!.value as! SKNode
    precondition(signalRoot.children.count == 1)
    for _ in 0..<20 { scene.showAgentSignal(codexEvent) }
    precondition(signalRoot.children.count == 1, "A burst must be rate limited")
    scene.reducedMotion = true
    scene.showAgentSignal(sample("PermissionRequest", session: "reduced-motion"))
    precondition(signalRoot.children.last?.children.count == 1, "Reduced motion uses one static light")
    precondition(signalRoot.children.last?.children.first?.hasActions() == false)
    precondition(scene.children.map(ObjectIdentifier.init) == rootIDs)
    let previewEvents = [sample("UserPromptSubmit", session: "stack-codex"), sample("PermissionRequest", session: "stack-claude"), sample("Stop", session: "stack-done")]
        .enumerated().map { index, value -> ClaudeHookEvent in var event = value; if index != 1 { event.source = .codex }; return event }
    for width in [320, 640, 960] {
        let view = NSHostingView(rootView: VStack(spacing: 8) {
            ForEach(previewEvents, id: \.id) { event in ClaudeToastView(event: event, dismiss: {}).frame(height: 70) }
        })
        view.frame = CGRect(x: 0, y: 0, width: width, height: 226)
        view.layoutSubtreeIfNeeded()
        let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try? bitmap.representation(using: .png, properties: [:])?.write(to: directory.appendingPathComponent("stack-\(width).png"))
    }
    var ledger = ClaudeHookLedger()
    var events: [String] = []
    let bridge = ClaudeHookBridge(configurationURL: directory.appendingPathComponent("bridge.json"), receive: { event in
        DispatchQueue.main.async {
            guard let notify = ledger.accept(event) else { return }
            events.append(event.event)
            try? JSONEncoder().encode(events).write(to: directory.appendingPathComponent("received.json"), options: .atomic)
            guard notify else { return }
            for width in [320, 640, 960] {
                let view = NSHostingView(rootView: ClaudeToastView(event: event, dismiss: {}))
                view.frame = NSRect(x: 0, y: 0, width: width, height: 70)
                view.layoutSubtreeIfNeeded()
                guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                try? bitmap.representation(using: .png, properties: [:])?.write(to: directory.appendingPathComponent("toast-\(event.agent.rawValue)-\(event.event)-\(width).png"))
            }
        }
    }, report: { status in
        if !status.isReady { exit(2) }
    })
    bridge.start()
    // The caller owns process lifetime. This mode never displays a desktop panel.
    withExtendedLifetime(bridge) { RunLoop.main.run() }
    exit(0)
}
#endif
