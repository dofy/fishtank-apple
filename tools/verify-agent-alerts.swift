// Build all Sources except FishtankApp.swift with -D DEBUG, in an isolated QA app.
import AppKit
import AVFoundation

@main struct VerifyAgentAlerts {
    @MainActor static func main() {
        guard Bundle.main.bundleIdentifier?.hasPrefix("net.yahaha.fishtank.renderqa.") == true,
              ProcessInfo.processInfo.environment["FISHTANK_UI_TEST_ID"].flatMap(UUID.init(uuidString:)) != nil else {
            fatalError("Requires isolated bundle and temporary save")
        }
        let app = NSApplication.shared; app.setActivationPolicy(.accessory)
        let store = AquariumStore()
        let controller = FloatingAquariumController(store: store)
        controller.agentSoundsEnabled = false
        let statusMenu = AquariumStatusMenu(store: store, aquarium: controller)
        let menu = Mirror(reflecting: statusMenu).children.first { $0.label == "menu" }!.value as! NSMenu
        let panel = Mirror(reflecting: controller).children.first { $0.label == "panel" }!.value as! NSPanel
        let toast = Mirror(reflecting: controller).children.first { $0.label == "claudeToast" }!.value as! ClaudeToastPresenter
        let sound = AgentAlertSound()
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        try! FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        Task { @MainActor in
            @MainActor func wait(_ seconds: Double) async { try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
            @MainActor func inspect() async -> (Bool, Int, Float, [ClaudeHookEvent.Status]) {
                await withCheckedContinuation { continuation in
                    sound.inspect { continuation.resume(returning: ($0, $1, $2, $3)) }
                }
            }
            // Native menu target/actions and persisted toggle, using this bundle's own defaults.
            let toggle = menu.items.first { $0.title == "提醒声音" }!
            precondition(toggle.state == .off)
            menu.performActionForItem(at: menu.items.firstIndex(of: toggle)!)
            precondition(controller.agentSoundsEnabled && UserDefaults.standard.bool(forKey: "agentSounds.enabled"))
            statusMenu.menuNeedsUpdate(menu)
            precondition(!menu.items.contains { $0.title == "试听提醒音效" })
            let onToggle = menu.items.first { $0.title == "提醒声音" }!
            menu.performActionForItem(at: menu.items.firstIndex(of: onToggle)!)
            precondition(!controller.agentSoundsEnabled)
            print("PASS concise menu sound toggle and persistence; auditions moved to settings")
            for scale in [1, 2, 3] {
                controller.pixelScale = scale
                panel.setFrameOrigin(NSPoint(x: 60, y: 60))
                controller.show(); controller.previewClaudeToast()
                await wait(0.25)
                precondition(panel.frame.width == CGFloat(320 * scale))
                let children = panel.childWindows ?? []
                precondition(children.count == 3 && toast.visibleEvents.count == 3)
                let frames = children.map(\.frame).sorted { $0.minY < $1.minY }
                for frame in frames {
                    precondition(frame.width == panel.frame.width && frame.height == 70)
                    precondition(panel.screen!.visibleFrame.contains(frame))
                }
                for pair in zip(frames, frames.dropFirst()) { precondition(pair.1.minY - pair.0.maxY == 8) }
                // Capture only this QA app's own panels, with no other desktop content.
                if ProcessInfo.processInfo.environment["FISHTANK_QA_NO_CAPTURE"] != "1" {
                let task = Process(); task.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
                task.arguments = [FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/skills/screenshot/scripts/take_screenshot.py").path, "--mode", "temp", "--window-id", String(panel.windowNumber)]
                try! task.run(); task.waitUntilExit(); precondition(task.terminationStatus == 0)
                }
                let dismiss = toast.visibleEvents[1].id
                toast.dismiss(id: dismiss)
                precondition(toast.visibleEvents.count == 2 && !toast.visibleEvents.contains { $0.id == dismiss })
                toast.clear()
                print("PASS native \(320 * scale)pt tank: three equal-width bubbles, spacing, screen bounds and independent close")
            }
            controller.hide()
            func event(_ name: String, _ session: String) -> ClaudeHookEvent {
                ClaudeHookEvent(id: UUID().uuidString, sessionID: "fishtank-preview:\(session)", project: "QA", event: name,
                                notificationType: nil, sentAt: Date(), source: .codex)
            }
            sound.preview(status: .permission)
            await wait(0.05)
            let playing = await inspect()
            precondition(playing.0 && playing.2 <= 0.35)
            sound.setVolume(0.2); await wait(0.01)
            let changedVolume = await inspect(); precondition(abs(changedVolume.2 - 0.2) < 0.001)
            sound.submit(event("Stop", "queued"), notify: true)
            sound.setEnabled(false)
            await wait(0.03)
            let muted = await inspect(); precondition(!muted.0 && muted.1 == 0)
            sound.preview(status: .failed); sound.setEnabled(true)
            await wait(0.1)
            let resumed = await inspect(); precondition(!resumed.0 && resumed.1 == 0 && resumed.3.count == 1)
            sound.submit(event("UserPromptSubmit", "first"), notify: true)
            sound.submit(event("Stop", "second"), notify: true)
            await wait(0.8)
            let serial = await inspect()
            precondition(!serial.0 && serial.1 == 0 && serial.3 == [.permission, .working, .responded])
            print("PASS real quiet AVAudioPlayer playback, immediate mute/queue clearing, no replay and serial state cues")
            sound.setEnabled(false); store.stopRemindersForTransfer(); app.terminate(nil)
        }
        withExtendedLifetime(statusMenu) { app.run() }
    }
}
