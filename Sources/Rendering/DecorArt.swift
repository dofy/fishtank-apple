import SpriteKit

enum DecorArt {
    private static var cache: [String: CGImage] = [:]
    static func image(_ item: AquariumDecor) -> CGImage {
        if let image = cache[item.id] { return image }
        var p = PixelGrid(width: 64, height: item.id == "fairylights" ? 32 : 64, hue: item.hue)
        // Materials have their own color ramps rather than a single hue per prop.
        let ramps: [String: [Int]] = [
            "kelp": [0x143C38,0x235E4B,0x3D9060,0x87BD79,0xB4D79A,0xD6E9B2],
            "rocks": [0x263D48,0x3E5360,0x667E85,0xA8B9AC,0x507D61,0xD2D8BD],
            "shell": [0x663E68,0x9D6380,0xCC8D9B,0xF1C3B5,0xE8B575,0xFFF1D4],
            "driftwood": [0x342E32,0x654940,0x91674C,0xC19467,0x5B7E59,0xE3BE89],
            "arch": [0x2B4149,0x4A6568,0x7A9390,0xB4C4AE,0x5F8C65,0xD6DDC0],
            "chest": [0x332F35,0x69483D,0xA5754C,0xDBB673,0x648C86,0xF6DCA1],
            "anchor": [0x253B45,0x3D5962,0x66888B,0xB2C9B7,0xA67B54,0xE0DDC0],
            "castle": [0x3E424B,0x686774,0x9C98A1,0xD4C9BD,0x749478,0xEADDC2],
            "statue": [0x2C4548,0x4D716E,0x83A89A,0xBCD2AF,0xA38969,0xE3E3BE]
        ]
        if let ramp = ramps[item.id] { p.colors = [[0,0,0,0]] + ramp.map { hex in
            [UInt8((hex >> 16) & 255), UInt8((hex >> 8) & 255), UInt8(hex & 255), 255]
        } }
        switch item.id {
        case "kelp":
            for i in 0..<5 {
                let x = 12 + i * 8, height = 26 + (i * 13) % 27
                let sway = i % 2 == 0 ? 1 : -1
                p.line(x, 61, x + sway * 3, 61 - height, 2, 2)
                for j in 0..<6 {
                    let y = 57 - j * 8
                    if y > 61 - height {
                        let side = j % 2 == 0 ? -1 : 1
                        p.triangle(x, y + 2, x + side * 8, y - 7, x + side * 3, y - 4, 3)
                        p.line(x, y, x + side * 6, y - 6, 4, 1)
                    }
                }
                p.triangle(x, 64 - height, x + sway * 4, 56 - height, x + sway * 5, 63 - height, 4)
            }
            p.ellipse(30, 62, 20, 1, 2)
        case "rocks":
            p.ellipse(27, 52, 23, 9, 2); p.ellipse(21, 48, 14, 10, 3); p.ellipse(41, 50, 13, 9, 3)
            p.rect(13, 42, 13, 2, 4); p.rect(33, 45, 10, 2, 4)
            p.line(21, 39, 17, 49, 2, 1); p.line(35, 43, 39, 52, 2, 1)
            p.line(11, 53, 25, 56, 1, 1); p.rect(36, 54, 10, 2, 5)
            p.rect(12, 47, 5, 2, 5); p.rect(16, 46, 3, 1, 4)
        case "shell":
            p.ellipse(31, 48, 24, 13, 2); p.ellipse(31, 44, 23, 12, 3)
            for i in 0..<7 { p.line(31, 56, 10 + i * 7, 38 + abs(i - 3), 4, 2) }
            p.ellipse(31, 49, 7, 6, 6); p.rect(28, 45, 3, 2, 4)
            p.ellipse(32, 51, 4, 3, 4); p.ellipse(30, 48, 4, 4, 6)
            p.rect(28, 46, 2, 1, 6); p.line(13, 53, 22, 58, 4, 1)
        case "coral":
            p.line(32, 62, 28, 13, 3, 4)
            for i in 0..<6 { let y = 53 - i * 7, dx = i % 2 == 0 ? -1 : 1
                p.line(30, y, 30 + dx * 16, y - 7, 3, 3); p.line(30 + dx * 16, y - 7, 30 + dx * 18, y - 17, 4, 3)
                p.line(30 + dx * 10, y - 4, 30 + dx * 8, y - 12, 3, 2)
                p.ellipse(30 + dx * 18, y - 17, 2, 2, 6)
            }
            p.ellipse(31, 61, 12, 2, 2); p.line(30, 57, 28, 19, 4, 1)
        case "mushroom":
            for i in 0..<3 { let x = 15 + i * 17, y = 40 + (i % 2) * 9
                p.rect(x - 2, y, 4, 60 - y, 2); p.ellipse(x, y, 12, 7, 3); p.rect(x - 8, y - 3, 5, 2, 4)
                p.line(x - 7, y + 3, x + 7, y + 3, 2, 1)
                for j in 0..<4 { p.rect(x - 7 + j * 4, y - 2 + j % 2 * 3, 2, 1, 6) }
                p.rect(x, y + 7, 1, max(0, 52 - y), 4)
            }
        case "starfish":
            p.ellipse(32, 53, 26, 9, 2)
            for i in 0..<5 { let a = Double(i) * .pi * 2 / 5 - .pi / 2
                p.line(31, 44, 31 + Int(cos(a) * 16), 44 + Int(sin(a) * 14), 3, 5)
            }; p.ellipse(31, 44, 6, 5, 4)
        case "driftwood":
            p.line(5, 58, 52, 38, 2, 8); p.line(8, 55, 49, 38, 3, 3)
            p.line(25, 49, 18, 25, 2, 5); p.line(40, 42, 53, 21, 2, 4)
            p.line(20, 36, 8, 30, 3, 3)
            p.line(13, 56, 47, 42, 4, 1); p.line(23, 52, 43, 43, 1, 1)
            p.ellipse(29, 48, 3, 2, 1); p.ellipse(29, 48, 1, 1, 4)
            p.line(10, 59, 19, 56, 5, 2); p.rect(17, 55, 3, 1, 4)
        case "anemone":
            p.ellipse(32, 58, 22, 6, 2)
            for i in 0..<9 { let x = 12 + i * 5
                p.line(x, 57, x + (i % 2 == 0 ? -4 : 4), 30 + (i * 7) % 14, 3, 3)
                p.ellipse(x + (i % 2 == 0 ? -4 : 4), 30 + (i * 7) % 14, 3, 3, 4)
            }
        case "arch":
            p.ellipse(32, 36, 27, 29, 2); p.ellipse(32, 36, 23, 26, 3)
            p.ellipse(32, 44, 14, 22, 0); p.rect(18, 44, 28, 20, 0)
            for i in 0..<5 { p.rect(9, 24 + i * 8, 9, 2, 4); p.rect(46, 20 + i * 8, 9, 2, 4) }
        case "crystal":
            p.ellipse(32, 58, 26, 5, 2)
            for i in 0..<5 { let x = 9 + i * 11, h = 20 + (i * 17) % 30
                p.triangle(x, 59 - h, x - 7, 58, x + 7, 58, 3); p.line(x, 59 - h, x - 1, 56, 4, 2)
            }
        case "chest":
            p.rect(10, 35, 44, 25, 1); p.rect(12, 37, 40, 21, 2); p.rect(12, 37, 40, 7, 3)
            p.rect(17, 37, 4, 21, 4); p.rect(43, 37, 4, 21, 4); p.rect(10, 45, 44, 3, 1)
            p.rect(29, 44, 7, 8, 4); p.rect(32, 46, 2, 3, 1)
            for y in [41, 51, 55] { p.line(22, y, 39, y, 1, 1) }
            for x in [18, 44] { for y in [40, 53] { p.rect(x, y, 1, 1, 6) } }
            p.rect(13, 38, 38, 1, 6)
        case "anchor":
            p.ellipse(32, 12, 7, 7, 2); p.ellipse(32, 12, 3, 3, 0)
            p.line(32, 17, 32, 54, 3, 4); p.rect(16, 26, 32, 4, 3)
            p.line(32, 57, 12, 45, 2, 5); p.line(32, 57, 52, 45, 2, 5)
            p.triangle(9, 39, 20, 44, 12, 50, 3); p.triangle(55, 39, 44, 44, 52, 50, 3)
        case "castle":
            for i in 0..<3 { let x = 10 + i * 18, y = i == 1 ? 12 : 28
                p.rect(x, y, 13, 48 - y + 12, 2); p.rect(x + 2, y, 10, 48 - y + 12, 3)
                for j in 0..<3 { p.rect(x + j * 5, y - 4, 3, 5, 4) }; p.rect(x + 5, y + 8, 3, 7, 1)
                for row in 0..<5 { let yy = y + 10 + row * 8
                    if yy < 58 { p.rect(x + 3, yy, 7, 1, 4); p.rect(x + 5 + row % 2 * 3, yy - 4, 1, 4, 2) }
                }
                p.rect(x, 58, 13, 3, 5)
            }; p.rect(26, 43, 12, 18, 1); p.ellipse(32, 43, 6, 6, 1)
            p.rect(24, 60, 16, 2, 4)
        case "statue":
            p.rect(18, 54, 28, 7, 2); p.rect(23, 35, 18, 20, 3)
            p.ellipse(32, 24, 13, 16, 2); p.rect(22, 15, 20, 18, 3)
            p.rect(23, 21, 5, 3, 4); p.rect(36, 21, 5, 3, 4); p.rect(29, 31, 7, 2, 1)
            p.rect(19, 11, 26, 5, 4)
        case "fairylights":
            p.colors += [0xEFAD85,0xE5C977,0x9EC8A4,0x89C8CC,0x97B9DC,0xB3A2D0,0xDDA3B3].map {
                [UInt8(($0 >> 16) & 255), UInt8(($0 >> 8) & 255), UInt8($0 & 255), 255]
            }
            // A single sagging cable, short sockets, and compact glass bulbs.
            for x in 0..<64 {
                let y = 4 + Int((7 * sin(Double(x) / 63 * .pi)).rounded())
                p.rect(x, y, 1, 1, 1)
            }
            p.rect(0, 2, 3, 4, 2); p.rect(61, 2, 3, 4, 2)
            for i in 0..<7 {
                let x = 6 + i * 8, y = 4 + Int((7 * sin(Double(x) / 63 * .pi)).rounded())
                p.rect(x, y + 1, 1, 3, 1)
                p.rect(x - 1, y + 3, 3, 2, 2)
                p.rect(x - 2, y + 5, 5, 5, 1)
                p.rect(x - 1, y + 5, 3, 4, 7 + i)
                p.rect(x - 1, y + 5, 1, 1, 6)
            }
        default: // Four distinct hanging fixtures.
            let count = item.id == "fairylights" ? 9 : 3
            for i in 0..<count {
                let x = 5 + i * 54 / max(1, count - 1), y = 8 + abs(i - count / 2) * (item.id == "fairylights" ? 1 : 2)
                p.line(x, 2, x, y + 6, 2, 1)
                if item.id == "fairylights" { p.rect(x - 2, y + 6, 4, 5, i % 2 == 0 ? 4 : 5) }
                else if item.id == "starlamps" {
                    p.line(x - 5, y + 13, x + 5, y + 13, 4, 3); p.line(x, y + 8, x, y + 18, 4, 3)
                } else if item.id == "lanterns" {
                    p.ellipse(x, y + 15, 7, 10, 3); p.rect(x - 2, y + 9, 4, 12, 4); p.rect(x - 3, y + 25, 6, 2, 2)
                } else {
                    p.ellipse(x, y + 14, 8, 6, 3); for j in 0..<3 { p.line(x - 5 + j * 5, y + 16, x - 6 + j * 5, y + 28, 4, 1) }
                }
            }
            p.line(2, 2, 62, 2, 2, 1)
        }
        if !item.top { p.materialDetails(stone: ["rocks", "arch", "castle", "statue"].contains(item.id)) }
        let image = p.image(cropped: item.id != "fairylights")
        cache[item.id] = image
        return image
    }

