import SpriteKit
#if os(macOS)
import AppKit
#endif

/// Original hand-authored pixel art. No PC FISH artwork is bundled or copied.
enum PixelArt {
    private static var speciesImages: [String: CGImage] = [:]
    private static var speciesTextures: [String: SKTexture] = [:]

    static func lampGlowImage() -> CGImage {
        if let cached = speciesImages["lamp-glow"] { return cached }
        let width = 96, height = 144
        var pixels: [UInt8] = []
        for y in 0..<height { for x in 0..<width {
            // Two-point pixels, with a feathered cross-section and a fading depth ramp.
            let depth = Double(y / 2 * 2) / Double(height - 2)
            let halfWidth = 8 + depth * 39
            let radius = abs(Double(x / 2 * 2 + 1) - 48) / halfWidth
            let edge = radius < 1 ? (exp(-4 * radius * radius) - exp(-4)) / (1 - exp(-4)) : 0
            let alpha = UInt8((255 * 0.16 * edge * pow(1 - depth, 1.4)).rounded())
            pixels += [255, 255, 255, alpha]
        } }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        speciesImages["lamp-glow"] = image
        return image
    }

    static func lampGlowTexture() -> SKTexture {
        if let cached = speciesTextures["lamp-glow"] { return cached }
        let texture = SKTexture(cgImage: lampGlowImage()); texture.filteringMode = .nearest
        speciesTextures["lamp-glow"] = texture
        return texture
    }

