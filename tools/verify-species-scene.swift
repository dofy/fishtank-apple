// Compile with Sources (excluding FishtankApp.swift) into an isolated renderqa app.
// FISHTANK_UI_TEST_ID=<uuid> QA.app/Contents/MacOS/FishtankMac <output-directory>
import AppKit
import SpriteKit
import ImageIO
import UniformTypeIdentifiers

@main struct SpeciesSceneVerification {
    @MainActor static func main() {
        precondition(Bundle.main.bundleIdentifier?.hasPrefix("net.yahaha.fishtank.renderqa.") == true)
        precondition(ProcessInfo.processInfo.environment["FISHTANK_UI_TEST_ID"].flatMap(UUID.init(uuidString:)) != nil)
        let app = NSApplication.shared; app.setActivationPolicy(.accessory)
        PixelTheme.registerFont()
        let scene = AquariumScene()
        let view = SKView(frame: NSRect(x: 0, y: 0, width: 640, height: 360))
        view.preferredFramesPerSecond = 30
        let window = NSWindow(contentRect: view.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = view; window.center(); window.orderFrontRegardless()
        view.presentScene(scene)
        let names = ["bandedkrait", "ambereel", "volteel", "auroraeel", "leviathanfry", "moonjelly", "coralseahorse", "jadeturtle", "voidray", "neonstreak", "neonstreak", "neonstreak"]
        let animals = names.enumerated().map { index, name -> AquariumFish in
            var fish = AquariumFish.make(species: FishCatalog.byID[name]!, at: Date(timeIntervalSince1970: 1_800_000_000), adult: true)
            fish.id = UUID(uuidString: String(format: "23456789-1234-4321-ABCD-%012d", index + 1))!
            return fish
        }
        scene.populate(with: animals)
        var demo = AquariumState.newGame(at: Date(timeIntervalSince1970: 1_800_000_000))
        demo.fish = animals; demo.tankIDs = animals.map(\.id); demo.exp = FishBalance.levelThresholds.last!
        demo.decorations = [.init(id: "kelp", x: 0.22), .init(id: "rocks", x: 0.5), .init(id: "shell", x: 0.78)]
        scene.syncExtras(from: demo, at: Date(timeIntervalSince1970: 1_800_000_000))
        Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 200_000_000)
                view.isPaused = true
                scene.resetFrameClock()
                let root = URL(fileURLWithPath: CommandLine.arguments[1]); try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                var clock = 0.0, rested = false, schooled = false
                for _ in 0..<1200 {
                    clock += 0.1; scene.update(clock)
                    let ecology = Mirror(reflecting: scene).children.first { $0.label == "ecology" }!.value as! AquariumEcology
                    rested = rested || ecology.swimmers.values.contains { $0.resting > 0 }
                    schooled = schooled || ecology.swimmers.values.contains { $0.school != nil }
                    precondition(ecology.swimmers.count == animals.count)
                    precondition(ecology.swimmers.values.allSatisfy { $0.x.isFinite && $0.y.isFinite && (23...297).contains($0.x) })
                }
                precondition(rested && schooled, "Native scene never rested or schooled")
                print("PASS actual SpriteKit scene: mixed families, rest and same-species schooling")
                let gif = CGImageDestinationCreateWithURL(root.appendingPathComponent("aquarium-motion.gif") as CFURL, UTType.gif.identifier as CFString, 96, nil)!
                CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
                var fingerprints = Set<Data>()
                for frame in 0..<96 {
                    clock += 1.0 / 12; scene.update(clock)
                    let texture = view.texture(from: scene)!
                    let image = texture.cgImage()
                    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 640, pixelsHigh: 360, bitsPerSample: 8, samplesPerPixel: 4,
                        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
                    context.cgContext.interpolationQuality = .none
                    context.cgContext.draw(image, in: CGRect(x: 0, y: 0, width: 640, height: 360))
                    let pixels = bitmap.cgImage!
                    fingerprints.insert(Data(pixels.dataProvider!.data! as Data))
                    if frame == 0 { try bitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("aquarium-motion.png")) }
                    CGImageDestinationAddImage(gif, pixels, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 12]] as CFDictionary)
                }
                precondition(fingerprints.count > 90, "Rendered animation froze")
                precondition(CGImageDestinationFinalize(gif))
                print("PASS native rendered poses and trajectories; GIF:", root.appendingPathComponent("aquarium-motion.gif").path)
            } catch { print("FAIL native scene", error); exit(2) }
            window.close(); app.terminate(nil)
        }
        withExtendedLifetime((window, view, scene)) { app.run() }
    }
}
