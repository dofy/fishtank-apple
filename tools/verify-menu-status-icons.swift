// Build all Sources except FishtankApp.swift with -D DEBUG into an isolated QA bundle.
import AppKit
import CryptoKit

@main struct VerifyMenuStatusIcons {
    @MainActor static func main() {
        guard Bundle.main.bundleIdentifier?.hasPrefix("net.yahaha.fishtank.renderqa.") == true,
              ProcessInfo.processInfo.environment["FISHTANK_UI_TEST_ID"].flatMap(UUID.init(uuidString:)) != nil else { fatalError("Requires isolated QA app and temporary save") }
        setbuf(stdout, nil)
        let app = NSApplication.shared; app.setActivationPolicy(.accessory)
        var fingerprints = Set<Data>()
        for state in AgentMenuIndicator.State.allCases {
            let image = MenuFishArt.image(state)
            precondition(image.isTemplate && image.size == NSSize(width: 36,height: 18))
            fingerprints.insert(Data(SHA256.hash(data: image.tiffRepresentation!)))
        }
        precondition(fingerprints.count == 10, "Status icons must all be distinct")
        let store = AquariumStore()
        let controller = FloatingAquariumController(store: store)
        controller.agentSoundsEnabled = false
        let menu = AquariumStatusMenu(store: store, aquarium: controller)
        let item = Mirror(reflecting: menu).children.first { $0.label == "item" }!.value as! NSStatusItem
        controller.startClaudeHooks()
        var probes: [AgentBridgeProbe] = []
        Task { @MainActor in
            @MainActor func wait(_ duration: Double) async { try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000)) }
            @MainActor func expect(_ state: AgentMenuIndicator.State) {
                precondition(item.button?.image?.tiffRepresentation == MenuFishArt.image(state).tiffRepresentation, "Menu icon did not update: " + state.rawValue)
                precondition(item.button?.toolTip?.contains(controller.menuIndicator(now: Date()).detail) == true)
            }
            await wait(0.3)
            for status in ClaudeHookEvent.Status.allCases {
                controller.previewAgent("codex", status: status, multiple: false, sound: false)
                expect(.init(status))
                precondition(item.button?.toolTip?.hasPrefix("预览") == true)
            }
            await wait(8.2); expect(.idle)
            controller.agentSettings.paused = true; expect(.paused)
            controller.agentSettings.paused = false; expect(.idle)
            @MainActor func send(_ event: String) async {
                let value = ClaudeHookEvent(id: UUID().uuidString, sessionID: "menu-qa", project: "图标验证", event: event,
                    notificationType: nil, sentAt: Date(), source: .codex)
                let probe = try! AgentBridgeProbe(event: value); probes.append(probe)
                probe.start { _ in }; await wait(0.4)
            }
            controller.previewAgent("codex",status:.failed,multiple:false,sound:false)
            await send("PermissionRequest"); expect(.permission)
            precondition(item.button?.toolTip?.contains("Codex · 图标验证") == true)
            await send("UserPromptSubmit"); expect(.working)
            await send("Stop"); expect(.responded)
            controller.agentSettings.disabledStates.insert("responded"); expect(.idle)
            controller.agentSettings.disabledStates.remove("responded"); expect(.responded)
            controller.agentSettings.removeLocal("codex"); expect(.idle)
            _ = controller.agentSettings.add(name:"Codex",source:.codex,color:0x78C8EB); expect(.idle)
            print("PASS 10 distinct fixed-size templates; all previews; timed restore; pause; real bridge transitions; live tooltip; disabled state; removal without revival")
            store.stopRemindersForTransfer(); app.terminate(nil)
        }
        withExtendedLifetime((controller,menu)) { app.run() }
    }
}
