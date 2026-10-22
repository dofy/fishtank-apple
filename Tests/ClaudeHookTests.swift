import XCTest
@testable import FishtankCore

final class ClaudeHookTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1000)
    private func event(_ name: String, id: String = UUID().uuidString, session: String = "one", kind: String? = nil, offset: Double = 0) -> ClaudeHookEvent {
        ClaudeHookEvent(id: id, sessionID: session, project: "fishtank", event: name, notificationType: kind, sentAt: now.addingTimeInterval(offset))
    }
    func testTurnEndIsNotTaskCompletion() {
        XCTAssertEqual(event("Stop").status, .responded)
        XCTAssertEqual(event("PostToolUseFailure").status, .working)
        XCTAssertEqual(event("StopFailure").status, .failed)
        XCTAssertNil(event("SubagentStop").status)
        XCTAssertNil(event("Notification", kind: "auth_success").status)
        XCTAssertEqual(event("Notification", kind: "idle_prompt").status, .input)
    }
    func testDuplicateWaitAndStaleEvents() {
        var ledger = ClaudeHookLedger()
        let permission = event("PermissionRequest", id: "permission")
        XCTAssertEqual(ledger.accept(permission, now: now), true)
        XCTAssertNil(ledger.accept(permission, now: now))
        XCTAssertEqual(ledger.accept(event("Notification", kind: "permission_prompt", offset: 6), now: now.addingTimeInterval(6)), false)
        XCTAssertNil(ledger.accept(event("UserPromptSubmit", offset: -1), now: now))
        XCTAssertEqual(ledger.sessions["claude-code:one"]?.status, .permission)
        XCTAssertEqual(ledger.accept(event("PostToolUse", offset: 7), now: now.addingTimeInterval(7)), false)
        XCTAssertEqual(ledger.sessions["claude-code:one"]?.status, .working)
        XCTAssertNil(ledger.accept(event("Stop", offset: -61), now: now))
    }
    func testIndependentSessionsAndExpiry() {
        var ledger = ClaudeHookLedger()
        _ = ledger.accept(event("PermissionRequest"), now: now)
        _ = ledger.accept(event("UserPromptSubmit", session: "two"), now: now)
        XCTAssertEqual(ledger.summary(now: now), L10n.render("{0} · {1} 个会话等待处理", arguments: ["Claude Code", "1"], language: L10n.language))
        _ = ledger.accept(event("SessionEnd", session: "one", offset: 1), now: now.addingTimeInterval(1))
        XCTAssertEqual(ledger.summary(now: now), L10n.render("{0} · {1} 个会话处理中", arguments: ["Claude Code", "1"], language: L10n.language))
        XCTAssertEqual(ledger.summary(now: now.addingTimeInterval(901)), L10n.render("{0} · 等待事件", arguments: ["Claude Code", "1"], language: L10n.language))
        for i in 0..<100 { _ = ledger.accept(event("Stop", session: "\(i)"), now: now) }
        XCTAssertEqual(ledger.sessions.count, 64)
    }
    func testInvalidMetadataIsRejected() {
        var ledger = ClaudeHookLedger()
        XCTAssertNil(ledger.accept(ClaudeHookEvent(id: "x", sessionID: "s", project: "bad\nname", event: "Stop", notificationType: nil, sentAt: now), now: now))
        XCTAssertNil(ledger.accept(event("Bogus"), now: now))
    }
    func testCodexAndClaudeSessionsCannotOverwriteEachOther() {
        var ledger = ClaudeHookLedger()
        let claude = event("PermissionRequest", session: "shared-id")
        var codex = event("UserPromptSubmit", session: "shared-id")
        codex.source = .codex
        XCTAssertEqual(ledger.accept(claude, now: now), true)
        XCTAssertEqual(ledger.accept(codex, now: now), true)
        XCTAssertEqual(ledger.sessions.count, 2)
        XCTAssertEqual(ledger.summary(source: .codex, now: now), L10n.render("{0} · {1} 个会话处理中", arguments: ["Codex", "1"], language: L10n.language))
        XCTAssertEqual(ledger.summary(now: now), L10n.render("{0} · {1} 个会话等待处理", arguments: ["Claude Code", "1"], language: L10n.language))
        codex = event("Interrupt", session: "shared-id", offset: 1)
        codex.source = .codex
        XCTAssertEqual(codex.status, .interrupted)
        XCTAssertEqual(ledger.accept(codex, now: now.addingTimeInterval(1)), true)
        XCTAssertEqual(ledger.sessions[claude.sessionKey]?.status, .permission)
        XCTAssertNil(event("Interrupt").status)
    }
    func testOldClaudeWireFormatRemainsDecodable() throws {
        let old = event("Stop")
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(ClaudeHookEvent.self, from: encoder.encode(old))
        XCTAssertEqual(decoded.agent, .claudeCode)
        XCTAssertEqual(decoded.status, .responded)
    }
    func testPlacementAcrossTankSizesAndScreenCeiling() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        for scale in 1...3 {
            let tank = CGRect(x: 100, y: 100, width: 320 * scale, height: 180 * scale)
            let toast = ClaudeToastPlacement.frame(tank: tank, visibleFrame: screen)
            XCTAssertEqual(toast.width, tank.width)
            XCTAssertEqual(toast.minX, tank.minX)
            XCTAssertEqual(toast.minY, tank.maxY + 8)
        }
        let ceiling = CGRect(x: 100, y: 900, width: 320, height: 180)
        let toast = ClaudeToastPlacement.frame(tank: ceiling, visibleFrame: screen)
        XCTAssertEqual(toast.maxY, ceiling.minY - 8)
        XCTAssertTrue(screen.contains(toast))
    }
}