    static func medal(_ id: String) -> CGImage {
        let key = "medal-" + id
        if let cached = cache[key] { return cached }
        let index = AchievementCatalog.all.firstIndex { $0.id == id } ?? 0
        var p = PixelGrid(width: 24, height: 32, hue: Double(index * 29 % 360))
        p.rect(4, 1, 6, 12, 2); p.rect(14, 1, 6, 12, 3)
        p.ellipse(12, 20, 10, 10, 1); p.ellipse(12, 20, 8, 8, 4)
        // Each medal has its own pixel emblem, not just a different color.
        switch index % 7 {
        case 0: p.line(7, 20, 17, 20, 2, 3); p.triangle(6, 20, 3, 16, 3, 24, 2); p.rect(15, 18, 1, 1, 1)
        case 1: p.rect(7, 17, 10, 7, 2); p.rect(9, 14, 6, 3, 2); p.rect(10, 19, 4, 2, 4)
        case 2: p.ellipse(12, 18, 5, 4, 2); for x in [8,12,16] { p.line(x, 20, x - 1, 25, 2, 1) }
        case 3: for i in 0..<5 { let a = Double(i) * .pi * 2 / 5; p.line(12,20,12+Int(cos(a)*6),20+Int(sin(a)*6),2,2) }
        case 4: for i in 0..<3 { p.rect(7+i*4, 22-i*3, 3, 4+i*3, 2) }
        case 5: p.ellipse(12,20,6,6,2); p.ellipse(12,20,3,3,4); p.rect(11,13,2,14,2)
        default: p.line(7,24,16,15,2,3); p.rect(6,15,4,4,2); p.rect(14,22,4,4,2)
        }
        if index >= 7 { p.rect(3,28,18,2,5) }
        let image = p.image(cropped: false); cache[key] = image; return image
    }
}

