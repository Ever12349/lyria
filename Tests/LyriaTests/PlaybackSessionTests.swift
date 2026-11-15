import XCTest
import LyriaCore

final class PlaybackSessionTests: XCTestCase {
    func testInitDropsOneShots() {
        let queue = PlaybackQueue(
            items: [.track("a"), .oneShot("file://x"), .track("b")],
            source: [.track("a"), .oneShot("file://x"), .track("b")],
            currentIndex: 1
        )
        let session = PlaybackSession(queue: queue, positionMs: 1200)
        XCTAssertEqual(session.items, ["a", "b"])
        XCTAssertEqual(session.source, ["a", "b"])
        XCTAssertNil(session.currentID)
        XCTAssertEqual(session.positionMs, 1200)
    }

    func testAdoptKeepsUnplayableCurrentWhenStillInLibrary() {
        let session = PlaybackSession(items: ["a", "b", "c"], source: ["a", "b", "c"], currentID: "b", positionMs: 40)
        let adopted = session.adopted(existingIDs: ["a", "b", "c"], isPlayable: { $0 != "b" })
        XCTAssertEqual(adopted.currentID, "b")
        XCTAssertEqual(adopted.positionMs, 40)
        XCTAssertEqual(adopted.items, ["a", "b", "c"])
    }

    func testAdoptPicksNextPlayableAfterDeletedCurrentAndWraps() {
        let session = PlaybackSession(items: ["a", "gone", "bad", "c"], source: ["a", "gone", "bad", "c"], currentID: "gone", positionMs: 99)
        let adopted = session.adopted(existingIDs: ["a", "bad", "c"], isPlayable: { $0 != "bad" })
        XCTAssertEqual(adopted.items, ["a", "bad", "c"])
        XCTAssertEqual(adopted.currentID, "c")
        XCTAssertEqual(adopted.positionMs, 0)
    }

    func testAdoptWrapsToHeadWhenNothingPlayableAfterDeletedCurrent() {
        let session = PlaybackSession(items: ["a", "gone"], source: ["a", "gone"], currentID: "gone", positionMs: 5)
        let adopted = session.adopted(existingIDs: ["a"], isPlayable: { $0 == "a" })
        XCTAssertEqual(adopted.currentID, "a")
        XCTAssertEqual(adopted.positionMs, 0)
    }

    func testAdoptClearsWhenNoPlayableTracksRemain() {
        let session = PlaybackSession(items: ["gone", "bad"], source: ["gone", "bad"], currentID: "gone", positionMs: 10)
        let adopted = session.adopted(existingIDs: ["bad"], isPlayable: { _ in false })
        XCTAssertEqual(adopted, .empty)
    }

    func testQueueRoundTripPreservesOrderAndIndex() {
        let session = PlaybackSession(items: ["c", "a", "b"], source: ["a", "b", "c"], currentID: "a", positionMs: 15)
        let queue = session.queue(shuffle: true, repeatMode: .all)
        XCTAssertEqual(queue.items.map(\.trackID), ["c", "a", "b"])
        XCTAssertEqual(queue.source.map(\.trackID), ["a", "b", "c"])
        XCTAssertEqual(queue.currentIndex, 1)
        XCTAssertTrue(queue.shuffle)
        XCTAssertEqual(queue.repeatMode, .all)
    }
}
