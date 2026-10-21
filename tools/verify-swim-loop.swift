// swiftc Sources/Core/*.swift Sources/Rendering/PixelArt.swift tools/verify-swim-loop.swift -o /tmp/fishtank-swim-loop
// /tmp/fishtank-swim-loop [output.gif]
import AppKit
import ImageIO
import UniformTypeIdentifiers

@main struct SwimLoopVerification {
    enum Failure: Error { case invalid(String) }
    static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw Failure.invalid(message) }
    }
    static func bytes(_ image: CGImage) -> [UInt8] { [UInt8](image.dataProvider!.data! as Data) }
    static func mask(_ image: CGImage) -> [Bool] {
        let data = bytes(image)
        return (0..<(image.width * image.height)).map { data[$0 * 4 + 3] != 0 }
    }
    static func main() throws {
        let species = FishCatalog.all.filter { $0.form == "eel" || $0.form == "seasnake" }
        for fish in species {
            let count = PixelArt.animationFrameCount(for: fish)
            try require(count == 16, "Incomplete phase count: \(fish.id)")
            let frames = (0..<count).map { PixelArt.image(species: fish, grade: 1, frame: $0) }
            let masks = frames.map(mask)
            let differences = (0..<count).map { i in zip(masks[i], masks[(i + 1) % count]).filter { $0 != $1 }.count }
            try require(differences.allSatisfy { $0 > 0 }, "Repeated pose: \(fish.id)")
            // The wrap step must be as small as other steps, rather than resetting across half a wave.
            try require(Double(differences.last!) <= Double(differences.dropLast().max()!) * 1.15,
                        "Discontinuous wrap: \(fish.id): \(differences)")
            try require(bytes(frames[0]) == bytes(PixelArt.image(species: fish, grade: 1, frame: count)),
                        "Frame normalization does not loop: \(fish.id)")
            for (frame, image) in frames.enumerated() {
                let time = (Double(frame) + 0.25) / 12
                try require(PixelArt.animationFrame(for: fish, time: time) == frame
                            && PixelArt.animationFrame(for: fish, time: time + Double(count) / 12) == frame,
                            "Playback phase skips a frame: \(fish.id):\(frame)")
                let data = bytes(image)
                try require(stride(from: 0, to: data.count, by: 4).contains {
                    data[$0] == 255 && data[$0 + 1] == 244 && data[$0 + 2] == 211 && data[$0 + 3] == 255
                }, "Eye detached from body: \(fish.id):\(frame)")
                var remaining = Set(masks[frame].indices.filter { masks[frame][$0] })
                var stack = [remaining.removeFirst()]
                while let i = stack.popLast() {
                    for dy in -1...1 { for dx in -1...1 {
                        let x = i % image.width + dx, y = i / image.width + dy
                        if x >= 0 && x < image.width && y >= 0 && y < image.height,
                           let neighbor = remaining.remove(y * image.width + x) { stack.append(neighbor) }
                    } }
                }
                try require(remaining.isEmpty, "Detached fin pixels: \(fish.id):\(frame)")
            }
            print("PASS \(fish.id): 16 poses, wrap difference \(differences.last!); adjacent range \(differences.min()!)...\(differences.max()!)")
        }
        guard CommandLine.arguments.count > 1 else { return }
        CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: "Sources/Resources/Fonts/FusionPixel.otf") as CFURL, .process, nil)
        let width = species.count * 208, height = 184
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 16, nil)!
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<16 {
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            let context = NSGraphicsContext(bitmapImageRep: bitmap)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
            context.imageInterpolation = .none
            NSColor(red: 0.078, green: 0.184, blue: 0.25, alpha: 1).setFill()
            NSRect(x: 0, y: 0, width: width, height: height).fill()
            for (index, fish) in species.enumerated() {
                let x = index * 208
                context.cgContext.draw(PixelArt.image(species: fish, grade: 1, frame: frame),
                                       in: CGRect(x: x + 8, y: 28, width: 192, height: 144))
                (fish.name as NSString).draw(at: CGPoint(x: x + 12, y: 10), withAttributes: [
                    .font: NSFont(name: "Fusion-Pixel-12px-Mono-zh-Hans-Regular", size: 12)!,
                    .foregroundColor: NSColor(red: 0.95, green: 0.83, blue: 0.6, alpha: 1)])
            }
            NSGraphicsContext.restoreGraphicsState()
            CGImageDestinationAddImage(destination, bitmap.cgImage!,
                [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 12]] as CFDictionary)
        }
        try require(CGImageDestinationFinalize(destination), "GIF export failed")
        print("Preview: \(url.path)")
    }
}