private struct PixelGrid {
    let width: Int
    let height: Int
    var cells: [Int]
    var colors: [[UInt8]]
    init(width: Int, height: Int, hue: Double) {
        self.width = width; self.height = height; cells = Array(repeating: 0, count: width * height)
        colors = [[0,0,0,0], PixelArt.hsl(hue,0.3,0.18), PixelArt.hsl(hue,0.5,0.31),
                  PixelArt.hsl(hue,0.62,0.51), PixelArt.hsl(hue,0.56,0.74), PixelArt.hsl((hue+75).truncatingRemainder(dividingBy:360),0.65,0.6), [247,239,202,255]]
    }
    mutating func materialDetails(stone: Bool) {
        let base = cells
        for y in 1..<(height - 1) { for x in 1..<(width - 1) {
            let i = y * width + x
            guard base[i] == 3 else { continue }
            if base[i - width] == 0 || base[i - 1] == 0 { cells[i] = 4 }
            else if base[i + width] == 0 || base[i + 1] == 0 { cells[i] = 2 }
            else if stone && (x * 7 + y * 11) % 47 == 0 {
                cells[i] = 2
                if base[i + 1] == 3 { cells[i + 1] = 4 }
            }
        } }
    }
    mutating func rect(_ x: Int,_ y: Int,_ w: Int,_ h: Int,_ c: Int) {
        guard w > 0, h > 0 else { return }
        for j in max(0,y)..<max(0,min(height,y+h)) { for i in max(0,x)..<max(0,min(width,x+w)) { cells[j*width+i] = c } }
    }
    mutating func line(_ x0: Int,_ y0: Int,_ x1: Int,_ y1: Int,_ c: Int,_ thickness: Int) {
        let steps = max(1,max(abs(x1-x0),abs(y1-y0)))
        for i in 0...steps { let t=Double(i)/Double(steps); rect(Int((Double(x0)+Double(x1-x0)*t).rounded()),Int((Double(y0)+Double(y1-y0)*t).rounded()),thickness,thickness,c) }
    }
    mutating func ellipse(_ cx: Int,_ cy: Int,_ rx: Int,_ ry: Int,_ c: Int) {
        for y in max(0,cy-ry)..<min(height,cy+ry+1) { for x in max(0,cx-rx)..<min(width,cx+rx+1) {
            if pow(Double(x-cx)/Double(rx),2)+pow(Double(y-cy)/Double(ry),2)<=1 { cells[y*width+x] = c }
        } }
    }
    mutating func triangle(_ ax: Int,_ ay: Int,_ bx: Int,_ by: Int,_ cx: Int,_ cy: Int,_ c: Int) {
        func cross(_ x: Int,_ y: Int,_ x0: Int,_ y0: Int,_ x1: Int,_ y1: Int) -> Int { (x-x0)*(y1-y0)-(y-y0)*(x1-x0) }
        for y in max(0,min(ay,min(by,cy)))..<min(height,max(ay,max(by,cy))+1) { for x in max(0,min(ax,min(bx,cx)))..<min(width,max(ax,max(bx,cx))+1) {
            let v=[cross(x,y,ax,ay,bx,by),cross(x,y,bx,by,cx,cy),cross(x,y,cx,cy,ax,ay)]
            if v.allSatisfy({$0>=0}) || v.allSatisfy({$0<=0}) { cells[y*width+x]=c }
        } }
    }
    func image(cropped: Bool) -> CGImage {
        let occupied = cells.indices.filter { cells[$0] != 0 }
        let x0 = cropped ? occupied.map { $0 % width }.min() ?? 0 : 0
        let x1 = cropped ? occupied.map { $0 % width }.max() ?? width-1 : width-1
        let y0 = cropped ? occupied.map { $0 / width }.min() ?? 0 : 0
        let y1 = cropped ? occupied.map { $0 / width }.max() ?? height-1 : height-1
        var bytes: [UInt8] = []
        for y in y0...y1 { for x in x0...x1 { bytes += colors[cells[y*width+x]] } }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(width:x1-x0+1,height:y1-y0+1,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:(x1-x0+1)*4,
                       space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.last.rawValue),provider:provider,
                       decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
    }
}
