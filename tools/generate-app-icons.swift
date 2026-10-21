import AppKit

@main
struct AppIcons {
    static func main() throws {
        let directory = URL(fileURLWithPath: "Sources/Resources/Assets.xcassets")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{\"info\":{\"author\":\"xcode\",\"version\":1}}".utf8).write(to: directory.appendingPathComponent("Contents.json"))
        for platform in ["Mac", "Pad"] {
            let target = directory.appendingPathComponent("\(platform)Icon.appiconset")
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            var entries: [[String: String]] = []
            let sizes = platform == "Mac" ? [16,32,128,256,512] : [20,29,40,76,83.5,1024]
            for size in sizes {
                let scales = platform == "Mac" ? [1,2] : size == 1024 || size == 83.5 ? [size == 1024 ? 1 : 2] : [1,2]
                for scale in scales {
                    let pixels = Int(size * Double(scale))
                    let name = "icon-\(pixels).png"
                    let c = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                        bytesPerRow: pixels * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: platform == "Mac" ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue)!
                    c.scaleBy(x: CGFloat(pixels) / 64, y: CGFloat(pixels) / 64)
                    c.setShouldAntialias(false); c.interpolationQuality = .none
                    func block(_ x: Int,_ y: Int,_ w: Int,_ h: Int,_ hex: Int) {
                        c.setFillColor(NSColor(red: CGFloat((hex >> 16) & 255)/255, green: CGFloat((hex >> 8) & 255)/255, blue: CGFloat(hex & 255)/255, alpha:1).cgColor)
                        c.fill(CGRect(x:x,y:y,width:w,height:h))
                    }
                    // One silhouette: the app icon itself is the glass tank.
                    // iPad supplies the system mask; Mac retains transparent corners.
                    if platform == "Pad" { block(0,0,64,64,0x20566C) }
                    let inset: CGFloat = platform == "Mac" ? 1 : 0
                    let bounds = CGRect(x: inset, y: inset, width: 64-inset*2, height: 64-inset*2)
                    let silhouette = CGPath(roundedRect: bounds, cornerWidth: 14, cornerHeight: 14, transform: nil)
                    c.addPath(silhouette); c.clip()
                    let water = [0x247A91,0x20758C,0x1C6E86,0x19667F,0x175E77,0x165770,0x164E67,0x17465E]
                    for band in 0..<8 { block(0,56-band*8,64,8,water[band]) }
                    // Low-relief substrate, continuous to both edges of the icon.
                    for x in stride(from:0,to:64,by:2) {
                        let top = 10 + Int((sin(Double(x)*0.14)*2 + cos(Double(x)*0.31)).rounded())
                        block(x,0,2,top,0xB59A6D)
                        block(x,top-3,2,2,0xD5B780);block(x,top-1,2,1,0xEFDAA7)
                    }
                    for i in 0..<32 { block((i*23)%62,2+(i*7)%5,i%3 == 0 ? 2 : 1,1,i%2 == 0 ? 0xF2DCAB : 0x947952) }
                    // A small kelp grove follows the lower left curve.
                    for (x,y,h) in [(7,9,15),(10,10,20),(13,10,12)] {
                        block(x,y,1,h,0x51B998)
                        for step in 0..<h/4 {
                            block(x-1,y+step*4+1,2,2,step%2 == 0 ? 0x8BD6AE : 0x3B9D88)
                            block(x+1,y+step*4+3,2,1,0xA0DDB6)
                        }
                    }
                    // Background shoal, kept quiet behind the single orange focal fish.
                    for (x,y) in [(17,48),(24,46),(31,49)] {
                        block(x,y,4,1,0x5595A6);block(x-1,y-1,1,3,0x5595A6)
                    }
                    let fish = PixelArt.image(species: FishCatalog.byID["goldfin"]!, grade:1)
                    c.draw(fish, in:CGRect(x:14,y:20,width:40,height:30))
                    // Pearl shell and rising bubbles balance the planted side.
                    block(47,10,9,3,0xA86683);block(48,13,7,2,0xDE9CAA)
                    block(50,14,3,1,0xF4C6BD);block(50,12,3,2,0xF8E8C4)
                    for (x,y) in [(49,38),(53,46)] {
                        block(x,y,2,1,0x8DCBD4);block(x-1,y+1,1,2,0x63A9BA)
                        block(x+2,y+1,1,2,0xB8E2DF);block(x,y+3,2,1,0xB8E2DF)
                    }
                    // A single flat, equal-width border on every side.
                    let rim = CGPath(roundedRect: bounds.insetBy(dx:1,dy:1),cornerWidth:13,cornerHeight:13,transform:nil)
                    c.addPath(rim)
                    c.setStrokeColor(NSColor(red:0.51,green:0.72,blue:0.76,alpha:1).cgColor)
                    c.setLineWidth(2)
                    c.strokePath()
                    let rep = NSBitmapImageRep(cgImage: c.makeImage()!)
                    try rep.representation(using:.png,properties:[:])!.write(to:target.appendingPathComponent(name))
                    entries.append(["idiom":platform == "Mac" ? "mac" : size == 1024 ? "ios-marketing" : "ipad",
                        "size":"\(String(format: "%g", size))x\(String(format: "%g", size))", "scale":"\(scale)x","filename":name])
                }
            }
            let manifest: [String: Any] = ["images":entries,"info":["author":"xcode","version":1]]
            try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys]).write(to:target.appendingPathComponent("Contents.json"))
        }
        let packager = Process()
        packager.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        packager.arguments = ["python3", "tools/build-mac-icon.py"]
        try packager.run(); packager.waitUntilExit()
        guard packager.terminationStatus == 0 else { throw CocoaError(.fileWriteUnknown) }
        print("Generated original pixel aquarium app icons.")
    }
}
