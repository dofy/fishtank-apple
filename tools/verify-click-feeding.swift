// Compile all Sources except FishtankApp.swift into an isolated DEBUG QA app.
import AppKit
import SpriteKit

@main struct VerifyClickFeeding {
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
        let scene = fields["scene"] as! AquariumScene
        let view = fields["spriteView"] as! SKView
        let panel = fields["panel"] as! NSPanel
        controller.show(); scene.isPaused = true; view.isPaused = true
        func require(_ condition: Bool, _ message: String) {
            guard condition else { print("FAIL",message);store.stopRemindersForTransfer();exit(2) }
        }
        func ecology() -> AquariumEcology { Mirror(reflecting: scene).children.first { $0.label == "ecology" }!.value as! AquariumEcology }
        func point(_ x: CGFloat,_ y: CGFloat) -> CGPoint { view.convert(scene.convertPoint(toView: CGPoint(x:x,y:y)), to:nil) }
        func event(_ type: NSEvent.EventType,_ at: CGPoint,_ count: Int = 1) -> NSEvent {
            NSEvent.mouseEvent(with:type,location:at,modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,
                               windowNumber:panel.windowNumber,context:nil,eventNumber:1,clickCount:count,pressure:1)!
        }
        func click(_ at: CGPoint,_ count: Int = 1) {
            view.mouseDown(with:event(.leftMouseDown,at,count));view.mouseUp(with:event(.leftMouseUp,at,count))
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            scene.isPaused = true; view.isPaused = true
            let fishBefore = store.state.fish, expBefore = store.state.exp, randomBefore = store.state.random.seed
            for scale in [1,2,3] {
                controller.pixelScale = scale
                for x in [CGFloat(80),CGFloat(160),CGFloat(260)] {
                    let before = ecology().foods.count
                    let origin = panel.frame.origin
                    let p = point(x,150)
                    view.mouseDown(with:event(.leftMouseDown,p))
                    require(ecology().foods.count == before,"Mouse-down must wait for click/drag discrimination")
                    view.mouseUp(with:event(.leftMouseUp,p))
                    let food = ecology().foods.last!
                    require(ecology().foods.count == before+1,"One blank click must feed exactly one pellet")
                    require(abs(food.x-Double(x))<0.001 && abs(food.y-164)<0.001,"Mouse X must scale correctly and food must start at the surface")
                    require(panel.frame.origin == origin,"A click must not move the tank")
                }
                let before = ecology().foods.count
                let p = point(220,150), origin = panel.frame.origin
                view.mouseDown(with:event(.leftMouseDown,p))
                let moved = CGPoint(x:p.x+24,y:p.y+12)
                view.mouseDragged(with:event(.leftMouseDragged,moved))
                let global = CGPoint(x:origin.x+moved.x,y:origin.y+moved.y)
                view.mouseUp(with:event(.leftMouseUp,panel.convertPoint(fromScreen:global)))
                require(ecology().foods.count == before,"Dragging must never feed")
                require(abs(panel.frame.minX-origin.x-24)<0.001 && abs(panel.frame.minY-origin.y-12)<0.001,"Tank drag must follow the event position without moving the real cursor")
                let tiny = point(220,150), currentOrigin = panel.frame.origin
                view.mouseDown(with:event(.leftMouseDown,tiny))
                let jitter = CGPoint(x:tiny.x+2,y:tiny.y)
                view.mouseDragged(with:event(.leftMouseDragged,jitter));view.mouseUp(with:event(.leftMouseUp,jitter))
                require(panel.frame.origin == currentOrigin && ecology().foods.count == before+1,"Small mouse jitter must remain a click")
            }
            let beforeFish = ecology().foods.count
            if let swimmer = ecology().swimmers.values.first {
                click(point(CGFloat(swimmer.x),CGFloat(swimmer.y)))
                require(ecology().foods.count == beforeFish,"Tapping a fish must not feed")
            } else { require(false,"Expected a starter fish") }
            let decorRoot = Mirror(reflecting:scene).children.first { $0.label == "decorRoot" }!.value as! SKNode
            let shell = decorRoot.childNode(withName:"shell")!
            let center = CGPoint(x:shell.frame.midX,y:shell.frame.midY)
            let scenePoint = scene.convert(center,from:decorRoot)
            let p = point(scenePoint.x,scenePoint.y), originalTank = panel.frame
            view.mouseDown(with:event(.leftMouseDown,p))
            let moved = CGPoint(x:p.x-18,y:p.y)
            view.mouseDragged(with:event(.leftMouseDragged,moved));view.mouseUp(with:event(.leftMouseUp,moved))
            require(ecology().foods.count == beforeFish && panel.frame == originalTank,"Decoration dragging must not feed or drag the tank")
            require(!scene.containsTankPoint(CGPoint(x:0,y:0)),"Transparent corner must be excluded")
            click(point(0,0));require(ecology().foods.count == beforeFish,"Transparent corner must not feed")
            click(point(260,150),2);require(ecology().foods.count == beforeFish+1,"Second click in a double-click must add just one pellet")
            controller.feed();require(abs(ecology().foods.last!.x-160)<0.001,"Menu feeding retains its centered default")
            require(store.state.fish == fishBefore && store.state.exp == expBefore && store.state.random.seed == randomBefore,"Feeding must not mutate fish, XP or gameplay RNG")
            print("PASS all 3 tank sizes: single blank click, pointer X, surface height, one pellet, click jitter, window drag, fish tap, decoration drag, transparent corners and menu default")
            controller.hide();store.stopRemindersForTransfer();app.terminate(nil)
        }
        withExtendedLifetime(controller) { app.run() }
    }
}
