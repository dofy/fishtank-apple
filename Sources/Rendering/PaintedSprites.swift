import Foundation
import CoreGraphics
import ImageIO

/// Shared raster import and pixel-pose pipeline for the approved chunky art set.
/// All consumers (tank, catalog, birth cards and icons) use the same source pixels.
enum PaintedSprites {
    private static var bases: [String: [UInt8]] = [:]

    static func assetURL(_ id: String) -> URL? {
        if let bundled = Bundle.main.url(forResource: id, withExtension: "png", subdirectory: "PixelSprites") { return bundled }
        // Standalone render verification explicitly supplies a resource directory.
        guard let root = ProcessInfo.processInfo.environment["FISHTANK_ART_ROOT"] else { return nil }
        let url = URL(fileURLWithPath: root).appendingPathComponent(id + ".png")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private static func base(_ id: String, width: Int, height: Int, anchor: String = "center", pixelAspect: Double = 1, inset: Int = 4) -> [UInt8]? {
        let key = "\(id):\(width):\(height):\(anchor):\(pixelAspect):\(inset)"
        if let cached = bases[key] { return cached }
        guard let url = assetURL(id), let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let original = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 256,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        let w = original.width, h = original.height
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        rgba.withUnsafeMutableBytes { storage in
            let c = CGContext(data: storage.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            c.draw(original, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        var minX = w, minY = h, maxX = 0, maxY = 0
        for y in 0..<h { for x in 0..<w where rgba[(y * w + x) * 4 + 3] >= 192 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        } }
        guard maxX > minX, maxY > minY else { return nil }
        // Normalize transparent padding, keep room for pixel deformation on every edge.
        let scale = min(Double(width - inset * 2) * pixelAspect / Double(maxX - minX + 1), Double(height - inset * 2) / Double(maxY - minY + 1))
        let dw = Int((Double(maxX - minX + 1) * scale / pixelAspect).rounded()), dh = Int((Double(maxY - minY + 1) * scale).rounded())
        let ox = (width - dw) / 2
        let oy = anchor == "bottom" ? height - dh - 1 : anchor == "top" ? 1 : (height - dh) / 2
        var result = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<dh { for x in 0..<dw {
            let sx = min(maxX, minX + Int(Double(x) * pixelAspect / scale)), sy = min(maxY, minY + Int(Double(y) / scale))
            let from = (sy * w + sx) * 4, to = ((oy + y) * width + ox + x) * 4
            let alpha = Int(rgba[from + 3]); guard alpha >= 160 else { continue }
            for channel in 0..<3 { result[to + channel] = UInt8(min(255, Int(rgba[from + channel]) * 255 / alpha)) }
            result[to + 3] = 255
        } }
        bases[key] = result
        return result
    }

    static func decor(_ item: AquariumDecor) -> CGImage? {
        let h = item.top ? 32 : 64
        let displayWidth = item.displayWidth
        let displayHeight = item.displayHeight
        let aspect = (displayWidth / 64) / (displayHeight / Double(h))
        guard let pixels = base(item.id, width: 64, height: h, anchor: item.top ? "top" : "bottom", pixelAspect: aspect) else { return nil }
        return image(pixels, width: 64, height: h)
    }

    static func medal(_ id: String) -> CGImage? {
        guard let pixels = base("medal-" + id, width: 24, height: 32, inset: 1) else { return nil }
        return image(pixels, width: 24, height: 32)
    }

    static func fish(_ species: FishSpecies, grade: Int, frame: Int, puffLevel: Int) -> CGImage? {
        let w = 64, h = 48
        guard let pixels = base(species.id, width: w, height: h) else { return nil }
        let count = PixelArt.animationFrameCount(for: species)
        let phase = Double(frame) * 2 * Double.pi / Double(count)
        var result = [UInt8](repeating: 0, count: w * h * 4)
        // Inverse sampling keeps silhouettes solid even at the strongest motion pose.
        for y in 0..<h { for x in 0..<w {
            var sx = Double(x), sy = Double(y)
            let tail = max(0, (40 - sx) / 40)
            switch species.form {
            case "eel", "seasnake":
                // A traveling wave grows toward the tail; the head stays readable.
                let along = max(0, min(1, (55 - sx) / 50))
                let amplitude: Double = species.form == "seasnake" ? 4.4 : species.id == "ambereel" ? 2.8 : 3.8
                let wave = phase - along * (species.form == "seasnake" ? 7.5 : 6.2)
                sy -= sin(wave) * amplitude * pow(along, 0.8)
                sx -= cos(wave) * along * 0.7
            case "jellyfish":
                let tentacle = max(0, min(1, (sy - 21) / 23))
                let bell = max(0, min(1, (25 - sy) / 8))
                let contraction = pow(max(0, sin(phase)), 3)
                // Bell contracts to propel; trailing tentacles respond later.
                sx = 32 + (sx - 32) / (1 - contraction * bell * 0.22)
                sy = 22 + (sy - 22) / (1 + contraction * bell * 0.12)
                sx -= sin(phase - tentacle * 3) * tentacle * 3.2
                sy -= sin(phase - 0.8) * tentacle * 1.8
            case "seahorse":
                // Keep the snout and torso steady. The lower tail flexes slowly,
                // while the small dorsal fin beats twice per body cycle.
                let tailWeight = max(0, min(1, (sy - 26) / 16))
                sx -= sin(phase - tailWeight * 2.8) * tailWeight * 3.0
                sy -= cos(phase - tailWeight * 2.8) * tailWeight * 1.2
                let finWeight = max(0, 1 - abs(sy - 23) / 8) * max(0, min(1, (29 - sx) / 8))
                sx -= sin(phase * 2) * finWeight * 1.8
            case "turtle":
                // Shoulder/hip anchors keep the shell still. Front flippers sweep
                // together; hind flippers recover out of phase below the shell.
                let lower = max(0, min(1, (sy - 23) / 10))
                let upper = max(0, min(1, (17 - sy) / 8))
                let rear = max(0, min(1, (29 - sx) / 9))
                let stroke = sin(phase - rear * 1.7)
                let limb = lower * lower * (3 - 2 * lower)
                sx -= stroke * limb * (4.5 - rear) + sin(phase + 1.2) * upper * 1.6
                sy -= cos(phase - rear * 1.7) * limb * 2.2
            case "ray":
                // Flex the broad wing tips, leaving the central body in place.
                let spread = max(0, abs(sy - 24) - 3)
                let wing = min(1, spread / 13)
                let side = sy < 24 ? -1.0 : 1.0
                sy -= side * sin(phase - wing * 0.8) * wing * 4.8
                sx -= cos(phase - wing * 0.8) * wing * 1.8
            default:
                if species.silhouette == "glider-fish" {
                    // Both long pectoral fins open and fold around the body axis.
                    let spread = max(0, abs(sy - 24) - 3)
                    let wing = min(1, spread / 12)
                    let side = sy < 24 ? -1.0 : 1.0
                    sy -= side * sin(phase) * wing * 5.5
                    sx -= cos(phase) * wing * 2.5
                    sy -= sin(phase) * tail * 0.8
                } else {
                    // Most fish propel from the caudal peduncle, not by bending
                    // the entire painted body. Different fin shapes get different strokes.
                    let caudal = max(0, min(1, (29 - sx) / 24))
                    let edge = max(0, min(1, (abs(sy - 24) - 9) / 10))
                    switch species.silhouette {
                    case "spiky-puffer":
                        let fin = max(0, min(1, (abs(sx - 32) - 12) / 7))
                            * max(0, 1 - abs(sy - 26) / 9)
                            * max(0, min(1, (46 - sx) / 8))
                        sy -= sin(phase * 3) * fin * 2.8
                    case "goldfish", "veil-koi", "lyretail":
                        sy -= sin(phase - caudal * 1.2) * caudal * 4.5
                        sy -= sin(phase - 1) * edge * 1.8
                    case "beak-butterfly", "crown-butterfly", "banner-cardinal", "moorish-idol":
                        sy -= sin(phase) * caudal * 1.8
                        sx -= sin(phase * 2 - sy * 0.12) * edge * 2.2
                    case "fire-goby":
                        sy -= sin(phase) * caudal * 2.4
                        sx -= sin(phase - 0.7) * max(0, (18 - sy) / 14) * 3
                    case "catfish":
                        sy -= sin(phase) * caudal * 1.8
                        sx -= sin(phase * 2) * max(0, (sy - 29) / 12) * 1.4
                    default:
                        sy -= sin(phase) * caudal * 3.2
                        let fin = max(0, 1 - abs(sx - 36) / 10) * max(0, min(1, (sy - 28) / 9))
                        sx -= sin(phase * 2) * fin * 1.3
                    }
                }
            }
            if species.id == "creampuff" {
                let puff = Double(puffLevel)
                sx = 32 + (sx - 32) / (1 + puff * 0.035)
                sy = 24 + (sy - 24) / (1 + puff * 0.065)
            }
            let ix = Int(sx.rounded()), iy = Int(sy.rounded())
            guard ix >= 0, ix < w, iy >= 0, iy < h else { continue }
            let source = (iy * w + ix) * 4, target = (y * w + x) * 4
            guard pixels[source + 3] > 0 else { continue }
            var rgb = (Double(pixels[source]) / 255, Double(pixels[source + 1]) / 255, Double(pixels[source + 2]) / 255)
            if grade > 1 { rgb = recolor(rgb, grade: grade) }
            result[target] = UInt8(max(0, min(255, (rgb.0 * 255).rounded())))
            result[target + 1] = UInt8(max(0, min(255, (rgb.1 * 255).rounded())))
            result[target + 2] = UInt8(max(0, min(255, (rgb.2 * 255).rounded())))
            result[target + 3] = 255
        } }
        return image(result, width: w, height: h)
    }

    private static func recolor(_ rgb: (Double, Double, Double), grade: Int) -> (Double, Double, Double) {
        let (r, g, b) = rgb, maximum = max(r, g, b), minimum = min(r, g, b), delta = maximum - minimum
        // Keep eyes and cream highlights neutral; saturated surfaces carry grade color.
        guard maximum > 0.15, delta > 0.035 else { return rgb }
        var hue: Double
        if maximum == r { hue = (g - b) / delta }
        else if maximum == g { hue = 2 + (b - r) / delta }
        else { hue = 4 + (r - g) / delta }
        hue = (hue / 6 + Double(grade - 1) * 43 / 360 + 2).truncatingRemainder(dividingBy: 1)
        let saturation = delta / maximum, sector = hue * 6, f = sector - floor(sector)
        let p = maximum * (1 - saturation), q = maximum * (1 - f * saturation), t = maximum * (1 - (1 - f) * saturation)
        switch Int(sector) % 6 {
        case 0: return (maximum, t, p)
        case 1: return (q, maximum, p)
        case 2: return (p, maximum, t)
        case 3: return (p, q, maximum)
        case 4: return (t, p, maximum)
        default: return (maximum, p, q)
        }
    }

    private static func image(_ pixels: [UInt8], width: Int, height: Int) -> CGImage {
        CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: CGDataProvider(data: Data(pixels) as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }
}
