import AppKit
import CoreText

@main
struct FishPreview {
    static func main() throws {
        let width = 1060, height = 1050
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let graphics = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = graphics
        let context = graphics.cgContext; context.interpolationQuality = .none
        context.setShouldAntialias(false)
        CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: "Sources/Resources/Fonts/FusionPixel.otf") as CFURL, .process, nil)
        func block(_ rect: CGRect, _ hex: Int) {
            context.setFillColor(NSColor(red: CGFloat((hex >> 16) & 255)/255, green: CGFloat((hex >> 8) & 255)/255, blue: CGFloat(hex & 255)/255, alpha: 1).cgColor)
            context.fill(rect)
        }
        func text(_ value: String, _ x: Int, _ y: Int, title: Bool = false) {
            (value as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [
                .font: NSFont(name: "Fusion-Pixel-12px-Mono-zh-Hans-Regular", size: title ? 24 : 12)!,
                .foregroundColor: NSColor(red: 0.94, green: 0.78, blue: 0.43, alpha: 1)])
        }
        block(CGRect(x: 0, y: 0, width: width, height: height), 0x102638)
        text("一缸彩色像素鱼 / 29 种", 24, 1004, title: true)
        text("原版鱼种与五品阶配色 · 原创像素轮廓与帧动画", 24, 980)
        for (index, species) in FishCatalog.all.enumerated() {
            let x = 24 + index % 5 * 204, y = 824 - index / 5 * 128
            block(CGRect(x: x, y: y, width: 196, height: 120), 0x214B65)
            context.draw(PixelArt.image(species: species, grade: 1), in: CGRect(x: x + 66, y: y + 61, width: 64, height: 48))
            text(species.name, x + 10, y + 42)
            text(species.tier == 0 ? "初始" : "\(species.tier)★", x + 9, y + 97)
            for grade in 1...(species.tier == 0 ? 1 : 5) {
                context.draw(PixelArt.image(species: species, grade: grade), in: CGRect(x: x + 9 + (grade - 1) * 36, y: y + 9, width: 32, height: 24))
            }
        }
        text("游动姿态", 24, 118)
        for frame in 0..<3 {
            context.draw(PixelArt.image(species: FishCatalog.byID["goldfin"]!, grade: 1, frame: frame),
                         in: CGRect(x: 24 + frame * 88, y: 48, width: 64, height: 48))
        }
        text("河豚轮廓四级", 384, 118)
        for puff in 0..<4 {
            context.draw(PixelArt.image(species: FishCatalog.byID["creampuff"]!, grade: 1, puffLevel: puff),
                         in: CGRect(x: 384 + puff * 100, y: 48, width: 64, height: 48))
        }
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "docs/previews/fish-catalog.png"))
        print("Rendered all 29 species, grade palettes and animation frames.")
    }
}
