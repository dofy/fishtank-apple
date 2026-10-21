// swiftc Sources/Core/*.swift Sources/Rendering/*.swift Sources/App/PixelTheme.swift tools/verify-render-recovery.swift -o /tmp/fishtank-render-recovery
import AppKit
import SpriteKit
@main struct VerifyRenderRecovery {
    @MainActor static func main() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let view = AquariumRenderView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        let scene = AquariumScene()
        view.presentScene(scene)
        let state = AquariumState.newGame(at: Date())
        scene.populate(with: state.tankFish)
        scene.syncExtras(from: state, at: Date())
        scene.setWaterOpacity(0.2)
        scene.update(0)
        let root = scene.children.first!
        let nodes = root.children.map(ObjectIdentifier.init)
        let water = root.children.prefix(45).compactMap { $0 as? SKSpriteNode }
        precondition(water.count == 45)
        for iteration in 0..<20 {
            view.isPaused = iteration.isMultiple(of: 2)
            // Simulate a lost presentation, as well as an intact paused surface.
            if iteration.isMultiple(of: 3) { view.presentScene(nil) }
            let paused = view.isPaused
            view.restorePresentation(of: scene)
            precondition(view.scene === scene && scene.view === view)
            precondition(view.isPaused == paused && view.allowsTransparency)
            precondition(root.children.map(ObjectIdentifier.init) == nodes)
            precondition(water.allSatisfy { abs($0.alpha - 0.2) < 0.001 })
            let texture = view.texture(from: scene)!
            let image = NSBitmapImageRep(cgImage: texture.cgImage())
            var colors = Set<String>()
            var translucent = false
            for y in stride(from: 8, to: image.pixelsHigh - 8, by: 8) {
                for x in stride(from: 8, to: image.pixelsWide - 8, by: 8) {
                    let color = image.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
                    colors.insert(String(format: "%.2f/%.2f/%.2f", color.redComponent, color.greenComponent, color.blueComponent))
                    if color.alphaComponent > 0.05 && color.alphaComponent < 0.95 { translucent = true }
                }
            }
            precondition(colors.count > 8 && translucent, "Recovered image must contain aquarium detail and transparent water")
        }
        print("PASS: 20 presentation recoveries retain scene nodes, pause state, transparent water and renderable textures.")
    }
}
