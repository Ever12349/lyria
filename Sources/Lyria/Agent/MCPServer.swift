import Darwin
import Foundation
import LyriaCore

enum UnixEndpoint {
    static func withAddress<T>(_ path: String, _ body: (UnsafePointer<sockaddr>, socklen_t) -> T) -> T? {
        var address = sockaddr_un()
        let limit = MemoryLayout.size(ofValue: address.sun_path)
        guard path.utf8.count < limit else { return nil }
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        _ = withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            path.withCString { source in
                strncpy(buffer.baseAddress?.assumingMemoryBound(to: CChar.self), source, limit - 1)
            }
        }
        let length = socklen_t(MemoryLayout<sockaddr_un>.size)
        return withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                body(socketAddress, length)
            }
        }
    }

    static func connect(_ path: String) -> Int32? {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        let connected = withAddress(path) { address, length in
            Darwin.connect(fd, address, length) == 0
        } ?? false
        guard connected else {
            close(fd)
            return nil
        }
        ignorePipe(fd)
        return fd
    }

    static func ignorePipe(_ fd: Int32) {
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
    }
}

final class LibraryGate: @unchecked Sendable {
    private let lock = NSLock()
    private var ready = false
    private var failure: String?
    private var waiters: [CheckedContinuation<String?, Never>] = []

    func markReady() {
        lock.lock()
        if failure == nil { ready = true }
        let pending = waiters
        waiters.removeAll()
        let message = failure
        lock.unlock()
        pending.forEach { $0.resume(returning: message) }
    }

    func markFailed(_ message: String) {
        lock.lock()
        failure = message
        ready = false
        let pending = waiters
        waiters.removeAll()
        lock.unlock()
        pending.forEach { $0.resume(returning: message) }
    }

    func wait() async -> String? {
        await withCheckedContinuation { continuation in
            lock.lock()
            if let failure {
                lock.unlock()
                continuation.resume(returning: failure)
                return
            }
            if ready {
                lock.unlock()
                continuation.resume(returning: nil)
                return
            }
            waiters.append(continuation)
            lock.unlock()
        }
    }
}

/// Line-delimited JSON-RPC over a Unix socket. One thread per connection, tools on the main actor.
final class MCPServer: @unchecked Sendable {
    static let maxLineLength = 1 << 20

    private let path: String
    private let service: MCPService
    private let state = NSLock()
    private var listenFD: Int32 = -1
    private var clientFDs: [Int32] = []
    private var closing = false

    init(path: String, service: MCPService) {
        self.path = path
        self.service = service
    }

    func start() throws {
        if FileManager.default.fileExists(atPath: path) {
            if let probe = UnixEndpoint.connect(path) {
                close(probe)
                throw MCPListenError.alreadyListening
            }
            unlink(path)
        }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw MCPListenError.bindFailed }
        let flags = fcntl(fd, F_GETFD)
        if flags >= 0 { _ = fcntl(fd, F_SETFD, flags | FD_CLOEXEC) }
        let bound = UnixEndpoint.withAddress(path) { address, length in
            bind(fd, address, length) == 0
        } ?? false
        guard bound, listen(fd, 8) == 0 else {
            close(fd)
            throw MCPListenError.bindFailed
        }
        chmod(path, 0o600)
        UnixEndpoint.ignorePipe(fd)
        state.lock()
        listenFD = fd
        closing = false
        state.unlock()
        Thread.detachNewThread { [weak self] in
            self?.acceptLoop()
        }
    }

    func stop() {
        state.lock()
        closing = true
        let listenFD = listenFD
        let clients = clientFDs
        self.listenFD = -1
        clientFDs.removeAll()
        state.unlock()
        if listenFD >= 0 { close(listenFD) }
        // Wake blocked reads. The connection thread writes any in-flight reply, then closes the fd.
        for fd in clients { _ = shutdown(fd, SHUT_RD) }
        unlink(path)
    }

    private func acceptLoop() {
        while true {
            state.lock()
            let listenFD = listenFD
            let closing = closing
            state.unlock()
            if closing || listenFD < 0 { return }
            let client = accept(listenFD, nil, nil)
            if client < 0 { return }
            UnixEndpoint.ignorePipe(client)
            state.lock()
            if closing {
                state.unlock()
                close(client)
                return
            }
            clientFDs.append(client)
            state.unlock()
            Thread.detachNewThread { [weak self] in
                self?.serve(client)
            }
        }
    }

    private func serve(_ fd: Int32) {
        let connection = Int32(fd)
        while let line = readLine(fd) {
            let reply = waitForReply(line, connection: connection)
            if let reply {
                let data = Data((reply + "\n").utf8)
                data.withUnsafeBytes { buffer in
                    guard let base = buffer.baseAddress else { return }
                    _ = Darwin.write(fd, base, buffer.count)
                }
            }
            if isClosing {
                break
            }
        }
        close(fd)
        state.lock()
        clientFDs.removeAll { $0 == fd }
        state.unlock()
        Task { @MainActor in
            self.service.closed(connection: connection)
        }
    }

    private var isClosing: Bool {
        state.lock()
        defer { state.unlock() }
        return closing
    }

    private func waitForReply(_ line: String, connection: Int32) -> String? {
        let box = ReplyBox()
        let semaphore = DispatchSemaphore(value: 0)
        Task { @MainActor in
            box.text = await self.service.handle(line: line, connection: connection)
            semaphore.signal()
        }
        semaphore.wait()
        return box.text
    }

    private func readLine(_ fd: Int32) -> String? {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(256)
        var byte: UInt8 = 0
        while true {
            let count = Darwin.read(fd, &byte, 1)
            if count == 0 { return nil }
            if count < 0 {
                if errno == EINTR { continue }
                return nil
            }
            if byte == 10 { break }
            bytes.append(byte)
            if bytes.count > Self.maxLineLength { return nil }
        }
        return String(bytes: bytes, encoding: .utf8)
    }
}

