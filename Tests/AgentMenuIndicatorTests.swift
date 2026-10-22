import XCTest
@testable import FishtankCore

final class AgentMenuIndicatorTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let agents = [AgentRegistration.builtIn(.claudeCode), AgentRegistration.builtIn(.codex)]
    func event(_ name: String, source: ClaudeHookEvent.Source = .codex, session: String = "s", at: Date? = nil) -> ClaudeHookEvent {
        ClaudeHookEvent(id: UUID().uuidString, sessionID: session, project: "project", event: name,
                        notificationType: nil, sentAt: at ?? now, source: source)
    }
    func result(_ ledger: ClaudeHookLedger, at: Date? = nil, registered: [AgentRegistration]? = nil,
                paused: Bool = false, disabled: Set<String> = []) -> AgentMenuIndicator.Presentation {
        AgentMenuIndicator.presentation(ledger: ledger, agents: registered ?? agents, paused: paused, disabledStates: disabled, now: at ?? now)
    }
    func testAllLifecycleStatesAndTheirExpiryReturnToIdleWithoutInventingCompletion() {
        let cases: [(String, ClaudeHookEvent.Status)] = [("SessionStart",.ready),("UserPromptSubmit",.working),
            ("PermissionRequest",.permission),("NeedsInput",.input),("Stop",.responded),("StopFailure",.failed),
            ("Interrupt",.interrupted),("SessionEnd",.ended)]
        for (name,status) in cases {
            var ledger = ClaudeHookLedger(); _ = ledger.accept(event(name),now:now)
            XCTAssertEqual(result(ledger).state, AgentMenuIndicator.State(status))
            XCTAssertEqual(result(ledger,at:now.addingTimeInterval(AgentMenuIndicator.lifetime(status))).state,.idle)
        }
    }
    func testAttentionOutranksBusyAndRecentCompletionFromOtherAgents() {
        var ledger = ClaudeHookLedger()
        _ = ledger.accept(event("PermissionRequest",source:.claudeCode,session:"permission"),now:now)
        _ = ledger.accept(event("NeedsInput",session:"input"),now:now)
        _ = ledger.accept(event("UserPromptSubmit",session:"working"),now:now)
        _ = ledger.accept(event("Stop",session:"responded"),now:now)
        XCTAssertEqual(result(ledger).state,.permission)
        _ = ledger.accept(event("StopFailure",session:"failure"),now:now)
        XCTAssertEqual(result(ledger).state,.failed)
        XCTAssertEqual(result(ledger,at:now.addingTimeInterval(120)).state,.permission)
        XCTAssertEqual(result(ledger,disabled:["failed","permission"]).state,.input)
    }
    func testSameSessionTransitionsAndRemovalDoNotLeaveStaleAttention() {
        var ledger = ClaudeHookLedger()
        _ = ledger.accept(event("PermissionRequest"),now:now)
        _ = ledger.accept(event("UserPromptSubmit",at:now.addingTimeInterval(1)),now:now.addingTimeInterval(1))
        XCTAssertEqual(result(ledger,at:now.addingTimeInterval(1)).state,.working)
        _ = ledger.accept(event("SessionEnd",at:now.addingTimeInterval(2)),now:now.addingTimeInterval(2))
        XCTAssertEqual(result(ledger,at:now.addingTimeInterval(2)).state,.ended)
        ledger.remove(source:.codex)
        XCTAssertEqual(result(ledger,at:now.addingTimeInterval(2)).state,.idle)
    }
    func testPausedDisabledRemovedAndSyntheticEventsDoNotRaiseRealAttention() {
        var ledger = ClaudeHookLedger(); _ = ledger.accept(event("PermissionRequest"),now:now)
        XCTAssertEqual(result(ledger,paused:true).state,.paused)
        var disabledAgent = agents[1]; disabledAgent.enabled=false
        XCTAssertEqual(result(ledger,registered:[disabledAgent]).state,.idle)
        XCTAssertEqual(result(ledger,registered:[]).state,.idle)
        var previewLedger = ClaudeHookLedger()
        _ = previewLedger.accept(event("StopFailure",session:"fishtank-preview:sample"),now:now)
        XCTAssertEqual(result(previewLedger).state,.idle)
    }
    func testTieUsesMostRecentSessionAndRegisteredDisplayName() {
        var ledger = ClaudeHookLedger()
        _ = ledger.accept(event("UserPromptSubmit",session:"old"),now:now)
        _ = ledger.accept(event("UserPromptSubmit",source:.claudeCode,session:"new",at:now.addingTimeInterval(1)),now:now.addingTimeInterval(1))
        var renamed=agents[0]; renamed.name="我的助手"
        XCTAssertEqual(result(ledger,at:now.addingTimeInterval(1),registered:[renamed,agents[1]]).detail,"我的助手 · project · " + L10n.text("正在处理"))
    }
}
