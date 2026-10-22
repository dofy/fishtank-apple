#if os(macOS)
import AppKit
import Combine
import Darwin

@MainActor
final class AgentSettingsStore: ObservableObject {
    @Published private(set) var agents: [AgentRegistration]
    @Published var paused: Bool { didSet { defaults.set(paused, forKey: "agents.paused"); changed?() } }
    @Published var disabledStates: Set<String> { didSet { defaults.set(Array(disabledStates), forKey: "agents.disabledStates"); changed?() } }
    @Published private(set) var messages: [String: L10n.Message] = [:]
    @Published private(set) var configurationChecks: [String: L10n.Message] = [:]
    @Published private(set) var recent: [String: ClaudeHookEvent] = [:]
    @Published private(set) var busy: Set<String> = []
    @Published private(set) var storageError: String?
    @Published var receiverReady = false
    var changed: (() -> Void)?
    private let defaults: UserDefaults
    private var probes: [String: String] = [:]
    private var connections: [String: AgentBridgeProbe] = [:]
    static var userHome: URL {
        guard let home = getpwuid(getuid())?.pointee.pw_dir else { return FileManager.default.homeDirectoryForCurrentUser }
        return URL(fileURLWithPath: String(cString: home), isDirectory: true)
    }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        paused = defaults.bool(forKey: "agents.paused")
        disabledStates = Set(defaults.stringArray(forKey: "agents.disabledStates") ?? [])
        if let data = defaults.data(forKey: "agents.registrations") {
            do { agents = try AgentRegistration.decode(data) }
            catch { agents = []; storageError = L10n.text("Agent 设置无法读取，原数据已保留。请重新打开或从备份恢复。") }
        } else {
            agents = [.builtIn(.claudeCode, enabled: defaults.object(forKey: "claudeHooks.enabled") as? Bool ?? true),
                      .builtIn(.codex, enabled: defaults.object(forKey: "codexHooks.enabled") as? Bool ?? true)]
        }
    }
    var enabledCount: Int { agents.filter(\.enabled).count }
    func agent(_ id: String) -> AgentRegistration? { agents.first { $0.id == id } }
    func update(_ agent: AgentRegistration) {
        guard agent.isValid, let index = agents.firstIndex(where: { $0.id == agent.id }) else { return }
        agents[index] = agent; persist()
    }
    @discardableResult func add(name: String, source: ClaudeHookEvent.Source? = nil, color: Int = 0xB9A0E8) -> String? {
        guard storageError == nil else { return nil }
        let id = source?.rawValue ?? "agent-" + UUID().uuidString.lowercased()
        guard agent(id) == nil else { return id }
        guard agents.count < 16 else { return nil }
        let value = AgentRegistration(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), colorHex: color)
        guard value.isValid else { return nil }
        agents.append(value); persist(); return id
    }
    func removeLocal(_ id: String) {
        connections.removeValue(forKey: id)?.cancel()
        probes.removeValue(forKey: id); busy.remove(id)
        agents.removeAll { $0.id == id }; recent.removeValue(forKey: id)
        messages.removeValue(forKey: id); configurationChecks.removeValue(forKey: id)
        defaults.removeObject(forKey: "agents.folder." + id); persist()
    }
    private func persist() {
        guard storageError == nil else { return }
        if let data = try? JSONEncoder().encode(agents) { defaults.set(data, forKey: "agents.registrations") }
        for a in agents where a.isBuiltIn { defaults.set(a.enabled, forKey: a.source == .codex ? "codexHooks.enabled" : "claudeHooks.enabled") }
        changed?()
    }
    func record(_ event: ClaudeHookEvent) {
        guard agent(event.agent.rawValue) != nil else { return }
        if probes[event.agent.rawValue] == event.sessionID {
            probes.removeValue(forKey: event.agent.rawValue); busy.remove(event.agent.rawValue)
            messages[event.agent.rawValue] = L10n.message("测试事件已收到。实际 hook 是否触发，请看下方真实事件。")
        } else if !event.isPreview { recent[event.agent.rawValue] = event }
    }
    func lastEvent(_ id: String) -> String {
        guard let event = recent[id] else { return L10n.text("等待真实事件") }
        return "\(event.status?.title ?? L10n.text("状态更新")) · \(event.sentAt.formatted(date: .omitted, time: .shortened))"
    }
    var bundledHook: URL? { Bundle.main.url(forResource: "claude-hook", withExtension: "py") }
    func command(for id: String) -> String? {
        guard let script = bundledHook, let executable = Bundle.main.executableURL else { return nil }
        return (["/usr/bin/python3", script.path, "--source", id, "--app", executable.path]).map(AgentHookConfiguration.shellQuote).joined(separator: " ")
    }
    private func paths(for agent: AgentRegistration) -> Set<String> {
        let legacy = Self.userHome.appendingPathComponent("Library/Application Support/" + (agent.source == .codex ? "FishtankCodexHook/codex-hook.py" : "FishtankClaudeHook/claude-hook.py"))
        return Set([legacy.path, bundledHook?.path].compactMap { $0 })
    }
    #if DEBUG
    var validationFolders: [String: URL] = [:]
    #endif
    private func folder(for agent: AgentRegistration) throws -> URL? {
        #if DEBUG
        if ProcessInfo.processInfo.environment["FISHTANK_UI_TEST_ID"].flatMap(UUID.init(uuidString:)) != nil,
           let url = validationFolders[agent.id], url.path.hasPrefix(FileManager.default.temporaryDirectory.path) { return url }
        #endif
        let key = "agents.folder." + agent.id
        if let data = defaults.data(forKey: key) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale),
               url.startAccessingSecurityScopedResource() {
                if stale, let data = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) { defaults.set(data, forKey: key) }
                return url
            }
        }
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false; panel.showsHiddenFiles = true
        let name = agent.source == .codex ? ".codex" : ".claude"
        panel.title = L10n.text("选择 \(agent.name) 的配置文件夹")
        panel.message = L10n.text("请选择 \(name) 文件夹。只管理鱼缸自己的 hook，保留其他配置和信任记录。")
        panel.directoryURL = Self.userHome.appendingPathComponent(name); panel.prompt = L10n.text("使用此文件夹")
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard url.lastPathComponent == name || FileManager.default.fileExists(atPath: url.appendingPathComponent(agent.source == .codex ? "hooks.json" : "settings.json").path) else { throw ConnectionError.wrongFolder(name) }
        _ = url.startAccessingSecurityScopedResource()
        do {
            let data = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            defaults.set(data, forKey: key); return url
        } catch { url.stopAccessingSecurityScopedResource(); throw error }
    }
    enum ConnectionError: LocalizedError {
        case wrongFolder(String), unavailable, conflict
        var errorDescription: String? {
            switch self { case .wrongFolder(let name): return L10n.text("请选择 \(name) 文件夹，未修改任何文件。")
            case .conflict: return L10n.text("配置刚被其他进程修改，请重试；未覆盖原文件。")
            case .unavailable: return L10n.text("接入组件不可用，请重新安装 Fishtank。") }
        }
    }
    /// Used only from an explicit settings action; migration itself never reads/writes outside the sandbox.
    func configure(_ id: String, remove: Bool = false) {
        guard let agent = agent(id), agent.isBuiltIn, !busy.contains(id) else { return }
        do {
            guard let directory = try folder(for: agent) else { return }
            defer { directory.stopAccessingSecurityScopedResource() }
            guard let command = command(for: id) else { throw ConnectionError.unavailable }
            let file = directory.appendingPathComponent(agent.source == .codex ? "hooks.json" : "settings.json").resolvingSymlinksInPath()
            let original = FileManager.default.fileExists(atPath: file.path) ? try Data(contentsOf: file) : nil
            let updated = try AgentHookConfiguration.merge(original, source: agent.source, scriptPaths: paths(for: agent), command: command, remove: remove)
            if original != updated && !(remove && original == nil) {
                let latest = FileManager.default.fileExists(atPath: file.path) ? try Data(contentsOf: file) : nil
                guard latest == original else { throw ConnectionError.conflict }
                let permissions = ((try? FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions]) as? NSNumber)?.uint16Value ?? 0o600
                if let original {
                    let backup = directory.appendingPathComponent(file.lastPathComponent + ".fishtank-backup-" + UUID().uuidString)
                    try atomicWrite(original, to: backup, permissions: 0o600)
                }
                try atomicWrite(updated, to: file, permissions: permissions)
            }
            if remove { removeLocal(id); return }
            configurationChecks[id] = L10n.message("\(AgentHookConfiguration.events(for: agent.source).count) 项 hook 已安装")
            messages[id] = original == updated ? L10n.message("配置完整，已有命令保持不变。") : agent.source == .codex ? L10n.message("已安装缺少的 hook。请在 Codex /hooks 审阅新项；原有信任记录保留。") : L10n.message("接入已安装，请重新打开 Claude Code 会话。")
        } catch { messages[id] = L10n.message("操作未完成：\(safeDescription(error))") }
    }
    func check(_ id: String) {
        guard let agent = agent(id), !busy.contains(id) else { return }
        do {
            if agent.isBuiltIn {
                guard let directory = try folder(for: agent) else { return }
                defer { directory.stopAccessingSecurityScopedResource() }
                let file = directory.appendingPathComponent(agent.source == .codex ? "hooks.json" : "settings.json")
                let found = try AgentHookConfiguration.inspect(Data(contentsOf: file), source: agent.source, scriptPaths: paths(for: agent))
                let expected = AgentHookConfiguration.events(for: agent.source).count
                configurationChecks[id] = L10n.message("\(found.count)/\(expected) 项鱼缸 hook")
                guard found.count == expected else { messages[id] = L10n.message("接入配置不完整，点击「安装 / 修复」补齐。"); return }
            }
            guard receiverReady, bundledHook != nil else { throw ConnectionError.unavailable }
            let session = "fishtank-preview:check:" + UUID().uuidString
            probes[id] = session; busy.insert(id); messages[id] = L10n.message("正在检查本机事件通路…")
            let event = ClaudeHookEvent(id: UUID().uuidString, sessionID: session, project: L10n.text("接入检查"), event: "SessionStart", notificationType: nil, sentAt: Date(), source: agent.source)
            let probe = try AgentBridgeProbe(event: event); connections[id] = probe
            probe.start { [weak self] success in
                Task { @MainActor in
                    guard let self else { return }
                    if self.connections[id] === probe { self.connections.removeValue(forKey: id) }
                    if !success && self.probes[id] == session {
                        self.probes.removeValue(forKey: id); self.busy.remove(id)
                        self.messages[id] = L10n.message("接收器测试未通过，请重新打开 Fishtank 后重试。")
                    }
                }
            }
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard let self, self.probes[id] == session else { return }
                self.probes.removeValue(forKey: id); self.busy.remove(id)
                self.connections.removeValue(forKey: id)?.cancel()
                self.messages[id] = L10n.message("未收到测试事件。请检查接收器状态后重试。")
            }
        } catch { probes.removeValue(forKey: id); busy.remove(id); messages[id] = L10n.message("检查未完成：\(safeDescription(error))") }
    }
    /// Create private temporary files with their final mode before writing sensitive configuration.
    private func atomicWrite(_ data: Data, to destination: URL, permissions: UInt16) throws {
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(".fishtank-" + UUID().uuidString)
        let fd = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL, mode_t(permissions))
        guard fd >= 0 else { throw CocoaError(.fileWriteNoPermission) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close(); try? FileManager.default.removeItem(at: temporary) }
        guard fchmod(fd, mode_t(permissions)) == 0 else { throw CocoaError(.fileWriteNoPermission) }
        try handle.write(contentsOf: data); try handle.synchronize(); try handle.close()
        guard rename(temporary.path, destination.path) == 0 else { throw CocoaError(.fileWriteUnknown) }
    }
    private func safeDescription(_ error: Error) -> String {
        if let error = error as? ConnectionError { return error.localizedDescription }
        if error is AquariumError { return L10n.text("配置格式无法安全处理，未覆盖原文件。") }
        return L10n.text("请检查所选配置文件夹的权限和文件格式。原配置与信任记录未被重置。")
    }
}
#endif
