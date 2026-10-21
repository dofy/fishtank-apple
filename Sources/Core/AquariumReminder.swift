import Foundation

/// Snapshot of the event being announced, independent of notification delivery.
struct AquariumReminder: Equatable {
    enum Kind: String, CaseIterable {
        case mature = "fishtank.mature", hearts = "fishtank.hearts", cooldown = "fishtank.cooldown"
    }
    let kind: Kind
    let date: Date
    let fishIDs: [UUID]
    var title: String {
        switch kind {
        case .mature: return "小鱼长大了"
        case .hearts: return "爱心已回满"
        case .cooldown: return "亲代冷却结束"
        }
    }
    var body: String {
        switch kind {
        case .mature: return "鱼缸里有小鱼成年了，回来看看吧。"
        case .hearts: return "5 颗爱心已经准备好。"
        case .cooldown: return "初始鱼可以再次参与繁育了。"
        }
    }
    static func scheduled(in state: AquariumState, at now: Date) -> [Self] {
        var current = state
        current.advance(to: now)
        return Kind.allCases.compactMap { kind in
            if kind == .hearts {
                guard let date = current.heartsFullAt, date > now else { return nil }
                return Self(kind: kind, date: date, fishIDs: [])
            }
            let candidates = current.fish.filter { fish in
                guard let date = fish.maturesAt, date > now else { return false }
                return kind == .mature ? !fish.expBanked : fish.expBanked
            }
            guard let date = candidates.compactMap(\.maturesAt).min() else { return nil }
            return Self(kind: kind, date: date, fishIDs: candidates.filter { $0.maturesAt == date }.map(\.id))
        }
    }
    func isSatisfied(in state: AquariumState, at now: Date) -> Bool {
        guard now >= date else { return false }
        var current = state
        current.advance(to: now)
        if kind == .hearts { return current.hearts == AquariumState.heartLimit }
        return current.fish.contains { fishIDs.contains($0.id) && $0.isAdult(at: now) }
    }
}
