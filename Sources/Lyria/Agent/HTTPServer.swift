import Darwin
import Foundation
import LyriaCore

enum HTTPListenFailure: Error {
    case addressInUse
    case failed

    var message: String {
        switch self {
        case .addressInUse: return HTTPContract.portInUse
        case .failed: return HTTPContract.listenFailed
        }
    }
}

/// One loopback HTTP/1.1 connection, then close. Product commands run on the main actor.
final class HTTPServer: @unchecked Sendable {
    private let service: HTTPService
    private let state = NSLock()
    private var listenFD: Int32 = -1
    private var clientFDs: [Int32] = []
    private var closing = false

    init(service: HTTPService) {
        self.service = service
    }

    func start() throws {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw HTTPListenFailure.failed }
        let flags = fcntl(fd, F_GETFD)
        if flags >= 0 { _ = fcntl(fd, F_SETFD, flags | FD_CLOEXEC) }
        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        UnixEndpoint.ignorePipe(fd)

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(HTTPContract.port).bigEndian
        guard withUnsafeMutablePointer(to: &address.sin_addr, { inet_pton(AF_INET, "127.0.0.1", $0) == 1 }) else {
            close(fd)
            throw HTTPListenFailure.failed
        }
        let bound = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                Darwin.bind(fd, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
            }
        }
        if !bound || listen(fd, 8) != 0 {
            let error = errno
            close(fd)
            throw error == EADDRINUSE ? HTTPListenFailure.addressInUse : HTTPListenFailure.failed
        }

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
        for fd in clients { _ = shutdown(fd, SHUT_RD) }
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
            let flags = fcntl(client, F_GETFD)
            if flags >= 0 { _ = fcntl(client, F_SETFD, flags | FD_CLOEXEC) }
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
        defer {
            close(fd)
            state.lock()
            clientFDs.removeAll { $0 == fd }
            state.unlock()
        }
        switch readHeader(fd) {
        case .closed:
            return
        case .incomplete:
            write(fd, wait(HTTPContract.malformedRequest()))
        case .overflow:
            write(fd, wait(HTTPContract.headerOverflow()))
        case .text(let header):
            switch HTTPContract.bodyPlan(for: header) {
            case .reject(let response):
                write(fd, wait(response))
            case .ignore:
                write(fd, wait(HTTPContract.classify(headerBlock: header, body: Data())))
            case .read(let count):
                if count == 0 {
                    write(fd, wait(HTTPContract.classify(headerBlock: header, body: Data())))
                } else if let body = readBody(fd, count: count) {
                    write(fd, wait(HTTPContract.classify(headerBlock: header, body: body)))
                } else {
                    write(fd, wait(HTTPContract.shortBody()))
                }
            }
        }
    }

    private func wait(_ classification: HTTPClassification) -> Data {
        let box = DataBox()
        let semaphore = DispatchSemaphore(value: 0)
        Task { @MainActor in
            box.data = await self.service.handle(classification).encoded()
            semaphore.signal()
        }
        semaphore.wait()
        return box.data
    }

    private func wait(_ response: HTTPResponse) -> Data {
        wait(.response(response))
    }

    private enum HeaderRead {
        case text(String)
        case overflow
        case incomplete
        case closed
    }

    private func readHeader(_ fd: Int32) -> HeaderRead {
        var data = Data()
        var byte: UInt8 = 0
        while true {
            let count = Darwin.read(fd, &byte, 1)
            if count == 0 { return data.isEmpty ? .closed : .incomplete }
            if count < 0 {
                if errno == EINTR { continue }
                return data.isEmpty ? .closed : .incomplete
            }
            data.append(byte)
            if data.count > HTTPContract.maxHeaderBytes { return .overflow }
            if data.count >= 4, data.suffix(4).elementsEqual([13, 10, 13, 10]) {
                let header = data.dropLast(4)
                guard let text = String(data: header, encoding: .utf8) else { return .incomplete }
                return .text(text)
            }
        }
    }

    private func readBody(_ fd: Int32, count: Int) -> Data? {
        var data = Data()
        data.reserveCapacity(count)
        while data.count < count {
            var buffer = [UInt8](repeating: 0, count: count - data.count)
            let readCount = buffer.withUnsafeMutableBytes { raw in
                Darwin.read(fd, raw.baseAddress, raw.count)
            }
            if readCount == 0 { return nil }
            if readCount < 0 {
                if errno == EINTR { continue }
                return nil
            }
            data.append(contentsOf: buffer.prefix(readCount))
        }
        return data
    }

    private func write(_ fd: Int32, _ data: Data) {
        var offset = 0
        let bytes = [UInt8](data)
        while offset < bytes.count {
            let wrote = bytes.withUnsafeBytes { raw in
                Darwin.write(fd, raw.baseAddress! + offset, bytes.count - offset)
            }
            if wrote < 0 {
                if errno == EINTR { continue }
                return
            }
            if wrote == 0 { return }
            offset += wrote
        }
    }
}

