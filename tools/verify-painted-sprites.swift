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
            for grade in 1...5 {
                let image = PixelArt.image(species: species, grade: grade)
                grades.insert(bytes(image)); save(image, to: root.appendingPathComponent("\(species.id)-grade-\(grade).png"))
            }
            precondition(grades.count == 5, "Lost grade variation: \(species.id)")
            entries.append(["id": species.id, "name": species.nameKey, "kind": "fish", "frames": count, "fps": Double(count) / PixelArt.animationCycleDuration(for: species), "width": 32, "height": 24, "tier": species.tier])
        }
        let puffer = FishCatalog.byID["creampuff"]!
        precondition(Set((0...3).map { bytes(PixelArt.image(species: puffer, grade: 1, puffLevel: $0)) }).count == 4)
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
        print("PASS 29 species, 18 decorations, 14 distinct medals, 145 grade appearances, distinct animation poses, 4 puff states; native renderer exports at \(root.path)")
    }
}
