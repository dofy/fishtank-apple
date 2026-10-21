// swiftc Sources/Core/*.swift Sources/Rendering/*.swift Sources/App/PixelTheme.swift tools/verify-fullscreen-scene.swift -o /tmp/fishtank-fullscreen
import AppKit
import SpriteKit
@main struct VerifyFullscreen {
 @MainActor static func main() {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let scene = AquariumScene(), view = SKView(frame: CGRect(x:0,y:0,width:320,height:180))
  view.allowsTransparency = true
  view.presentScene(scene)
  let state = AquariumState.newGame(at: Date())
  scene.populate(with: state.tankFish); scene.syncExtras(from: state, at: Date())
  for viewport in [CGSize(width: 1024, height: 1366), CGSize(width: 1366,height:1024), CGSize(width: 600,height:900)] {
   scene.setViewportSize(viewport)
   precondition(abs(scene.size.width / scene.size.height - viewport.width / viewport.height) < 0.001)
   scene.update(0)
   let root = scene.children.first!
   let fish = root.children.compactMap { $0 as? SKSpriteNode }.filter { $0.zPosition == 5 }
   precondition(fish.count == state.tankFish.count && fish.allSatisfy { $0.size == CGSize(width:32,height:24) && $0.yScale == 1 })
   let water = root.children.prefix(45).compactMap { $0 as? SKSpriteNode }
   precondition(water.count == 45 && water.first!.position.y == 0)
   precondition(water.last!.position.y + water.last!.size.height >= scene.size.height)
   for decor in state.decorations {
    let node = scene.childNode(withName:"//" + decor.id) as! SKSpriteNode
    precondition(abs(Double(node.position.y) - AquariumFloor.decorationBase(at: Double(node.position.x), width: Double(node.size.width))) < 0.001)
   }
   let foodCount = root.children.filter { $0.zPosition == 6 }.count
   precondition(scene.tapWater(at: fish.first!.position))
   precondition(root.children.filter { $0.zPosition == 6 }.count == foodCount)
   precondition(!scene.tapWater(at: CGPoint(x:10,y:scene.size.height-20)))
   precondition(root.children.filter { $0.zPosition == 6 }.count == foodCount + 1)
   precondition(view.texture(from:scene) != nil)
  }
  scene.setViewportSize(nil)
  precondition(scene.size == CGSize(width:320,height:180))
  print("PASS: portrait, landscape and split viewport fill, square fish proportions, grounded decor, intact rendering and default-size restoration.")
 }
}
