import AppKit
import CoreText

@main struct IconOverview {
    static func main() throws {
        let columns = 6, cell = 240, rows = (AppIconCatalog.all.count + 5) / 6
        let width = columns * cell, height = rows * 244 + 20
        let c = CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,
                          space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.setFillColor(NSColor(calibratedRed:20/255,green:47/255,blue:64/255,alpha:1).cgColor)
        c.fill(CGRect(x:0,y:0,width:width,height:height))
        NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:c,flipped:false)
        CTFontManagerRegisterFontsForURL(URL(fileURLWithPath:"Sources/Resources/Fonts/FusionPixel.otf") as CFURL,.process,nil)
        let font=NSFont(name:"FusionPixel-12px-monospaced-zh_hans",size:16) ?? NSFont.systemFont(ofSize:16)
        for (i,design) in AppIconCatalog.all.enumerated() {
            let x=24+(i%columns)*cell, y=height-212-(i/columns)*244
            let path=design.id == "classic" ? "Sources/Resources/FishtankIcon.icns" : "Sources/Resources/AppIcons/\(design.resourceName).png"
            let image=NSImage(contentsOfFile:path)!
            NSGraphicsContext.current!.imageInterpolation = .none
            image.draw(in:NSRect(x:x,y:y,width:192,height:192))
            let name=AppIconCatalog.label(design) as NSString
            let attributes:[NSAttributedString.Key:Any]=[.font:font,.foregroundColor:NSColor(calibratedRed:241/255,green:238/255,blue:212/255,alpha:1)]
            let textWidth=name.size(withAttributes:attributes).width
            name.draw(at:NSPoint(x:CGFloat(x)+96-textWidth/2,y:CGFloat(y)-30),withAttributes:attributes)
        }
        NSGraphicsContext.restoreGraphicsState()
        let output=URL(fileURLWithPath:"docs/design/app-icons-all-species.png")
        try FileManager.default.createDirectory(at:output.deletingLastPathComponent(),withIntermediateDirectories:true)
        try NSBitmapImageRep(cgImage:c.makeImage()!).representation(using:.png,properties:[:])!.write(to:output)
        print(output.path)
    }
}
