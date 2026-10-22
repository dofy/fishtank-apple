import XCTest
@testable import FishtankCore

final class AgentAlertToneTests: XCTestCase {
    func testStatesHaveDistinctShortSoftPCMWithoutClicks() {
        let tones = ClaudeHookEvent.Status.allCases.map { AgentAlertTone(status: $0) }
        XCTAssertEqual(Set(tones.map(\.wave)).count, 8)
        XCTAssertLessThanOrEqual(AgentAlertTone.playbackVolume, 0.35)
        for tone in tones {
            let samples = tone.samples
            XCTAssertGreaterThan(tone.duration, 0.1)
            XCTAssertLessThan(tone.duration, 0.6)
            XCTAssertEqual(samples.first, 0)
            XCTAssertEqual(samples.last, 0)
            XCTAssertLessThan(samples.map { abs(Int($0)) }.max()!, 6000)
            XCTAssertGreaterThan(samples.map { abs(Int($0)) }.max()!, 100)
            XCTAssertEqual(String(data: tone.wave.prefix(4), encoding: .utf8), "RIFF")
            XCTAssertEqual(tone.wave.count, 44 + samples.count * 2)
        }
    }
    func event(_ name: String, session: String = "a", source: ClaudeHookEvent.Source = .codex, age: Double = 0) -> ClaudeHookEvent {
        ClaudeHookEvent(id: UUID().uuidString, sessionID: session, project: "test", event: name,
                       notificationType: nil, sentAt: Date().addingTimeInterval(-age), source: source)
    }
    func testMuteStopsBacklogAndDoesNotReplayAfterEnabling() {
        var queue = AgentSoundQueue()
        queue.receive(event("Stop"), notify: true)
        queue.setEnabled(false)
        queue.receive(event("PermissionRequest"), notify: true)
        queue.setEnabled(true)
        XCTAssertNil(queue.next())
    }
    func testSilentResolutionAndSourceIsolation() {
        var queue = AgentSoundQueue()
        let claude = event("PermissionRequest", source: .claudeCode)
        let codex = event("PermissionRequest")
        queue.receive(claude, notify: true); queue.receive(codex, notify: true)
        queue.receive(event("PostToolUse", source: .claudeCode), notify: false)
        XCTAssertEqual(queue.next()?.id, codex.id)
        XCTAssertNil(queue.next())
        queue.receive(claude, notify: true); queue.receive(codex, notify: true)
        queue.remove(source: .codex)
        XCTAssertEqual(queue.next()?.id, claude.id)
    }
    func testDisabledStateDropsOnlyMatchingQueuedCues() {
        var queue = AgentSoundQueue()
        let working = event("UserPromptSubmit", session: "working")
        let permission = event("PermissionRequest", session: "permission")
        queue.receive(working, notify: true); queue.receive(permission, notify: true)
        queue.remove(states: ["working"])
        XCTAssertEqual(queue.next()?.id, permission.id)
        XCTAssertNil(queue.next())
    }
    func testUpdatesCoalesceAndBacklogIsBoundedAndExpires() {
        var queue = AgentSoundQueue()
        queue.receive(event("PermissionRequest"), notify: true)
        queue.receive(event("Stop"), notify: true)
        XCTAssertEqual(queue.pending.count, 1)
        XCTAssertEqual(queue.next()?.status, .responded)
        for i in 0..<10 { queue.receive(event("Stop", session: "\(i)", age: 6), notify: true) }
        XCTAssertEqual(queue.pending.count, 3)
        XCTAssertNil(queue.next())
    }
}
