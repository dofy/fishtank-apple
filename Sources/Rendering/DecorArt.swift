import SpriteKit

enum DecorArt {
    private static var cache: [String: CGImage] = [:]
    static func image(_ item: AquariumDecor) -> CGImage {
        if let image = cache[item.id] { return image }
        if let image = PaintedSprites.decor(item) {
            cache[item.id] = image
            return image
        }
        var p = PixelGrid(width: 64, height: item.id == "fairylights" ? 32 : 64, hue: item.hue)
        // Materials have their own color ramps rather than a single hue per prop.
        let ramps: [String: [Int]] = [
            "coral": [0x613E44,0x974D52,0xD57272,0xF3AC92,0xAD7556,0xFFDBB7],
            "mushroom": [0x224E55,0x3B7374,0x6EA9A2,0xA4DBBC,0x70AFA1,0xD7F0C5],
            "starfish": [0x4D4849,0x696D69,0xDE9465,0xF6C181,0xA58564,0xFFE0A4],
            "anemone": [0x513E68,0x77588A,0xB57BB6,0xE9ACCF,0x8F738F,0xFADBE5],
            "crystal": [0x343653,0x55527D,0x9381BD,0xC5B4E1,0x697E9E,0xE7DEF7],
            "lanterns": [0x493F3A,0x8B493F,0xCE7254,0xF6B77D,0xAD9672,0xFFE6B2],
            "starlamps": [0x4E4C44,0x9E8553,0xDBC17A,0xF4DDA4,0xC7AD75,0xFFF2C6],
            "jellylamps": [0x443D65,0x72628D,0xB48FC4,0xE1BADD,0x9A96CE,0xFCE4EF],
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
            for (i, x) in [15, 26, 38, 48].enumerated() {
                let top = 10 + (i * 11) % 19
                p.line(x, 61, x - 2, top, 2, 2)
                for j in 0..<5 {
                    let y = 55 - j * 9
                    guard y > top else { continue }
                    let side = j % 2 == 0 ? -1 : 1
                    p.polygon([(x,y),(x+side*9,y-3),(x+side*12,y-12),(x+side*4,y-9)],3)
                    p.line(x,y,x+side*9,y-9,4,1)
                }
                p.polygon([(x-2,top+8),(x-6,top),(x-2,top-5),(x+2,top+3)],3)
                p.line(x-2,top+7,x-2,top-2,4,1)
            }
            p.ellipse(31,61,22,2,2)
        case "rocks":
            p.polygon([(3,54),(8,43),(18,38),(31,40),(38,51),(34,60),(12,61)],2)
            p.polygon([(8,43),(18,38),(30,41),(26,50),(9,52)],3)
            p.polygon([(8,43),(18,38),(26,40),(17,42)],4)
            p.polygon([(28,58),(32,46),(43,41),(55,45),(61,56),(54,61)],2)
            p.polygon([(33,47),(44,42),(54,46),(51,54),(38,56)],3)
            p.line(44,43,53,46,4,1);p.line(23,43,20,49,1,1)
            p.line(20,49,25,54,1,1);p.line(43,53,46,58,2,1)
            p.line(9,55,18,57,5,2);p.rect(42,56,9,2,5)
        case "shell":
            p.ellipse(32,56,25,6,2)
            p.polygon([(9,43),(12,33),(20,26),(31,23),(42,26),(51,33),(55,43),(40,54),(25,54)],2)
            p.polygon([(12,42),(15,34),(22,28),(31,26),(41,28),(49,35),(52,42),(38,50),(26,50)],3)
            for i in 0..<9 { p.line(32,52,13+i*5,34+abs(i-4)*2,4,1) }
            p.ellipse(32,53,19,5,1);p.ellipse(32,55,20,3,3)
            p.ellipse(32,50,7,6,4);p.ellipse(31,48,5,5,6)
            p.rect(28,45,3,2,6);p.line(13,57,26,60,4,1)
        case "coral":
            let branches = [[(31,60),(29,43),(23,31),(22,12)],[(29,44),(43,34),(47,17)],[(24,33),(12,27),(9,14)],[(42,35),(54,29),(55,22)],[(30,51),(14,44),(10,35)]]
            for points in branches {
                for i in 1..<points.count {
                    p.line(points[i-1].0,points[i-1].1,points[i].0,points[i].1,2,5)
                    p.line(points[i-1].0,points[i-1].1,points[i].0,points[i].1,3,3)
                    p.line(points[i-1].0,points[i-1].1,points[i].0,points[i].1,4,1)
                }
                let tip=points.last!;p.ellipse(tip.0+1,tip.1,2,2,6)
            }
            p.line(24,30,33,22,3,3);p.line(33,22,34,11,4,2)
            p.line(44,31,39,23,3,2);p.line(15,43,19,34,4,2)
            p.ellipse(32,61,12,2,2)
        case "mushroom":
            for i in 0..<3 { let x = 15 + i * 17, y = 40 + (i % 2) * 9
                p.rect(x - 2, y, 4, 60 - y, 2); p.ellipse(x, y, 12, 7, 3); p.rect(x - 8, y - 3, 5, 2, 4)
                p.line(x - 7, y + 3, x + 7, y + 3, 2, 1)
                for j in 0..<4 { p.rect(x - 7 + j * 4, y - 2 + j % 2 * 3, 2, 1, 6) }
                p.rect(x, y + 7, 1, max(0, 52 - y), 4)
                for ray in [-7,-3,3,7] { p.line(x+ray,y+3,x,y+7,2,1) }
                p.ellipse(x-3,y-3,2,1,6)
            }
        case "starfish":
            p.polygon([(5,57),(10,47),(25,44),(47,47),(58,55),(51,62),(16,62)],2)
            var points:[(Int,Int)]=[]
            for i in 0..<10 {
                let a=Double(i)*Double.pi/5-Double.pi/2,r=Double(i%2==0 ? 19 : 7)
                points.append((31+Int(cos(a)*r),42+Int(sin(a)*r)))
            }
            p.polygon(points,3)
            for i in 0..<5 { let a=Double(i)*Double.pi*2/5-Double.pi/2
                p.line(31,42,31+Int(cos(a)*15),42+Int(sin(a)*15),4,1)
            }
            p.ellipse(31,42,3,3,4);p.rect(30,41,1,1,6)
        case "driftwood":
            p.line(5, 58, 52, 38, 2, 8); p.line(8, 55, 49, 38, 3, 3)
            p.line(25, 49, 18, 25, 2, 5); p.line(40, 42, 53, 21, 2, 4)
            p.line(20, 36, 8, 30, 3, 3)
            p.line(13, 56, 47, 42, 4, 1); p.line(23, 52, 43, 43, 1, 1)
            p.ellipse(29, 48, 3, 2, 1); p.ellipse(29, 48, 1, 1, 4)
            p.line(10, 59, 19, 56, 5, 2); p.rect(17, 55, 3, 1, 4)
            p.ellipse(8,58,4,4,1);p.ellipse(8,58,3,3,3);p.ellipse(8,58,1,1,2)
            p.line(27,44,20,29,4,1);p.line(43,40,51,24,4,1)
        case "anemone":
            p.ellipse(32, 58, 22, 6, 2)
            for i in 0..<9 { let x = 12 + i * 5
                p.line(x, 57, x + (i % 2 == 0 ? -4 : 4), 30 + (i * 7) % 14, 3, 3)
                p.ellipse(x + (i % 2 == 0 ? -4 : 4), 30 + (i * 7) % 14, 3, 3, 4)
            }
            p.ellipse(32,56,12,4,1);p.ellipse(32,55,9,3,4)
            p.ellipse(32,55,4,2,2)
        case "arch":
            p.ellipse(32,35,27,28,2);p.ellipse(32,35,24,26,3)
            p.ellipse(32,42,14,21,0);p.rect(18,42,28,22,0)
            // Wedge joints make a stone arch, with the opening left transparent.
            for (a,b,c,d) in [(8,29,18,32),(6,41,18,41),(7,52,18,51),(46,32,57,29),(46,42,58,42),(46,52,57,53),(16,13,23,24),(31,8,31,21),(47,13,40,24)] {
                p.line(a,b,c,d,2,2);p.line(a,b-1,c,d-1,4,1)
            }
            p.rect(7,59,12,4,2);p.rect(45,59,13,4,2)
            p.line(11,21,17,14,5,2);p.line(45,14,51,20,5,2)
        case "crystal":
            p.ellipse(32,59,26,4,2)
            for (x,h) in [(12,23),(24,38),(39,49),(52,27)] {
                p.polygon([(x,59-h),(x+6,65-h),(x+7,56),(x,61),(x-6,56),(x-5,65-h)],2)
                p.polygon([(x,59-h),(x+1,60),(x-5,55),(x-4,65-h)],3)
                p.polygon([(x,59-h),(x+5,65-h),(x+6,55),(x+1,60)],4)
                p.line(x,60-h,x,56,6,1)
            }
        case "chest":
            p.rect(9,40,46,22,1);p.rect(12,42,40,17,2)
            p.ellipse(32,37,23,12,1);p.ellipse(32,37,20,9,3)
            p.rect(10,39,44,6,2);p.line(11,40,52,40,4,1)
            for y in [32,36,48,54] { p.line(14,y,49,y,2,1) }
            for x in [18,43] { p.rect(x,29,4,30,4);p.rect(x+1,31,1,26,6)
                for y in [33,39,49,56] { p.rect(x+1,y,1,1,1) }
            }
            p.rect(9,44,46,3,1);p.rect(29,42,8,10,4)
            p.ellipse(33,46,1,1,1);p.rect(33,47,1,3,1)
            p.line(12,60,52,60,4,1)
        case "anchor":
            p.ellipse(32, 12, 7, 7, 2); p.ellipse(32, 12, 3, 3, 0)
            p.line(32, 17, 32, 54, 3, 4); p.rect(16, 26, 32, 4, 3)
            p.line(32, 57, 12, 45, 2, 5); p.line(32, 57, 52, 45, 2, 5)
            p.triangle(9, 39, 20, 44, 12, 50, 3); p.triangle(55, 39, 44, 44, 52, 50, 3)
            p.line(31,19,31,52,4,1);p.line(17,26,45,26,4,1)
            p.line(14,46,30,55,4,1);p.line(34,55,50,46,4,1)
            p.rect(30,35,3,3,5);p.rect(42,49,3,2,5)
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
            p.line(29,44,29,59,2,1);p.line(34,42,34,59,2,1)
            p.rect(26,53,12,2,2);p.rect(25,48,14,2,2)
            p.line(17,37,17,42,6,1);p.line(53,37,53,42,6,1)
        case "statue":
            p.rect(15,57,34,5,2);p.rect(18,54,28,3,4)
            p.polygon([(22,54),(24,38),(20,31),(21,17),(25,11),(39,11),(44,17),(44,31),(39,38),(42,54)],2)
            p.polygon([(25,16),(38,16),(40,30),(35,38),(36,52),(26,52),(28,38),(24,30)],3)
            p.rect(20,12,25,4,4);p.rect(23,8,19,4,3)
            p.line(24,23,29,22,1,2);p.line(35,22,40,23,1,2)
            p.polygon([(31,22),(34,22),(36,32),(30,32)],4)
            p.line(28,35,37,35,1,1);p.line(25,43,28,47,4,1)
            p.rect(21,48,4,5,5);p.rect(37,17,3,2,5)
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
                p.rect(x - 1, y + 5, 1, 2, 6)
                p.rect(x, y + 9, 1, 1, 7+i)
            }
        default: // Four distinct hanging fixtures.
            let count = item.id == "fairylights" ? 9 : 3
            for i in 0..<count {
                let x = 9 + i * 46 / max(1, count - 1), y = 8 + abs(i - count / 2) * (item.id == "fairylights" ? 1 : 2)
                p.line(x, 2, x, y + 6, 2, 1)
                if item.id == "fairylights" { p.rect(x - 2, y + 6, 4, 5, i % 2 == 0 ? 4 : 5) }
                else if item.id == "starlamps" {
                    var star:[(Int,Int)]=[]
                    for k in 0..<10 { let a=Double(k)*Double.pi/5-Double.pi/2,r=Double(k%2==0 ? 8 : 3)
                        star.append((x+Int(cos(a)*r),y+14+Int(sin(a)*r)))
                    };p.polygon(star,3);p.line(x,y+8,x,y+17,4,1);p.rect(x,y+13,2,2,6)
                } else if item.id == "lanterns" {
                    p.ellipse(x, y + 15, 7, 10, 2);p.ellipse(x,y+15,6,9,3)
                    for rib in [-4,0,4] { p.line(x+rib,y+8,x+rib,y+22,4,1) }
                    p.rect(x-3,y+5,6,2,2);p.rect(x-3,y+24,6,2,2)
                    p.line(x,y+26,x,y+32,4,1);p.rect(x-1,y+31,3,4,3)
                } else {
                    p.ellipse(x, y + 14, 8, 6, 3);p.ellipse(x-2,y+12,4,2,4)
                    p.line(x-7,y+17,x+7,y+17,2,1)
                    for j in 0..<3 { p.line(x-5+j*5,y+17,x-6+j*5,y+26,4,1);p.line(x-6+j*5,y+26,x-3+j*5,y+31,3,1) }
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
        if let image = PaintedSprites.medal(id) { cache[key] = image; return image }
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
        let left = max(0, x), right = min(width, x + w)
        let top = max(0, y), bottom = min(height, y + h)
        guard w > 0, h > 0, left < right, top < bottom else { return }
        for j in top..<bottom { for i in left..<right { cells[j*width+i] = c } }
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
    mutating func polygon(_ points: [(Int, Int)], _ color: Int) {
        guard points.count >= 3 else { return }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: points[0].0, y: points[0].1))
        for point in points.dropFirst() { path.addLine(to: CGPoint(x: point.0, y: point.1)) }
        path.closeSubpath()
        for y in 0..<height { for x in 0..<width where path.contains(CGPoint(x: Double(x)+0.5, y: Double(y)+0.5)) {
            cells[y*width+x] = color
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
