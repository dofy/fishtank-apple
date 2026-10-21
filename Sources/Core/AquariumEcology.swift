import Foundation

/// Transient visual simulation. Its RNG never consumes the saved breeding RNG.
/// Positions use a 320 × 180 tank, with the origin at the sand (SpriteKit convention).
struct AquariumEcology {
    struct Swimmer {
        var fish: AquariumFish
        var x: Double
        var y: Double
        var direction = 1.0
        var age = 0.0
        var puff = 0.0
        var scared = 0.0
        var shocked = 0.0
        var discharging = 0.0
        var zapCooldown = 12.0
        var eatCooldown = 0.0
        var withdrawal: Double?
        var withdrawalDuration = 0.55
        var clicks: [Double] = []
        var school: UUID?
        var visit: String?
        var passedArch = false
        var activityUntil = 0.0
        var sceneryCooldown = 8.0
        var baseY: Double
        var dropping = false
        var alpha: Double { withdrawal.map { max(0, $0 / withdrawalDuration) } ?? 1 }
        var available: Bool { withdrawal == nil && !dropping && scared <= 0 && shocked <= 0 && discharging <= 0 }
        var puffAmount: Double { puff <= 0 ? 0 : min(1, min((1.8 - puff) / 0.12, puff / 0.6)) }
    }
    struct Food: Identifiable {
        var id: Int
        var x: Double
        var y: Double
        var age = 0.0
        var plankton = false
        var lifetime = 20.0
    }
    private(set) var swimmers: [UUID: Swimmer] = [:]
    private(set) var foods: [Food] = []
    private(set) var lampColors = [1, 4, 1]
    private(set) var time = 0.0
    private var random: FishRandom
    private var foodID = 0
    private var planktonIn = 14.0
    private var hasPopulated = false
    private var decorations: [PlacedDecoration] = []
    private var activeDecoration: String?
    private(set) var height = 180.0
    var night = false
    var reducedMotion = false
    private(set) var events: [String] = []

    init(seed: UInt32 = UInt32.random(in: 1...UInt32.max)) { random = FishRandom(seed: seed) }

    /// Resize transient swimming space without consuming gameplay or visual RNG.
    mutating func resize(height nextHeight: Double) {
        guard nextHeight.isFinite, nextHeight >= 80, nextHeight != height else { return }
        let oldHeight = height
        func project(_ y: Double) -> Double { 30 + (y - 30) * (nextHeight - 60) / (oldHeight - 60) }
        for id in Array(swimmers.keys) {
            guard var swimmer = swimmers[id] else { continue }
            swimmer.y = project(swimmer.y)
            swimmer.baseY = project(swimmer.baseY)
            swimmers[id] = swimmer
        }
        for index in foods.indices { foods[index].y = project(foods[index].y) }
        height = nextHeight
    }

    mutating func sync(_ fish: [AquariumFish], decorations nextDecor: [PlacedDecoration]) {
        let ids = Set(fish.map(\.id))
        for id in Array(swimmers.keys) where !ids.contains(id) && swimmers[id]?.withdrawal == nil {
            let duration = reducedMotion ? 0.12 : 0.55
            swimmers[id]?.withdrawalDuration = duration
            swimmers[id]?.withdrawal = duration
            interrupt(id)
        }
        for (index, fish) in fish.enumerated() {
            if var current = swimmers[fish.id] {
                current.fish = fish; current.withdrawal = nil
                swimmers[fish.id] = current
            } else {
                let y = 30 + Double(15 + index * 31 % 102) * (height - 60) / 120
                let dropping = hasPopulated && !reducedMotion
                swimmers[fish.id] = Swimmer(fish: fish, x: Double(45 + index * 53 % 232), y: dropping ? height + 12 : y,
                    direction: index % 2 == 0 ? 1 : -1, zapCooldown: 8 + random.next() * 14,
                    baseY: y, dropping: dropping)
            }
        }
        if nextDecor != decorations {
            for id in Array(swimmers.keys) where swimmers[id]?.visit != nil { interrupt(id) }
            decorations = nextDecor
        }
        hasPopulated = true
    }

    mutating func feed(x: Double = 160, y: Double? = nil, count: Int = 1) {
        // Bound temporary nodes even when a user holds the feed shortcut.
        for index in 0..<max(0, min(8, count)) {
            foodID += 1
            foods.append(Food(id: foodID, x: min(302, max(18, x + Double(index - count / 2) * 5)), y: min(height - 14, max(18, y ?? height - 16))))
        }
        if foods.count > 80 { foods.removeFirst(foods.count - 80) }
    }

    mutating func setActiveDecoration(_ id: String?) {
        activeDecoration = id
        if let id {
            for fishID in Array(swimmers.keys) where swimmers[fishID]?.visit == id { interrupt(fishID) }
        }
    }

    mutating func discardMissingFish(in inventory: Set<UUID>) {
        // Only a living fish returned to the inventory gets a withdrawal animation.
        // Synthesis, release and replacing a save remove its transient agent immediately.
        for id in Array(swimmers.keys) where !inventory.contains(id) {
            interrupt(id)
            swimmers.removeValue(forKey: id)
        }
    }

