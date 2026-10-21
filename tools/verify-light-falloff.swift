// swiftc Sources/Core/*.swift Sources/Rendering/PixelArt.swift tools/verify-light-falloff.swift -o /tmp/fishtank-light-falloff
import Foundation
@main struct VerifyLightFalloff {
    static func main() {
        let image = PixelArt.lampGlowImage()
        let pixels = [UInt8](image.dataProvider!.data! as Data)
        func alpha(_ x: Int, _ y: Int) -> Int { Int(pixels[y * image.bytesPerRow + x * 4 + 3]) }
        precondition(image.width == 96 && image.height == 144)
        var levels = Set<Int>(), largestStep = 0
        for y in 0..<image.height {
            precondition(alpha(0,y) == 0 && alpha(95,y) == 0)
            for x in 0..<image.width {
                let value = alpha(x,y)
                precondition(value <= 41 && value == alpha(95-x,y))
                precondition(value == alpha(x/2*2,y/2*2))
                levels.insert(value)
                if x < 47 { precondition(value <= alpha(x+1,y)) }
                if x > 48 { precondition(value <= alpha(x-1,y)) }
                if x > 0 { largestStep = max(largestStep,abs(value-alpha(x-1,y))) }
            }
            if y > 0 { precondition(alpha(47,y) <= alpha(47,y-1)) }
        }
        precondition(levels.count >= 25 && largestStep <= 16 && alpha(47,143) == 0)
        print("PASS feathered pixel light: \(levels.count) alpha levels, max horizontal step \(largestStep)/255, transparent edges and floor, symmetric falloff, intact 2x2 pixel cells.")
    }
}
