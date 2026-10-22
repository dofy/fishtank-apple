import Foundation

/// Workspace suspension is a bounded hint, not a permanent veto on recovery.
struct AquariumRenderWatchdog {
    enum Action: Equatable { case rebind, rebuild }
    private(set) var suspendedAt: TimeInterval?
    private(set) var lastRecovery: TimeInterval = 0
    private(set) var attempts = 0

    mutating func suspend(at uptime: TimeInterval) { suspendedAt = uptime }
    mutating func recovered(at uptime: TimeInterval) {
        suspendedAt = nil; lastRecovery = uptime; attempts += 1
    }
    mutating func action(at uptime: TimeInterval, visible: Bool, consoleAvailable: Bool,
                         lastFrame: TimeInterval?, paused: Bool, attached: Bool) -> Action? {
        guard visible, consoleAvailable else { return nil }
        if let suspendedAt {
            if let lastFrame, lastFrame > suspendedAt { self.suspendedAt = nil }
            else {
                guard uptime - suspendedAt >= 10 else { return nil }
                return .rebuild
            }
        }
        if let lastFrame, lastFrame > lastRecovery { attempts = 0 }
        let lastProgress = max(lastFrame ?? lastRecovery, lastRecovery)
        guard paused || !attached || uptime - lastProgress > 4 else { return nil }
        return attempts > 0 ? .rebuild : .rebind
    }
}
