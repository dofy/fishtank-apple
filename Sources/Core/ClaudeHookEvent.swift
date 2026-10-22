import Foundation

/// The bridge accepts metadata only; prompts, transcripts and tool arguments never enter the app.
struct ClaudeHookEvent: Codable, Equatable {
    let id: String
    let sessionID: String
    let project: String
    let event: String
    let notificationType: String?
    let sentAt: Date
    var source: Source? = nil
    private enum CodingKeys: String, CodingKey { case id, sessionID, project, event, notificationType, sentAt, source }
    var previewStatus: Status? = nil

    struct Source: RawRepresentable, Codable, Hashable, CaseIterable {
        let rawValue: String
        init(rawValue: String) { self.rawValue = rawValue }
        static let claudeCode = Self(rawValue: "claude-code"), codex = Self(rawValue: "codex")
        static let allCases: [Self] = [.claudeCode, .codex]
        var title: String { self == .codex ? "Codex" : self == .claudeCode ? "Claude Code" : rawValue }
        var colorHex: Int { self == .codex ? 0x78C8EB : self == .claudeCode ? 0xE9AC86 : 0xB9A0E8 }
        var isValid: Bool { rawValue.range(of: "^[a-z][a-z0-9-]{0,63}$", options: .regularExpression) != nil }
        init(from decoder: Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
        func encode(to encoder: Encoder) throws { var value = encoder.singleValueContainer(); try value.encode(rawValue) }
    }
    // Supplied from the local registration after decoding; never trusted from the sender.
    var displayName: String? = nil
    var displayColor: Int? = nil
    var agentTitle: String { displayName ?? agent.title }
    var agentColorHex: Int { displayColor ?? agent.colorHex }
    var agent: Source { source ?? .claudeCode }
    var sessionKey: String { agent.rawValue + ":" + sessionID }

    enum Status: String, Codable, CaseIterable {
        case ready, working, permission, input, responded, failed, interrupted, ended
        var title: String {
            switch self {
            case .ready: return "会话已连接"
            case .working: return "正在处理"
            case .permission: return "等待你的授权"
            case .input: return "等待你的输入"
            case .responded: return "本轮回复已结束"
            case .failed: return "本轮运行出错"
            case .interrupted: return "本轮已中断"
            case .ended: return "会话已结束"
            }
        }
        var colorHex: Int {
            switch self {
            case .working: return 0x8CBCEB
            case .permission: return 0xF0C66E
            case .input: return 0xC1A1E8
            case .responded: return 0x8CC5A5
            case .failed: return 0xF08E97
            case .interrupted: return 0xD4A47C
            case .ready: return 0x86CBC2
            case .ended: return 0xACB9C4
            }
        }
        var needsAttention: Bool { self == .permission || self == .input || self == .failed }
        var holdsToast: Bool { self == .permission || self == .input }
    }

    var status: Status? {
        if isPreview, let previewStatus { return previewStatus }
        switch event {
        case "SessionStart": return .ready
        case "UserPromptSubmit", "PostToolUse", "PostToolUseFailure": return .working
        case "PermissionRequest": return .permission
        case "Stop": return .responded
        case "StopFailure": return .failed
        case "SessionEnd": return .ended
        case "Interrupt": return agent != .claudeCode ? .interrupted : nil
        case "NeedsInput": return agent != .claudeCode ? .input : nil
        case "Notification":
            switch notificationType {
            case "permission_prompt": return .permission
            case "idle_prompt", "elicitation_dialog", "elicitation_url_dialog", "agent_needs_input": return .input
            default: return nil
            }
        default: return nil
        }
    }
    var isPreview: Bool { sessionID == "preview" || sessionID.hasPrefix("fishtank-preview:") }
    var showsToast: Bool { event != "PostToolUse" && event != "PostToolUseFailure" && status != nil }
    var isValid: Bool {
        agent.isValid && !id.isEmpty && id.utf8.count <= 128 && !sessionID.isEmpty && sessionID.utf8.count <= 256 &&
        !project.isEmpty && project.count <= 80 && !project.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) && status != nil
    }
}

struct ClaudeHookLedger {
    struct Session {
        let event: ClaudeHookEvent
        let status: ClaudeHookEvent.Status
        let updatedAt: Date
    }
    private(set) var sessions: [String: Session] = [:]
    private var seen: [String] = []

    mutating func accept(_ event: ClaudeHookEvent, now: Date = Date()) -> Bool? {
        guard event.isValid, abs(now.timeIntervalSince(event.sentAt)) < 60,
              !seen.contains(event.id) else { return nil }
        if let previous = sessions[event.sessionKey], previous.event.sentAt > event.sentAt { return nil }
        seen.append(event.id)
        if seen.count > 256 { seen.removeFirst(seen.count - 256) }
        // Synthetic previews are transient UI events, not real waiting sessions.
        if event.isPreview { return event.showsToast }
        let previous = sessions[event.sessionKey]
        sessions[event.sessionKey] = Session(event: event, status: event.status!, updatedAt: now)
        if sessions.count > 64, let oldest = sessions.min(by: { $0.value.updatedAt < $1.value.updatedAt })?.key {
            sessions.removeValue(forKey: oldest)
        }
        // PermissionRequest and its delayed Notification describe the same wait.
        return event.showsToast && (previous?.status != event.status || now.timeIntervalSince(previous!.updatedAt) > 10)
    }

    mutating func remove(source: ClaudeHookEvent.Source) { sessions = sessions.filter { $0.value.event.agent != source } }

    func summary(source: ClaudeHookEvent.Source = .claudeCode, now: Date = Date()) -> String {
        let title = source.title
        let active = sessions.values.filter { $0.event.agent == source && now.timeIntervalSince($0.updatedAt) < 900 && $0.status != .ended }
        let waiting = active.filter { $0.status.holdsToast }.count
        let working = active.filter { $0.status == .working }.count
        if waiting > 0 { return "\(title) · \(waiting) 个会话等待处理" }
        if working > 0 { return "\(title) · \(working) 个会话处理中" }
        return active.isEmpty ? "\(title) · 等待事件" : "\(title) · \(active.count) 个近期会话"
    }
}

/// Shares geometry with offscreen validation; tank coordinates and canvas stay unchanged.
enum ClaudeToastPlacement {
    static func frame(tank: CGRect, visibleFrame: CGRect) -> CGRect {
        frames(tank: tank, visibleFrame: visibleFrame, count: 1)[0]
    }
    static func frames(tank: CGRect, visibleFrame: CGRect, count: Int) -> [CGRect] {
        let count = max(0, min(AgentToastStack.capacity, count))
        guard count > 0 else { return [] }
        let height: CGFloat = 70, gap: CGFloat = 8
        let total = CGFloat(count) * height + CGFloat(count - 1) * gap
        var bottom = tank.maxY + gap
        if bottom + total > visibleFrame.maxY {
            let below = tank.minY - gap - total
            bottom = below >= visibleFrame.minY ? below : max(visibleFrame.minY, min(tank.maxY - total, visibleFrame.maxY - total))
        }
        return (0..<count).map { CGRect(x: tank.minX, y: bottom + CGFloat($0) * (height + gap), width: tank.width, height: height) }
    }
}
