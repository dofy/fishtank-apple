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
        func currentView() -> SKView {
            Mirror(reflecting: controller).children.first { $0.label == "spriteView" }!.value as! SKView
        }
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
            let originalRoots = scene.children.map(ObjectIdentifier.init)
            let beforeSleepView = ObjectIdentifier(currentView())
            NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.screensDidSleepNotification, object: NSWorkspace.shared)
            scene.isPaused = true
            await wait(14)
            let missedWakeAdvanced = await advancing()
            precondition(missedWakeAdvanced && !scene.isPaused, "Missing a wake notification must not permanently suspend recovery")
            precondition(ObjectIdentifier(currentView()) != beforeSleepView, "Stalled suspension must rebuild its renderer")
            precondition(scene.children.map(ObjectIdentifier.init) == originalRoots, "Rebuilding the view preserves the scene graph")
            print("PASS missed wake rebuilds renderer and preserves scene graph")
            let wakeView = ObjectIdentifier(currentView())
            NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.screensDidWakeNotification, object: NSWorkspace.shared)
            await wait(2)
            let woke = await advancing()
            precondition(ObjectIdentifier(currentView()) != wakeView && woke, "Wake must replace the stale surface and resume frames")
            print("PASS wake replaces render surface")
            scene.isPaused = true
            await wait(8)
            let sceneAdvanced = await advancing(); precondition(!scene.isPaused && sceneAdvanced, "Watchdog must recover paused scene")
            print("PASS scene pause recovered")
            currentView().isPaused = true
            await wait(8)
            let viewAdvanced = await advancing(); precondition(!currentView().isPaused && viewAdvanced, "Watchdog must recover paused view")
            print("PASS view pause recovered")
            precondition(panel.frame == originalFrame, "Recovery must not move the tank")
            controller.hide()
            await wait(7)
            precondition(currentView().isPaused && scene.isPaused, "Hidden tank must remain paused")
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
