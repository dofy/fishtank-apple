import SpriteKit
import ImageIO
#if os(macOS)
import AppKit
#endif

/// Original pixel artwork. No PC FISH artwork is bundled or copied.
enum PixelArt {
    private static var speciesImages: [String: CGImage] = [:]
    private static var speciesTextures: [String: SKTexture] = [:]

    static func inkCloudTexture() -> SKTexture {
        if let cached = speciesTextures["ink-cloud"] { return cached }
        let w = 32, h = 24
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        for y in 0..<h { for x in 0..<w {
            let lobes = [(10.0, 12.0, 8.5, 7.0), (18, 10, 10, 8), (24, 14, 6, 6)]
            let distance = lobes.map { pow((Double(x) - $0.0) / $0.2, 2) + pow((Double(y) - $0.1) / $0.3, 2) }.min()!
            guard distance < 1, distance < 0.78 || (x + y * 3) % 4 != 0 else { continue }
            let i = (y * w + x) * 4, rim = distance > 0.64
            pixels[i] = rim ? 43 : 19; pixels[i + 1] = rim ? 40 : 20; pixels[i + 2] = rim ? 66 : 36
            pixels[i + 3] = rim ? 155 : 230
        } }
        let image = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                            provider: CGDataProvider(data: Data(pixels) as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let texture = SKTexture(cgImage: image); texture.filteringMode = .nearest
        speciesTextures["ink-cloud"] = texture
        return texture
    }

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
        32
    }

    static func animationCycleDuration(for species: FishSpecies) -> Double {
        switch species.form {
        case "eel", "seasnake": return 1.6
        case "seahorse": return 2.4
        case "turtle", "ray", "nautilus": return 2.8
        case "seaangel": return 1.8
        case "cuttlefish": return 2.6
        default: return 2
        }
    }

    static func animationFrame(for species: FishSpecies, time: Double) -> Int {
        guard time.isFinite, time > 0 else { return 0 }
        let count = animationFrameCount(for: species)
        let fps = Double(count) / animationCycleDuration(for: species)
        return Int((time.truncatingRemainder(dividingBy: Double(count) / fps) * fps).rounded(.down)) % count
    }

