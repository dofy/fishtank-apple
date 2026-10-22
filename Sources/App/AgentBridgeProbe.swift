#if os(macOS)
import Foundation
import Network

/// A native authenticated receiver check. External adapter/hook execution is evidenced separately.
final class AgentBridgeProbe: @unchecked Sendable {
    private let queue = DispatchQueue(label: "net.yahaha.fishtank.agent-probe")
    private let connection: NWConnection
    private let request: Data
    private var finished = false
    private var result: ((Bool) -> Void)?
    init(event: ClaudeHookEvent) throws {
        let data = try Data(contentsOf: ClaudeHookBridge.defaultConfigurationURL)
        guard data.count <= 4096, let config = try JSONSerialization.jsonObject(with: data) as? [String: String],
              let value = config["url"], let url = URLComponents(string: value), url.scheme == "http", url.host == "127.0.0.1",
              url.path == "/claude", let port = url.port, (1...65535).contains(port), let token = config["token"],
              token.range(of: "^[A-Za-z0-9-]{32,128}$", options: .regularExpression) != nil else { throw CocoaError(.fileReadCorruptFile) }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .secondsSince1970
        let body = try encoder.encode(event)
        var bytes = Data("POST /events HTTP/1.1\r\nHost: 127.0.0.1\r\nAuthorization: Bearer \(token)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8)
        bytes.append(body); request = bytes
        connection = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: UInt16(port))!, using: .tcp)
    }
    func start(result: @escaping (Bool) -> Void) {
        self.result = result
        connection.stateUpdateHandler = { [weak self] state in
            guard let self, !self.finished else { return }
            switch state {
            case .ready:
                self.connection.send(content: self.request, completion: .contentProcessed { [weak self] error in
                    guard let self else { return }
                    if error != nil { self.finish(false) } else { self.read(Data()) }
                })
            case .failed: self.finish(false)
            default: break
            }
        }
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + 3) { [weak self] in self?.finish(false) }
    }
    func cancel() { queue.async { [self] in finished = true; result = nil; connection.cancel() } }
    private func read(_ buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] data, _, complete, error in
            guard let self, !self.finished else { return }
            var bytes = buffer; bytes.append(data ?? Data())
            if let end = bytes.range(of: Data("\r\n".utf8)) {
                self.finish(String(data: bytes[..<end.lowerBound], encoding: .utf8) == "HTTP/1.1 200 OK")
            } else if bytes.count >= 2048 || complete || error != nil { self.finish(false) }
            else { self.read(bytes) }
        }
    }
    private func finish(_ success: Bool) {
        guard !finished else { return }; finished = true
        connection.cancel(); let report = result; result = nil; report?(success)
    }
}
#endif
