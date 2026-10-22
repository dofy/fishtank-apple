// Build all Sources except FishtankApp.swift with -D DEBUG into a separate QA bundle.
import AppKit
import SwiftUI

@main struct VerifyAgentSettings {
    @MainActor static func main() {
        guard Bundle.main.bundleIdentifier?.hasPrefix("net.yahaha.fishtank.renderqa.") == true,
              ProcessInfo.processInfo.environment["FISHTANK_UI_TEST_ID"].flatMap(UUID.init(uuidString:)) != nil else { fatalError("Requires isolated QA app and save") }
        if ProcessInfo.processInfo.arguments.contains("--export-agent-bridge") || ProcessInfo.processInfo.arguments.contains("--export-claude-bridge") {
            FileHandle.standardOutput.write(try! Data(contentsOf: ClaudeHookBridge.defaultConfigurationURL)); exit(0)
        }
        setbuf(stdout, nil)
        PixelTheme.registerFont()
        let app = NSApplication.shared; app.setActivationPolicy(.accessory)
        let store = AquariumStore(), controller: FloatingAquariumController
        controller = FloatingAquariumController(store: store)
        controller.agentSoundsEnabled = false
        var audio = store.state.audio; audio.sfxEnabled = false; audio.musicEnabled = false; store.setAudio(audio)
        let model = controller.agentSettings
        let status = AquariumStatusMenu(store: store, aquarium: controller)
        let menu = Mirror(reflecting: status).children.first { $0.label == "menu" }!.value as! NSMenu
        controller.startClaudeHooks()
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("FishtankAgentSettingsQA-" + UUID().uuidString)
        try! FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        Task { @MainActor in
            @MainActor func wait(_ seconds: Double) async { try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
            @MainActor func snapshot(_ window: NSWindow) {
                if ProcessInfo.processInfo.environment["FISHTANK_QA_NO_CAPTURE"] == "1" { return }
                let task = Process(); task.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
                task.arguments = [AgentSettingsStore.userHome.appendingPathComponent(".codex/skills/screenshot/scripts/take_screenshot.py").path, "--path", output.appendingPathComponent("settings-" + UUID().uuidString + ".png").path, "--window-id", String(window.windowNumber)]
                try! task.run(); task.waitUntilExit(); precondition(task.terminationStatus == 0)
            }
            var nativeSends: [AgentBridgeProbe] = []
            @MainActor func send(_ source: String, event: String, session: String) {
                if ProcessInfo.processInfo.environment["FISHTANK_QA_NO_CAPTURE"] == "1" {
                    let value = ClaudeHookEvent(id: UUID().uuidString, sessionID: session, project: "QA", event: event, notificationType: nil, sentAt: Date(), source: .init(rawValue: source))
                    let probe = try! AgentBridgeProbe(event: value); nativeSends.append(probe); probe.start { _ in }; return
                }
                let task = Process(); task.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
                task.arguments = [model.bundledHook!.path, "--source", source, "--app", Bundle.main.executableURL!.path]
                let input = Pipe(); task.standardInput = input; task.standardOutput = FileHandle.nullDevice; task.standardError = FileHandle.nullDevice
                try! task.run(); input.fileHandleForWriting.write(try! JSONSerialization.data(withJSONObject: ["hook_event_name": event, "session_id": session, "cwd": "/QA/local"])); try! input.fileHandleForWriting.close()
                task.waitUntilExit(); precondition(task.terminationStatus == 0)
            }
            let suite = "FishtankAgentMigrationQA-" + UUID().uuidString
            let defaults = UserDefaults(suiteName: suite)!
            defaults.set(false, forKey: "claudeHooks.enabled"); defaults.set(true, forKey: "codexHooks.enabled")
            let migrated = AgentSettingsStore(defaults: defaults)
            precondition(migrated.agents.count == 2 && migrated.agent("claude-code")?.enabled == false && migrated.agent("codex")?.enabled == true)
            let customID = migrated.add(name: "本地助手")!
            precondition(AgentSettingsStore(defaults: defaults).agent(customID) != nil)
            for agent in migrated.agents { migrated.removeLocal(agent.id) }
            precondition(AgentSettingsStore(defaults: defaults).agents.isEmpty)
            defaults.removePersistentDomain(forName: suite)
            print("PASS preference migration, custom registration persistence and removed entries do not return")

            let fixture = output.appendingPathComponent(".codex")
            try! FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)
            let config = fixture.appendingPathComponent("hooks.json")
            let original = Data("{\"hooks\":{\"Stop\":[{\"matcher\":\"*\",\"hooks\":[{\"type\":\"command\",\"command\":\"echo keep\"}]}]},\"description\":\"preserve\"}".utf8)
            try! original.write(to: config)
            try! FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: config.path)
            let trust = fixture.appendingPathComponent("config.toml"), trustData = Data("[hooks.state.existing]\ntrusted_hash = \"keep\"\n".utf8)
            try! trustData.write(to: trust)
            model.validationFolders["codex"] = fixture
            model.configure("codex")
            let installed = try! Data(contentsOf: config)
            precondition(installed != original)
            precondition((try! FileManager.default.attributesOfItem(atPath: config.path)[.posixPermissions] as! NSNumber).intValue == 0o640)
            for backup in try! FileManager.default.contentsOfDirectory(at: fixture, includingPropertiesForKeys: nil) where backup.lastPathComponent.contains("fishtank-backup") {
                precondition((try! FileManager.default.attributesOfItem(atPath: backup.path)[.posixPermissions] as! NSNumber).intValue == 0o600)
            }
            model.configure("codex"); precondition(try! Data(contentsOf: config) == installed)
            precondition(try! Data(contentsOf: trust) == trustData)
            for _ in 0..<30 { if model.receiverReady { break }; await wait(0.1) }
            precondition(model.receiverReady)
            model.check("codex")
            await wait(4.3)
            precondition(model.messages["codex"]?.contains("测试事件已收到") == true, "Probe must arrive through the authenticated loopback receiver")
            precondition(model.recent.isEmpty, "Probe cannot impersonate a real event")
            model.configure("codex", remove: true)
            let removed = try! JSONSerialization.jsonObject(with: Data(contentsOf: config)) as! NSDictionary
            let expected = try! JSONSerialization.jsonObject(with: original) as! NSDictionary
            precondition(removed == expected && model.agent("codex") == nil)
            precondition(try! Data(contentsOf: trust) == trustData)
            _ = model.add(name: "Codex", source: .codex, color: ClaudeHookEvent.Source.codex.colorHex)
            print("PASS native install/repair/check/uninstall on isolated config, exact existing command preservation and untouched trust")

            let id = model.add(name: "本地助手")!
            model.check(id); await wait(1)
            precondition(model.messages[id]?.contains("测试事件已收到") == true)
            send(id, event: "PermissionRequest", session: "real-test"); await wait(0.2)
            precondition(model.recent[id]?.status == .permission)
            let toast = Mirror(reflecting: controller).children.first { $0.label == "claudeToast" }!.value as! ClaudeToastPresenter
            precondition(toast.visibleEvents.contains { $0.agent.rawValue == id && $0.agentTitle == "本地助手" })
            model.paused = true; precondition(toast.visibleEvents.isEmpty)
            model.paused = false
            model.disabledStates.insert("working")
            send(id, event: "UserPromptSubmit", session: "filtered"); await wait(0.2)
            precondition(toast.visibleEvents.isEmpty)
            model.disabledStates.remove("working")
            controller.previewAgent(id, status: .input, multiple: true, sound: false)
            precondition(toast.visibleEvents.count == 3 && toast.visibleEvents.contains { $0.status == .input })
            toast.clear()
            print("PASS custom adapter loopback, real/preview separation, global pause, state filtering and multi-agent preview")

            let entry = menu.items.first { $0.title.hasPrefix("Agent 设置") }!
            menu.performActionForItem(at: menu.items.firstIndex(of: entry)!)
            await wait(0.3)
            let window = Mirror(reflecting: controller).children.first { $0.label == "agentSettingsWindow" }!.value as! NSWindow
            precondition(window.isVisible && window.title == "Fishtank · 设置")
            precondition(window.styleMask.contains(.borderless) && !window.styleMask.contains(.titled))
            precondition(window.canBecomeKey && window.canBecomeMain && !window.isOpaque && window.backgroundColor == .clear)
            precondition(!menu.items.contains { $0.title.contains("Claude") || $0.title.contains("Codex") || $0.title.contains("试听") })
            snapshot(window)
            let fixedSize = NSSize(width: 880, height: 660)
            precondition(!window.styleMask.contains(.resizable))
            precondition(window.contentMinSize == fixedSize && window.contentMaxSize == fixedSize)
            precondition(window.contentView?.bounds.size == fixedSize)
            let customContent = NSHostingView(rootView: AgentSettingsView(aquarium: controller, model: model, store: store, initialSelection: id).frame(width: 880, height: 660))
            customContent.sizingOptions = [.minSize, .maxSize]; window.contentView = customContent
            await wait(0.2); snapshot(window)
            let notificationContent = NSHostingView(rootView: AgentSettingsView(aquarium: controller, model: model, store: store, initialPage: "notifications").frame(width: 880, height: 660))
            notificationContent.sizingOptions = [.minSize, .maxSize]; window.contentView = notificationContent
            await wait(0.2); snapshot(window)
            model.removeLocal(id)
            send(id, event: "Stop", session: "removed"); await wait(0.1)
            precondition(model.recent[id] == nil && !toast.visibleEvents.contains { $0.agent.rawValue == id })
            print("PASS concise menu opens independent settings; fixed-size/custom/notification layouts captured; removed source ignored")
            controller.closeAgentSettings(); precondition(!window.isVisible)
            controller.showAgentSettings(); precondition(window.isVisible)
            controller.showManagement(); await wait(0.2)
            let handbook = Mirror(reflecting: controller).children.first { $0.label == "managementWindow" }!.value as! NSWindow
            precondition(handbook.styleMask.contains(.borderless) && handbook.canBecomeKey && !handbook.isOpaque)
            snapshot(handbook); handbook.close()
            print("PASS settings/handbook share borderless window behavior, pixel chrome, close and reopen")
            window.close(); controller.hide(); store.stopRemindersForTransfer(); app.terminate(nil)
        }
        withExtendedLifetime(status) { app.run() }
    }
}
