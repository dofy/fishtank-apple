import AppKit

@main struct MenuIconPreview {
    static func main() throws {
        let c = CGContext(data: nil, width: 1280, height: 1000, bitsPerComponent: 8, bytesPerRow: 5120,
                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.scaleBy(x: 2, y: 2)
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: c, flipped: false)
        let fontURL = URL(fileURLWithPath: "Sources/Resources/Fonts/FusionPixel.otf")
        CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
        let font = NSFont(name: "FusionPixel-12px-monospaced-zh_hans", size: 12) ?? NSFont.systemFont(ofSize: 12)
        for (column, dark) in [false,true].enumerated() {
            let x = column * 320
            let background = dark ? NSColor(calibratedWhite: 0.12, alpha: 1) : NSColor(calibratedWhite: 0.94, alpha: 1)
            let foreground = dark ? NSColor(calibratedWhite: 0.94, alpha: 1) : NSColor.black
            c.setFillColor(background.cgColor); c.fill(CGRect(x: x, y: 0, width: 320, height: 500))
            (dark ? "深色菜单栏" : "浅色菜单栏" as NSString).draw(at: NSPoint(x: x + 24, y: 470), withAttributes: [.font: font, .foregroundColor: foreground])
            for (row, state) in AgentMenuIndicator.State.allCases.enumerated() {
                let y = 428 - row * 42
                let image = MenuFishArt.image(state)
                var bounds = NSRect(x: 0, y: 0, width: 36, height: 18)
                let cg = image.cgImage(forProposedRect: &bounds, context: nil, hints: nil)!
                c.saveGState(); c.clip(to: CGRect(x: x + 24, y: y, width: 36, height: 18), mask: cg)
                c.setFillColor(foreground.cgColor); c.fill(CGRect(x: x + 24, y: y, width: 36, height: 18)); c.restoreGState()
                (state.title as NSString).draw(at: NSPoint(x: x + 82, y: y + 3), withAttributes: [.font: font, .foregroundColor: foreground])
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        let output = URL(fileURLWithPath: "docs/design/menu-status-icons.png")
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try NSBitmapImageRep(cgImage: c.makeImage()!).representation(using: .png, properties: [:])!.write(to: output)
        print(output.path)
    }
}
