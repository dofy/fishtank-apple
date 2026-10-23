import XCTest
@testable import FishtankCore

final class AgentToastStackTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1000)
    func event(_ name: String, session: String, source: ClaudeHookEvent.Source = .codex) -> ClaudeHookEvent {
        ClaudeHookEvent(id: UUID().uuidString, sessionID: session, project: "验证", event: name,
                       notificationType: nil, sentAt: now, source: source)
    }
    func testIndependentSessionsStayVisibleAndUpdatesCoalesce() {
        var stack = AgentToastStack()
        let a = event("PermissionRequest", session: "a", source: .claudeCode)
        let b = event("UserPromptSubmit", session: "b")
        let c = event("Stop", session: "c")
        for e in [a,b,c] { stack.receive(e, notify: true, now: now) }
        XCTAssertEqual(stack.visible.count, 3)
        XCTAssertEqual(Set(stack.visible.map(\.id)), Set([a,b,c].map(\.id)))
        let updated = event("Stop", session: "b")
        stack.receive(updated, notify: true, now: now)
        XCTAssertEqual(stack.visible.count, 3)
        XCTAssertEqual(stack.visible.first?.id, updated.id)
        XCTAssertFalse(stack.visible.contains { $0.id == b.id })
        XCTAssertTrue(stack.visible.contains { $0.id == a.id })
    }
    func testDismissingOnePromotesQueuedWithoutRemovingOthers() {
        var stack = AgentToastStack()
        let events = (0..<4).map { event("Stop", session: "\($0)") }
        for e in events { stack.receive(e, notify: true, now: now) }
        XCTAssertEqual(stack.visible.count, 3)
        XCTAssertEqual(stack.pending.map(\.id), [events[3].id])
        stack.dismiss(id: events[1].id, now: now)
        XCTAssertEqual(Set(stack.visible.map(\.id)), Set([events[0],events[2],events[3]].map(\.id)))
        stack.dismiss(id: events[1].id, now: now)
        XCTAssertEqual(stack.visible.count, 3)
    }
    func testNewPromptCannotBeBlockedByThreeWaitingSessions() {
        var stack = AgentToastStack()
        for i in 0..<3 { stack.receive(event("PermissionRequest", session: "\(i)"), notify: true, now: now) }
        let prompt = event("UserPromptSubmit", session: "new")
        stack.receive(prompt, notify: true, now: now)
        XCTAssertEqual(stack.visible.count, 3)
        XCTAssertEqual(stack.visible.first?.id, prompt.id)
    }
    func testSourceIsolationAndSilentResolution() {
        var stack = AgentToastStack()
        let claude = event("PermissionRequest", session: "same", source: .claudeCode)
        let codex = event("PermissionRequest", session: "same")
        for e in [claude,codex] { stack.receive(e, notify: true, now: now) }
        stack.receive(event("PostToolUse", session: "same", source: .claudeCode), notify: false, now: now)
        XCTAssertEqual(stack.visible.map(\.id), [codex.id])
        stack.remove(source: .claudeCode, now: now)
        XCTAssertEqual(stack.visible.map(\.id), [codex.id])
        stack.remove(source: .codex, now: now)
        XCTAssertTrue(stack.visible.isEmpty)
    }
    func testOverflowIsBoundedAndExpiredBacklogDoesNotReappear() {
        var stack = AgentToastStack()
        for i in 0..<20 { stack.receive(event("Stop", session: "\(i)"), notify: true, now: now) }
        XCTAssertEqual(stack.visible.count, 3)
        XCTAssertEqual(stack.pending.count, 8)
        for e in stack.visible { stack.dismiss(id: e.id, now: now.addingTimeInterval(31)) }
        XCTAssertTrue(stack.visible.isEmpty)
        XCTAssertTrue(stack.pending.isEmpty)
    }
    func testPreviewsDoNotCreateGhostWaitingSessions() {
        var ledger = ClaudeHookLedger()
        let preview = event("PermissionRequest", session: "fishtank-preview:demo")
        XCTAssertEqual(ledger.accept(preview, now: now), true)
        XCTAssertNil(ledger.accept(preview, now: now))
        XCTAssertTrue(ledger.sessions.isEmpty)
        XCTAssertEqual(ledger.summary(source: .codex, now: now), L10n.render("{0} · Waiting for events", arguments: ["Codex", "1"], language: L10n.language))
    }
    func testStackGeometryHasNoOverlapAndStaysWithinScreen() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        for width in [320, 640, 960] {
        for y in [20, 500, 900] {
            let tank = CGRect(x: 100, y: y, width: width, height: width * 180 / 320)
            let widths: [CGFloat] = [260, 380, 520]
            let frames = ClaudeToastPlacement.frames(tank: tank, visibleFrame: screen, widths: widths)
            XCTAssertEqual(frames.count, 3)
            for (frame, width) in zip(frames, widths) {
                XCTAssertEqual(frame.width, width)
                // Right-aligned with the tank, unless the screen edge clamps it.
                XCTAssertEqual(frame.maxX, min(max(tank.maxX, width), screen.maxX))
                XCTAssertTrue(screen.contains(frame))
            }
            for pair in zip(frames, frames.dropFirst()) { XCTAssertEqual(pair.1.minY - pair.0.maxY, 8) }
        }
        }
    }
}
