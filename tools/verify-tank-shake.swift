// Compile with Sources excluding FishtankApp.swift into an isolated DEBUG QA bundle.
import AppKit
import SpriteKit
import AVFoundation

@main struct VerifyTankShake {
    @MainActor static func main() {
        guard Bundle.main.bundleIdentifier?.hasPrefix("net.yahaha.fishtank.renderqa.") == true,
              ProcessInfo.processInfo.environment["FISHTANK_UI_TEST_ID"].flatMap(UUID.init(uuidString:)) != nil else {
            FileHandle.standardError.write(Data("Requires isolated QA bundle and temporary save\n".utf8)); exit(2)
        }
        setbuf(stdout, nil)
        let app = NSApplication.shared; app.setActivationPolicy(.accessory)
        let store = AquariumStore()
        var audio = store.state.audio; audio.musicEnabled = false; audio.sfxEnabled = false; store.setAudio(audio)
        let controller = FloatingAquariumController(store: store)
        let fields = Dictionary(uniqueKeysWithValues: Mirror(reflecting: controller).children.compactMap { value in value.label.map { ($0,value.value) } })
        let scene = fields["scene"] as! AquariumScene, view = fields["spriteView"] as! SKView, panel = fields["panel"] as! NSPanel
        let tank = Mirror(reflecting:scene).children.first { $0.label == "tankRoot" }!.value as! SKNode
        let decor = Mirror(reflecting:scene).children.first { $0.label == "decorRoot" }!.value as! SKNode
        var effects: [String] = []; scene.effect = { effects.append($0) }
        func require(_ condition: Bool, _ message: String) {
            guard condition else { print("FAIL",message);store.stopRemindersForTransfer();exit(2) }
        }
        func ecology() -> AquariumEcology { Mirror(reflecting:scene).children.first { $0.label == "ecology" }!.value as! AquariumEcology }
        func mouse(_ type: NSEvent.EventType,_ point: CGPoint) {
            let location = view.convert(scene.convertPoint(toView:point),to:nil)
            let event = NSEvent.mouseEvent(with:type,location:location,modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,
                                          windowNumber:panel.windowNumber,context:nil,eventNumber:1,clickCount:1,pressure:1)!
            app.sendEvent(event)
        }
        func rightClick(_ point: CGPoint) { mouse(.rightMouseDown,point);mouse(.rightMouseUp,point) }
        controller.show()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds:200_000_000)
            scene.isPaused = true;view.isPaused = true
            let fish = store.state.fish, exp = store.state.exp, random = store.state.random.seed
            let foods = ecology().foods.count
            for scale in [1,2,3] {
                controller.pixelScale = scale
                let original = panel.frame
                let swimmer = ecology().swimmers.values.first!
                let shell = decor.childNode(withName:"shell")!
                let decoration = scene.convert(CGPoint(x:shell.frame.midX,y:shell.frame.midY),from:decor)
                for point in [CGPoint(x:160,y:150),CGPoint(x:swimmer.x,y:swimmer.y),decoration] {
                    let count = effects.count
                    rightClick(point)
                    require(effects.count == count+1 && effects.last == "scare","Right-click on water, fish and decoration must play one scare cue")
                    require(ecology().swimmers.values.allSatisfy { (3...5).contains($0.scared) },"Every fish must startle for 3–5 seconds")
                    require(tank.action(forKey:"tankShake") != nil,"Shake action must be active")
                    require(panel.frame == original && ecology().foods.count == foods,"Right-click must neither move the window nor feed")
                    try? await Task.sleep(nanoseconds:200_000_000)
                }
            }
            let count = effects.count
            rightClick(CGPoint(x:0,y:0));require(effects.count == count,"Transparent corner must not shake")
            rightClick(CGPoint(x:160,y:150));let after = effects.count
            rightClick(CGPoint(x:160,y:150));require(effects.count == after,"Rapid repeats must not stack audio or animation")
            scene.isPaused = false;view.isPaused = false
            var moved = false
            for _ in 0..<30 {
                try? await Task.sleep(nanoseconds:30_000_000)
                moved = moved || tank.position != .zero
            }
            require(moved && tank.position == .zero && tank.action(forKey:"tankShake") == nil,"Shake must visibly move then return exactly to origin")
            let url = Bundle.main.url(forResource:"scare",withExtension:"wav")!
            let sound = try! AVAudioPlayer(contentsOf:url)
            require(sound.duration > 0 && sound.prepareToPlay(),"Bundled scare audio must decode")
            require(store.state.fish == fish && store.state.exp == exp && store.state.random.seed == random,"Shake must not change fish, XP or breeding RNG")
            print("PASS all 3 sizes: native right clicks on water/fish/decor, all-fish 3–5s startle, audio dispatch and decode, no feed/window movement, bounded repeated clicks, visible shake and exact reset, unchanged gameplay")
            controller.hide();store.stopRemindersForTransfer();app.terminate(nil)
        }
        withExtendedLifetime(controller) { app.run() }
    }
}
