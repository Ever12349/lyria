import AppKit
import Darwin
import Foundation

enum InstanceLock {
    private static var held: Int32 = -1

    /// Take the single-instance lock. A live holder is activated and this process should exit.
    static func becomePrimary() -> Bool {
        guard let url = try? SupportPaths.instanceLockURL() else {
            fputs("Lyria instance lock unavailable\n", stderr)
            return true
        }
        let fd = open(url.path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else {
            fputs("Lyria instance lock unavailable\n", stderr)
            return true
        }
        for _ in 0..<20 {
            if flock(fd, LOCK_EX | LOCK_NB) == 0 {
                writePID(fd)
                held = fd
                return true
            }
            if let pid = readPID(fd), pid != getpid(), processAlive(pid) {
                activate(pid)
                close(fd)
                return false
            }
            usleep(50_000)
        }
        close(fd)
        fputs("Lyria instance lock unavailable\n", stderr)
        return true
    }

    private static func writePID(_ fd: Int32) {
        _ = ftruncate(fd, 0)
        _ = lseek(fd, 0, SEEK_SET)
        let text = "\(getpid())\n"
        _ = text.withCString { Darwin.write(fd, $0, strlen($0)) }
    }

    private static func readPID(_ fd: Int32) -> pid_t? {
        var buffer = [CChar](repeating: 0, count: 64)
        _ = lseek(fd, 0, SEEK_SET)
        let count = Darwin.read(fd, &buffer, buffer.count - 1)
        guard count > 0 else { return nil }
        let text = String(cString: buffer).trimmingCharacters(in: .whitespacesAndNewlines)
        return pid_t(text)
    }

    private static func processAlive(_ pid: pid_t) -> Bool {
        if kill(pid, 0) == 0 { return true }
        return errno == EPERM
    }

    private static func activate(_ pid: pid_t) {
        guard let application = NSRunningApplication(processIdentifier: pid) else { return }
        application.activate(from: .current, options: [.activateAllWindows])
    }
}
