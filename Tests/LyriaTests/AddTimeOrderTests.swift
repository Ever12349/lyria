import XCTest
import LyriaCore

final class AddTimeOrderTests: XCTestCase {
    private struct Row {
        var id: String
        var addedAt: Int64
    }

    func testNewestAddedAtComesFirst() {
        let rows = [
            Row(id: "old", addedAt: 10),
            Row(id: "new", addedAt: 30),
            Row(id: "mid", addedAt: 20),
        ]
        let ids = AddTimeOrder.newestFirst(rows) { $0.addedAt }.map(\.id)
        XCTAssertEqual(ids, ["new", "mid", "old"])
    }

    func testEmptyAndSingleStayPut() {
        let none: [Row] = []
        XCTAssertTrue(AddTimeOrder.newestFirst(none) { $0.addedAt }.isEmpty)
        let only = [Row(id: "solo", addedAt: 1)]
        XCTAssertEqual(AddTimeOrder.newestFirst(only) { $0.addedAt }.map(\.id), ["solo"])
    }

    /// Position backfill stores small integers. A later add stores unix seconds.
    /// Descending order puts the new row first without a second key.
    func testPositionStampsSortBehindUnixSeconds() {
        let rows = [
            Row(id: "legacy", addedAt: 2),
            Row(id: "fresh", addedAt: 1_700_000_000),
            Row(id: "older-legacy", addedAt: 0),
        ]
        let ids = AddTimeOrder.newestFirst(rows) { $0.addedAt }.map(\.id)
        XCTAssertEqual(ids, ["fresh", "legacy", "older-legacy"])
    }

    /// Equal stamps must not grow an id tie-break. Swift's sort leaves them in arrival order.
    func testEqualStampsAreNotBrokenByIdentity() {
        let forward = [
            Row(id: "b", addedAt: 5),
            Row(id: "a", addedAt: 5),
            Row(id: "c", addedAt: 9),
        ]
        let reversed = [
            Row(id: "a", addedAt: 5),
            Row(id: "b", addedAt: 5),
            Row(id: "c", addedAt: 9),
        ]
        XCTAssertEqual(
            AddTimeOrder.newestFirst(forward) { $0.addedAt }.map(\.id),
            ["c", "b", "a"]
        )
        XCTAssertEqual(
            AddTimeOrder.newestFirst(reversed) { $0.addedAt }.map(\.id),
            ["c", "a", "b"]
        )
    }
}
