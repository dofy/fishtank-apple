import AppKit
import CoreText

@main
struct ArtPreview {
    static func main() throws {
        let width = 960, height = 780
        let rep = NSBitmapImageRep(bitmapDataPlanes:nil, pixelsWide:width, pixelsHigh:height, bitsPerSample:8,
                                   samplesPerPixel:4, hasAlpha:true, isPlanar:false, colorSpaceName:.deviceRGB, bytesPerRow:0, bitsPerPixel:0)!
        let graphics = NSGraphicsContext(bitmapImageRep:rep)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current=graphics
        let c=graphics.cgContext
        c.setFillColor(NSColor(red:0.055,green:0.12,blue:0.2,alpha:1).cgColor);c.fill(CGRect(x:0,y:0,width:width,height:height))
        let url=URL(fileURLWithPath:"Sources/Resources/Fonts/FusionPixel.otf")
        CTFontManagerRegisterFontsForURL(url as CFURL,.process,nil)
        let font=NSFont(name:"Fusion-Pixel-12px-Mono-zh-Hans-Regular",size:12)!
        let gold=NSColor(red:0.94,green:0.78,blue:0.43,alpha:1)
        func text(_ value:String,_ x:CGFloat,_ y:CGFloat,_ title:Bool=false) {
            let attr:[NSAttributedString.Key:Any]=[.font:title ? NSFont(name:font.fontName,size:24)! : font,.foregroundColor:gold]
            (value as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:attr)
        }
        text("像素海底造景 / 18 件",24,740,true)
        for (i,item) in DecorCatalog.all.enumerated() {
            let x=CGFloat(i%6*156+14),y=CGFloat(592-i/6*136)
            c.setFillColor(NSColor(red:0.13,green:0.29,blue:0.39,alpha:1).cgColor);c.fill(CGRect(x:x,y:y,width:146,height:126))
            let image=DecorArt.image(item),scale=min(100/CGFloat(image.width),80/CGFloat(image.height))
            let w=CGFloat(image.width)*floor(max(1,scale)),h=CGFloat(image.height)*floor(max(1,scale))
            c.interpolationQuality = .none
            c.draw(image,in:CGRect(x:x+(146-w)/2,y:y+32,width:w,height:h))
            text(item.name,x+8,y+11)
            text("Lv.\(item.unlockLevel)",x+102,y+108)
        }
        text("永久收藏勋章 / 14 枚",24,288,true)
        for (i,item) in AchievementCatalog.all.enumerated() {
            let x=CGFloat(i%7*134+14),y=CGFloat(151-i/7*136)
            c.setFillColor(NSColor(red:0.13,green:0.29,blue:0.39,alpha:1).cgColor);c.fill(CGRect(x:x,y:y,width:124,height:126))
            c.interpolationQuality = .none;c.draw(DecorArt.medal(item.id),in:CGRect(x:x+38,y:y+40,width:48,height:64))
            text(item.title,x+8,y+13)
        }
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"docs/previews/pixel-assets.png"))
        print("Rendered all 18 decorations and 14 medals.")
    }
}
