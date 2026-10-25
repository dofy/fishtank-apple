// Run with FISHTANK_ART_ROOT=Sources/Resources/PixelSprites; exports only synthetic art previews.
// swiftc Sources/Core/*.swift Sources/Rendering/{PixelArt,PaintedSprites,DecorArt}.swift tools/verify-painted-sprites.swift -o build/verify-painted-sprites
import AppKit
import ImageIO
import UniformTypeIdentifiers

@main struct PaintedSpriteVerification {
    static func bytes(_ image: CGImage) -> Data { image.dataProvider!.data! as Data }
    static func save(_ image: CGImage, to url: URL) {
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        precondition(CGImageDestinationFinalize(destination))
    }
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/style-samples/full")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var entries: [[String: Any]] = []
        for species in FishCatalog.all {
            precondition(PaintedSprites.assetURL(species.id) != nil, "Missing fish artwork: \(species.id)")
            let count = PixelArt.animationFrameCount(for: species)
            let duration = PixelArt.animationCycleDuration(for: species)
            var previous = 0
            for tick in 0...600 {
                let frame = PixelArt.animationFrame(for: species, time: Double(tick) / 60)
                let step = (frame - previous + count) % count
                precondition(step <= 1, "Skipped animation pose: \(species.id)")
                previous = frame
            }
            precondition(PixelArt.animationFrame(for: species, time: duration) == 0)
            var frames = Set<Data>(), grades = Set<Data>()
            for frame in 0..<count {
                guard let rendered = PaintedSprites.fish(species, grade: 1, frame: frame, puffLevel: 0) else { fatalError("Invalid image \(species.id)") }
                precondition(rendered.width == 64 && rendered.height == 48)
                let raw = [UInt8](bytes(rendered))
                precondition(stride(from: 3, to: raw.count, by: 4).filter { raw[$0] > 0 }.count > 100, "Unreadable silhouette \(species.id)")
                frames.insert(bytes(rendered)); save(rendered, to: root.appendingPathComponent("\(species.id)-\(frame).png"))
                precondition(bytes(PixelArt.image(species: species, grade: 1, frame: frame)) == bytes(rendered), "Legacy renderer used \(species.id)")
            }
            precondition(frames.count >= 3, "Static motion: \(species.id)")
            if ["jadeturtle", "skywing", "voidray"].contains(species.id) {
                // Limb-region changes must be visible without relying on tail motion.
                let a = [UInt8](bytes(PaintedSprites.fish(species, grade: 1, frame: 8, puffLevel: 0)!))
                let b = [UInt8](bytes(PaintedSprites.fish(species, grade: 1, frame: 24, puffLevel: 0)!))
                var changed = 0
                for y in 28..<44 { for x in 24..<48 {
                    let i = (y * 64 + x) * 4
                    if a[i + 3] != b[i + 3] { changed += 1 }
                } }
                precondition(changed >= 12, "Frozen limb silhouette: \(species.id) (\(changed))")
                print("PASS animated limb silhouette: \(species.id), \(changed) changed pixels")
            }
            if ["jadeturtle", "creampuff"].contains(species.id) {
                // The shell / puffer torso must remain rigid while appendages move.
                let first = [UInt8](bytes(PaintedSprites.fish(species, grade: 1, frame: 0, puffLevel: 0)!))
                for frame in 1..<count {
                    let pose = [UInt8](bytes(PaintedSprites.fish(species, grade: 1, frame: frame, puffLevel: 0)!))
                    for y in 18..<23 { for x in 27..<37 {
                        let offset = (y * 64 + x) * 4
                        precondition(Array(first[offset..<offset + 4]) == Array(pose[offset..<offset + 4]), "Torso wobble: \(species.id)")
                    } }
                }
            }
            for grade in 1...5 {
                let image = PixelArt.image(species: species, grade: grade)
                grades.insert(bytes(image)); save(image, to: root.appendingPathComponent("\(species.id)-grade-\(grade).png"))
            }
            precondition(grades.count == 5, "Lost grade variation: \(species.id)")
            entries.append(["id": species.id, "name": species.nameKey, "kind": "fish", "frames": count, "fps": Double(count) / PixelArt.animationCycleDuration(for: species), "width": 32, "height": 24, "tier": species.tier])
        }
        let puffer = FishCatalog.byID["creampuff"]!
        precondition(Set((0...3).map { bytes(PixelArt.image(species: puffer, grade: 1, puffLevel: $0)) }).count == 4)
        let cuttlefish = FishCatalog.byID["cuttlefish"]!
        for level in 0...3 { for frame in 0..<32 {
            let image = PixelArt.image(species: cuttlefish, grade: 1, frame: frame, jetLevel: level)
            precondition(bytes(image) == bytes(PaintedSprites.fish(cuttlefish, grade: 1, frame: frame, puffLevel: 0, jetLevel: level)!))
            let pixels = [UInt8](bytes(image))
            precondition(stride(from: 3, to: pixels.count, by: 4).filter { pixels[$0] > 0 }.count > 100)
        } }
        precondition(Set((0...3).map { bytes(PixelArt.image(species: cuttlefish, grade: 1, frame: 8, jetLevel: $0)) }).count == 4)
        precondition(bytes(PixelArt.image(species: cuttlefish, grade: 1, frame: 8, jetLevel: 99)) == bytes(PixelArt.image(species: cuttlefish, grade: 1, frame: 8, jetLevel: 3)))
        print("PASS four bounded cuttlefish jet poses with streamlined trailing arms")
        for item in DecorCatalog.all {
            guard let image = PaintedSprites.decor(item) else { fatalError("Missing decoration \(item.id)") }
            precondition(bytes(DecorArt.image(item)) == bytes(image))
            save(image, to: root.appendingPathComponent("\(item.id)-0.png"))
            entries.append(["id": item.id, "name": item.nameKey, "kind": "decor", "frames": 1,
                            "width": item.displayWidth,
                            "height": item.displayHeight, "top": item.top])
        }
        var medals = Set<Data>()
        for item in AchievementCatalog.all {
            guard let image = PaintedSprites.medal(item.id) else { fatalError("Missing medal \(item.id)") }
            precondition(bytes(DecorArt.medal(item.id)) == bytes(image))
            medals.insert(bytes(image))
            save(image, to: root.appendingPathComponent("medal-\(item.id)-0.png"))
        }
        precondition(medals.count == AchievementCatalog.all.count)
        try JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys]).write(to: root.appendingPathComponent("catalog.json"))
        let template = URL(fileURLWithPath: "tools/painted-sprites-preview.html")
        if FileManager.default.fileExists(atPath: template.path) {
            try Data(contentsOf: template).write(to: root.appendingPathComponent("index.html"))
        }
        print("PASS \(FishCatalog.all.count) species, \(DecorCatalog.all.count) decorations, \(AchievementCatalog.all.count) distinct medals, \(FishCatalog.all.count * 5) grade appearances, distinct animation poses, 4 puff states; native renderer exports at \(root.path)")
    }
}
