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
        case .mature: return L10n.text("A fish has grown up")
        case .hearts: return L10n.text("Hearts are full")
        case .cooldown: return L10n.text("Parent cooldown complete")
        }
    }
    var body: String {
        switch kind {
        case .mature: return L10n.text("A fish has grown up in your aquarium. Come take a look.")
        case .hearts: return L10n.text("All 5 hearts are ready.")
        case .cooldown: return L10n.text("Your starter fish can breed again.")
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