private final class ReplyBox: @unchecked Sendable {
    var text: String?
}

enum MCPListenError: Error {
    case alreadyListening
    case bindFailed
}

@MainActor
final class MCPService {
    private let library: LibraryStore
    private weak var session: AppSession?
    private let gate: LibraryGate
    private let commands: AgentCommands
    private var server: MCPServer?
    private var listening = false
    private var libraryIsReady = false
    private var initialized: Set<Int32> = []

    init(library: LibraryStore, gate: LibraryGate, commands: AgentCommands) {
        self.library = library
        self.gate = gate
        self.commands = commands
    }

    func bind(_ session: AppSession) {
        self.session = session
    }

    func startIfEnabled() async {
        let enabled = await library.isMCPEnabled()
        session?.mcpEnabled = enabled
        guard enabled else { return }
        startListening()
    }

    func apply(_ enabled: Bool) async -> Bool {
        do {
            try await library.setMCPEnabled(enabled)
        } catch {
            return false
        }
        if enabled {
            startListening()
            if libraryIsReady { gate.markReady() }
        } else {
            stopListening()
        }
        return true
    }

    func libraryReady() {
        libraryIsReady = true
        gate.markReady()
    }

    func failLibrary(_ message: String) {
        gate.markFailed(message)
        stopListening()
    }

    func closed(connection: Int32) {
        initialized.remove(connection)
    }

    private func startListening() {
        guard !listening else { return }
        guard let path = try? SupportPaths.mcpSocketURL().path else { return }
        let server = MCPServer(path: path, service: self)
        do {
            try server.start()
            self.server = server
            listening = true
        } catch {
            fputs("Lyria MCP listen failed\n", stderr)
        }
    }

    private func stopListening() {
        server?.stop()
        server = nil
        listening = false
        initialized.removeAll()
    }

