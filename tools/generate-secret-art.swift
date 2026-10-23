// Original chunky pixel artwork, authored on the same 64 × 48 specimen grid.
// swift tools/generate-secret-art.swift [output-directory]
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct SecretCanvas {
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

func angler() -> SecretCanvas {
    let p = SecretCanvas(), ink = 0x172143, dark = 0x293968, blue = 0x4260A0, teal = 0x5EBBC2, light = 0xA2E9D7
    // An unmistakable round head, cavernous jaw and arched luminous fishing lure.
    p.polygon([(20,25),(7,18),(5,21),(7,27),(5,34),(8,35),(21,31)], ink)
    p.polygon([(19,27),(8,22),(10,27),(8,32),(19,30)], blue)
    p.polygon([(23,19),(24,12),(29,15),(32,9),(37,14),(42,12),(44,21)], ink)
    p.polygon([(26,19),(27,15),(31,18),(34,13),(38,18),(42,16),(42,22)], blue)
    p.ellipse(16,17,40,25,ink); p.ellipse(18,18,36,21,dark)
    p.polygon([(20,24),(25,20),(35,18),(45,21),(48,25),(38,24),(31,27),(21,28)], blue)
    p.polygon([(24,33),(32,35),(48,32),(51,36),(44,39),(30,39)], teal)
    p.polygon([(36,28),(47,25),(55,25),(53,31),(50,35),(38,36),(35,33)], ink)
    p.polygon([(38,28),(42,27),(43,31)], 0xF5EAC5)
    p.polygon([(47,26),(51,26),(49,31)], 0xF5EAC5)
    p.polygon([(40,35),(43,31),(45,35)], 0xF5EAC5)
    p.polygon([(47,34),(50,30),(51,33)], 0xF5EAC5)
    p.ellipse(39,20,8,7,ink); p.ellipse(41,21,5,4,light); p.rect(44,22,2,3,ink); p.rect(41,21,1,1,0xFFF9DC)
    p.polygon([(28,35),(21,42),(26,44),(34,38)], ink); p.polygon([(29,36),(24,41),(27,42),(32,38)], blue)
    p.line([(33,18),(32,12),(35,6),(40,4),(46,5),(49,10)], ink, 3)
    p.line([(33,16),(34,11),(37,7),(42,6),(46,7),(48,10)], teal, 1)
    p.ellipse(44,8,11,9,ink); p.ellipse(46,9,7,6,teal); p.ellipse(47,9,4,4,0xF7F6AA)
    p.rect(47,9,2,2,0xFFFFE6)
    for xy in [(24,27),(28,23),(30,31)] { p.rect(xy.0,xy.1,2,1,teal) }
    // Broad light planes and stepped fin rays keep the small sprite readable.
    p.line([(19,24),(22,21),(29,19),(36,19)], 0x7094CD)
    p.rect(25,20,6,1,0x86BDDC); p.rect(22,22,3,1,0x668ECB)
    p.polygon([(18,29),(21,34),(29,37),(33,36),(27,33),(24,28)], 0x344E85)
    p.line([(28,38),(35,39),(44,38),(48,36)], light)
    p.line([(8,22),(15,27),(9,31)], 0x81A9D5)
    p.line([(27,16),(30,20)], teal); p.line([(35,14),(37,19)], 0x7094CD)
    p.line([(25,41),(28,38),(30,38)], 0x86BDDC)
    p.rect(51,10,1,3,0xBDF3DF); p.rect(45,13,1,2,teal)
    return p
}

func angel() -> SecretCanvas {
    let p = SecretCanvas(), ink = 0x246C84, edge = 0x50B9C8, aqua = 0x85E9D8, pearl = 0xDFFFF1
    // Two broad swimming wings, a translucent spindle and warm internal organs.
    p.polygon([(28,20),(19,12),(11,13),(6,20),(10,25),(19,29),(28,27)], ink)
    p.polygon([(27,21),(19,15),(12,15),(9,20),(13,24),(21,26)], edge)
    p.polygon([(26,22),(18,17),(12,18),(13,21),(21,24)], pearl)
    p.polygon([(36,20),(45,12),(53,13),(58,20),(54,25),(45,29),(36,27)], ink)
    p.polygon([(37,21),(45,15),(52,15),(55,20),(51,24),(43,26)], edge)
    p.polygon([(38,22),(46,17),(52,18),(51,21),(43,24)], pearl)
    p.polygon([(25,15),(23,8),(26,5),(30,9),(34,9),(38,5),(41,8),(39,15),(40,21),(38,28),(35,39),(32,45),(29,39),(26,28),(24,21)], ink)
    p.polygon([(27,15),(26,9),(28,9),(30,13),(34,13),(37,9),(38,10),(36,16),(38,21),(35,30),(33,40),(31,41),(29,32),(27,26),(26,20)], aqua)
    p.polygon([(29,15),(30,13),(34,13),(36,17),(35,24),(33,30),(31,36),(29,28),(28,21)], pearl)
    p.ellipse(29,17,6,8,0xFFB97F); p.ellipse(30,18,4,4,0xFFDF9D)
    p.polygon([(30,25),(34,25),(33,32),(31,34)], 0xF88772)
    p.rect(28,14,1,2,ink); p.rect(35,14,1,2,ink)
    p.rect(29,12,2,1,0xFFFFFF); p.rect(31,37,1,3,0xFFFFFF)
    p.line([(10,19),(13,16),(18,16),(23,19)], 0xD5FFF4)
    p.line([(54,19),(51,16),(46,16),(41,19)], 0xD5FFF4)
    p.line([(11,23),(17,26),(22,26)], 0x46A5B8)
    p.line([(53,23),(47,26),(42,26)], 0x46A5B8)
    p.line([(27,17),(27,23),(29,29)], 0x58C8BD)
    p.line([(36,17),(37,21),(35,27)], 0xB0FFF0)
    p.rect(30,19,2,2,0xFFE9BB); p.rect(33,22,1,3,0xF2937A)
    p.line([(30,32),(32,37),(33,34)], 0xB4F9DF)
    p.rect(26,10,1,3,0xADFFE6); p.rect(37,10,1,3,0xADFFE6)
    return p
}

func nautilus() -> SecretCanvas {
    let p = SecretCanvas(), ink = 0x3C2B69, rim = 0x9E74D7, shell = 0xECD8EE, cream = 0xFFF0CE
    // A segmented coiled shell, visible eye and a fan of separate tentacles.
    p.ellipse(8,6,38,37,ink); p.ellipse(10,7,34,33,rim)
    p.ellipse(12,8,30,29,shell); p.ellipse(15,9,24,24,cream)
    p.polygon([(24,8),(30,8),(40,17),(42,24),(39,26),(36,18)], 0xCE9BC6)
    p.polygon([(12,22),(14,14),(18,11),(19,16)], 0xB586C8)
    p.polygon([(14,31),(18,36),(27,39),(33,37),(24,35)], 0xC195D7)
    p.line([(27,11),(34,14),(38,21),(36,29),(30,33),(22,32),(18,27),(18,21),(22,17),(28,17),(31,21),(30,26),(26,27),(23,24),(24,21),(27,22)], ink, 2)
    p.line([(27,12),(32,15),(35,21),(33,28),(28,30)], 0xF6B577, 1)
    for path in [[(16,12),(20,16)],[(12,19),(18,21)],[(12,27),(18,27)],[(18,35),(22,31)],[(28,38),(29,33)],[(37,33),(34,29)]] { p.line(path, rim) }
    p.polygon([(38,25),(44,23),(50,25),(51,30),(46,35),(37,35),(33,31)], ink)
    p.polygon([(39,26),(45,25),(48,27),(48,31),(43,33),(37,33)], 0x72C9C6)
    p.ellipse(43,25,7,6,ink); p.ellipse(44,25,4,4,cream); p.rect(46,26,2,2,ink)
    for (i, y) in [27,30,33,36,39].enumerated() {
        let end = 57 + (i % 2 == 0 ? 2 : -1)
        p.line([(47,30),(53,y),(end,y-2)], ink, 3)
        p.line([(48,30),(53,y),(end,y-2)], i % 2 == 0 ? cream : 0xE6A69F, 1)
    }
    p.star(21,12,0xFFFFFF); p.star(12,30,0xFFF1A0)
    p.line([(15,10),(21,8),(28,8),(34,11)], 0xFFF6E5)
    p.line([(12,33),(17,38),(25,41),(32,40)], 0xB185DC)
    p.line([(20,34),(25,35),(32,34)], 0xF8ECE0)
    p.rect(34,16,2,2,0xFAE9DC); p.rect(37,23,1,3,0xE0B9E8)
    p.line([(38,28),(41,27),(42,27)], 0xBAF3DC)
    return p
}

func medal(trio: Bool) -> SecretCanvas {
    let p = SecretCanvas(24,32)
    let ribbon = trio ? 0x9D65D8 : 0x43ABB8
    p.polygon([(4,1),(10,1),(12,10),(7,14),(3,8)],0x152848)
    p.polygon([(14,1),(20,1),(21,8),(17,14),(12,10)],0x152848)
    p.polygon([(5,2),(9,2),(11,9),(8,12),(4,7)],ribbon)
    p.polygon([(15,2),(19,2),(20,7),(16,12),(13,9)],ribbon)
    p.rect(5,2,2,6,0xB8F4DF); p.rect(15,2,2,6,0xD6C6FF)
    p.rect(9,9,6,3,0x8A4C13); p.rect(10,9,4,2,0xFFE56C)
    p.ellipse(1,11,22,21,0x79441B);p.ellipse(2,12,20,19,0xD98921)
    p.ellipse(3,12,18,17,0xFFCC3E);p.ellipse(5,14,14,14,0x132D50)
    p.line([(4,20),(5,16),(9,13)],0xFFF6B2,2)
    p.line([(9,29),(16,28),(20,23)],0xF4A522,1)
    if trio {
        for point in [(8,18),(16,18),(12,24)] {
            p.ellipse(point.0-2,point.1-2,5,5,ribbon)
            p.star(point.0,point.1,0xDDFBE9)
        }
        p.line([(9,20),(11,22),(14,20)],0xF2D66A)
    } else {
        p.ellipse(6,20,12,7,0x328D9A)
        p.ellipse(8,20,8,5,0x9CE2CF)
        p.line([(10,20),(9,17),(12,15),(15,17)],0x73DFCF,1)
        p.ellipse(14,16,3,3,0xFFF5AE);p.rect(14,22,1,1,0x132D50)
    }
    return p
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Sources/Resources/PixelSprites")
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
try angler().save("lanternangler", at: root)
try angel().save("glassangel", at: root)
try nautilus().save("starnautilus", at: root)
try medal(trio:false).save("medal-secret-encounter", at: root)
try medal(trio:true).save("medal-secret-trio", at: root)
print("Generated three original secret creature sprites and two discovery medals")
