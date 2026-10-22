// swiftc Sources/Core/*.swift Sources/Rendering/PixelArt.swift tools/verify-creature-art.swift -o build/verify-creature-art
// build/verify-creature-art [output-directory]
import AppKit
import ImageIO
import UniformTypeIdentifiers

@main struct CreatureArtVerification {
    static func bytes(_ image: CGImage) -> [UInt8] { [UInt8](image.dataProvider!.data! as Data) }
    static func mask(_ species: FishSpecies) -> Set<Int> {
        let pixels = bytes(PixelArt.image(species: species, grade: 1))
        return Set((0..<3072).filter { pixels[$0 * 4 + 3] > 0 })
    }
    static func main() throws {
        let snakes = FishCatalog.all.filter { $0.form == "eel" || $0.form == "seasnake" }
        for (i, a) in snakes.enumerated() {
            for b in snakes.dropFirst(i + 1) {
                let lhs = mask(a), rhs = mask(b)
                let overlap = Double(lhs.intersection(rhs).count) / Double(lhs.union(rhs).count)
                precondition(overlap < 0.82, "Silhouettes too similar: \(a.id), \(b.id): \(overlap)")
                print("PASS distinct silhouette", a.id, b.id, String(format: "overlap %.2f", overlap))
            }
        }
        for species in FishCatalog.all {
            let grades = (1...5).map { Data(bytes(PixelArt.image(species: species, grade: $0))) }
            precondition(Set(grades).count == 5, "Appearance grades collapsed: \(species.id)")
            let count = PixelArt.animationFrameCount(for: species)
            let frames = (0..<count).map { bytes(PixelArt.image(species: species, grade: 1, frame: $0)) }
            precondition(Set(frames.map { Data($0) }).count >= 3, "Static species: \(species.id)")
            for frame in frames {
                precondition(frame.count == 64 * 48 * 4)
                precondition(stride(from: 3, to: frame.count, by: 4).filter { frame[$0] > 0 }.count > 100)
            }
        }
        print("PASS 29 original species retain animated pixel poses")
        guard CommandLine.arguments.count > 1 else { return }
        let root = URL(fileURLWithPath: CommandLine.arguments[1]); try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: "Sources/Resources/Fonts/FusionPixel.otf") as CFURL, .process, nil)
        let font = NSFont(name: "Fusion-Pixel-12px-Mono-zh-Hans-Regular", size: 12)!
        let selected = ["bandedkrait", "ambereel", "volteel", "auroraeel", "leviathanfry", "goldfin", "neonstreak", "creampuff", "moonjelly", "crystaljelly", "astraljelly", "coralseahorse", "goldenseahorse", "jadeturtle", "voidray", "banggai"].map { FishCatalog.byID[$0]! }
        let gifURL = root.appendingPathComponent("creature-poses.gif")
        let destination = CGImageDestinationCreateWithURL(gifURL as CFURL, UTType.gif.identifier as CFString, 32, nil)!
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<32 {
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 832, pixelsHigh: 640,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            let context = NSGraphicsContext(bitmapImageRep: bitmap)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
            context.imageInterpolation = .none
            NSColor(red: 0.078, green: 0.184, blue: 0.25, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: 832, height: 640).fill()
            for (index, species) in selected.enumerated() {
                let x = index % 4 * 208, y = (3 - index / 4) * 160
                let time = Double(frame) / 12 * species.swimProfile.tempo
                let pose = PixelArt.animationFrame(for: species, time: time)
                context.cgContext.draw(PixelArt.image(species: species, grade: 1, frame: pose), in: CGRect(x: x + 24, y: y + 34, width: 160, height: 120))
                (species.nameKey as NSString).draw(at: CGPoint(x: x + 16, y: y + 12), withAttributes: [.font: font, .foregroundColor: NSColor(red: 0.94, green: 0.93, blue: 0.83, alpha: 1)])
            }
            NSGraphicsContext.restoreGraphicsState()
            if frame == 0 { try bitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("creature-poses.png")) }
            CGImageDestinationAddImage(destination, bitmap.cgImage!, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 12]] as CFDictionary)
        }
        precondition(CGImageDestinationFinalize(destination))
        print("Preview:", gifURL.path)
    }
}
