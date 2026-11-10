import XCTest
import LyriaCore

final class TrackSelectionTests: XCTestCase {
    private let table = ["a", "b", "c", "d", "e"]

    func testPlainClickReplacesSelectionAndMovesAnchor() {
        let start = TrackSelectionState(ids: ["a", "c"], anchor: "a")
        let next = TrackSelection.click("e", command: false, shift: false, state: start, orderedIDs: table)
        XCTAssertEqual(next, TrackSelection.replace("e"))
        XCTAssertEqual(next.ids, ["e"])
        XCTAssertEqual(next.anchor, "e")
    }

    func testCommandClickTogglesAndAlwaysMovesAnchor() {
        let added = TrackSelection.toggle("b", in: TrackSelectionState(ids: ["a"], anchor: "a"))
        XCTAssertEqual(added.ids, ["a", "b"])
        XCTAssertEqual(added.anchor, "b")

        let removed = TrackSelection.toggle("a", in: added)
        XCTAssertEqual(removed.ids, ["b"])
        XCTAssertEqual(removed.anchor, "a")

        let emptied = TrackSelection.click("b", command: true, shift: false, state: removed, orderedIDs: table)
        XCTAssertEqual(emptied.ids, [])
        XCTAssertEqual(emptied.anchor, "b")
    }

    func testShiftClickSelectsTheInclusiveRangeWithoutMovingAnchor() {
        let anchored = TrackSelectionState(ids: ["b"], anchor: "b")
        let downward = TrackSelection.range(to: "d", in: anchored, orderedIDs: table)
        XCTAssertEqual(downward.ids, ["b", "c", "d"])
        XCTAssertEqual(downward.anchor, "b")

        let upward = TrackSelection.range(to: "a", in: anchored, orderedIDs: table)
        XCTAssertEqual(upward.ids, ["a", "b"])
        XCTAssertEqual(upward.anchor, "b")

        let scattered = TrackSelectionState(ids: ["a", "e"], anchor: "e")
        let replaced = TrackSelection.click("c", command: true, shift: true, state: scattered, orderedIDs: table)
        XCTAssertEqual(replaced.ids, ["c", "d", "e"])
        XCTAssertEqual(replaced.anchor, "e")
    }

    func testShiftClickWithNoUsableAnchorSelectsOnlyThatRow() {
        let missing = TrackSelection.range(to: "c", in: .empty, orderedIDs: table)
        XCTAssertEqual(missing, TrackSelectionState(ids: ["c"], anchor: nil))

        let stale = TrackSelectionState(ids: ["a"], anchor: "gone")
        let next = TrackSelection.range(to: "d", in: stale, orderedIDs: table)
        XCTAssertEqual(next.ids, ["d"])
        XCTAssertEqual(next.anchor, "gone")

        let unknown = TrackSelection.range(to: "missing", in: TrackSelectionState(ids: ["a"], anchor: "a"), orderedIDs: table)
        XCTAssertEqual(unknown.ids, ["a"])
        XCTAssertEqual(unknown.anchor, "a")
    }

    func testSelectAllUsesTheTableAndClearDropsTheAnchor() {
        let anchored = TrackSelectionState(ids: ["b"], anchor: "b")
        let all = TrackSelection.selectAll(orderedIDs: table, state: anchored)
        XCTAssertEqual(all.ids, Set(table))
        XCTAssertEqual(all.anchor, "b")

        let stillEmptyAnchor = TrackSelection.selectAll(orderedIDs: ["a"], state: .empty)
        XCTAssertEqual(stillEmptyAnchor, TrackSelectionState(ids: ["a"], anchor: nil))
        XCTAssertEqual(TrackSelection.selectAll(orderedIDs: [], state: anchored).ids, [])
        XCTAssertEqual(TrackSelection.selectAll(orderedIDs: [], state: anchored).anchor, "b")

        XCTAssertEqual(TrackSelection.clear(), .empty)
    }

    func testPruneDropsDeadIdsButKeepsALiveAnchorThatIsNotSelected() {
        let state = TrackSelectionState(ids: ["a", "gone"], anchor: "a")
        let pruned = TrackSelection.prune(state, keeping: ["a", "b"])
        XCTAssertEqual(pruned.ids, ["a"])
        XCTAssertEqual(pruned.anchor, "a")

        let anchorOff = TrackSelectionState(ids: ["b"], anchor: "a")
        XCTAssertEqual(TrackSelection.prune(anchorOff, keeping: ["a", "b"]).anchor, "a")
        XCTAssertNil(TrackSelection.prune(anchorOff, keeping: ["b"]).anchor)
    }

    func testOrderedIdsFollowTheTableThenAppendUnknownSelections() {
        let selected: Set<String> = ["e", "b", "z", "b"]
        XCTAssertEqual(
            TrackSelection.orderedIDs(selected: selected, orderedIDs: ["a", "b", "b", "c", "e"]),
            ["b", "e", "z"]
        )
    }

    func testMenuUsesTheWholeSelectionOnlyWhenTheRowIsAlreadySelected() {
        let selected: Set<String> = ["c", "a", "e"]
        XCTAssertEqual(
            TrackSelection.menuTrackIDs(trackID: "c", selected: selected, orderedIDs: table),
            ["a", "c", "e"]
        )
        XCTAssertEqual(
            TrackSelection.menuTrackIDs(trackID: "b", selected: selected, orderedIDs: table),
            ["b"]
        )
        XCTAssertEqual(
            TrackSelection.menuTrackIDs(trackID: "z", selected: ["z", "a"], orderedIDs: table),
            ["a", "z"]
        )
    }
}
