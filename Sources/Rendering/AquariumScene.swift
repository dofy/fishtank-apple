import SpriteKit
import SwiftUI

final class AquariumScene: SKScene {
    private var fishNodes: [UUID: SKSpriteNode] = [:]
    private var foodNodes: [Int: SKSpriteNode] = [:]
    private var ecology = AquariumEcology()
    private var currentFish: [AquariumFish] = []
    private var currentDecor: [PlacedDecoration] = []
    private(set) var lastFrameUptime: TimeInterval?
    private var previousTime: TimeInterval?
    private var lastShakeUptime: TimeInterval = -.infinity
    private var railLights = AquariumRailLights()
    private var railNodes: [SKSpriteNode] = []
    private var lampNodes: [(node: SKSpriteNode, lamp: Int)] = []
    private var backdropNodes: [SKSpriteNode] = []
    private var backdropTime = 0.0
    private let lampRoot = SKNode()
    private let electricRoot = SKNode()
    private var bubbles: [SKSpriteNode] = []
    var reducedMotion = false
    var effect: ((String) -> Void)?
    private let tankRoot = SKCropNode()
    private let glassRoot = SKNode()
    private let agentSignalRoot = SKNode()
    private var lastAgentSignal: [ClaudeHookEvent.Source: TimeInterval] = [:]
    private var lastExtras: (AquariumState, Date)?
    private var installed = false
    private var waterOpacity: CGFloat = 1
    private var waterBands: [SKSpriteNode] = []
    private var fishSignature = ""
    private var extrasSignature = ""
    private let decorRoot = SKNode()
    private let medalRoot = SKNode()
    private var draggedID: String?
    private var night = false
    var decorationMoved: ((String, Double) -> Void)?

    override init() {
        super.init(size: CGSize(width: 320, height: 180))
        scaleMode = .aspectFit
        backgroundColor = .clear
        addChild(tankRoot)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }

    override func didMove(to view: SKView) {
        guard !installed else { return }
        installed = true
        agentSignalRoot.zPosition = 48
        tankRoot.addChild(agentSignalRoot)
        let mask = SKShapeNode(path: PixelOutline(cut: 8, steps: 4).path(in: CGRect(x: 0, y: 0, width: 320, height: 180)).cgPath)
        mask.fillColor = .white; mask.strokeColor = .clear; mask.isAntialiased = false
        tankRoot.maskNode = mask
        for band in 0..<45 {
            let water = block(x: 2, y: CGFloat(band * 4), width: 316, height: 4,
                              color: waterColor(band: band))
            water.alpha = waterOpacity; waterBands.append(water)
        }
        // Layered, opaque pixel glass; only the water uses the opacity preference.
        let rim = glassRoot; rim.zPosition = 50; tankRoot.addChild(rim)
        drawGlass()
        func sandHeight(_ x: Int) -> Int { Int(AquariumFloor.height(at: Double(x))) }
        for x in stride(from: 2, to: 318, by: 4) {
            let height = sandHeight(x)
            block(x: CGFloat(x), y: 2, width: 4, height: CGFloat(height - 2), color: color(0xAE9167))
            block(x: CGFloat(x), y: CGFloat(max(4, height - 6)), width: 4, height: 4, color: color(0xCFB17C))
            block(x: CGFloat(x), y: CGFloat(height - 2), width: 4, height: 2, color: color(0xE8CE98))
        }
        for i in 0..<100 {
            let x = 4 + (i * 37) % 310
            block(x: CGFloat(x), y: CGFloat(4 + (i * 7) % max(1, sandHeight(x) - 7)), width: 2, height: 1,
                  color: color(i % 2 == 0 ? 0x977F58 : 0xEFDBA8))
        }
        for i in 0..<22 {
            let x = 9 + (i * 43) % 300
            let y = sandHeight(x) - 3 - (i % 3)
            block(x: CGFloat(x), y: CGFloat(y), width: CGFloat(i % 3 + 2), height: 2,
                  color: color(i % 2 == 0 ? 0x8C9C92 : 0xA18972))
            block(x: CGFloat(x), y: CGFloat(y + 1), width: 1, height: 1, color: color(0xE3D9AD))
        }
        decorRoot.zPosition = 2; medalRoot.zPosition = 12
        tankRoot.addChild(decorRoot); tankRoot.addChild(medalRoot)
        for pose in AquariumBackdrop.fish(at: 0) {
            let node = SKSpriteNode(texture: PixelArt.backgroundFish(round: pose.round, frame: 0))
            node.size = CGSize(width: pose.round ? 8 : 7, height: pose.round ? 5 : 4)
            node.zPosition = 1; tankRoot.addChild(node); backdropNodes.append(node)
        }
        renderBackdrop()
        lampRoot.zPosition = 3; tankRoot.addChild(lampRoot)
        electricRoot.zPosition = 8; tankRoot.addChild(electricRoot)
        for lamp in 0..<3 {
            let x = CGFloat(65 + lamp * 95)
            let housing = SKSpriteNode(color: color(0x173449), size: CGSize(width: 14, height: 5))
            housing.position = CGPoint(x: x, y: 171); housing.zPosition = 1
            lampRoot.addChild(housing)
            let beam = SKSpriteNode(texture: PixelArt.lampGlowTexture())
            beam.size = CGSize(width: 96, height: 144); beam.position = CGPoint(x: x, y: 95)
            beam.colorBlendFactor = 1
            lampRoot.addChild(beam); lampNodes.append((beam, lamp))
            let lens = SKSpriteNode(color: color(0xE9D88C), size: CGSize(width: 10, height: 3))
            lens.position = CGPoint(x: x, y: 168); lens.zPosition = 2
            lampRoot.addChild(lens); lampNodes.append((lens, lamp))
            let glint = SKSpriteNode(color: color(0xFFFBE8), size: CGSize(width: 4, height: 1))
            glint.position = CGPoint(x: x - 1, y: 169); glint.zPosition = 3
            lampRoot.addChild(glint)
        }
        lampRoot.isHidden = !night
        for index in 0..<9 {
            let bubble = SKSpriteNode(color: color(0x9ED3D4), size: CGSize(width: 1, height: 2))
            bubble.position = CGPoint(x: 17 + index * 31, y: 25 + (index * 19) % 140)
            bubble.alpha = 0.4; tankRoot.addChild(bubble); bubbles.append(bubble)
            bubble.run(.repeatForever(.sequence([.moveBy(x: 0, y: 160, duration: Double(16 + index)), .moveBy(x: 0, y: -160, duration: 0)])))
        }
        #if os(macOS)
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String, !version.isEmpty {
            let label = SKLabelNode(fontNamed: PixelTheme.fontName)
            label.name = "appVersion"; label.text = "v" + version
            label.fontSize = 12; label.fontColor = color(0xFFFFFF)
            label.horizontalAlignmentMode = .left; label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 11, y: AquariumFloor.height(at: 24) / 2 + 2); label.zPosition = 81
            tankRoot.addChild(label)
        }
        #endif
        layoutViewport()
    }

    func refreshLocalizedFont() {
        enumerateChildNodes(withName: "//appVersion") { node, _ in
            (node as? SKLabelNode)?.fontName = PixelTheme.fontName
        }
    }

    /// Keep square pixels and sprite proportions: extend the water and swimming
    /// space to the viewport instead of stretching or cropping the 16:9 scene.
    func setViewportSize(_ viewport: CGSize?) {
        let height: CGFloat
        if let viewport, viewport.width > 0, viewport.height > 0 {
            height = max(80, 320 * viewport.height / viewport.width)
        } else { height = 180 }
        guard abs(size.height - height) > 0.01 else { return }
        size = CGSize(width: 320, height: height)
        ecology.resize(height: Double(height))
        guard installed else { return }
        layoutViewport()
        if let (state, date) = lastExtras {
            extrasSignature = ""
            syncExtras(from: state, at: date)
        }
        renderSwimmers()
        renderBackdrop()
    }

    private func drawGlass() {
        let rim = glassRoot
        rim.removeAllChildren()
        for (inset, stroke, hex) in [(CGFloat(1), CGFloat(4), 0x173449), (CGFloat(3), CGFloat(2), 0x7FAEBA)] {
            let path = PixelOutline(cut: 8, steps: 4).path(in: CGRect(x: 0, y: 0, width: 320 - inset * 2, height: size.height - inset * 2)).cgPath
            var shift = CGAffineTransform(translationX: inset, y: inset)
            let glass = SKShapeNode(path: path.copy(using: &shift)!)
            glass.fillColor = .clear; glass.strokeColor = color(hex); glass.lineWidth = stroke; glass.isAntialiased = false
            rim.addChild(glass)
        }
        for (x, y, w, h, hex) in [(8,Int(size.height)-6,304,3,0xC4DFDF), (8,3,304,3,0x36576A), (6,45,1,100,0xABCED3), (313,28,1,118,0x527E92)] {
            let shine = SKSpriteNode(color: color(hex), size: CGSize(width: w, height: h))
            shine.anchorPoint = .zero; shine.position = CGPoint(x: x, y: y); rim.addChild(shine)
        }
        // Small joins and interrupted reflections give the glass a physical edge.
        for x in [10, 308] {
            for y in [8, Int(size.height) - 10] {
                let joint = SKSpriteNode(color: color(0x375B67), size: CGSize(width: 3, height: 3))
                joint.position = CGPoint(x: x, y: y); rim.addChild(joint)
                let glint = SKSpriteNode(color: color(0xD8E8D8), size: CGSize(width: 1, height: 1))
                glint.position = CGPoint(x: x - 1, y: y + 1); rim.addChild(glint)
            }
        }
        for (x, y, height) in [(9, 124, 19), (11, 145, 9), (309, 47, 17)] {
            let reflection = SKSpriteNode(color: color(0xD3E3D6), size: CGSize(width: 1, height: height))
            reflection.position = CGPoint(x: x, y: y); reflection.alpha = 0.2; rim.addChild(reflection)
        }
    }

    private func layoutViewport() {
        let mask = tankRoot.maskNode as? SKShapeNode
        mask?.path = PixelOutline(cut: 8, steps: 4).path(in: CGRect(origin: .zero, size: size)).cgPath
        for (index, band) in waterBands.enumerated() {
            band.position.y = CGFloat(index) * size.height / 45
            band.size.height = size.height / 45 + 0.01
        }
        drawGlass()
        for (index, node) in lampRoot.children.enumerated() {
            switch index % 4 {
            case 0: node.position.y = size.height - 9
            case 1:
                node.position.y = size.height / 2 + 5
                (node as? SKSpriteNode)?.size.height = size.height - 36
            case 2: node.position.y = size.height - 12
            default: node.position.y = size.height - 11
            }
        }
        for (index, bubble) in bubbles.enumerated() {
            bubble.removeAllActions()
            bubble.position.y = 25 + CGFloat(index) / 9 * (size.height - 40)
            let travel = size.height - 20
            bubble.run(.repeatForever(.sequence([.moveBy(x: 0, y: travel, duration: Double(16 + index)), .moveBy(x: 0, y: -travel, duration: 0)])))
        }
    }

    func populate(with fish: [AquariumFish]) {
        currentFish = fish
        ecology.reducedMotion = reducedMotion
        ecology.sync(fish, decorations: currentDecor)
        renderSwimmers()
    }

    func resetFrameClock() { previousTime = nil }

    override func update(_ currentTime: TimeInterval) {
        lastFrameUptime = ProcessInfo.processInfo.systemUptime
        let dt = previousTime.map { currentTime - $0 } ?? 1.0 / 30
        previousTime = currentTime
        ecology.night = night; ecology.reducedMotion = reducedMotion
        ecology.update(dt)
        if !reducedMotion { backdropTime += min(0.1, max(0, dt)) }
        renderBackdrop()
        renderSwimmers()
        bubbles.forEach { $0.speed = reducedMotion ? 0 : 1 }
        for event in Set(ecology.events) { effect?(event) }
        for (index, node) in railNodes.enumerated() {
            node.alpha = railLights.brightness(time: ecology.time, index: index, reducedMotion: reducedMotion)
        }
        let palette = [0xFECDD3, 0xFEF08A, 0xFED7AA, 0xA7F3D0, 0xBAE6FD, 0xC7D2FE, 0xE9D5FF]
        for light in lampNodes { light.node.color = color(palette[ecology.lampColors[light.lamp]]) }
    }

    private func renderSwimmers() {
        electricRoot.removeAllChildren()
        for a in ecology.swimmers.values where a.discharging > 0 || a.shocked > 0 {
            // Stepped electric bolts remain legible in both the desktop tank and iPad.
            // Reduced motion uses a quiet, static pair rather than flickering arcs.
            let source = a.discharging > 0
            let arcs = SKNode()
            arcs.name = "electric-" + a.fish.id.uuidString
            arcs.position = CGPoint(x: a.x.rounded(), y: a.y.rounded())
            let phase = reducedMotion ? 0 : Int(ecology.time * 10) % 3
            let count = reducedMotion ? 2 : source ? 6 : 3
            for index in 0..<count {
                let angle = Double(index) * 2 * .pi / Double(count) + Double(phase) * 0.22
                let radius = source ? 20.0 : 16.0
                let origin = CGPoint(x: (cos(angle) * radius).rounded(), y: (sin(angle) * radius * 0.65).rounded())
                let points = [CGPoint(x: 0, y: -6), CGPoint(x: 4, y: -2),
                              CGPoint(x: 0, y: 1), CGPoint(x: 4, y: 6)]
                for pair in zip(points, points.dropFirst()) {
                    let steps = Int(max(abs(pair.1.x - pair.0.x), abs(pair.1.y - pair.0.y)))
                    for step in 0...steps {
                        let t = CGFloat(step) / CGFloat(steps)
                        let x = origin.x + (pair.0.x + (pair.1.x - pair.0.x) * t).rounded()
                        let y = origin.y + (pair.0.y + (pair.1.y - pair.0.y) * t).rounded()
                        let halo = SKSpriteNode(color: color(0x529FCE), size: CGSize(width: 3, height: 3))
                        halo.position = CGPoint(x: x, y: y); halo.alpha = 0.55
                        arcs.addChild(halo)
                        let core = SKSpriteNode(color: color(source ? 0xFFF2A6 : 0xD8FAFF), size: CGSize(width: 1, height: 1))
                        core.position = halo.position; core.zPosition = 1
                        arcs.addChild(core)
                    }
                }
            }
            electricRoot.addChild(arcs)
        }
        for id in Array(fishNodes.keys) where ecology.swimmers[id] == nil {
            fishNodes.removeValue(forKey: id)?.removeFromParent()
        }
        for (id, a) in ecology.swimmers {
            let node: SKSpriteNode
            if let existing = fishNodes[id] { node = existing }
            else {
                node = SKSpriteNode(texture: PixelArt.texture(fish: a.fish))
                node.size = CGSize(width: 32, height: 24)
                fishNodes[id] = node; tankRoot.addChild(node)
            }
            // Move only this swimmer behind the arch. Decorations retain their saved
            // relative order, including while dragging and while other fish pass.
            if a.visit == "arch", a.withdrawal == nil, draggedID != "arch",
               let arch = decorRoot.childNode(withName: "arch") {
                node.zPosition = decorRoot.zPosition + arch.zPosition - 0.005
            } else {
                node.zPosition = 5
            }
            node.position = CGPoint(x: a.x.rounded(), y: a.y.rounded())
            let frame = reducedMotion || a.shocked > 0 ? 0 : PixelArt.animationFrame(for: a.fish.species, time: a.motionTime)
            node.texture = PixelArt.texture(fish: a.fish, frame: frame, puffLevel: Int((a.puffAmount * 3).rounded()))
            let facing = a.fish.species.swimProfile.family == .jellyfish ? 1 : a.facing
            node.xScale = facing * a.individuality.size
            node.yScale = a.individuality.size * (a.resting > 0 && !reducedMotion ? 1 + sin(a.age * 1.7) * 0.012 : 1)
            node.alpha = a.alpha
            node.color = color(0xD8FAFF)
            node.colorBlendFactor = a.shocked > 0 ? (reducedMotion ? 0.3 : 0.35 + 0.3 * abs(sin(ecology.time * 16))) : 0
            node.zRotation = reducedMotion ? 0 : a.shocked > 0 ? sin(ecology.time * 25) * 0.12 : a.pitch * (facing >= 0 ? 1 : -1)
        }
        let active = Set(ecology.foods.map(\.id))
        for id in Array(foodNodes.keys) where !active.contains(id) { foodNodes.removeValue(forKey: id)?.removeFromParent() }
        for food in ecology.foods {
            let node = foodNodes[food.id] ?? SKSpriteNode(color: color(food.plankton ? 0xA4DFA8 : 0xE8B574), size: CGSize(width: 2, height: 2))
            if node.parent == nil { node.zPosition = 6; tankRoot.addChild(node); foodNodes[food.id] = node }
            node.position = CGPoint(x: food.x.rounded(), y: food.y.rounded())
        }
    }

    private func renderBackdrop() {
        for (node, pose) in zip(backdropNodes, AquariumBackdrop.fish(at: backdropTime)) {
            node.position = CGPoint(x: pose.x.rounded(), y: 30 + (pose.y - 30) * (Double(size.height) - 60) / 120)
            node.xScale = pose.heading
            node.alpha = night ? 0.26 : 0.36
            node.texture = PixelArt.backgroundFish(round: pose.round, frame: pose.frame)
        }
    }

    @discardableResult
    func tapFish(at point: CGPoint) -> Bool {
        let hit = ecology.swimmers.values.filter { $0.withdrawal == nil && !$0.dropping
            && abs($0.x - point.x) < 16 && abs($0.y - point.y) < 12 }
            .min { hypot($0.x - point.x, $0.y - point.y) < hypot($1.x - point.x, $1.y - point.y) }
        guard let hit, let sound = ecology.tap(hit.fish.id, x: point.x) else { return false }
        effect?(sound); renderSwimmers(); return true
    }

    @discardableResult
    func tapWater(at point: CGPoint) -> Bool {
        if tapFish(at: point) { return true }
        ecology.feed(x: point.x, y: point.y, count: 1); effect?("feed"); renderSwimmers()
        return false
    }

    func syncExtras(from state: AquariumState, at date: Date) {
        lastExtras = (state, date)
        ecology.discardMissingFish(in: Set(state.fish.map(\.id)))
        renderSwimmers()
        railLights = state.railLights
        currentDecor = state.decorations
        ecology.sync(currentFish, decorations: currentDecor)
        let nextNight = state.lighting.isNight(at: date)
        let signature = state.decorations.map { "\($0.id):\($0.x):\($0.flip)" }.joined(separator: ",")
            + state.displayedAchievements.joined(separator: ",") + "\(nextNight)"
        guard signature != extrasSignature else { return }
        extrasSignature = signature; night = nextNight; lampRoot.isHidden = !night
        for (index, water) in waterBands.enumerated() { water.color = waterColor(band: index) }
        decorRoot.removeAllChildren(); medalRoot.removeAllChildren(); railNodes = []
        for (index, placed) in state.decorations.enumerated() {
            guard let item = DecorCatalog.byID[placed.id] else { continue }
            let texture = SKTexture(cgImage: DecorArt.image(item)); texture.filteringMode = .nearest
            let node = SKSpriteNode(texture: texture)
            node.name = placed.id
            node.size = CGSize(width: max(18, item.width * 0.48), height: max(12, item.height * 0.4))
            if placed.id == "fairylights" { node.size = CGSize(width: 64, height: 32) }
            node.anchorPoint = CGPoint(x: 0.5, y: item.top ? 1 : 0)
            node.position = CGPoint(x: placed.x * 320, y: item.top ? Double(size.height - 6) : AquariumFloor.decorationBase(at: placed.x * 320, width: Double(node.size.width)))
            node.xScale = CGFloat(placed.flip)
            node.zPosition = CGFloat(index) * 0.01
            decorRoot.addChild(node)
            if placed.id == "fairylights" {
                let palette = [0xEFAD85,0xE5C977,0x9EC8A4,0x89C8CC,0x97B9DC,0xB3A2D0,0xDDA3B3]
                for bead in 0..<7 {
                    let x = 6 + bead * 8
                    let y = 4 + Int((7 * sin(Double(x) / 63 * .pi)).rounded())
                    let light = SKSpriteNode(color: color(palette[bead]), size: CGSize(width: 3, height: 4))
                    light.position = CGPoint(x: x - 32, y: -y - 7)
                    light.zPosition = 1; node.addChild(light); railNodes.append(light)
                    let shine = SKSpriteNode(color: color(0xFFF0CD), size: CGSize(width: 1, height: 1))
                    shine.position = CGPoint(x: -0.5, y: 1); shine.alpha = 0.8; light.addChild(shine)
                }
            }
            if item.top && night && placed.id != "fairylights" {
                // Deliberate pixel light beams instead of blur/glow filters.
                for step in 0..<8 {
                    let beam = SKSpriteNode(color: color(0xE9D88C), size: CGSize(width: 8 + step * 4, height: 3))
                    beam.position = CGPoint(x: CGFloat(placed.x * 320), y: size.height - CGFloat(25 + step * 7))
                    beam.alpha = CGFloat(8 - step) * 0.008
                    beam.zPosition = -1; decorRoot.addChild(beam)
                }
            }
        }
        for (index, id) in state.displayedAchievements.enumerated() {
            let texture = SKTexture(cgImage: DecorArt.medal(id)); texture.filteringMode = .nearest
            let node = SKSpriteNode(texture: texture)
            node.size = CGSize(width: 12, height: 16)
            node.anchorPoint = CGPoint(x: 0.5, y: 1)
            node.position = CGPoint(x: CGFloat(12 + index * 16), y: size.height - 5)
            medalRoot.addChild(node)
        }
    }

    @discardableResult
    func beginDecorationDrag(at point: CGPoint) -> Bool {
        guard draggedID == nil else { return true }
        let local = decorRoot.convert(point, from: self)
        if let node = decorRoot.nodes(at: local).compactMap({ $0 as? SKSpriteNode }).filter({ $0.name != nil }).max(by: { $0.zPosition < $1.zPosition }) {
            draggedID = node.name
            ecology.setActiveDecoration(node.name)
            return true
        }
        return false
    }
    func dragDecoration(to point: CGPoint) {
        guard let id = draggedID, let node = decorRoot.childNode(withName: id) as? SKSpriteNode else { return }
        node.position.x = max(19.2, min(300.8, point.x))
        if DecorCatalog.byID[id]?.top == false {
            node.position.y = CGFloat(AquariumFloor.decorationBase(at: Double(node.position.x), width: Double(node.size.width)))
        }
    }
    func endDecorationDrag() {
        guard let id = draggedID, let node = decorRoot.childNode(withName: id) else { return }
        draggedID = nil
        ecology.setActiveDecoration(nil)
        decorationMoved?(id, Double(node.position.x / 320))
    }

    func containsTankPoint(_ point: CGPoint) -> Bool {
        (tankRoot.maskNode as? SKShapeNode)?.path?.contains(point) ?? CGRect(origin: .zero, size: size).contains(point)
    }

    func feed(reducedMotion: Bool, x: Double = 160) {
        self.reducedMotion = reducedMotion
        ecology.feed(x: x)
        renderSwimmers()
    }
    func shake() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastShakeUptime >= 0.18 else { return }
        lastShakeUptime = now
        ecology.reducedMotion = reducedMotion
        ecology.shake()
        effect?("scare")
        tankRoot.removeAction(forKey: "tankShake")
        tankRoot.position = .zero
        guard !reducedMotion else { return }
        let duration = 0.48
        let motion = SKAction.customAction(withDuration: duration) { node, elapsed in
            let progress = min(1, Double(elapsed) / duration)
            let amplitude = 1 - progress
            node.position = CGPoint(x: sin(progress * .pi * 10) * 3 * amplitude,
                                    y: sin(progress * .pi * 6) * amplitude)
        }
        tankRoot.run(.sequence([motion, .run { [weak self] in self?.tankRoot.position = .zero }]), withKey: "tankShake")
    }

    /// Local status feedback only: no food, fish inventory, lighting preference or gameplay RNG changes.
    func showAgentSignal(_ event: ClaudeHookEvent) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - (lastAgentSignal[event.agent] ?? -.infinity) >= 0.5 else { return }
        lastAgentSignal[event.agent] = now
        while agentSignalRoot.children.count >= 3 { agentSignalRoot.children.first?.removeFromParent() }
        let signal = SKNode(); agentSignalRoot.addChild(signal)
        let statusColor = color(event.status?.colorHex ?? event.agentColorHex)
        let brandColor = color(event.agentColorHex)
        if reducedMotion {
            let marker = SKSpriteNode(color: statusColor, size: CGSize(width: 5, height: 3))
            marker.position = CGPoint(x: event.agent == .codex ? 148 : 172, y: size.height - 5)
            signal.addChild(marker)
        } else {
            for index in 0..<(event.status == .responded ? 5 : 3) {
                let bubble = SKShapeNode(rectOf: CGSize(width: 3, height: 3))
                bubble.strokeColor = brandColor; bubble.fillColor = .clear; bubble.lineWidth = 1
                bubble.isAntialiased = false
                bubble.position = CGPoint(x: 144 + index * 8, y: Int(size.height) - 28 - (index % 2) * 6)
                signal.addChild(bubble)
                bubble.run(.sequence([.wait(forDuration: Double(index) * 0.08),
                    .group([.moveBy(x: CGFloat(index % 2 == 0 ? -3 : 3), y: 23, duration: 1.1), .fadeOut(withDuration: 1.1)])]))
            }
            if event.status?.needsAttention == true {
                let reflection = SKSpriteNode(color: statusColor, size: CGSize(width: 110, height: 2))
                reflection.position = CGPoint(x: 160, y: size.height - 4); reflection.alpha = 0.25
                signal.addChild(reflection)
                reflection.run(.repeat(.sequence([.fadeAlpha(to: 0.55, duration: 0.25), .fadeAlpha(to: 0.15, duration: 0.35)]), count: 2))
            }
        }
        signal.run(.sequence([.wait(forDuration: reducedMotion ? 0.8 : 1.6), .removeFromParent()]))
    }

    func setWaterOpacity(_ opacity: CGFloat) {
        waterOpacity = max(0, min(1, opacity)); waterBands.forEach { $0.alpha = waterOpacity }
    }
    private func waterColor(band: Int) -> SKColor {
        let depth = Double(band) / 44
        if night { return SKColor(red: 0.035, green: 0.11 + depth * 0.056, blue: 0.19 + depth * 0.105, alpha: 1) }
        return SKColor(red: 0.1, green: 0.23 + depth * 0.126, blue: 0.32 + depth * 0.161, alpha: 1)
    }
    @discardableResult
    private func block(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, color: SKColor) -> SKSpriteNode {
        let node = SKSpriteNode(color: color, size: CGSize(width: width, height: height))
        node.anchorPoint = .zero; node.position = CGPoint(x: x, y: y); tankRoot.addChild(node); return node
    }
    private func color(_ hex: Int) -> SKColor {
        SKColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}