    /// Draw on a fixed pixel grid. Each species keeps its original body family and colors.
    static func image(species: FishSpecies, grade: Int, frame: Int = 0, puffLevel: Int = 0, jetLevel: Int = 0) -> CGImage {
        let frameCount = animationFrameCount(for: species)
        let frame = max(0, frame) % frameCount, puffLevel = max(0, min(3, puffLevel))
        let jetLevel = species.spraysInk ? max(0, min(3, jetLevel)) : 0
        let key = "\(species.id):\(grade):\(frame):\(puffLevel):\(jetLevel)"
        if let cached = speciesImages[key] { return cached }
        if let image = PaintedSprites.fish(species, grade: grade, frame: frame, puffLevel: puffLevel, jetLevel: jetLevel) {
            speciesImages[key] = image
            return image
        }
        let width = 64, height = 48
        let hue = (species.hue + Double(grade - 1) * 43).truncatingRemainder(dividingBy: 360)
        let main = hsl(hue, species.saturation, species.lightness)
        let shade = hsl(hue, species.saturation, max(0.2, species.lightness - 0.18))
        let light = hsl(hue, species.saturation * 0.7, min(0.9, species.lightness + 0.2))
        let accent = hsl((hue + 155).truncatingRemainder(dividingBy: 360), species.saturation, 0.72)
        let outline = hsl(hue, 0.45, 0.2)
        let fin = hsl((hue + 12).truncatingRemainder(dividingBy: 360), species.saturation * 0.8, species.lightness + 0.08)
        let belly = hsl(hue, species.saturation * 0.65, min(0.82, species.lightness + 0.12))
        let scale = hsl(hue, species.saturation * 0.85, min(0.86, species.lightness + 0.07))
        let undulating = species.form == "eel" || species.form == "seasnake"
        let phase = Double(frame) * 2 * .pi / Double(frameCount)
        func spine(_ x: Double) -> Double {
            let amplitude: Double, frequency: Double
            switch species.silhouette {
            case "krait": amplitude = 5; frequency = 0.36
            case "amber-eel": amplitude = 2.4; frequency = 0.22
            case "electric-eel": amplitude = 3.2; frequency = 0.29
            case "ribbon-eel": amplitude = 4.8; frequency = 0.19
            default: amplitude = 4.5; frequency = 0.27
            }
            return 11 + sin(x * frequency + phase) * amplitude * (0.3 + (29 - x) / 29 * 0.7)
        }

        // Anatomy is a continuous contour; the pixel grid is the rendering style,
        // not a substitute for a recognizable head, neck, belly and curled tail.
        let horse = CGMutablePath()
        horse.move(to: CGPoint(x: 15, y: 3))
        horse.addCurve(to: CGPoint(x: 21, y: 5), control1: CGPoint(x: 18, y: 1.5), control2: CGPoint(x: 21, y: 2.5))
        horse.addLine(to: CGPoint(x: 26, y: 6.5))
        horse.addLine(to: CGPoint(x: 25.5, y: 8))
        horse.addLine(to: CGPoint(x: 20.5, y: 7.5))
        horse.addCurve(to: CGPoint(x: 16.5, y: 9), control1: CGPoint(x: 19.5, y: 9), control2: CGPoint(x: 17.5, y: 7.5))
        horse.addCurve(to: CGPoint(x: 20, y: 14), control1: CGPoint(x: 16, y: 10.5), control2: CGPoint(x: 20, y: 10.5))
        horse.addCurve(to: CGPoint(x: 17, y: 18), control1: CGPoint(x: 20.5, y: 16), control2: CGPoint(x: 18, y: 17.5))
        horse.addCurve(to: CGPoint(x: 13, y: 22), control1: CGPoint(x: 17, y: 21), control2: CGPoint(x: 15, y: 23))
        horse.addCurve(to: CGPoint(x: 11, y: 18.5), control1: CGPoint(x: 10, y: 22), control2: CGPoint(x: 9.5, y: 20))
        horse.addCurve(to: CGPoint(x: 14.5, y: 18.5), control1: CGPoint(x: 12, y: 17), control2: CGPoint(x: 14, y: 17))
        horse.addLine(to: CGPoint(x: 14, y: 19.5))
        horse.addCurve(to: CGPoint(x: 12, y: 19.5), control1: CGPoint(x: 13, y: 18.5), control2: CGPoint(x: 12, y: 18.5))
        horse.addCurve(to: CGPoint(x: 14.5, y: 20), control1: CGPoint(x: 11, y: 21), control2: CGPoint(x: 14, y: 21.5))
        horse.addCurve(to: CGPoint(x: 14.5, y: 16), control1: CGPoint(x: 16, y: 19), control2: CGPoint(x: 15, y: 17))
        horse.addCurve(to: CGPoint(x: 12.5, y: 12), control1: CGPoint(x: 13, y: 15), control2: CGPoint(x: 12, y: 14))
        horse.addCurve(to: CGPoint(x: 14, y: 7), control1: CGPoint(x: 12.5, y: 10), control2: CGPoint(x: 15, y: 8))
        horse.addCurve(to: CGPoint(x: 15, y: 3), control1: CGPoint(x: 12.5, y: 6), control2: CGPoint(x: 13.5, y: 4))
        horse.closeSubpath()

        func inside(_ xi: Int, _ yi: Int) -> Bool {
            let x = Double(xi) / 2
            let finOffset = undulating ? 0 : sin(phase) * 1.5
            let y = Double(yi) / 2 + (x < 10 ? finOffset * (10 - x) / 8 : 0)
            func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> Bool {
                pow((x - cx) / rx, 2) + pow((y - cy) / ry, 2) <= 1
            }
            switch species.form {
            case "jellyfish":
                let squeeze = max(0, sin(phase))
                let radius = species.silhouette == "saucer-jelly" ? 10.5 : species.silhouette == "crown-jelly" ? 11 : 9
                let bell = y <= 12 && ellipse(16, 12, radius - squeeze * 2, (species.silhouette == "saucer-jelly" ? 6 : 8.5) - squeeze * 1.8)
                let tentacleLength = species.silhouette == "saucer-jelly" ? 19.0 : 23.0
                let stems: [Double] = [10, 14, 18, 22]
                let tentacleWidth = species.silhouette == "ribbon-jelly" ? 0.9 : 0.55
                let tentacleWave = sin((y - 12) * 0.5 - phase) * (y - 12) / 9
                let onStem = stems.contains { abs(x - $0 - tentacleWave) < tentacleWidth }
                let tentacles = y >= 11.5 && y < tentacleLength && onStem
                let crown = species.silhouette == "crown-jelly" && x > 10 && x < 23 && y > 1 && y < 7
                    && abs(x - 16) < 7 - y && (Int(x) % 4 < 2 || y > 5)
                return bell || tentacles || crown
            case "seahorse":
                let leafy = species.silhouette == "leafy-seahorse"
                let finReach = 1.4 + (sin(phase) + 1) * 0.65
                let dorsal = x >= 12 - finReach && x <= 13.5 && y >= 10 && y <= 14
                    && abs(y - 12) < (x - 12 + finReach) * 1.2
                let crown = x > 14 && x < 17.5 && y > 1 && y < 4 && x + y > 17
                let spines = !leafy && y >= 8 && y <= 15 && Int(y * 2) % 5 < 2
                    && x > 11.5 && x < 13.5
                let leaf = leafy && (ellipse(11.5, 9, 1.5, 0.65) || ellipse(12, 15, 1.5, 0.65))
                return horse.contains(CGPoint(x: x, y: y)) || dorsal || crown || spines || leaf
            case "eel", "seasnake":
                let dy = y - spine(x)
                switch species.silhouette {
                case "krait":
                    return (x >= 3 && x <= 27 && abs(dy) < 1.15)
                        || ellipse(27, spine(27), 2.4, 1.7) || ellipse(3.5, spine(3.5), 2, 1.6)
                case "amber-eel":
                    let radius = 0.6 + x / 29 * 2.2
                    return (x >= 2 && x <= 28 && abs(dy) < radius)
                        || ellipse(27, spine(27), 2.7, 2.5)
                        || (x >= 5 && x <= 23 && dy > radius - 0.3 && dy < radius + 0.9)
                case "electric-eel":
                    let radius = 0.65 + x / 29 * 1.5
                    let ridge = 1.8 + (Int(x) % 4 < 2 ? 1.8 : 0.4)
                    return (x >= 2 && x <= 28 && abs(dy) < radius)
                        || ellipse(27, spine(27), 2.8, 1.9)
                        || (x >= 7 && x <= 24 && dy < 0 && dy > -ridge)
                case "ribbon-eel":
                    let ribbon = 2.8 + sin(x * 0.42 + phase) * 1.2
                    return (x >= 2 && x <= 28 && abs(dy) < 0.95)
                        || ellipse(27.5, spine(27.5), 2.1, 1.5)
                        || (x >= 4 && x <= 25 && dy < 0 && dy > -ribbon)
                default:
                    let radius = 0.8 + x / 29 * 1.6
                    let crest = 2.3 + (Int(x) % 4 < 2 ? 2.5 : 0.5)
                    let horn = x >= 24 && x <= 27 && y > spine(26) - 6 && y < spine(26) - 1
                        && abs(x - 25.5) < (y - spine(26) + 6) * 0.35
                    return (x >= 2 && x <= 28 && abs(dy) < radius)
                        || ellipse(27, spine(27), 3.2, 2.1) || horn
                        || (x >= 8 && x <= 23 && dy < 0 && dy > -crest)
                }
            case "ray":
                let span = abs(x - 16) / 13
                let lift = sin(phase) * 1.5
                let wings = span <= 1 && y >= 5 + span * 3 + span * lift
                    && y <= 16 - pow(span, 0.55) * 7 + span * lift
                let lobes = (ellipse(13.5, 5.5, 1.2, 3) || ellipse(18.5, 5.5, 1.2, 3))
                return wings || ellipse(16, 10, 3.8, 6) || lobes
                    || (y >= 14 && y <= 23 && abs(x - (16 + sin((y - 14) * 0.2 + phase) * 1.5)) < 0.55)
            case "turtle":
                let stroke = sin(phase), reach = cos(phase)
                return ellipse(15, 11, 8, 6) || ellipse(25, 10, 4, 2.6)
                    || ellipse(10 + reach, 5 + stroke * 1.4, 4, 1.8)
                    || ellipse(10 - reach, 17 - stroke * 1.4, 4, 1.8)
                    || ellipse(21 - reach, 5 - stroke, 3.5, 1.8)
                    || ellipse(21 + reach, 17 + stroke, 3.5, 1.8)
                    || (x >= 4 && x <= 9 && abs(y - 11) < (x - 3) * 0.35)
            default:
                let depth = max(3.0, species.depth * 8) * (species.silhouette == "spiky-puffer" ? 1 + Double(puffLevel) / 3 * 0.28 : 1)
                let tailWidth = 4 + species.tail * 11
                let body: Bool
                switch species.silhouette {
                case "rhomboid-barb", "diamond-tetra": body = abs(x - 18) / 9 + abs(y - 11) / (depth + 1) < 1
                case "beak-butterfly", "moorish-idol", "unicorn-tang": body = ellipse(17, 11, 6.5, depth + 0.8)
                case "wrasse", "minnow", "tetra", "fire-goby": body = ellipse(18, 11, 10, depth * 0.72)
                case "catfish": body = ellipse(17, 12, 10, depth * 0.75)
                case "banner-cardinal": body = abs(x - 18) / 7 + abs(y - 11) / (depth + 2) < 1
                case "damsel": body = ellipse(18, 11, 7, depth + 0.5)
                case "crown-butterfly": body = ellipse(17, 11, 6.5, depth + 1.3)
                default: body = ellipse(18, 11, 8, depth)
                }
                let veil = ["goldfish", "veil-koi", "lyretail"].contains(species.silhouette)
                let tail = x >= 2 && x <= 11.5 && abs(y - 11) <= max(0.9, (11.5 - x) * (veil ? 0.8 : 0.5))
                    && (x > 4 || abs(y - 11) > (veil ? 1.5 : 0.7))
                    && abs(y - 11) < tailWidth * 0.75
                let dorsal = x > 12 && x < 22 && y >= 11 - depth - species.dorsal * (1 + (22 - x) * 0.45) && y < 11 - depth + 2
                let streamer = species.silhouette == "moorish-idol" && x > 12 && x < 18 && y > 1 && y < 11 - depth + 2
                    && abs(x - (18 - y * 0.65)) < 0.8
                let sail = species.silhouette == "fire-goby" && x > 14 && x < 18 && y > 2 && y < 10
                let whiskers = species.silhouette == "catfish" && x > 24 && x < 30 && abs(y - (11 + (x - 24) * 0.6)) < 0.5
                let ventral = x > 14 && x < 19 && y > 11 + depth - 1 && y < 11 + depth + (19 - x) * 0.65
                let beak = ["beak-butterfly", "unicorn-tang", "moorish-idol"].contains(species.silhouette)
                    && x >= 24 && x <= 29 && y >= 9 && y <= 11
                let puffer = species.silhouette == "spiky-puffer" && (Int(x) % 3 == 0 || Int(y) % 3 == 0) && ellipse(18, 11, 9, depth + 1)
                let wings = species.silhouette == "glider-fish" && x > 6 && x < 21
                    && abs(y - 11) < (21 - x) * 0.65 && abs(y - 11) > (21 - x) * 0.22
                return body || tail || dorsal || ventral || beak || puffer || wings || streamer || sail || whiskers
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
                        // Markings follow the anatomy: vertical bars, lateral stripes,
                        // koi patches and puffer spots, never random confetti.
                        switch species.silhouette {
                        case "beak-butterfly", "crown-butterfly", "moorish-idol", "banner-cardinal", "rhomboid-barb":
                            if px > 11 && px < 25 && Int((px + py * 0.18) / 3.2) % 2 == 0 { color = shade }
                            if species.silhouette == "banner-cardinal" && px < 22 && x % 7 == 0 && y % 6 == 0 { color = light }
                        case "wrasse", "tetra", "minnow":
                            if px > 8 && px < 25 && abs(py - (10.5 + (px - 16) * 0.04)) < 0.65 { color = light }
                            if px > 10 && px < 24 && py > 11.5 && py < 12.2 { color = shade }
                        case "veil-koi":
                            if pow((px - 15) / 3, 2) + pow((py - 9) / 2.5, 2) < 1
                                || pow((px - 21) / 2.4, 2) + pow((py - 13) / 3, 2) < 1 { color = accent }
                        case "spiky-puffer", "catfish":
                            if py < 12.5 && px > 12 && px < 24 && x % 8 < 2 && y % 7 < 2 { color = shade }
                            if py > 12 { color = belly }
                        case "lyretail": if px < 11 { color = accent }
                        case "fire-goby": if px > 19 { color = belly }
                        case "glider-fish":
                            if abs(py - 11) > 3 { color = x % 5 < 1 ? shade : fin }
                        default: break
                        }
                    } else if species.form == "seahorse" {
                        color = px > 16 ? belly : main
                        if px < 13.5 && py > 9 { color = fin }
                        if py > 9 && py < 17 && px > 13 && px < 19 && y % 5 == 0 { color = shade }
                        if px > 15.5 && px < 16.5 && py > 9 && py < 16 { color = light }
                        if px > 21 && py > 7 { color = shade }
                    } else if species.form == "turtle" {
                        let shell = pow((px - 15) / 7.3, 2) + pow((py - 11) / 5.3, 2)
                        color = shell < 1 ? main : fin
                        if shell > 0.77 && shell < 1 { color = belly }
                        if shell < 0.77 && (abs(px - 15) < 0.4 || abs(py - 8.5) < 0.35 || abs(py - 12.5) < 0.35
                            || abs(abs(px - 15) - 3.5) < 0.35) { color = shade }
                        if px > 23 && py > 10.5 { color = belly }
                    } else if species.form == "jellyfish" {
                        color = py < 8 ? light : py < 11 ? main : fin
                        if py > 7 && py < 11 {
                            let ring = hypot((px - 16) / 1.5, py - 9)
                            if ring > 1.2 && ring < 1.8 { color = belly }
                        }
                        if abs(py - 12) < 0.6 { color = shade }
                        if py > 13 && abs(px - 16) < 3 { color = belly }
                    } else if species.form == "ray" {
                        color = abs(px - 16) < 3 ? light : main
                        if py > 10 && abs(px - 16) > 4 { color = shade }
                        if abs(px - 16) > 3 && abs(px - 16) < 9 && x % 7 == 0 && y % 6 == 0 { color = belly }
                    } else if species.form == "eel" || species.form == "seasnake" {
                        let dy = py - spine(px)
                        if dy > 0.4 { color = belly }
                        if species.silhouette == "krait" {
                            let pale = grade == 1 ? [UInt8(225), 230, 210, 255] : light
                            let dark = grade == 1 ? [UInt8(32), 52, 67, 255] : shade
                            color = Int(px / 2.5) % 2 == 0 ? pale : dark
                        }
                        if species.silhouette == "amber-eel" && abs(dy) < 0.45 { color = shade }
                        if species.silhouette == "electric-eel" && dy < -1.5 { color = accent }
                        if species.silhouette == "ribbon-eel" && dy < -0.9 { color = fin }
                        if species.silhouette == "sea-dragon" && Int(px) % 4 < 1 { color = light }
                        if px > 26 && dy > 0.5 && dy < 1 { color = shade }
                        if px > 23.5 && px < 24.2 && abs(dy) < 1.2 { color = shade }
                    }
                }
                let eyeX = species.form == "seahorse" ? 19 : species.form == "ray" ? (px < 16 ? 13 : 19) : undulating ? 27 : 24
                let eyeY = undulating ? Int((spine(Double(eyeX)) - 0.5).rounded()) : species.form == "seahorse" ? 5 : species.form == "ray" ? 7 : 9
                if species.form != "jellyfish" && abs(x - eyeX * 2) <= 1 && abs(y - eyeY * 2) <= 1 { color = [255, 244, 211, 255] }
                if species.form != "jellyfish" && x == eyeX * 2 + 1 && abs(y - eyeY * 2) <= 1 { color = [15, 25, 39, 255] }
                if species.form != "jellyfish" && x == eyeX * 2 && y == eyeY * 2 - 1 { color = [255, 255, 240, 255] }
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

    static func texture(fish: AquariumFish, frame: Int = 0, puffLevel: Int = 0, jetLevel: Int = 0) -> SKTexture {
        let frame = max(0, frame) % animationFrameCount(for: fish.species)
        let puffLevel = max(0, min(3, puffLevel))
        let jetLevel = fish.species.spraysInk ? max(0, min(3, jetLevel)) : 0
        let key = "\(fish.speciesID):\(fish.grade):\(frame):\(puffLevel):\(jetLevel)"
        if let texture = speciesTextures[key] { return texture }
        let texture = SKTexture(cgImage: image(species: fish.species, grade: fish.grade, frame: frame, puffLevel: puffLevel, jetLevel: jetLevel))
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
        icon.accessibilityDescription = L10n.text("Pixel Aquarium")
        return icon
    }
    #endif
}
