// Compile all Sources Swift files except FishtankApp.swift with -D DEBUG and this entry point.
// Run only from a separately identified QA app with FISHTANK_UI_TEST_ID set to a fresh UUID.
import AppKit
import SpriteKit

@main struct VerifyDesktopAnimation {
    @MainActor static func main() {
        guard Bundle.main.bundleIdentifier?.hasPrefix("net.yahaha.fishtank.renderqa.") == true,
              ProcessInfo.processInfo.environment["FISHTANK_UI_TEST_ID"].flatMap(UUID.init(uuidString:)) != nil else {
            fatalError("Requires isolated QA bundle and temporary save")
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let store = AquariumStore()
        let controller = FloatingAquariumController(store: store)
        let fields = Dictionary(uniqueKeysWithValues: Mirror(reflecting: controller).children.compactMap { item in
            item.label.map { ($0, item.value) }
        })
        let scene = fields["scene"] as! AquariumScene
        let view = fields["spriteView"] as! SKView
        let panel = fields["panel"] as! NSPanel
        panel.setFrameOrigin(NSPoint(x: 40, y: 80))
        controller.show()
        Task { @MainActor in
            @MainActor func wait(_ seconds: Double) async { try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
            @MainActor func advancing() async -> Bool {
                let previous = scene.lastFrameUptime ?? 0
                await wait(1)
                return (scene.lastFrameUptime ?? 0) > previous
            }
            await wait(2)
            let initial = await advancing(); precondition(initial, "Initial frames must advance")
            let originalFrame = panel.frame
            scene.isPaused = true
            await wait(8)
            let sceneAdvanced = await advancing(); precondition(!scene.isPaused && sceneAdvanced, "Watchdog must recover paused scene")
            print("PASS scene pause recovered")
            view.isPaused = true
            await wait(8)
            let viewAdvanced = await advancing(); precondition(!view.isPaused && viewAdvanced, "Watchdog must recover paused view")
            print("PASS view pause recovered")
            precondition(panel.frame == originalFrame, "Recovery must not move the tank")
            controller.hide()
            await wait(7)
            precondition(view.isPaused && scene.isPaused, "Hidden tank must remain paused")
            controller.show()
            await wait(2)
            let reopened = await advancing(); precondition(reopened, "Showing must resume frames")
            print("PASS hidden pause and reopen; window position retained")
            controller.hide()
            store.stopRemindersForTransfer()
            app.terminate(nil)
        }
        app.run()
    }
}
