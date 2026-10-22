import Foundation

/// A single menu-bar slot summarizes registered, enabled agents without inventing session outcomes.
enum AgentMenuIndicator {
    enum State: String, CaseIterable {
        case idle, paused, ready, working, permission, input, responded, failed, interrupted, ended
        init(_ status: ClaudeHookEvent.Status) { self = Self(rawValue: status.rawValue)! }
        var title: String {
            if self == .idle { return L10n.text("等待 Agent 事件") }
            if self == .paused { return L10n.text("Agent 提醒已暂停") }
            return ClaudeHookEvent.Status(rawValue: rawValue)!.title
        }
    }
    struct Presentation: Equatable {
        var state: State
        var detail: String
        static var idle: Self { Self(state: .idle, detail: State.idle.title) }
    }
    static func lifetime(_ status: ClaudeHookEvent.Status) -> TimeInterval {
        switch status {
        case .permission, .input, .working: return 900
        case .failed: return 120
        default: return 30
        }
    }
    private static func priority(_ status: ClaudeHookEvent.Status) -> Int {
        switch status {
        case .failed: return 8
        case .permission: return 7
        case .input: return 6
        case .working: return 5
        case .interrupted: return 4
        case .responded: return 3
        case .ready: return 2
        case .ended: return 1
        }
    }
    static func presentation(ledger: ClaudeHookLedger, agents: [AgentRegistration], paused: Bool,
                             disabledStates: Set<String>, now: Date) -> Presentation {
        if paused { return .init(state: .paused, detail: State.paused.title) }
        let enabled = Dictionary(uniqueKeysWithValues: agents.filter(\.enabled).map { ($0.id, $0.name) })
        let eligible = ledger.sessions.values.filter { session in
            enabled[session.event.agent.rawValue] != nil && !disabledStates.contains(session.status.rawValue)
                && now.timeIntervalSince(session.updatedAt) >= 0
                && now.timeIntervalSince(session.updatedAt) < lifetime(session.status)
        }
        let selected = eligible.sorted {
            let left = priority($0.status), right = priority($1.status)
            if left != right { return left > right }
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.event.sessionKey < $1.event.sessionKey
        }.first
        guard let selected else { return .idle }
        return .init(state: State(selected.status), detail: "\(enabled[selected.event.agent.rawValue]!) · \(selected.event.project) · \(selected.status.title)")
    }
}