    @discardableResult
    mutating func tap(_ id: UUID, x: Double) -> String? {
        guard var a = swimmers[id], a.withdrawal == nil, !a.dropping else { return nil }
        interrupt(id)
        a.school = nil; a.visit = nil; a.sceneryCooldown = 10
        if a.fish.species.silhouette == "spiky-puffer" && !reducedMotion { a.puff = 1.8 }
        a.clicks = a.clicks.filter { time - $0 <= 30 }; a.clicks.append(time)
        swimmers[id] = a
        if a.fish.species.electric && a.clicks.count >= 6 {
            swimmers[id]?.clicks = []; discharge(id); return "zap"
        }
        a.scared = reducedMotion ? 0 : 1.35
        a.direction = a.x < 65 ? 1 : a.x > 255 ? -1 : a.x >= x ? 1 : -1
        swimmers[id] = a
        return "scare"
    }

    private mutating func interrupt(_ id: UUID) {
        swimmers[id]?.school = nil; swimmers[id]?.visit = nil; swimmers[id]?.sceneryCooldown = 10
        for other in Array(swimmers.keys) where swimmers[other]?.school == id {
            swimmers[other]?.school = nil; swimmers[other]?.sceneryCooldown = 10
        }
    }

    private mutating func discharge(_ id: UUID) {
        guard swimmers[id]?.fish.species.electric == true, swimmers[id]?.withdrawal == nil else { return }
        interrupt(id)
        swimmers[id]?.shocked = 0
        swimmers[id]?.scared = 0
        swimmers[id]?.discharging = 0.85
        swimmers[id]?.zapCooldown = 22 + random.next() * 18
        for other in Array(swimmers.keys) where other != id && swimmers[other]?.withdrawal == nil && swimmers[other]?.dropping == false {
            interrupt(other)
            swimmers[other]?.shocked = 3; swimmers[other]?.scared = 0; swimmers[other]?.puff = 0
        }
        if night {
            let index = random.int(3)
            lampColors[index] = (lampColors[index] + 1 + random.int(6)) % 7
        }
    }

