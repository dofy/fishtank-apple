#if os(macOS)
import AppKit

/// Fixed 36 × 18 pt monochrome templates, rasterized at 2× for crisp menu-bar pixels.
enum MenuFishArt {
    private static var cache: [AgentMenuIndicator.State: NSImage] = [:]
    static func image(_ state: AgentMenuIndicator.State) -> NSImage {
        if let image = cache[state] { return image }
        let c = CGContext(data: nil, width: 72, height: 36, bitsPerComponent: 8, bytesPerRow: 72 * 4,
                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.scaleBy(x: 2, y: 2); c.setShouldAntialias(false); c.setFillColor(NSColor.black.cgColor)
        func block(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat = 1, _ h: CGFloat = 1) {
            c.fill(CGRect(x: x, y: 18 - y - h, width: w, height: h))
        }
        let filled = state == .working || state == .responded || state == .failed
        for (y, row) in PixelArt.fish.enumerated() { for (x, pixel) in row.enumerated() {
            let inside = filled || (state == .interrupted && y >= 5)
            if pixel == "o" || (inside && pixel != "." && pixel != "w") {
                block(CGFloat(x) * 1.5, 1.5 + CGFloat(y) * 1.5, 1.5, 1.5)
            }
        } }
        func badge(_ rows: [String], x: Int = 26, y: Int = 3) {
            for (dy,row) in rows.enumerated() { for (dx,pixel) in row.enumerated() where pixel == "#" {
                block(CGFloat(x + dx), CGFloat(y + dy))
            } }
        }
        func bubble(_ x: Int, _ y: Int) { badge([".#.","#.#",".#."], x: x, y: y) }
        switch state {
        case .idle: break
        case .ready: bubble(28, 5)
        case .working: bubble(25, 10); bubble(29, 5); bubble(33, 0)
        case .permission:
            badge([".#######.","#.......#","#...#...#","#...#...#","#...#...#","#.......#","#...#...#",".#######.","...#.....","..#......"], y: 1)
        case .input:
            badge([".#######.","#.......#","#.......#","#.#.#.#.#","#.......#",".#######.","...#.....","..#......"], y: 3)
        case .responded:
            badge([".......#.","......##.",".....##..","#...##...","##.##....",".###.....","..#......"], y: 5)
        case .failed:
            badge(["##....##",".##..##.","..####..","...##...","..####..",".##..##.","##....##"], y: 5)
        case .interrupted, .paused:
            badge(Array(repeating: "##..##", count: 8), x: 28, y: 5)
        case .ended:
            badge(["########","########"], y: 8)
        }
        let image = NSImage(cgImage: c.makeImage()!, size: NSSize(width: 36, height: 18))
        image.isTemplate = true; image.accessibilityDescription = L10n.text("Pixel Fish · ") + state.title
        cache[state] = image
        return image
    }
}
#endif
