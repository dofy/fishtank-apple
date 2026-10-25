import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct CuttleCanvas {
    let width: Int, height: Int
    let c: CGContext
    init(_ width: Int = 64, _ height: Int = 48) {
        self.width = width; self.height = height
        c = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.setShouldAntialias(false); c.setAllowsAntialiasing(false)
        c.translateBy(x: 0, y: CGFloat(height)); c.scaleBy(x: 1, y: -1)
    }
    func color(_ hex: Int) -> CGColor {
        CGColor(red: CGFloat(hex >> 16 & 255) / 255, green: CGFloat(hex >> 8 & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
    func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ hex: Int) {
        c.setFillColor(color(hex)); c.fill(CGRect(x: x, y: y, width: w, height: h))
    }
    func ellipse(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ hex: Int) {
        c.setFillColor(color(hex)); c.fillEllipse(in: CGRect(x: x, y: y, width: w, height: h))
    }
    func polygon(_ points: [(Int, Int)], _ hex: Int) {
        c.beginPath(); c.move(to: CGPoint(x: points[0].0, y: points[0].1))
        for p in points.dropFirst() { c.addLine(to: CGPoint(x: p.0, y: p.1)) }
        c.closePath(); c.setFillColor(color(hex)); c.fillPath()
    }
    func line(_ points: [(Int, Int)], _ hex: Int, _ width: Int = 1) {
        c.beginPath(); c.move(to: CGPoint(x: points[0].0, y: points[0].1))
        for p in points.dropFirst() { c.addLine(to: CGPoint(x: p.0, y: p.1)) }
        c.setStrokeColor(color(hex)); c.setLineWidth(CGFloat(width)); c.setLineJoin(.round); c.strokePath()
    }
    func star(_ x: Int, _ y: Int, _ hex: Int) {
        rect(x, y - 2, 1, 5, hex); rect(x - 2, y, 5, 1, hex)
    }
    func save(_ name: String, at root: URL) throws {
        let url = root.appendingPathComponent(name + ".png")
        let target = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(target, c.makeImage()!, nil)
        precondition(CGImageDestinationFinalize(target))
    }
}

// Code-authored on the same 64 x 48 grid as the existing PC FISH-inspired set.
let p = CuttleCanvas()
let outline=0x28374D, shadow=0x925E55, copper=0xC98265, warm=0xE6B38B
let pearl=0xFFF0C7, teal=0x55AFAD, pale=0xA9DFCB
// The broad, rounded mantle and a continuous frilled fin distinguish a cuttlefish.
p.polygon([(7,21),(9,15),(13,12),(19,11),(25,9),(30,12),(36,10),(41,15),(42,22),(41,31),(36,36),(30,35),(25,38),(19,35),(13,35),(9,30)],outline)
p.polygon([(9,21),(11,16),(16,14),(22,13),(25,12),(30,15),(35,13),(39,17),(39,29),(35,33),(30,32),(25,35),(19,32),(14,33),(11,29)],teal)
p.line([(11,18),(15,15),(20,15),(25,13),(30,16),(35,15),(38,18)],pale)
p.line([(11,28),(15,31),(20,30),(25,33),(30,30),(35,31),(38,28)],pale)
p.ellipse(11,15,31,19,outline)
p.ellipse(12,16,29,17,shadow)
p.polygon([(14,20),(19,17),(29,16),(36,19),(40,23),(37,28),(29,31),(20,30),(15,27)],copper)
p.polygon([(16,20),(21,18),(28,18),(35,20),(37,23),(32,26),(24,27),(18,25)],warm)
p.line([(17,20),(22,18),(28,18),(33,20)],pearl,2)
// Banded mantle planes, no smooth gradients or photographic texture.
for x in [21,27,33] {
 p.line([(x,20),(x+2,23),(x+1,27)],shadow,2)
 p.rect(x+1,21,2,2,warm)
}
p.line([(16,28),(21,30),(28,31),(34,29)],0xEAB58B)
// A short head with an obvious eye, plus separate curled arms at the front.
for (i,dy) in [-9,-5,-1,3,7,11].enumerated() {
 let end=56+(i%2)*4
 let path=[(43,24),(50,22+dy/2),(end,22+dy),(end+1,20+dy),(end-1,19+dy)]
 p.line(path,outline,4)
 p.line(path,i%2 == 0 ? warm : copper,2)
 p.rect(end-1,21+dy,1,1,pearl)
}
p.line([(45,23),(52,21),(60,22),(62,20)],outline,3)
p.line([(45,23),(52,21),(60,22),(62,20)],pale,1)
p.ellipse(36,18,14,14,outline)
p.ellipse(38,19,11,11,warm)
p.ellipse(40,19,8,8,pearl)
p.ellipse(42,20,5,5,outline)
p.rect(43,20,2,2,0xFFFFFF)
p.polygon([(37,29),(42,29),(46,33),(42,35),(37,32)],outline)
p.polygon([(38,29),(42,30),(44,33),(41,33)],pale)
let root=URL(fileURLWithPath:CommandLine.arguments.count>1 ? CommandLine.arguments[1] : "Sources/Resources/PixelSprites")
try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
try p.save("cuttlefish",at:root)
print("Generated original 64 x 48 cuttlefish specimen")
