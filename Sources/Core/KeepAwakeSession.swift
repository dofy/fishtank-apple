/// Owns idle-sleep assertions transactionally. The platform supplies allocation/release.
final class KeepAwakeSession {
    enum Mode: String, CaseIterable { case off, system, display }
    enum Kind { case system, display }
    private(set) var mode: Mode = .off
    private var ids: [UInt32] = []
    private let create: (Kind) -> UInt32?
    private let release: (UInt32) -> Void
    init(create: @escaping (Kind) -> UInt32?, release: @escaping (UInt32) -> Void) {
        self.create = create; self.release = release
    }
    @discardableResult func select(_ next: Mode) -> Bool {
        if next == mode { return true }
        let kinds: [Kind] = next == .off ? [] : next == .system ? [.system] : [.system, .display]
        var pending: [UInt32] = []
        for kind in kinds {
            guard let id = create(kind) else { pending.forEach(release); return false }
            pending.append(id)
        }
        ids.forEach(release); ids = pending; mode = next
        return true
    }
    func stop() { ids.forEach(release); ids.removeAll(); mode = .off }
    deinit { ids.forEach(release) }
}