    static func backgroundFish(round: Bool, frame: Int) -> SKTexture {
        let frame = max(0, frame) % 4
        let key = "backdrop:\(round):\(frame)"
        if let cached = speciesTextures[key] { return cached }
        let tail = [0, 1, 0, -1][frame]
        var pixels: [UInt8] = []
        for y in 0..<8 { for x in 0..<12 {
            let body = pow(Double(x - 8) / (round ? 3 : 3.5), 2) + pow(Double(y - 4) / (round ? 2.4 : 1.4), 2) <= 1
            let fin = x >= 1 && x <= 5 && abs(y - 4 - tail) <= (5 - x) / 2
            pixels += body || fin ? (y < 4 ? [203,232,227,255] : [118,175,183,255]) : [0,0,0,0]
        } }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let image = CGImage(width: 12, height: 8, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 48,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let texture = SKTexture(cgImage: image); texture.filteringMode = .nearest
        speciesTextures[key] = texture
        return texture
    }

    static func animationFrameCount(for species: FishSpecies) -> Int {
        species.form == "eel" || species.form == "seasnake" ? 16 : 3
    }

    static func animationFrame(for species: FishSpecies, time: Double) -> Int {
        guard time.isFinite, time > 0 else { return 0 }
        let count = animationFrameCount(for: species)
        let fps = count == 3 ? 4.0 : 12.0
        return Int((time.truncatingRemainder(dividingBy: Double(count) / fps) * fps).rounded(.down)) % count
    }

    /// Draw on a fixed pixel grid. Each species keeps its original body family and colors.
    static func image(species: FishSpecies, grade: Int, frame: Int = 0, puffLevel: Int = 0) -> CGImage {
        let frameCount = animationFrameCount(for: species)
        let frame = max(0, frame) % frameCount, puffLevel = max(0, min(3, puffLevel))
        let key = "\(species.id):\(grade):\(frame):\(puffLevel)"
        if let cached = speciesImages[key] { return cached }
        let width = 64, height = 48
        let variant = species.id.utf8.reduce(0) { $0 + Int($1) }
        let hue = (species.hue + Double(grade - 1) * 43).truncatingRemainder(dividingBy: 360)
        let main = hsl(hue, species.saturation, species.lightness)
        let shade = hsl(hue, species.saturation, max(0.2, species.lightness - 0.18))
        let light = hsl(hue, species.saturation * 0.7, min(0.9, species.lightness + 0.2))
        let accent = hsl((hue + 155).truncatingRemainder(dividingBy: 360), species.saturation, 0.72)
        let outline = hsl(hue, 0.45, 0.2)
        let fin = hsl((hue + 12).truncatingRemainder(dividingBy: 360), species.saturation * 0.8, species.lightness + 0.08)
        let belly = hsl(hue, species.saturation * 0.65, min(0.82, species.lightness + 0.12))
        let scale = hsl(hue, species.saturation * 0.85, min(0.86, species.lightness + 0.07))
        let undulating = frameCount == 16
        let phase = Double(frame) * 2 * .pi / Double(frameCount)
        func spine(_ x: Double) -> Double { 11 + sin((x + Double(variant % 5)) * 0.23 + phase) * 4 }

        func inside(_ xi: Int, _ yi: Int) -> Bool {
            let x = Double(xi) / 2
            let finOffset = undulating ? 0 : Double([0, 1, -1][frame])
            let y = Double(yi) / 2 + (x < 10 ? finOffset * (10 - x) / 8 : 0)
            func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> Bool {
                pow((x - cx) / rx, 2) + pow((y - cy) / ry, 2) <= 1
            }
            switch species.form {
            case "jellyfish":
                return (y <= 12 && ellipse(16, 12, 10, 9))
                    || (y >= 12 && y < 22 && (Int(x) + (Int(y) / 3 + frame) % 2) % 4 == 0 && abs(x - 16) < 8)
                    || (species.tier == 5 && y < 7 && y > 1 && Int(x) % 5 == 1 && abs(x - 16) < 8)
            case "seahorse":
                return ellipse(18, 6, 5, 4) || (x >= 20 && x <= 27 && y >= 5 && y <= 8)
                    || ellipse(15, 13, 4, 6) || (y >= 17 && y <= 22 && abs(x - (12 + sin(y) * 3)) < 1.6)
                    || (x >= 8 && x <= 12 && y >= 9 && y <= 15 && (Int(x) + Int(y)) % 2 == 0)
            case "eel", "seasnake":
                return x >= 2 && x <= 29 && abs(y - spine(x)) < (x > 22 ? 2.4 : 1.8)
                    || (species.tier >= 4 && x > 8 && x < 22 && abs(y - (spine(x) - 2.2)) < 1.3 && Int(x) % 3 == 0)
            case "ray":
                return abs(x - 16) / 13 + abs(y - 10) / 8 < 1
                    || (y >= 13 && y <= 23 && abs(x - (16 + (y - 13) * 0.28)) < 1)
            case "turtle":
                return ellipse(15, 11, 8, 6) || ellipse(25, 10, 4, 3)
                    || ellipse(10, 5, 4, 2) || ellipse(10, 17, 4, 2)
                    || ellipse(21, 5, 3, 2) || ellipse(21, 17, 3, 2)
            default:
                let depth = max(3.0, species.depth * 8) * (species.silhouette == "spiky-puffer" ? 1 + Double(puffLevel) / 3 * 0.28 : 1)
                let tailWidth = 4 + species.tail * 11
                let body: Bool
                switch species.silhouette {
                case "rhomboid-barb", "diamond-tetra": body = abs(x - 18) / 9 + abs(y - 11) / (depth + 1) < 1
                case "beak-butterfly", "moorish-idol", "unicorn-tang": body = ellipse(17, 11, 6.5, depth + 0.8)
                case "wrasse", "minnow": body = ellipse(18, 11, 10, depth * 0.85)
                default: body = ellipse(18, 11, 8, depth)
                }
                let veil = ["goldfish", "veil-koi", "lyretail"].contains(species.silhouette)
                let tail = x >= 2 && x <= 2 + tailWidth && abs(y - 11) <= (2 + tailWidth - x) * (veil ? 1.1 : 0.72)
                    && (!veil || x > 4 || abs(y - 11) > 1.2)
                let dorsal = x > 12 && x < 22 && y >= 11 - depth - species.dorsal * (1 + (22 - x) * 0.45) && y < 11 - depth + 2
                let ventral = x > 14 && x < 19 && y > 11 + depth - 1 && y < 11 + depth + (19 - x) * 0.65
                let beak = ["beak-butterfly", "unicorn-tang", "moorish-idol"].contains(species.silhouette)
                    && x >= 24 && x <= 29 && y >= 9 && y <= 11
                let puffer = species.silhouette == "spiky-puffer" && (Int(x) % 3 == 0 || Int(y) % 3 == 0) && ellipse(18, 11, 9, depth + 1)
                let wings = species.silhouette == "glider-fish" && abs(x - 15) < 6 && abs(y - 12) < 9 && Int(x) % 2 == 0
                return body || tail || dorsal || ventral || beak || puffer || wings
            }
        }

        var bytes: [UInt8] = []
        for y in 0..<height {
            for x in 0..<width {
                guard inside(x, y) else { bytes += [0, 0, 0, 0]; continue }
                let px = Double(x) / 2, py = Double(y) / 2
                let edge = !inside(x - 1, y) || !inside(x + 1, y) || !inside(x, y - 1) || !inside(x, y + 1)
                var color = edge ? outline : (py < 9 ? light : py > 13 ? shade : main)
                if !edge {
                    if species.pattern == "bands" && (Int(px) + variant) % 7 < 2 { color = accent }
                    if species.pattern == "stripes" && (Int(py) + variant) % 5 == 0 { color = accent }
                    if species.pattern == "spots" && (Int(px) * 13 + Int(py) * 7 + variant) % 17 < 2 { color = light }
                    if species.form == "fish" {
                        // Fin rays follow the tail fan; the belly and gill describe volume.
                        if px < 10 || py < 7 || py > 16 {
                            let ray = [-0.65, 0, 0.65].contains { abs(py - 11 - (10 - px) * $0) < 0.3 }
                            color = ray ? shade : fin
                        }
                        if px > 11 && px < 23 && py > 13 && py < 15 { color = belly }
                        if px > 13 && px < 22 && py > 8 && py < 12 && (x + (y / 3) % 2 * 2) % 7 == 0 && y % 3 == 0 { color = scale }
                        if px > 21 && px < 22 && py > 9 && py < 13 { color = shade }
                        if px > 18 && px < 21 && abs(py - (12 + (21 - px) * 0.45)) < 0.6 { color = fin }
                        if px > 25 && py > 11 && py < 11.6 { color = shade }
                    } else if species.form == "turtle" {
                        if px < 22 && ((x + y / 2) % 10 == 0 || y % 9 == 0) { color = shade }
                        if px < 20 && py < 10 && x % 6 < 2 { color = light }
                    } else if species.form == "jellyfish" {
                        if py < 11 && abs(px - 16) < 6 && (x % 8 < 2) { color = belly }
                        if abs(py - 12) < 0.6 { color = accent }
                    } else if species.form == "eel" || species.form == "seasnake" {
                        if inside(x, y - 2) && !inside(x, y + 3) { color = belly }
                    }
                }
                let eyeX = species.form == "seahorse" ? 20 : species.form == "ray" ? 18 : species.form == "jellyfish" ? 18 : 24
                let eyeY = undulating ? Int((spine(Double(eyeX)) - 0.5).rounded()) : species.form == "seahorse" ? 5 : species.form == "jellyfish" ? 10 : 9
                if abs(x - eyeX * 2) <= 2 && abs(y - eyeY * 2) <= 2 { color = [255, 244, 211, 255] }
                if abs(x - (eyeX * 2 + 1)) <= 1 && abs(y - eyeY * 2) <= 1 { color = [15, 25, 39, 255] }
                if x == eyeX * 2 && y == eyeY * 2 - 1 { color = [255, 255, 240, 255] }
                bytes += color
            }
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        speciesImages[key] = image
        return image
    }

    static func texture(fish: AquariumFish, frame: Int = 0, puffLevel: Int = 0) -> SKTexture {
        let frame = max(0, frame) % animationFrameCount(for: fish.species)
        let puffLevel = max(0, min(3, puffLevel))
        let key = "\(fish.speciesID):\(fish.grade):\(frame):\(puffLevel)"
        if let texture = speciesTextures[key] { return texture }
        let texture = SKTexture(cgImage: image(species: fish.species, grade: fish.grade, frame: frame, puffLevel: puffLevel))
        texture.filteringMode = .nearest; speciesTextures[key] = texture
        return texture
    }

    static func hsl(_ hue: Double, _ saturation: Double, _ lightness: Double) -> [UInt8] {
        let c = (1 - abs(2 * lightness - 1)) * saturation
        let h = hue / 60, x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let rgb: [Double]
        switch Int(h) {
        case 0: rgb = [c, x, 0]
        case 1: rgb = [x, c, 0]
        case 2: rgb = [0, c, x]
        case 3: rgb = [0, x, c]
        case 4: rgb = [x, 0, c]
        default: rgb = [c, 0, x]
        }
        let m = lightness - c / 2
        return rgb.map { UInt8(max(0, min(255, (($0 + m) * 255).rounded()))) } + [255]
    }

    static let fish = [
        "................",
        ".......oo.......",
        "......ohho......",
        ".oo..ohhhhoo....",
        ".ohooohhhhhho...",
        "..ohhhhhhhwkho..",
        ".ohooohhhhhho...",
        ".oo..ohsssoo....",
        "......osso......",
        ".......oo......."
    ]

    static func image(palette: Int = 0, monochrome: Bool = false) -> CGImage {
        let palettes: [[Character: [UInt8]]] = [
            ["o": [91, 47, 46, 255], "h": [255, 162, 74, 255], "s": [214, 84, 55, 255]],
            ["o": [25, 75, 82, 255], "h": [109, 220, 165, 255], "s": [47, 151, 139, 255]],
            ["o": [53, 44, 100, 255], "h": [154, 174, 255, 255], "s": [99, 99, 202, 255]]
        ]
        var colors = palettes[max(0, min(2, palette))]
        colors["w"] = [255, 245, 213, 255]
        colors["k"] = [25, 34, 49, 255]
        var bytes: [UInt8] = []
        for row in fish {
            for pixel in row {
                if monochrome {
                    bytes += pixel == "." ? [0, 0, 0, 0] : [0, 0, 0, 255]
                } else {
                    bytes += colors[pixel] ?? [0, 0, 0, 0]
                }
            }
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(width: 16, height: 10, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: 64, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }

    static func texture(palette: Int) -> SKTexture {
        let texture = SKTexture(cgImage: image(palette: palette))
        texture.filteringMode = .nearest
        return texture
    }

    #if os(macOS)
    static var menuIcon: NSImage {
        let icon = NSImage(cgImage: image(monochrome: true), size: NSSize(width: 24, height: 15))
        icon.isTemplate = true
        icon.accessibilityDescription = "像素鱼缸"
        return icon
    }
    #endif
}
