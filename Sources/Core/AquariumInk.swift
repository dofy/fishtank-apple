import Foundation

/// Visual-only defense. Every trigger shares the same per-animal cooldown.
enum AquariumInk {
    enum Trigger { case spontaneous, shock, shake }
    static let minimumCooldown = 300.0
    static let cooldownSpread = 180.0
    static let spontaneousRate = 0.003
    static let cloudLifetime = 4.8
    static let maximumClouds = 6
    static let escapeDuration = 1.5

    static func probability(_ trigger: Trigger, elapsed: Double = 0.1) -> Double {
        switch trigger {
        case .spontaneous: return 1 - exp(-spontaneousRate * max(0, min(0.1, elapsed)))
        case .shock: return 0.5
        case .shake: return 0.35
        }
    }

    struct Cloud: Identifiable {
        let id: Int
        let sourceID: UUID
        var x: Double
        var y: Double
        let direction: Double
        var age = 0.0
        var width: Double { 10 + 34 * min(1, age / 1.3) }
        var alpha: Double { min(1, age / 0.15) * max(0, 1 - age / cloudLifetime) * 0.85 }
    }
}
