import XCTest
import LyriaCore

final class ScanSessionTests: XCTestCase {
    func testOnlyRunningShowsTheLibraryBar() {
        XCTAssertFalse(ScanSession.idle.isRunning)
        XCTAssertTrue(ScanSession(phase: .running, percent: 12).isRunning)
        XCTAssertFalse(ScanSession(phase: .completed, percent: 100).isRunning)
        XCTAssertFalse(ScanSession(phase: .failed, percent: 40).isRunning)
        XCTAssertFalse(ScanSession(phase: .cancelled, percent: 40).isRunning)
    }

    func testPercentCapsBelowCompletionUntilTheScanReturns() {
        XCTAssertEqual(ScanSession.percent(done: 0, total: 10), 0)
        XCTAssertEqual(ScanSession.percent(done: 1, total: 2), 50)
        XCTAssertEqual(ScanSession.percent(done: 10, total: 10), 99)
        XCTAssertEqual(ScanSession.percent(done: 0, total: 0), 100)
    }

    func testReloadThrottleIsAboutHalfASecond() {
        XCTAssertTrue(ScanSession.shouldReload(now: 10, lastReload: nil))
        XCTAssertFalse(ScanSession.shouldReload(now: 10.49, lastReload: 10))
        XCTAssertTrue(ScanSession.shouldReload(now: 10.5, lastReload: 10))
    }
}
