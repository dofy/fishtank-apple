import XCTest
@testable import FishtankCore

final class AgentRegistrationTests: XCTestCase {
    let legacy = "/Users/test/Library/Application Support/FishtankCodexHook/codex-hook.py"
    let bundled = "/Applications/Fishtank.app/Contents/Resources/claude-hook.py"
    func json(_ object: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) }
    func handler(_ command: String) -> [String: Any] { ["type": "command", "command": command, "timeout": 2] }
    func command(_ script: String, source: String = "codex") -> String { "/usr/bin/python3 \(AgentHookConfiguration.shellQuote(script)) --source \(source) --app /Applications/Fishtank.app/Contents/MacOS/FishtankMac" }
    func testCompleteExistingHooksAreByteIdenticalAndTrustMetadataRemains() throws {
        let existingCommand = command(legacy)
        let row: [String: Any] = ["matcher": "*", "hooks": [handler(existingCommand)], "enabled": true, "trusted_hash": "unchanged"]
        let hooks = Dictionary(uniqueKeysWithValues: AgentHookConfiguration.events(for: .codex).map { ($0, [row]) })
        let original = try json(["hooks": hooks, "description": "preserved"])
        let output = try AgentHookConfiguration.merge(original, source: .codex, scriptPaths: [legacy, bundled], command: command(bundled), remove: false)
        XCTAssertEqual(output, original)
        XCTAssertEqual(try AgentHookConfiguration.inspect(output, source: .codex, scriptPaths: [legacy, bundled]).count, 8)
    }
    func testRepairAddsMissingWithoutRewritingExistingCommandsOrRows() throws {
        let old: [String: Any] = ["matcher": "shell", "hooks": [handler(command(legacy)), handler("other-tool")], "metadata": ["trusted": true]]
        let original = try json(["hooks": ["Stop": [old]], "env": ["keep": "untouched"]])
        let output = try AgentHookConfiguration.merge(original, source: .codex, scriptPaths: [legacy, bundled], command: command(bundled), remove: false)
        let decoded = try JSONSerialization.jsonObject(with: output) as! [String: Any]
        let rows = (decoded["hooks"] as! [String: Any])["Stop"] as! [[String: Any]]
        XCTAssertEqual(try json(rows[0]), try json(old))
        XCTAssertEqual((decoded["env"] as! [String: String])["keep"], "untouched")
        XCTAssertEqual(try AgentHookConfiguration.inspect(output, source: .codex, scriptPaths: [legacy, bundled]).count, 8)
        XCTAssertEqual(try AgentHookConfiguration.merge(output, source: .codex, scriptPaths: [legacy, bundled], command: command(bundled), remove: false), output)
    }
    func testRemoveOnlyOwnedHandlersInMixedRowsAndPreservesOtherSource() throws {
        let keep = handler("echo keep")
        let original = try json(["hooks": ["Stop": [["matcher": "*", "hooks": [handler(command(legacy)), keep, handler(command(bundled, source: "agent-other"))]]]], "trust": ["preserve": true]])
        let output = try AgentHookConfiguration.merge(original, source: .codex, scriptPaths: [legacy, bundled], command: "", remove: true)
        let decoded = try JSONSerialization.jsonObject(with: output) as! [String: Any]
        let rows = (decoded["hooks"] as! [String: Any])["Stop"] as! [[String: Any]]
        XCTAssertEqual(rows[0]["matcher"] as? String, "*")
        XCTAssertEqual((rows[0]["hooks"] as! [[String: Any]]).count, 2)
        XCTAssertEqual((decoded["trust"] as! [String: Bool])["preserve"], true)
        XCTAssertTrue(try AgentHookConfiguration.inspect(output, source: .codex, scriptPaths: [legacy, bundled]).isEmpty)
    }
    func testMalformedConfigurationFailsWithoutGuessingOwnership() throws {
        for invalid in [Data("[]".utf8), try json(["hooks": "bad"]), try json(["hooks": ["Stop": [["hooks": "bad"]]]])] {
            XCTAssertThrowsError(try AgentHookConfiguration.merge(invalid, source: .codex, scriptPaths: [legacy], command: command(bundled), remove: true))
        }
        XCTAssertFalse(AgentHookConfiguration.owns(handler("/usr/bin/python3 /other/codex-hook.py --source codex"), source: .codex, scriptPaths: [legacy]))
        XCTAssertFalse(AgentHookConfiguration.owns(handler(command(bundled, source: "agent-other")), source: .codex, scriptPaths: [bundled]))
    }
    func testShellWordsHandlesSpacesApostrophesAndNeverEvaluates() {
        let path = "/a folder/it's $(private)/hook.py"
        XCTAssertEqual(AgentHookConfiguration.words("python3 " + AgentHookConfiguration.shellQuote(path)), ["python3", path])
        XCTAssertNil(AgentHookConfiguration.words("python3 'unterminated"))
    }
    func testCustomSourceWireFormatAndLocalPresentationCannotBeSpoofed() throws {
        let source = ClaudeHookEvent.Source(rawValue: "agent-local")
        var event = ClaudeHookEvent(id: "1", sessionID: "session", project: "project", event: "NeedsInput", notificationType: nil, sentAt: Date(), source: source)
        event.displayName = "local name"; event.displayColor = 0x123456; event.previewStatus = .failed
        XCTAssertEqual(event.status, .input)
        let encoded = try JSONEncoder().encode(event)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("local name"))
        let decoded = try JSONDecoder().decode(ClaudeHookEvent.self, from: encoded)
        XCTAssertEqual(decoded.agent, source); XCTAssertTrue(decoded.isValid)
        XCTAssertNil(decoded.displayName); XCTAssertNil(decoded.previewStatus)
        event.source = .init(rawValue: "bad/source"); XCTAssertFalse(event.isValid)
    }
    func testPresetsUseValidUniqueWireIDsAndPreserveInstallerBoundaries() throws {
        let registrations = AgentPreset.all.map(\.registration)
        XCTAssertEqual(try AgentRegistration.decode(JSONEncoder().encode(registrations)), registrations)
        XCTAssertEqual(Set(AgentPreset.all.filter(\.supportsAutomaticSetup).map(\.id)), ["claude-code", "codex"])
        for id in ["cursor", "gemini-cli", "opencode"] {
            let preset = try XCTUnwrap(AgentPreset.find(id))
            XCTAssertNotNil(preset.documentation)
            XCTAssertFalse(preset.registration.isBuiltIn)
            let event = ClaudeHookEvent(id: "preset", sessionID: "session", project: "project", event: "Stop", notificationType: nil, sentAt: Date(), source: preset.registration.source)
            XCTAssertTrue(try JSONDecoder().decode(ClaudeHookEvent.self, from: JSONEncoder().encode(event)).isValid)
        }
        XCTAssertNil(AgentPreset.find("agent-personal"))
    }
    func testRegistrationRoundTripEmptyRemovalDuplicatesAndBounds() throws {
        let valid = [AgentRegistration.builtIn(.codex), AgentRegistration(id: "agent-local", name: "本地助手", colorHex: 0xB9A0E8)]
        XCTAssertEqual(try AgentRegistration.decode(JSONEncoder().encode(valid)), valid)
        XCTAssertEqual(try AgentRegistration.decode(Data("[]".utf8)), [])
        XCTAssertThrowsError(try AgentRegistration.decode(JSONEncoder().encode([valid[0], valid[0]])))
        var bad = valid[1]; bad.name = "\n"; XCTAssertFalse(bad.isValid)
        bad = valid[1]; bad.colorHex = -1; XCTAssertFalse(bad.isValid)
    }
}
