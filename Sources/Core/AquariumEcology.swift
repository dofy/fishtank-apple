import Foundation

/// Transient visual simulation. Its RNG never consumes the saved breeding RNG.
/// Positions use a 320 × 180 tank, with the origin at the sand (SpriteKit convention).
struct AquariumEcology {
    private static let minimumZapCooldown = 300.0
    private static let zapCooldownSpread = 180.0
    private static let automaticZapRate = 0.005
    enum CuttlefishGait { case forward, backward, hover }

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
        var zapCooldown = AquariumEcology.minimumZapCooldown
        var inkCooldown = 0.0
        var inkJet = 0.0
        var inkJetDirection = -1.0
        var cuttlefishGait = CuttlefishGait.forward
        var cuttlefishGaitIn = 4.0
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
        var individuality = FishIndividuality(id: UUID(uuid: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)))
        var motionTime = 0.0
        var motionRate = 1.0
        var heading = 0.0
        var resting = 0.0
        var restIn = 20.0
        var restX = 0.0
        var restY = 0.0
        var turnIn = 18.0
        var roamOffset = 0.0
        var velocityX = 0.0
        var velocityY = 0.0
        var pitch = 0.0
        var facing = 1.0
        mutating func easeVelocity(x targetX: Double, y targetY: Double, response: Double, dt: Double) {
            let blend = 1 - exp(-dt / response)
            velocityX += (targetX - velocityX) * blend
            velocityY += (targetY - velocityY) * blend
        }
        mutating func easeFacing(duration: Double, dt: Double) {
            let target = direction > 0 ? 0.0 : Double.pi
            let step = Double.pi * dt / duration
            heading += max(-step, min(step, target - heading))
            facing = cos(heading)
        }
        var alpha: Double { withdrawal.map { max(0, $0 / withdrawalDuration) } ?? 1 }
        var available: Bool { withdrawal == nil && !dropping && scared <= 0 && shocked <= 0 && discharging <= 0 && resting <= 0 && inkJet <= 0 }
        var puffAmount: Double { puff <= 0 ? 0 : min(1, min((1.8 - puff) / 0.12, puff / 0.6)) }
        var inkJetAmount: Double { inkJet <= 0 ? 0 : max(0, min(1, min((AquariumInk.escapeDuration - inkJet) / 0.12, inkJet / 0.45))) }
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
    private(set) var inkClouds: [AquariumInk.Cloud] = []
    private(set) var lampColors = [1, 4, 1]
    private(set) var time = 0.0
    private var random: FishRandom
    private var foodID = 0
    private var inkID = 0
    private var inkReadyAt: [UUID: Double] = [:]
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
            swimmer.roamOffset *= (nextHeight - 60) / (oldHeight - 60)
            if swimmer.resting > 0 { swimmer.restY = project(swimmer.restY) }
            swimmers[id] = swimmer
        }
        for index in foods.indices { foods[index].y = project(foods[index].y) }
        for index in inkClouds.indices { inkClouds[index].y = project(inkClouds[index].y) }
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
                let individuality = FishIndividuality(id: fish.id)
                let profile = fish.species.swimProfile
                let y = 30 + min(0.92, max(0.06, profile.depth + individuality.lane)) * (height - 60)
                let dropping = hasPopulated && !reducedMotion
                var swimmer = Swimmer(fish: fish, x: Double(45 + index * 53 % 232), y: dropping ? height + 12 : y,
                    direction: index % 2 == 0 ? 1 : -1, zapCooldown: Self.minimumZapCooldown + random.next() * Self.zapCooldownSpread,
                    baseY: y, dropping: dropping, individuality: individuality)
                swimmer.motionTime = individuality.phase
                swimmer.inkCooldown = max(0, (inkReadyAt[fish.id] ?? time) - time)
                swimmer.facing = swimmer.direction
                swimmer.heading = swimmer.direction > 0 ? 0 : .pi
                swimmer.restIn = profile.restEvery * (0.55 + individuality.pace * 0.45)
                swimmer.turnIn = 12 + individuality.phase * 3
                swimmer.cuttlefishGaitIn = 3 + individuality.phase * 0.7
                swimmers[fish.id] = swimmer
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
        inkReadyAt = inkReadyAt.filter { inventory.contains($0.key) }
    }

    @discardableResult
    mutating func tap(_ id: UUID, x: Double) -> String? {
        guard var a = swimmers[id], a.withdrawal == nil, !a.dropping else { return nil }
        interrupt(id)
        a.school = nil; a.visit = nil; a.resting = 0; a.restIn = max(a.restIn, 8); a.sceneryCooldown = 10
        if a.fish.species.silhouette == "spiky-puffer" && !reducedMotion { a.puff = 1.8 }
        a.clicks = a.clicks.filter { time - $0 <= 30 }; a.clicks.append(time)
        swimmers[id] = a
        if a.fish.species.electric && a.clicks.count >= 6 {
            discharge(id); return "zap"
        }
        a.scared = reducedMotion ? 0 : 1.35
        a.direction = a.x < 65 ? 1 : a.x > 255 ? -1 : a.x >= x ? 1 : -1
        swimmers[id] = a
        return "scare"
    }

    /// Visual-only startle: never changes fish, breeding RNG or saved progress.
    mutating func shake() {
        guard !reducedMotion else { return }
        for id in swimmers.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
            guard swimmers[id]?.withdrawal == nil else { continue }
            interrupt(id)
            guard var a = swimmers[id] else { continue }
            a.scared = 3 + random.next() * 2
            a.shocked = 0; a.discharging = 0; a.dropping = false
            a.y = max(AquariumFloor.height(at: a.x) + 12, min(height - 29, a.y))
            a.direction = a.x < 65 ? 1 : a.x > 255 ? -1 : random.next() < 0.5 ? -1 : 1
            a.zapCooldown = max(a.zapCooldown, 6)
            swimmers[id] = a
            releaseInk(id, trigger: .shake)
        }
    }

    private mutating func interrupt(_ id: UUID) {
        swimmers[id]?.school = nil; swimmers[id]?.visit = nil; swimmers[id]?.sceneryCooldown = 10
        let nextRest = max(8, swimmers[id]?.restIn ?? 0)
        swimmers[id]?.resting = 0; swimmers[id]?.restIn = nextRest
        for other in Array(swimmers.keys) where swimmers[other]?.school == id {
            swimmers[other]?.school = nil; swimmers[other]?.sceneryCooldown = 10
        }
    }

    private mutating func discharge(_ id: UUID) {
        guard let source = swimmers[id], source.fish.species.electric, source.withdrawal == nil else { return }
        interrupt(id)
        swimmers[id]?.shocked = 0
        swimmers[id]?.scared = 0
        swimmers[id]?.discharging = 0.85
        swimmers[id]?.zapCooldown = Self.minimumZapCooldown + random.next() * Self.zapCooldownSpread
        swimmers[id]?.clicks = []
        for other in Array(swimmers.keys) where other != id && swimmers[other]?.withdrawal == nil && swimmers[other]?.dropping == false {
            interrupt(other)
            swimmers[other]?.shocked = 3; swimmers[other]?.scared = 0; swimmers[other]?.puff = 0
            releaseInk(other, trigger: .shock)
        }
        if night {
            let index = random.int(3)
            lampColors[index] = (lampColors[index] + 1 + random.int(6)) % 7
        }
    }

    @discardableResult private mutating func releaseInk(_ id: UUID, trigger: AquariumInk.Trigger, elapsed: Double = 0.1) -> Bool {
        guard !reducedMotion, let current = swimmers[id], current.fish.species.spraysInk,
              current.withdrawal == nil, !current.dropping, current.inkCooldown <= 0,
              random.next() < AquariumInk.probability(trigger, elapsed: elapsed) else { return false }
        interrupt(id)
        guard var a = swimmers[id] else { return false }
        let facing = a.facing >= 0 ? 1.0 : -1.0
        a.inkCooldown = AquariumInk.minimumCooldown + random.next() * AquariumInk.cooldownSpread
        inkReadyAt[id] = time + a.inkCooldown
        a.inkJet = AquariumInk.escapeDuration
        // Mantle leads the escape. Preserve the current facing hemisphere even
        // near the glass; braking must never turn an ink jet into a head-first dash.
        a.inkJetDirection = -facing
        a.direction = facing
        a.scared = 0
        a.resting = 0; a.restIn = max(a.restIn, 10)
        swimmers[id] = a
        inkID += 1
        inkClouds.append(.init(id: inkID, sourceID: id, x: a.x + facing * 9, y: a.y - 3, direction: facing))
        if inkClouds.count > AquariumInk.maximumClouds { inkClouds.removeFirst(inkClouds.count - AquariumInk.maximumClouds) }
        events.append("ink")
        return true
    }

    mutating func update(_ elapsed: Double) {
        guard elapsed.isFinite, elapsed > 0 else { return }
        let dt = min(elapsed, 0.1) // No catch-up animation burst after waking from sleep.
        time += dt; events = []
        inkReadyAt = inkReadyAt.filter { $0.value > time }
        if reducedMotion { inkClouds.removeAll() }
        else {
            for index in inkClouds.indices {
                inkClouds[index].age += dt
                inkClouds[index].x = min(305, max(15, inkClouds[index].x + inkClouds[index].direction * 4 * dt))
                inkClouds[index].y = min(height - 16, max(24, inkClouds[index].y + dt))
            }
            inkClouds.removeAll { $0.age >= AquariumInk.cloudLifetime }
        }
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
            let profile = a.fish.species.swimProfile
            if !reducedMotion {
                let hovering = profile.family == .cuttlefish && a.cuttlefishGait == .hover && a.inkJet <= 0 && a.scared <= 0
                let targetRate = a.resting > 0 ? 0.14 : a.inkJet > 0 ? 1.8 : a.scared > 0 ? 2.4 : hovering ? 0.65 : 1.0
                a.motionRate += (targetRate - a.motionRate) * (1 - exp(-dt / profile.accelerationTime))
                a.motionTime += dt * profile.tempo * a.individuality.pace * a.motionRate
            }
            a.resting = max(0, a.resting - dt)
            a.restIn = max(0, a.restIn - dt); a.turnIn = max(0, a.turnIn - dt)
            a.scared = max(0, a.scared - dt); a.shocked = max(0, a.shocked - dt)
            a.puff = reducedMotion ? 0 : max(0, a.puff - dt)
            a.discharging = max(0, a.discharging - dt); a.zapCooldown = max(0, a.zapCooldown - dt)
            a.inkCooldown = max(0, a.inkCooldown - dt)
            let wasJetting = a.inkJet > 0
            if reducedMotion { a.inkJet = 0 }
            else if a.shocked <= 0 { a.inkJet = max(0, a.inkJet - dt) }
            if wasJetting && a.inkJet <= 0 && !reducedMotion {
                a.cuttlefishGait = .hover; a.cuttlefishGaitIn = 2.5 + random.next() * 2
                a.restX = a.x; a.restY = a.y; a.scared = 0; a.turnIn = max(a.turnIn, 3)
            }
            a.eatCooldown = max(0, a.eatCooldown - dt); a.sceneryCooldown = max(0, a.sceneryCooldown - dt)
            if reducedMotion { a.school = nil; a.visit = nil; a.resting = 0; a.dropping = false; a.y = a.baseY; a.pitch = 0; a.facing = a.direction; a.heading = a.direction > 0 ? 0 : .pi; a.velocityX = 0; a.velocityY = 0 }
            swimmers[id] = a
        }
        if reducedMotion {
            for index in foods.indices { foods[index].age += dt }
            foods.removeAll { $0.plankton || $0.age > 0.4 }; return
        }
        updateFood(dt)
        let ids = swimmers.keys.sorted { $0.uuidString < $1.uuidString }
        let activeCount = ids.filter { swimmers[$0]?.withdrawal == nil }.count
        let schoolLeaders = Set(swimmers.values.compactMap(\.school))
        for id in ids {
            guard var a = swimmers[id], a.withdrawal == nil else { continue }
            if a.fish.species.electric && a.available && a.zapCooldown <= 0 && activeCount > 1 && random.next() < dt * Self.automaticZapRate {
                discharge(id); events.append("zap"); a = swimmers[id]!
            }
            if a.fish.species.spraysInk && a.available {
                if releaseInk(id, trigger: .spontaneous, elapsed: dt) { a = swimmers[id]! }
            }
            let profile = a.fish.species.swimProfile
            let cuttlefish = profile.family == .cuttlefish
            if cuttlefish { updateCuttlefishGait(&a, dt: dt) }
            if a.turnIn <= 0 && a.available && a.school == nil && a.visit == nil {
                a.turnIn = 15 + random.next() * 24
                if random.next() < 0.32 { a.direction *= -1 }
                a.roamOffset = (random.next() - 0.5) * (height - 60) * 0.2
            }
            // Start braking before the glass rather than hitting it at full speed.
            let margin = min(35, 5 + abs(a.velocityX) * profile.accelerationTime * 1.8)
            if !cuttlefish || (a.inkJet <= 0 && a.scared > 0) {
                if a.x < 23 + margin && a.direction < 0 { a.direction = 1 }
                if a.x > 297 - margin && a.direction > 0 { a.direction = -1 }
            }
            var (targetX, targetY, speed) = cruise(for: a)
            var arriving = false
            var faceTarget = !cuttlefish
            if a.dropping {
                a.y -= 70 * dt
                if a.y <= a.baseY { a.y = a.baseY; a.dropping = false }
                swimmers[id] = a; continue
            }
            if a.shocked > 0 {
                a.school = nil; a.visit = nil; a.resting = 0; a.sceneryCooldown = 10
                a.y = max(AquariumFloor.height(at: a.x) + 12, min(height - 29, a.y + sin(time * 24) * dt * 2)); swimmers[id] = a; continue
            }
            if a.inkJet > 0 {
                a.direction = -a.inkJetDirection
                targetX = a.x + a.inkJetDirection * 30; targetY = a.y + 2
                let room = a.inkJetDirection < 0 ? a.x - 23 : 297 - a.x
                speed = min(48 * min(1, a.inkJet / 0.6), max(0, room) / 0.55)
                a.school = nil; a.visit = nil; a.resting = 0
            } else if a.scared > 0 {
                if cuttlefish { targetX = a.x + a.direction * 30; faceTarget = true }
                speed = 85 * min(1, a.scared * 2); a.school = nil; a.visit = nil; a.resting = 0; a.sceneryCooldown = 10
            } else if a.eatCooldown <= 0, let food = closestFood(to: a) {
                faceTarget = true
                if cuttlefish { a.cuttlefishGaitIn = min(a.cuttlefishGaitIn, 1); a.restX = a.x; a.restY = a.y }
                a.school = nil; a.visit = nil; a.sceneryCooldown = 10
                a.resting = 0; a.restIn = max(a.restIn, 8)
                arriving = true
                targetX = food.x; targetY = food.y; speed = min(38, profile.speed * 2 + 6)
                if hypot(a.x - food.x, a.y - food.y) < 7 {
                    foods.removeAll { $0.id == food.id }; a.eatCooldown = 9; events.append("eat")
                }
            } else {
                if time >= a.activityUntil { a.school = nil; a.visit = nil }
                if let leaderID = a.school {
                    if let leader = swimmers[leaderID], leader.available, leader.school == nil {
                        let followers = ids.filter { $0 == id || swimmers[$0]?.school == leaderID }
                        let slot = Double(followers.firstIndex(of: id) ?? 0)
                        arriving = true
                        targetX = min(292, max(28, leader.x - leader.direction * (16 + slot.truncatingRemainder(dividingBy: 4) * 9)))
                        targetY = leader.y + (slot.truncatingRemainder(dividingBy: 3) - 1) * 8
                        speed = profile.speed * 1.25 + min(12, abs(targetX - a.x) * 0.1)
                    } else { a.school = nil; a.sceneryCooldown = 10 }
                }
                if let visit = a.visit, let decor = decorations.first(where: { $0.id == visit }) {
                    arriving = true
                    let center = decor.x * 320
                    targetX = a.passedArch ? center + a.direction * 38 : center
                    let width = max(18, (DecorCatalog.byID[visit]?.width ?? 58) * 0.48)
                    targetY = AquariumFloor.decorationBase(at: center, width: width) + (visit == "kelp" ? 39 : 21)
                    speed = 15
                    if visit == "arch", !a.passedArch, abs(a.x - center) < 8 { a.passedArch = true; a.activityUntil = min(a.activityUntil, time + 3) }
                    if visit == "kelp", abs(a.x - center) < 3 { speed = 0; a.y += sin(time * 2) * dt }
                } else if a.school == nil && a.sceneryCooldown <= 0 && a.available {
                    if a.fish.species.form == "seahorse", activeDecoration != "kelp", decorations.contains(where: { $0.id == "kelp" }), random.next() < dt * 0.12 {
                        a.visit = "kelp"; a.activityUntil = time + 18; a.sceneryCooldown = 25
                    } else if a.fish.species.form == "fish", a.fish.species.length <= 14, a.fish.species.depth < 0.72,
                              activeDecoration != "arch", decorations.contains(where: { $0.id == "arch" }), random.next() < dt * 0.12 {
                        a.visit = "arch"; a.passedArch = false; a.activityUntil = time + 12; a.sceneryCooldown = 20
                    } else if profile.schoolingRate > 0 && random.next() < dt * profile.schoolingRate {
                        // A follower never leads another fish. Same species only, groups of 2–5.
                        let peers = ids.filter { $0 != id && swimmers[$0]?.fish.speciesID == a.fish.speciesID
                            && swimmers[$0]?.available == true && swimmers[$0]?.school == nil
                            && hypot((swimmers[$0]?.x ?? 0) - a.x, (swimmers[$0]?.y ?? 0) - a.y) < 100 }
                        let leaders = Set(swimmers.values.compactMap(\.school))
                        if !leaders.contains(id), let leader = peers.first(where: { candidate in swimmers.values.filter { $0.school == candidate }.count < 4 }),
                           swimmers.values.filter({ $0.school == leader }).count < 4 {
                            a.school = leader; a.activityUntil = time + 8 + random.next() * 6; a.sceneryCooldown = 24
                        }
                    }
                }
            }
            if a.available && a.school == nil && a.visit == nil && !schoolLeaders.contains(id)
                && a.restIn <= 0 && profile.restEvery > 0 {
                a.resting = profile.restDuration * (0.7 + random.next() * 0.6)
                a.restIn = a.resting + profile.restEvery * (0.7 + random.next() * 0.6)
                a.restX = a.x; a.restY = a.y

            }
            var desiredX = 0.0, desiredY = 0.0
            if a.resting > 0 {
                // Coast to rest. Tiny water drift remains after momentum dissipates.
                desiredY = cos(a.age * 0.6) * 0.18
            } else {
                let dx = targetX - a.x, dy = targetY - a.y, distance = hypot(dx, dy)
                if distance > 0.1 {
                    let arrivalSpeed = arriving ? min(speed, distance / max(0.2, profile.accelerationTime * 2)) : speed
                    desiredX = dx / distance * arrivalSpeed
                    desiredY = dy / distance * arrivalSpeed
                    if abs(dx) > 1.5 && faceTarget && a.inkJet <= 0 { a.direction = dx > 0 ? 1 : -1 }
                }
            }
            let slowing = hypot(desiredX, desiredY) < hypot(a.velocityX, a.velocityY)
            let response = slowing ? profile.stoppingTime : profile.accelerationTime
            a.easeVelocity(x: desiredX, y: desiredY, response: response, dt: dt)
            a.x += a.velocityX * dt; a.y += a.velocityY * dt
            if a.x < 23 { a.x = 23; if !cuttlefish { a.direction = 1 }; a.velocityX = max(0, a.velocityX) }
            if a.x > 297 { a.x = 297; if !cuttlefish { a.direction = -1 }; a.velocityX = min(0, a.velocityX) }
            a.y = max(AquariumFloor.height(at: a.x) + 12, min(height - 29, a.y))
            let desiredPitch = profile.family == .seahorse ? sin(a.motionTime * 2 * .pi / 2.4) * 0.065 + min(0.08, abs(a.velocityX) * 0.009)
                : profile.family == .jellyfish ? sin(a.motionTime * 0.6) * 0.045
                : max(-0.2, min(0.2, atan2(a.velocityY, max(2, abs(a.velocityX))) * 0.22))
            a.pitch += (desiredPitch - a.pitch) * min(1, dt * 5)
            a.easeFacing(duration: profile.turningTime, dt: dt)
            swimmers[id] = a
        }
    }

    private mutating func updateCuttlefishGait(_ a: inout Swimmer, dt: Double) {
        guard a.available, closestFood(to: a) == nil else { return }
        a.cuttlefishGaitIn -= dt
        let travel = a.direction * (a.cuttlefishGait == .backward ? -1 : 1)
        let nearGlass = (a.x < 58 && travel < 0) || (a.x > 262 && travel > 0)
        if a.cuttlefishGait != .hover && nearGlass {
            a.cuttlefishGait = .hover; a.cuttlefishGaitIn = 2 + random.next() * 2
            a.restX = a.x; a.restY = a.y
        } else if a.cuttlefishGaitIn <= 0 {
            switch a.cuttlefishGait {
            case .forward: a.cuttlefishGait = random.next() < 0.65 ? .backward : .hover
            case .backward: a.cuttlefishGait = random.next() < 0.65 ? .hover : .forward
            case .hover:
                a.cuttlefishGait = random.next() < 0.6 ? .backward : .forward
                if a.x < 70 { a.cuttlefishGait = a.direction > 0 ? .forward : .backward }
                if a.x > 250 { a.cuttlefishGait = a.direction > 0 ? .backward : .forward }
            }
            a.cuttlefishGaitIn = a.cuttlefishGait == .hover ? 2.5 + random.next() * 3.5 : 5 + random.next() * 6
            a.restX = a.x; a.restY = a.y
        }
    }

    private func cruise(for a: Swimmer) -> (Double, Double, Double) {
        let p = a.fish.species.swimProfile, phase = a.individuality.phase
        let t = a.motionTime
        var x = a.x + a.direction * 30, y = a.baseY + a.roamOffset
        var speed = p.speed * a.individuality.pace
        switch p.family {
        case .fish:
            y += sin(a.age * 0.65 + phase) * p.sway + sin(a.age * 0.17 + phase) * p.sway * 0.3
            speed *= 0.8 + 0.2 * pow(sin(t * 1.4), 2)
        case .seaSnake:
            y += sin(t * 1.3 + phase) * p.sway
            speed *= 0.85 + 0.15 * sin(t * 1.3)
        case .eel:
            y += sin(t * 0.65 + phase) * p.sway
            speed *= 0.85 + 0.15 * cos(t)
        case .jellyfish:
            let pulse = pow(max(0, sin(t * .pi)), 5)
            let drift = sin(a.age * 0.22 + phase) * 1.4
            let lift = (pulse * 14 - 2.5) * p.speed / 3 + (a.baseY + a.roamOffset - a.y) * 0.14
            x = a.x + drift; y = a.y + lift; speed = hypot(drift, lift)
        case .seahorse:
            let beat = t * 2 * .pi / 2.4
            x = a.x + a.direction * 8
            y += sin(a.age * 0.5 + phase) * p.sway + sin(beat) * 1.2
            // Gentle propulsion alternates with suspended drifting, never a hard stop.
            speed *= 0.35 + 0.65 * pow((1 + sin(beat)) * 0.5, 2)
        case .turtle:
            y += sin(a.age * 0.17 + phase) * p.sway
            speed *= 0.3 + 0.7 * pow(max(0, sin(t * 2 * .pi / 2.8)), 2)
        case .ray:
            y += sin(a.age * 0.24 + phase) * p.sway
            speed *= 0.75 + 0.25 * sin(t * .pi) * sin(t * .pi)
        case .cuttlefish:
            if a.cuttlefishGait == .hover {
                x = a.restX + sin(a.age * 0.6 + phase) * 0.6
                y = a.restY + sin(a.age * 1.1 + phase) * 0.7
                speed = min(3, hypot(x - a.x, y - a.y) * 1.8)
            } else {
                // Facing and travel are independent: mantle-first backward fin
                // swimming never needs a mirror flip, and reversals ease through zero.
                x = a.x + a.direction * (a.cuttlefishGait == .backward ? -30 : 30)
                y += sin(a.age * 0.38 + phase) * p.sway
                speed *= 0.55 + 0.45 * pow(max(0, sin(t * 2 * .pi / 2.6)), 3)
            }
        }
        return (x, y, speed)
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
