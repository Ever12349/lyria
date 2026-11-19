import Darwin
import Foundation
import LyriaCore

enum MCPBridge {
    private static let budget: TimeInterval = 3

    static func run() -> Never {
        let deadline = Date().addingTimeInterval(budget)
        var launched = false
        var delay: TimeInterval = 0.05
        while true {
            let fd = connectProbe()
            let alive = processAlive()
            let exhausted = Date() >= deadline
            switch AgentContract.bridgeTick(
                socketConnected: fd != nil,
                processAlive: alive,
                launched: launched,
                budgetExhausted: exhausted
            ) {
            case .connected:
                guard let fd else { fail(AgentCopy.launchFailed) }
                pump(fd)
            case .launch:
                if let fd { close(fd) }
                guard spawnGUI() else { fail(AgentCopy.launchFailed) }
                launched = true
                sleep(&delay, deadline: deadline)
            case .waiting:
                if let fd { close(fd) }
                sleep(&delay, deadline: deadline)
            case .fail(let message):
                if let fd { close(fd) }
                fail(message)
            }
        }
    }

    private static func sleep(_ delay: inout TimeInterval, deadline: Date) {
        let remaining = deadline.timeIntervalSinceNow
        guard remaining > 0 else { return }
        Thread.sleep(forTimeInterval: min(delay, remaining))
        delay = min(delay * 2, 0.4)
    }

    private static func connectProbe() -> Int32? {
        guard let path = socketPath() else { return nil }
        return UnixEndpoint.connect(path)
    }

    private static func socketPath() -> String? {
        try? SupportPaths.mcpSocketURL().path
    }

    private static func processAlive() -> Bool {
        guard let url = try? SupportPaths.instanceLockURL(),
              let text = try? String(contentsOf: url, encoding: .utf8),
              let pid = pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)),
              pid > 0
        else { return false }
        if kill(pid, 0) == 0 { return true }
        return errno == EPERM
    }

    private static func spawnGUI() -> Bool {
        guard let executable = Bundle.main.executableURL?.path ?? CommandLine.arguments.first else { return false }
        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        guard posix_spawn_file_actions_init(&actions) == 0,
              posix_spawnattr_init(&attributes) == 0
        else { return false }
        defer {
            posix_spawn_file_actions_destroy(&actions)
            posix_spawnattr_destroy(&attributes)
        }
        let devNull = open("/dev/null", O_RDWR)
        guard devNull >= 0 else { return false }
        defer { close(devNull) }
        guard posix_spawn_file_actions_adddup2(&actions, devNull, STDIN_FILENO) == 0,
              posix_spawn_file_actions_adddup2(&actions, devNull, STDOUT_FILENO) == 0,
              posix_spawn_file_actions_adddup2(&actions, devNull, STDERR_FILENO) == 0,
              posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETSID)) == 0
        else { return false }
        var pid: pid_t = 0
        let result = executable.withCString { path in
            argv(path) { arguments in
                posix_spawn(&pid, path, &actions, &attributes, arguments, environ)
            }
        }
        return result == 0
    }

    private static func argv<T>(_ path: UnsafePointer<CChar>, _ body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> T) -> T {
        let copy = strdup(path)
        defer { free(copy) }
        var arguments: [UnsafeMutablePointer<CChar>?] = [copy, nil]
        return arguments.withUnsafeMutableBufferPointer { buffer in
            body(buffer.baseAddress!)
        }
    }

    private static func pump(_ fd: Int32) -> Never {
        let input = Thread {
            var buffer = [UInt8](repeating: 0, count: 16_384)
            while true {
                let count = Darwin.read(STDIN_FILENO, &buffer, buffer.count)
                if count == 0 {
                    shutdown(fd, SHUT_WR)
                    return
                }
                if count < 0 {
                    if errno == EINTR { continue }
                    shutdown(fd, SHUT_WR)
                    return
                }
                var sent = 0
                while sent < count {
                    let wrote = Darwin.write(fd, buffer[sent...].withUnsafeBytes { $0.baseAddress }, count - sent)
                    if wrote < 0 {
                        if errno == EINTR { continue }
                        return
                    }
                    sent += wrote
                }
            }
        }
        input.start()
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while true {
            let count = Darwin.read(fd, &buffer, buffer.count)
            if count == 0 { break }
            if count < 0 {
                if errno == EINTR { continue }
                break
            }
            var sent = 0
            while sent < count {
                let wrote = Darwin.write(STDOUT_FILENO, buffer[sent...].withUnsafeBytes { $0.baseAddress }, count - sent)
                if wrote < 0 {
                    if errno == EINTR { continue }
                    break
                }
                sent += wrote
            }
        }
        close(fd)
        exit(0)
    }

    private static func fail(_ message: String) -> Never {
        let line = AgentJSON.text([
            "jsonrpc": "2.0",
            "id": NSNull(),
            "error": ["code": -32000, "message": message],
        ])
        fputs(line + "\n", stdout)
        fputs(message + "\n", stderr)
        exit(1)
    }
}
