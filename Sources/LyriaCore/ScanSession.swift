import Foundation

/// One scan's phase and percent. The library page reads this instead of separate flags.
public struct ScanSession: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case idle
        case running
        case completed
        case failed
        case cancelled
    }

    public var phase: Phase
    public var percent: Int

    public init(phase: Phase, percent: Int) {
        self.phase = phase
        self.percent = percent
    }

    public static let idle = ScanSession(phase: .idle, percent: 0)

    public var isRunning: Bool { phase == .running }

    /// Percent while files are still being scheduled. The caller sets 100 only after the scan returns.
    public static func percent(done: Int, total: Int) -> Int {
        guard total > 0 else { return 100 }
        return min(99, Int((Double(done) / Double(total) * 100).rounded()))
    }

    /// Library reloads during a scan are at most once per `interval` (default 0.5s).
    public static func shouldReload(
        now: TimeInterval,
        lastReload: TimeInterval?,
        interval: TimeInterval = 0.5
    ) -> Bool {
        guard let lastReload else { return true }
        return now - lastReload >= interval
    }
}
