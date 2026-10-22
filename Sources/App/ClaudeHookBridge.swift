#if os(macOS)
import AppKit
import Network

/// A bounded, authenticated loopback HTTP endpoint. Runs all socket state on one queue.
final class ClaudeHookBridge {
    static var defaultConfigurationURL: URL {
        #if DEBUG
        if let id = ProcessInfo.processInfo.environment["FISHTANK_UI_TEST_ID"], UUID(uuidString: id) != nil {
            return FileManager.default.temporaryDirectory.appendingPathComponent("FishtankBridgeQA/" + id + "/bridge.json")
        }
        #endif
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FishtankApplePrototype/claude-bridge.json")
    }
    private let queue = DispatchQueue(label: "net.yahaha.fishtank.claude-hooks")
    private var listener: NWListener?
    private var connections: [UUID: NWConnection] = [:]
    private let token = UUID().uuidString + UUID().uuidString
    private let configurationURL: URL
    private let receiveEvent: (ClaudeHookEvent) -> Void
    private let report: (String) -> Void

    init(configurationURL: URL? = nil, receive: @escaping (ClaudeHookEvent) -> Void, report: @escaping (String) -> Void) {
        receiveEvent = receive
        self.report = report
        self.configurationURL = configurationURL ?? Self.defaultConfigurationURL
    }

    func start() {
        queue.async { [self] in
            do {
                let parameters = NWParameters.tcp
                parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
                let server = try NWListener(using: parameters)
                listener = server
                server.stateUpdateHandler = { [weak self, weak server] state in
                    guard let self else { return }
                    switch state {
                    case .ready:
                        guard let port = server?.port else { return }
                        do {
                            try FileManager.default.createDirectory(at: self.configurationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                            let data = try JSONSerialization.data(withJSONObject: ["url": "http://127.0.0.1:\(port.rawValue)/claude", "token": self.token])
                            let temporary = self.configurationURL.deletingLastPathComponent().appendingPathComponent(".claude-" + UUID().uuidString)
                            defer { try? FileManager.default.removeItem(at: temporary) }
                            guard FileManager.default.createFile(atPath: temporary.path, contents: data,
                                                                 attributes: [.posixPermissions: 0o600]) else { throw CocoaError(.fileWriteUnknown) }
                            let result = temporary.path.withCString { source in
                                self.configurationURL.path.withCString { destination in rename(source, destination) }
                            }
                            guard result == 0 else { throw CocoaError(.fileWriteUnknown) }
                            self.report("Claude Code · 接收器已就绪")
                        } catch { self.report("Claude Code · 无法保存接入配置") ; server?.cancel() }
                    case .failed: self.report("Claude Code · 接收器启动失败")
                    default: break
                    }
                }
                server.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
                server.start(queue: queue)
            } catch { report("Claude Code · 接收器启动失败") }
        }
    }

    private func accept(_ connection: NWConnection) {
        guard connections.count < 16 else { connection.cancel(); return }
        let id = UUID()
        connections[id] = connection
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + 2) { [weak self, weak connection] in
            connection?.cancel(); self?.connections.removeValue(forKey: id)
        }
        read(connection, id: id, buffer: Data())
    }

    private func finish(_ connection: NWConnection, id: UUID, code: Int) {
        let reason = code == 200 ? "OK" : "Rejected"
        let response = Data("HTTP/1.1 \(code) \(reason)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8)
        connection.send(content: response, completion: .contentProcessed { [weak self] _ in
            connection.cancel(); self?.connections.removeValue(forKey: id)
        })
    }

    private func read(_ connection: NWConnection, id: UUID, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, complete, error in
            guard let self else { return }
            var bytes = buffer
            bytes.append(data ?? Data())
            guard bytes.count <= 16384 else { self.finish(connection, id: id, code: 413); return }
            if let split = bytes.range(of: Data("\r\n\r\n".utf8)) {
                guard split.lowerBound <= 4096,
                      let header = String(data: bytes[..<split.lowerBound], encoding: .utf8) else {
                    self.finish(connection, id: id, code: 400); return
                }
                let lines = header.components(separatedBy: "\r\n")
                guard ["POST /claude HTTP/1.1", "POST /events HTTP/1.1"].contains(lines.first ?? "") else { self.finish(connection, id: id, code: 404); return }
                var headers: [String: String] = [:]
                for line in lines.dropFirst() {
                    let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
                    guard parts.count == 2, headers[parts[0].lowercased()] == nil else { self.finish(connection, id: id, code: 400); return }
                    headers[parts[0].lowercased()] = parts[1].trimmingCharacters(in: .whitespaces)
                }
                guard headers["authorization"] == "Bearer \(self.token)" else { self.finish(connection, id: id, code: 401); return }
                guard headers["transfer-encoding"] == nil, let size = headers["content-length"].flatMap(Int.init),
                      (1...8192).contains(size) else { self.finish(connection, id: id, code: 400); return }
                let body = bytes[split.upperBound...]
                if body.count >= size {
                    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
                    guard body.count == size, let event = try? decoder.decode(ClaudeHookEvent.self, from: Data(body)),
                          event.isValid, abs(event.sentAt.timeIntervalSinceNow) < 60 else {
                        self.finish(connection, id: id, code: 422); return
                    }
                    self.receiveEvent(event)
                    self.finish(connection, id: id, code: 200)
                    return
                }
            }
            guard error == nil, !complete else { connection.cancel(); self.connections.removeValue(forKey: id); return }
            self.read(connection, id: id, buffer: bytes)
        }
    }
}
#endif
