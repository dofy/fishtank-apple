import Foundation

/// Repeated shaking stresses the tank. A continuous burst of 33 shakes costs one
/// displayed fish; a pause longer than `maximumGap` starts the count over.
struct AquariumShakeStress {
    static let limit = 33
    static let maximumGap: TimeInterval = 3
    private(set) var count = 0
    private var last: Date?

    mutating func register(at date: Date = Date()) -> Bool {
        let gap = last.map { date.timeIntervalSince($0) }
        if let gap, gap > Self.maximumGap || gap < 0 { count = 0 }
        last = date
        count += 1
        guard count >= Self.limit else { return false }
        count = 0
        return true
    }
}