    func handle(line: String, connection: Int32) async -> String? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return AgentJSON.text(rpcError(id: NSNull(), code: -32700, message: "Parse error"))
        }
        let method = object["method"] as? String ?? ""
        let hasID = object.keys.contains("id")
        if !hasID {
            if method == "notifications/initialized" {
                initialized.insert(connection)
            }
            return nil
        }
        let id = object["id"] ?? NSNull()
        if method != "initialize", method != "ping", !initialized.contains(connection) {
            return AgentJSON.text(rpcError(id: id, code: -32600, message: "initialize required"))
        }
        switch method {
        case "initialize":
            let params = object["params"] as? [String: Any]
            let requested = params?["protocolVersion"] as? String
            initialized.insert(connection)
            return AgentJSON.text(rpcResult(id: id, result: [
                "protocolVersion": AgentCopy.negotiatedProtocolVersion(requested),
                "capabilities": ["tools": [String: Any]()],
                "serverInfo": ["name": "lyria", "version": AgentCopy.productVersion],
                "instructions": "Lyria 播放本机曲库。先 lyria_search，再用返回的 id 调用 lyria_play。",
            ]))
        case "ping":
            return AgentJSON.text(rpcResult(id: id, result: [String: Any]()))
        case "tools/list":
            return AgentJSON.text(rpcResult(id: id, result: ["tools": toolDefinitions()]))
        case "tools/call":
            let params = object["params"] as? [String: Any]
            let name = params?["name"] as? String ?? ""
            let arguments = params?["arguments"] as? [String: Any] ?? [:]
            let result = await callTool(name: name, arguments: arguments)
            if let error = result.error {
                return AgentJSON.text(rpcError(id: id, code: error.code, message: error.message))
            }
            return AgentJSON.text(rpcResult(id: id, result: result.body))
        default:
            return AgentJSON.text(rpcError(id: id, code: -32601, message: "Method not found"))
        }
    }

    private struct ProtocolError {
        var code: Int
        var message: String
    }

    private struct ToolCall {
        var body: [String: Any] = [:]
        var error: ProtocolError?
    }

    private func callTool(name: String, arguments: [String: Any]) async -> ToolCall {
        guard AgentCopy.toolNames.contains(name) else {
            return ToolCall(error: ProtocolError(code: -32602, message: "Unknown tool: \(name)"))
        }
        if let blocked = await gate.wait() {
            return ToolCall(body: toolContent(AgentFailure(error: PlaybackErrorCode.notReady, message: blocked).jsonObject(), isError: true))
        }
        guard let reply = await commands.executeTool(name: name, arguments: arguments) else {
            return ToolCall(error: ProtocolError(code: -32602, message: "Unknown tool: \(name)"))
        }
        switch reply {
        case .success(let body):
            return ToolCall(body: toolContent(body, isError: false))
        case .failure(let failure):
            return product(failure)
        }
    }

    private func product(_ failure: AgentFailure) -> ToolCall {
        ToolCall(body: toolContent(failure.jsonObject(), isError: true))
    }

    private func toolContent(_ body: [String: Any], isError: Bool) -> [String: Any] {
        [
            "content": [["type": "text", "text": AgentJSON.text(body)]],
            "structuredContent": body,
            "isError": isError,
        ]
    }

    private func toolDefinitions() -> [[String: Any]] {
        [
            tool("lyria_status", "当前曲、播放状态、进度、随机、重复、音量和队列长度", [:]),
            tool("lyria_play", "id 按曲库表的「播放」处理：队列换成曲库顺序，并从这首开始。uri 为 file:// 一次性点播，都空则继续播放。两者不能同时填。", [
                "id": ["type": "string"],
                "uri": ["type": "string"],
            ]),
            tool("lyria_pause", "暂停。重复调用返回当前状态。", [:]),
            tool("lyria_toggle", "播放和暂停切换。", [:]),
            tool("lyria_next", "下一首。", [:]),
            tool("lyria_previous", "上一首。", [:]),
            tool("lyria_seek", "把进度跳到 positionMs 毫秒。", ["positionMs": ["type": "integer"]], required: ["positionMs"]),
            tool("lyria_shuffle", "设定随机播放。值相同则不重排。", ["enabled": ["type": "boolean"]], required: ["enabled"]),
            tool("lyria_repeat", "设定重复：off、all 或 one。", ["mode": ["type": "string", "enum": ["off", "all", "one"]]], required: ["mode"]),
            tool("lyria_search", "按标题、艺人或专辑搜索曲库。", [
                "q": ["type": "string"],
                "limit": ["type": "integer"],
            ], required: ["q"]),
            tool("lyria_queue_list", "当前播放队列。", [:]),
            tool("lyria_queue_add", "加入队列。id 和 uri 恰好填一个。不传 position 时加到队尾；next 插到当前曲后面，不开始播放。", [
                "id": ["type": "string"],
                "uri": ["type": "string"],
                "position": ["type": "string", "enum": ["next", "end"]],
            ]),
            tool("lyria_queue_clear", "清空队列并停止播放。", [:]),
        ]
    }

    private func tool(
        _ name: String,
        _ description: String,
        _ properties: [String: Any],
        required: [String] = []
    ) -> [String: Any] {
        var schema: [String: Any] = ["type": "object", "properties": properties]
        if !required.isEmpty { schema["required"] = required }
        return ["name": name, "description": description, "inputSchema": schema]
    }

    private func rpcResult(id: Any, result: [String: Any]) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id, "result": result]
    }

    private func rpcError(id: Any, code: Int, message: String) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]]
    }
}