private final class DataBox: @unchecked Sendable {
    var data = Data()
}

/// Opens and closes the loopback listener. Calls are serialized so a failed bind cannot undo a later success.
@MainActor
final class HTTPService {
    private let library: LibraryStore
    private let gate: LibraryGate
    private let commands: AgentCommands
    private weak var session: AppSession?
    private var server: HTTPServer?
    private var listening = false
    private var chain: Task<Void, Never>?

    init(library: LibraryStore, gate: LibraryGate, commands: AgentCommands) {
        self.library = library
        self.gate = gate
        self.commands = commands
    }

    func bind(_ session: AppSession) {
        self.session = session
    }

    func startIfEnabled() async {
        await enqueue { await self.applySaved() }
    }

    func setEnabled(_ enabled: Bool) {
        Task { await self.enqueue { await self.apply(enabled) } }
    }

    /// Library failure stops the port and leaves the saved switch alone.
    func failLibrary() {
        stopListening()
    }

    func handle(_ classification: HTTPClassification) async -> HTTPResponse {
        if let blocked = await gate.wait() {
            return HTTPContract.libraryBlocked(blocked)
        }
        switch classification {
        case .response(let response):
            return response
        case .action(let action):
            let reply = await commands.execute(action)
            switch reply {
            case .success(let object):
                return HTTPContract.success(object)
            case .failure(let failure):
                return HTTPContract.failure(failure)
            }
        }
    }

    private func applySaved() async {
        let enabled = await library.isHTTPEnabled()
        guard enabled else {
            session?.httpEnabled = false
            return
        }
        switch ensureListening() {
        case .success:
            session?.httpEnabled = true
        case .failure(let failure):
            session?.httpEnabled = false
            do {
                try await library.setHTTPEnabled(false)
                session?.showToast(failure.message)
            } catch {
                session?.showToast(AgentCopy.databaseFailed)
            }
        }
    }

    private func apply(_ enabled: Bool) async {
        if enabled {
            switch ensureListening() {
            case .success:
                do {
                    try await library.setHTTPEnabled(true)
                    session?.httpEnabled = true
                } catch {
                    stopListening()
                    session?.httpEnabled = false
                    session?.showToast(AgentCopy.databaseFailed)
                }
            case .failure(let failure):
                session?.httpEnabled = false
                session?.showToast(failure.message)
            }
        } else {
            do {
                try await library.setHTTPEnabled(false)
                stopListening()
                session?.httpEnabled = false
            } catch {
                session?.httpEnabled = listening
                session?.showToast(AgentCopy.databaseFailed)
            }
        }
    }

    private func ensureListening() -> Result<Void, HTTPListenFailure> {
        if listening { return .success(()) }
        let server = HTTPServer(service: self)
        do {
            try server.start()
            self.server = server
            listening = true
            return .success(())
        } catch let failure as HTTPListenFailure {
            return .failure(failure)
        } catch {
            return .failure(.failed)
        }
    }

    private func stopListening() {
        server?.stop()
        server = nil
        listening = false
    }

    private func enqueue(_ body: @escaping @MainActor () async -> Void) async {
        let previous = chain
        let task = Task { @MainActor in
            _ = await previous?.value
            await body()
        }
        chain = task
        await task.value
    }
}
