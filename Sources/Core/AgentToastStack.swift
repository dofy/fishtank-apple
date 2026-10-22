import Foundation

/// At most three independent sessions on screen; same-session events coalesce.
struct AgentToastStack {
    static let capacity = 3
    private(set) var visible: [ClaudeHookEvent] = []
    private(set) var pending: [ClaudeHookEvent] = []

    mutating func receive(_ event: ClaudeHookEvent, notify: Bool, now: Date = Date()) {
        pending.removeAll { $0.sessionKey == event.sessionKey && (notify || $0.status != event.status) }
        if let index = visible.firstIndex(where: { $0.sessionKey == event.sessionKey }) {
            if notify || visible[index].status != event.status { visible.remove(at: index) }
            else { return }
        }
        guard notify else { promote(now: now); return }
        if visible.count < Self.capacity { visible.insert(event, at: 0) }
        else if event.event == "UserPromptSubmit" || event.status?.needsAttention == true || visible.contains(where: \.isPreview) {
            let index = visible.lastIndex(where: \.isPreview) ??
                visible.lastIndex(where: { $0.status?.needsAttention != true }) ?? visible.count - 1
            // This entry was already shown. Do not replay it later as an old alert.
            visible.remove(at: index)
            visible.insert(event, at: 0)
        } else {
            pending.append(event)
            if pending.count > 8 { pending.removeFirst(pending.count - 8) }
        }
        promote(now: now)
    }

    mutating func dismiss(id: String, now: Date = Date()) {
        visible.removeAll { $0.id == id }
        promote(now: now)
    }
    mutating func remove(source: ClaudeHookEvent.Source, now: Date = Date()) {
        visible.removeAll { $0.agent == source }
        pending.removeAll { $0.agent == source }
        promote(now: now)
    }
    mutating func clear() { visible.removeAll(); pending.removeAll() }

    private mutating func promote(now: Date) {
        pending.removeAll { now.timeIntervalSince($0.sentAt) > 30 }
        while visible.count < Self.capacity, !pending.isEmpty {
            visible.append(pending.removeFirst())
        }
    }
}
