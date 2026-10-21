// swiftc Sources/Core/*.swift Sources/Rendering/*.swift Sources/App/PixelTheme.swift tools/verify-electric-scene.swift -o /tmp/fishtank-electric
import AppKit
import SpriteKit
@main struct VerifyElectric {
 @MainActor static func main() throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let scene = AquariumScene(), view = SKView(frame: CGRect(x:0,y:0,width:960,height:540))
  view.presentScene(scene)
  let now = Date()
  let fish = ["volteel", "goldfin", "copperband"].map { AquariumFish.make(species: FishCatalog.byID[$0]!, at: now, adult: true) }
  scene.populate(with: fish)
  let root = scene.children.first!
  func sprites() -> [SKSpriteNode] { root.children.compactMap { $0 as? SKSpriteNode }.filter { $0.zPosition == 5 } }
  let eel = sprites().first { $0.position.x == 45 }!
  let other = sprites().first { $0.position.x == 98 }!
  for _ in 0..<6 { precondition(scene.tapFish(at: eel.position)) }
  let effects = root.children.first { $0.zPosition == 8 }!
  precondition(effects.children.count == 3, "source and every victim need electric arcs")
  precondition(eel.colorBlendFactor == 0 && eel.zRotation == 0, "source must not look stunned")
  precondition(other.colorBlendFactor > 0, "victim must visibly react")
  let start = eel.position.x
  scene.update(0); scene.update(0.1)
  precondition(eel.position.x != start, "source must continue swimming")
  if let texture = view.texture(from: scene), let cg = texture.cgImage() as CGImage? {
   let rep = NSBitmapImageRep(cgImage: cg)
   try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "build/validation/electric-scene.png"))
  }
  for i in 2...11 { scene.update(Double(i) * 0.1) }
  precondition(effects.children.count == 2, "victim arcs must persist after source discharge ends")
  scene.reducedMotion = true; scene.update(1.2)
  precondition(effects.children.count == 2 && other.zRotation == 0)
  for i in 13...45 { scene.update(Double(i) * 0.1) }
  precondition(effects.children.isEmpty && other.colorBlendFactor == 0 && other.zRotation == 0)
  print("PASS: source swims without stun, victims have visible persistent arcs, reduced motion is static, effects recover cleanly.")
 }
}
