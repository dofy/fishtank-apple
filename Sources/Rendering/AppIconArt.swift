#if os(macOS)
import AppKit

/// The original 64-pixel tank silhouette and palette, with compact hand-drawn props.
enum AppIconArt {
    static func image(_ design: AppIconDesign, pixels: Int) -> CGImage {
        let c = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: pixels * 4,
                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.scaleBy(x: CGFloat(pixels) / 64, y: CGFloat(pixels) / 64)
        c.setShouldAntialias(false); c.interpolationQuality = .none
        func block(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ hex: Int) {
            c.setFillColor(NSColor(red: CGFloat((hex >> 16) & 255)/255, green: CGFloat((hex >> 8) & 255)/255, blue: CGFloat(hex & 255)/255, alpha: 1).cgColor)
            c.fill(CGRect(x: x, y: y, width: w, height: h))
        }
        let bounds = CGRect(x: 1, y: 1, width: 62, height: 62)
        c.addPath(CGPath(roundedRect: bounds, cornerWidth: 14, cornerHeight: 14, transform: nil)); c.clip()
        let water = [0x247A91,0x20758C,0x1C6E86,0x19667F,0x175E77,0x165770,0x164E67,0x17465E]
        for band in 0..<8 { block(0,56-band*8,64,8,water[band]) }
        for x in stride(from: 0, to: 64, by: 2) {
            let top = 10 + Int((sin(Double(x)*0.14)*2 + cos(Double(x)*0.31)).rounded())
            block(x,0,2,top,0xB59A6D); block(x,top-3,2,2,0xD5B780); block(x,top-1,2,1,0xEFDAA7)
        }
        for i in 0..<32 { block((i*23)%62,2+(i*7)%5,i%3 == 0 ? 2 : 1,1,i%2 == 0 ? 0xF2DCAB : 0x947952) }
        func prop(_ id: String, x: Int, y: Int) {
            func b(_ dx: Int,_ dy: Int,_ w: Int,_ h: Int,_ hex: Int) { block(x+dx,y+dy,w,h,hex) }
            switch id {
            case "kelp":
                for (dx,h) in [(1,15),(4,20),(7,12)] {
                    b(dx,0,1,h,0x51B998)
                    for step in 0..<h/4 { b(dx-1,step*4+1,2,2,step%2 == 0 ? 0x8BD6AE : 0x3B9D88); b(dx+1,step*4+3,2,1,0xA0DDB6) }
                }
            case "coral":
                b(5,0,3,20,0xC8687A); b(6,1,1,18,0xF3AF9F)
                for (dx,dy,h) in [(0,7,6),(11,11,7),(1,15,5),(10,3,5)] {
                    b(dx,dy,2,h,0xE18892); b(min(dx,5),dy,abs(dx-5)+2,2,0xC8687A); b(dx,dy+h,2,1,0xF7C5B0)
                }
            case "mushroom":
                for (dx,dy) in [(1,6),(8,11)] { b(dx+2,0,2,dy,0x489D9A); b(dx,dy,7,3,0x88DDC6); b(dx+1,dy+3,5,1,0xC5EFD2); b(dx+1,dy+1,1,1,0xF4F0B6) }
            case "crystal":
                for (dx,h) in [(0,8),(4,15),(9,10)] { b(dx,0,4,h,0x8F7BC5); b(dx+1,1,1,h-1,0xD6B5F1); b(dx+1,h,2,2,0xEBD2EF) }
            case "anemone":
                b(0,0,14,3,0x74538F)
                for i in 0..<5 { let h = 5+(i*3)%7; b(i*3,2,1,h,0xBE8BCC); b(i*3-1,h+2,3,2,0xE5B4D4) }
            case "arch":
                b(0,0,4,19,0x6E9693); b(11,0,4,19,0x6E9693); b(2,18,11,4,0x9EBBA7); b(4,21,7,2,0xBED0AF)
                for dy in [3,9,15] { b(0,dy,3,1,0xBED0AF); b(12,dy,3,1,0x4B706F) }
            case "castle":
                b(0,0,5,15,0x9C98A1); b(9,0,5,15,0x9C98A1); b(5,0,4,20,0xBCB3B3)
                for dx in [0,3,9,12] { b(dx,15,2,2,0xD4C9BD) }; b(5,20,2,2,0xEADDC2); b(8,20,2,2,0xEADDC2)
                b(6,0,2,6,0x414B5E); b(1,9,2,3,0x414B5E); b(10,9,2,3,0x414B5E)
            case "chest":
                b(0,0,12,8,0x69483D); b(1,1,10,6,0xAC7A52); b(0,8,12,2,0xDBB673); b(2,0,2,8,0xDBB673); b(8,0,2,8,0xDBB673); b(0,4,12,1,0x332F35); b(5,3,2,3,0xF6DCA1)
            case "starfish":
                b(2,0,10,2,0x627C83); b(5,2,3,8,0xF1AA7C); b(1,6,11,2,0xF1AA7C); b(3,2,2,3,0xD07864); b(8,2,2,3,0xD07864); b(6,6,1,1,0xF8DC9E)
            case "rocks":
                b(0,0,14,4,0x526D77); b(2,4,7,4,0x8FA8AA); b(8,3,5,3,0x769792); b(3,7,4,1,0xBECCBB); b(1,1,4,1,0x85AE8D)
            case "driftwood":
                b(0,1,14,3,0x654940); b(2,4,10,2,0x91674C); b(3,5,2,5,0xC19467); b(10,5,2,7,0x91674C); b(1,4,3,1,0xC19467); b(11,0,3,1,0x7D9A72)
            default: // Original compact pearl shell.
                b(0,0,9,3,0xA86683); b(1,3,7,2,0xDE9CAA); b(3,4,3,1,0xF4C6BD); b(3,2,3,2,0xF8E8C4)
            }
        }
        prop(design.decorationID, x: 6, y: 10)
        for (x,y) in [(17,48),(24,46),(31,49)] { block(x,y,4,1,0x5595A6); block(x-1,y-1,1,3,0x5595A6) }
        let fish = PixelArt.image(species: FishCatalog.byID[design.speciesID]!, grade: 1)
        if let secondaryID = design.secondarySpeciesID, let secondary = FishCatalog.byID[secondaryID] {
            c.draw(fish, in: CGRect(x: 8, y: 31, width: 34, height: 25.5))
            c.saveGState(); c.translateBy(x: 56, y: 0); c.scaleBy(x: -1, y: 1)
            c.draw(PixelArt.image(species: secondary, grade: 1), in: CGRect(x: 0, y: 16, width: 32, height: 24))
            c.restoreGState()
        } else {
            c.draw(fish, in: CGRect(x: 14, y: 20, width: 40, height: 30))
        }
        prop(design.companionID, x: design.companionID == "shell" ? 47 : 43, y: 10)
        for (x,y) in [(49,38),(53,46)] {
            block(x,y,2,1,0x8DCBD4); block(x-1,y+1,1,2,0x63A9BA); block(x+2,y+1,1,2,0xB8E2DF); block(x,y+3,2,1,0xB8E2DF)
        }
        c.addPath(CGPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), cornerWidth: 13, cornerHeight: 13, transform: nil))
        c.setStrokeColor(NSColor(red: 0.51, green: 0.72, blue: 0.76, alpha: 1).cgColor); c.setLineWidth(2); c.strokePath()
        return c.makeImage()!
    }
}
#endif
