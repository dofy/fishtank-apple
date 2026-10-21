import Foundation

/// Scenery only: never creates inventory fish or consumes the breeding/ecology RNG.
enum AquariumBackdrop {
    struct Fish: Equatable {
        var x: Double
        var y: Double
        var round: Bool
        var heading: Double
        var frame: Int
    }
    static func fish(at time: Double) -> [Fish] {
        let t = time.isFinite ? max(0, time) : 0
        let leaderX = (t * 9 + 110).truncatingRemainder(dividingBy: 420) - 50
        let leaderY = 128 + sin(t * 0.42) * 4.5
        var fish = (0..<7).map { i -> Fish in
            let row = Double((i + 1) / 2)
            let side = i == 0 ? 0.0 : i % 2 == 0 ? 1.0 : -1.0
            return Fish(x: leaderX - row * 8 + sin(t * 2.1 - Double(i) * 0.4) * 0.4,
                        y: leaderY + side * (2 + row * 1.4), round: false, heading: 1,
                        frame: Int(t * 6 + Double(i)) % 4)
        }
        let turn = t * 0.12 + 0.35
        let centerX = 205 + sin(turn) * 65
        let centerY = 81 + sin(t * 0.23 + 1) * 6
        let offsets = [(-16.0,4.0),(-6,8),(8,6),(19,-2),(6,-6),(-10,-7)]
        for (i, offset) in offsets.enumerated() {
            let heading = cos(turn)
            fish.append(Fish(x: centerX + offset.0 + sin(t * 0.5 + Double(i)),
                             y: centerY + offset.1 + cos(t * 0.8 + Double(i) * 0.9), round: true,
                             heading: (heading < 0 ? -1 : 1) * max(0.15, abs(heading)),
                             frame: Int(t * 3 + Double(i)) % 4))
        }
        return fish
    }
}

enum AquariumFloor {
    /// Same four-point columns used by the renderer, so contact never uses a different curve.
    static func height(at x: Double) -> Double {
        let column = floor(min(318, max(2, x) - 2) / 4) * 4 + 2
        return 24 + (3 * sin(column * 0.035) + 2 * cos(column * 0.074)).rounded()
    }
    static func decorationBase(at x: Double, width: Double) -> Double {
        let half = max(1, width / 2)
        let samples = stride(from: x - half, through: x + half, by: 1).map { height(at: $0) }
        // Slightly seat the cropped sprite in the lowest sand under its footprint.
        return (samples.min() ?? height(at: x)) - 1
    }
}
