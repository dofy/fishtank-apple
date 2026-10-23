import Foundation

struct AgentRegistration: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var colorHex: Int
    var enabled = true
    var bubbles = true
    var sound = true
    var aquariumResponse = true
    var source: ClaudeHookEvent.Source { .init(rawValue: id) }
    var isBuiltIn: Bool { source == .claudeCode || source == .codex }
    var isValid: Bool { source.isValid && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 32 && !name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) && (0...0xFFFFFF).contains(colorHex) }
    static func builtIn(_ source: ClaudeHookEvent.Source, enabled: Bool = true) -> Self {
        Self(id: source.rawValue, name: source.title, colorHex: source.colorHex, enabled: enabled)
    }
    static func decode(_ data: Data) throws -> [Self] {
        let agents = try JSONDecoder().decode([Self].self, from: data)
        guard agents.count <= 16, agents.allSatisfy(\.isValid), Set(agents.map(\.id)).count == agents.count else { throw AquariumError.invalidSave }
        return agents
    }
}

/// Presets describe presentation and setup; only the original two have native installers.
struct AgentPreset: Identifiable {
    let id: String
    let name: String
    let colorHex: Int
    let setup: String
    let documentation: URL?
    var registration: AgentRegistration { AgentRegistration(id: id, name: name, colorHex: colorHex) }
    var supportsAutomaticSetup: Bool { registration.isBuiltIn }
    static func find(_ id: String) -> Self? { all.first { $0.id == id } }
    static let all: [Self] = [
        .init(id: "claude-code", name: "Claude Code", colorHex: ClaudeHookEvent.Source.claudeCode.colorHex,
              setup: L10n.text("After adding, install the hook from its details page. The first operation uses the system picker to authorize the configuration folder."), documentation: nil),
        .init(id: "codex", name: "Codex", colorHex: ClaudeHookEvent.Source.codex.colorHex,
              setup: L10n.text("After adding, install the hook from its details page. New hooks require trust review in Codex."), documentation: nil),
        .init(id: "cursor", name: "Cursor", colorHex: 0xC3CDDF,
              setup: L10n.text("Manual setup: convert raw events to Fishtank's standard JSON in Cursor Hooks, then call the send command."), documentation: URL(string: "https://cursor.com/docs/hooks")),
        .init(id: "gemini-cli", name: "Gemini CLI", colorHex: 0x94ACF4,
              setup: L10n.text("Manual setup: convert raw events to Fishtank's standard JSON in Gemini CLI Hooks, then call the send command."), documentation: URL(string: "https://geminicli.com/docs/hooks/")),
        .init(id: "opencode", name: "OpenCode", colorHex: 0xD7A4DA,
              setup: L10n.text("Manual setup: listen for events in an OpenCode plugin, convert them to Fishtank's standard JSON, then call the send command."), documentation: URL(string: "https://opencode.ai/docs/plugins/"))
    ]
}

/// Mutates only this application's handlers. Existing owned command text/hash inputs remain intact.
enum AgentHookConfiguration {
    static func events(for source: ClaudeHookEvent.Source) -> [String] {
        source == .codex ? ["SessionStart", "UserPromptSubmit", "PermissionRequest", "PreToolUse", "PostToolUse", "Stop", "Interrupt", "SessionEnd"] :
            ["SessionStart", "UserPromptSubmit", "PermissionRequest", "Notification", "Stop", "StopFailure", "SessionEnd", "PostToolUse", "PostToolUseFailure"]
    }
    static func shellQuote(_ text: String) -> String { "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'" }
    /// Tokenize without evaluation. Never executes substitutions or arbitrary hook commands.
    static func words(_ text: String) -> [String]? {
        var result: [String] = [], word = "", quote: Character?, escape = false, started = false
        for c in text {
            if escape { word.append(c); escape = false; started = true; continue }
            if c == "\\" && quote != "'" { escape = true; started = true; continue }
            if let q = quote { if c == q { quote = nil } else { word.append(c) }; continue }
            if c == "'" || c == "\"" { quote = c; started = true }
            else if c.isWhitespace { if started { result.append(word); word = ""; started = false } }
            else { word.append(c); started = true }
        }
        guard !escape, quote == nil else { return nil }
        if started { result.append(word) }
        return result
    }
    static func owns(_ handler: [String: Any], source: ClaudeHookEvent.Source, scriptPaths: Set<String>) -> Bool {
        guard handler["type"] as? String == "command", let command = handler["command"] as? String,
              let parts = words(command), parts.count >= 2, scriptPaths.contains(parts[1]) else { return false }
        if let index = parts.firstIndex(of: "--source") { return parts.indices.contains(index + 1) && parts[index + 1] == source.rawValue }
        return source == .claudeCode
    }
    static func inspect(_ data: Data, source: ClaudeHookEvent.Source, scriptPaths: Set<String>) throws -> [String] {
        let root = try object(data)
        guard let hooks = root["hooks"] as? [String: Any] else { if root["hooks"] == nil { return [] }; throw AquariumError.invalidSave }
        return try events(for: source).filter { event in
            try rows(hooks[event]).contains { row in
                (row["hooks"] as! [[String: Any]]).contains { owns($0, source: source, scriptPaths: scriptPaths) }
            }
        }
    }
    static func merge(_ data: Data?, source: ClaudeHookEvent.Source, scriptPaths: Set<String>, command: String, remove: Bool) throws -> Data {
        var root = try data.map(object) ?? [:]
        guard root["hooks"] == nil || root["hooks"] is [String: Any] else { throw AquariumError.invalidSave }
        var hooks = root["hooks"] as? [String: Any] ?? [:], changed = false
        for event in events(for: source) {
            var list = try rows(hooks[event])
            let hasOwned = list.contains { ($0["hooks"] as! [[String: Any]]).contains { owns($0, source: source, scriptPaths: scriptPaths) } }
            if remove && hasOwned {
                list = list.compactMap { row in
                    var row = row
                    let kept = (row["hooks"] as! [[String: Any]]).filter { !owns($0, source: source, scriptPaths: scriptPaths) }
                    guard !kept.isEmpty else { return nil }; row["hooks"] = kept; return row
                }; changed = true
                if list.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = list }
            } else if !remove && !hasOwned {
                list.append(["hooks": [["type": "command", "command": command, "timeout": 2]]]); hooks[event] = list; changed = true
            }
        }
        if !changed, let data { return data }
        root["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }
    private static func object(_ data: Data) throws -> [String: Any] {
        guard data.count <= 2_000_000, let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw AquariumError.invalidSave }
        return value
    }
    private static func rows(_ value: Any?) throws -> [[String: Any]] {
        guard let value else { return [] }
        guard let rows = value as? [[String: Any]], rows.allSatisfy({ $0["hooks"] is [[String: Any]] }) else { throw AquariumError.invalidSave }
        return rows
    }
}
