import XCTest
import LyriaCore

final class MenuBarUpNextTests: XCTestCase {
    func testTakesNextThenWrapsExcludingCurrent() {
        // Queue A B C D E, current C (2) → D E A
        XCTAssertEqual(
            MenuBarUpNext.indices(count: 5, currentIndex: 2, limit: 3),
            [3, 4, 0]
        )
    }

    func testCurrentAtEndWrapsToStart() {
        XCTAssertEqual(
            MenuBarUpNext.indices(count: 5, currentIndex: 4, limit: 3),
            [0, 1, 2]
        )
    }

    func testCurrentAtStartOnlyUsesTail() {
        XCTAssertEqual(
            MenuBarUpNext.indices(count: 5, currentIndex: 0, limit: 3),
            [1, 2, 3]
        )
    }

    func testSingleCurrentYieldsEmpty() {
        XCTAssertEqual(MenuBarUpNext.indices(count: 1, currentIndex: 0), [])
    }

    func testEmptyQueue() {
        XCTAssertEqual(MenuBarUpNext.indices(count: 0, currentIndex: nil), [])
        XCTAssertEqual(MenuBarUpNext.indices(count: 0, currentIndex: 0), [])
    }

    func testNoCurrentUsesPrefix() {
        XCTAssertEqual(
            MenuBarUpNext.indices(count: 5, currentIndex: nil, limit: 3),
            [0, 1, 2]
        )
    }

    func testOutOfRangeCurrentTreatedAsNoCurrent() {
        XCTAssertEqual(
            MenuBarUpNext.indices(count: 3, currentIndex: 9, limit: 2),
            [0, 1]
        )
    }

    func testLimitCapsResults() {
        XCTAssertEqual(
            MenuBarUpNext.indices(count: 10, currentIndex: 0, limit: 3),
            [1, 2, 3]
        )
        XCTAssertEqual(
            MenuBarUpNext.indices(count: 4, currentIndex: 1, limit: 2),
            [2, 3]
        )
    }
}