    mutating func update(_ elapsed: Double) {
        guard elapsed.isFinite, elapsed > 0 else { return }
        let dt = min(elapsed, 0.1) // No catch-up animation burst after waking from sleep.
        time += dt; events = []
        for id in Array(swimmers.keys) {
            guard var a = swimmers[id] else { continue }
            if let remaining = a.withdrawal {
                let next = min(remaining, reducedMotion ? 0.12 : 0.55) - dt
                if next <= 0 { swimmers.removeValue(forKey: id); continue }
                a.withdrawal = next
                if !reducedMotion { a.x += a.direction * 16 * dt; a.y += 5 * dt }
                swimmers[id] = a; continue
            }
            a.age += dt
            a.scared = max(0, a.scared - dt); a.shocked = max(0, a.shocked - dt)
            a.puff = reducedMotion ? 0 : max(0, a.puff - dt)
            a.discharging = max(0, a.discharging - dt); a.zapCooldown = max(0, a.zapCooldown - dt)
            a.eatCooldown = max(0, a.eatCooldown - dt); a.sceneryCooldown = max(0, a.sceneryCooldown - dt)
            if reducedMotion { a.school = nil; a.visit = nil; a.dropping = false; a.y = a.baseY }
            swimmers[id] = a
        }
        if reducedMotion {
            for index in foods.indices { foods[index].age += dt }
            foods.removeAll { $0.plankton || $0.age > 0.4 }; return
        }
        updateFood(dt)
        let ids = swimmers.keys.sorted { $0.uuidString < $1.uuidString }
        let activeCount = ids.filter { swimmers[$0]?.withdrawal == nil }.count
        for id in ids {
            guard var a = swimmers[id], a.withdrawal == nil else { continue }
            if a.fish.species.electric && a.available && a.zapCooldown <= 0 && activeCount > 1 && random.next() < dt * 0.04 {
                discharge(id); events.append("zap"); a = swimmers[id]!
            }
            var targetX = a.x + a.direction * 30, targetY = a.baseY + sin(time * 1.5 + a.baseY) * 3
            var speed = 8.0 + a.fish.species.length * 0.35
            if a.dropping {
                a.y -= 70 * dt
                if a.y <= a.baseY { a.y = a.baseY; a.dropping = false }
                swimmers[id] = a; continue
            }
            if a.shocked > 0 {
                a.school = nil; a.visit = nil; a.sceneryCooldown = 10
                a.y = max(30, min(height - 29, a.y + sin(time * 24) * dt * 2)); swimmers[id] = a; continue
            }
            if a.scared > 0 {
                speed = 85 * min(1, a.scared * 2); a.school = nil; a.visit = nil; a.sceneryCooldown = 10
            } else if a.eatCooldown <= 0, let food = closestFood(to: a) {
                a.school = nil; a.visit = nil; a.sceneryCooldown = 10
                targetX = food.x; targetY = food.y; speed = 38
                if hypot(a.x - food.x, a.y - food.y) < 7 {
                    foods.removeAll { $0.id == food.id }; a.eatCooldown = 9; events.append("eat")
                }
            } else {
                if time >= a.activityUntil { a.school = nil; a.visit = nil }
                if let leaderID = a.school {
                    if let leader = swimmers[leaderID], leader.available, leader.school == nil {
                        let slot = Double(ids.firstIndex(of: id) ?? 0)
                        targetX = min(292, max(28, leader.x - leader.direction * (16 + slot.truncatingRemainder(dividingBy: 4) * 9)))
                        targetY = leader.y + (slot.truncatingRemainder(dividingBy: 3) - 1) * 9; speed = 22
                    } else { a.school = nil; a.sceneryCooldown = 10 }
                }
                if let visit = a.visit, let decor = decorations.first(where: { $0.id == visit }) {
                    let center = decor.x * 320
                    targetX = a.passedArch ? center + a.direction * 38 : center
                    let width = max(18, (DecorCatalog.byID[visit]?.width ?? 58) * 0.48)
                    targetY = AquariumFloor.decorationBase(at: center, width: width) + (visit == "kelp" ? 39 : 21)
                    speed = 15
                    if visit == "arch", !a.passedArch, abs(a.x - center) < 8 { a.passedArch = true; a.activityUntil = min(a.activityUntil, time + 3) }
                    if visit == "kelp", abs(a.x - center) < 3 { speed = 0; a.y += sin(time * 2) * dt }
                } else if a.school == nil && a.sceneryCooldown <= 0 {
                    if a.fish.species.form == "seahorse", activeDecoration != "kelp", decorations.contains(where: { $0.id == "kelp" }), random.next() < dt * 0.12 {
                        a.visit = "kelp"; a.activityUntil = time + 18; a.sceneryCooldown = 25
                    } else if a.fish.species.form == "fish", a.fish.species.length <= 14, a.fish.species.depth < 0.72,
                              activeDecoration != "arch", decorations.contains(where: { $0.id == "arch" }), random.next() < dt * 0.12 {
                        a.visit = "arch"; a.passedArch = false; a.activityUntil = time + 12; a.sceneryCooldown = 20
                    } else if random.next() < dt * 0.18 {
                        // A follower never leads another fish. Same species only, groups of 2–5.
                        let peers = ids.filter { $0 != id && swimmers[$0]?.fish.speciesID == a.fish.speciesID
                            && swimmers[$0]?.available == true && swimmers[$0]?.school == nil }
                        let leaders = Set(swimmers.values.compactMap(\.school))
                        if !leaders.contains(id), let leader = peers.first(where: { candidate in swimmers.values.filter { $0.school == candidate }.count < 4 }),
                           swimmers.values.filter({ $0.school == leader }).count < 4 {
                            a.school = leader; a.activityUntil = time + 8 + random.next() * 6; a.sceneryCooldown = 24
                        }
                    }
                }
            }
            let dx = targetX - a.x, dy = targetY - a.y, distance = hypot(dx, dy)
            if distance > 0.1 {
                let move = min(distance, speed * dt)
                a.x += dx / distance * move; a.y += dy / distance * move
                if abs(dx) > 0.5 { a.direction = dx > 0 ? 1 : -1 }
            }
            if a.x < 23 { a.x = 23; a.direction = 1 }
            if a.x > 297 { a.x = 297; a.direction = -1 }
            a.y = max(AquariumFloor.height(at: a.x) + 12, min(height - 29, a.y))
            swimmers[id] = a
        }
    }

    private func closestFood(to a: Swimmer) -> Food? {
        let nearby = foods.filter { hypot(a.x - $0.x, a.y - $0.y) < ($0.plankton ? 60 : 100) }
        let pellets = nearby.filter { !$0.plankton }
        return (pellets.isEmpty ? nearby : pellets).min { hypot(a.x - $0.x, a.y - $0.y) < hypot(a.x - $1.x, a.y - $1.y) }
    }

    private mutating func updateFood(_ dt: Double) {
        planktonIn -= dt
        if planktonIn <= 0 {
            planktonIn = 18 + random.next() * 24
            let active = swimmers.values.filter { $0.available }
            let count = min(1 + random.int(3), 3 - foods.filter(\.plankton).count)
            if !active.isEmpty && count > 0 {
                let sorted = active.sorted { $0.fish.id.uuidString < $1.fish.id.uuidString }
                let a = sorted[random.int(sorted.count)]
                for _ in 0..<count {
                    foodID += 1
                    foods.append(Food(id: foodID, x: min(294, max(26, a.x + (random.next() - 0.5) * 50)),
                                      y: min(height - 32, max(34, a.y + (random.next() - 0.5) * 30)), plankton: true,
                                      lifetime: 16 + random.next() * 8))
                }
            }
        }
        for index in foods.indices {
            foods[index].age += dt
            foods[index].y += foods[index].plankton ? cos(time + Double(index)) * dt : -10 * dt
            foods[index].x = min(306, max(14, foods[index].x + sin(time * 2 + Double(index)) * 2 * dt))
        }
        foods.removeAll { $0.y < AquariumFloor.height(at: $0.x) + 1 || ($0.plankton && $0.age > $0.lifetime) }
    }
}
