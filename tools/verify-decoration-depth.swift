// Standalone SpriteKit regression with synthetic state; no window or save access.
// swiftc Sources/Core/*.swift Sources/Rendering/{PixelArt,DecorArt,AquariumScene}.swift Sources/App/{PixelTheme,AppLocalization}.swift tools/verify-decoration-depth.swift -o <binary>
import AppKit
import SpriteKit

@main struct DecorationDepthVerification {
    @MainActor static func main() {
        func field<T>(_ scene: AquariumScene, _ name: String, _: T.Type) -> T {
            Mirror(reflecting: scene).children.first { $0.label == name }!.value as! T
        }
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let view = SKView(frame: NSRect(x: 0, y: 0, width: 320, height: 180))
        for order in [["arch", "kelp", "rocks"], ["kelp", "arch", "rocks"], ["kelp", "rocks", "arch"]] {
            let scene = AquariumScene(); scene.didMove(to: view)
            var state = AquariumState.newGame(at: date)
            state.fish = (1...4).map { index in
                var fish = AquariumFish.make(species: FishCatalog.byID["goldfin"]!, at: date, adult: true)
                fish.id = UUID(uuidString: String(format: "34567890-1234-4321-ABCD-%012d", index))!
                return fish
            }
            state.tankIDs = state.fish.map(\.id)
            state.decorations = order.map { .init(id: $0, x: 0.5) }
            scene.populate(with: state.fish); scene.syncExtras(from: state, at: date)
            let root = field(scene, "decorRoot", SKNode.self)
            let depths = Dictionary(uniqueKeysWithValues: order.map { ($0, root.childNode(withName: $0)!.zPosition) })
            func verifyOrder() {
                for id in order { precondition(root.childNode(withName: id)!.zPosition == depths[id], "Decoration reordered: \(id)") }
            }
            var passing = Set<UUID>(), returned = false, mixed = false
            for tick in 0..<6000 {
                scene.update(Double(tick) * 0.1)
                verifyOrder()
                let ecology = field(scene, "ecology", AquariumEcology.self)
                let nodes = field(scene, "fishNodes", [UUID: SKSpriteNode].self)
                let archDepth = root.zPosition + depths["arch"]!
                let visitors = ecology.swimmers.values.filter { $0.visit == "arch" }
                mixed = mixed || (!visitors.isEmpty && visitors.count < nodes.count)
                for (id, swimmer) in ecology.swimmers {
                    if swimmer.visit == "arch" {
                        passing.insert(id)
                        precondition(nodes[id]!.zPosition < archDepth, "Visitor must pass behind arch")
                        precondition(nodes[id]!.zPosition > archDepth - 0.01, "Visitor must stay above lower decorations")
                    } else {
                        precondition(nodes[id]!.zPosition == 5, "Unrelated swimmer moved layers")
                        returned = returned || passing.contains(id)
                    }
                }
            }
            precondition(!passing.isEmpty && returned && mixed, "Missing visit, exit or simultaneous non-visitor coverage")
            // Isolate each decoration for a drag, then put all overlapping props back.
            for id in order {
                state.decorations = [.init(id: id, x: 0.5)]
                scene.syncExtras(from: state, at: date)
                let node = root.childNode(withName: id)!
                let depth = node.zPosition
                let point = scene.convert(CGPoint(x: 0, y: 8), from: node)
                precondition(scene.beginDecorationDrag(at: point), "Could not start drag")
                precondition(node.zPosition == depth, "Drag raised decoration")
                scene.dragDecoration(to: CGPoint(x: 170, y: 40))
                precondition(node.zPosition == depth)
                scene.endDecorationDrag(); precondition(node.zPosition == depth)
            }
            state.decorations = order.map { .init(id: $0, x: 0.5) }
            scene.syncExtras(from: state, at: date); verifyOrder()
            print("PASS stable overlapping decoration order, per-fish arch occlusion and dragging:", order.joined(separator: ", "))
        }
    }
}
