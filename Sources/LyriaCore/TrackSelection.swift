import Foundation

/// Selected track ids plus the shift-click anchor. Anchor is the last plain or ⌘ click.
public struct TrackSelectionState: Equatable, Sendable {
    public var ids: Set<String>
    public var anchor: String?

    public init(ids: Set<String> = [], anchor: String? = nil) {
        self.ids = ids
        self.anchor = anchor
    }

    public static let empty = TrackSelectionState()
}

/// Pure selection edits. The session applies the result; this type does not touch the library.
public enum TrackSelection {
    public static func replace(_ id: String) -> TrackSelectionState {
        TrackSelectionState(ids: [id], anchor: id)
    }

    /// ⌘-click. The anchor moves to `id` even when that id is toggled off.
    public static func toggle(_ id: String, in state: TrackSelectionState) -> TrackSelectionState {
        var ids = state.ids
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        return TrackSelectionState(ids: ids, anchor: id)
    }

    /// Inclusive ⇧ range from the anchor through `id`. Does not move the anchor.
    /// With no usable anchor, the selection becomes just `id` and the anchor stays as it was.
    public static func range(
        to id: String,
        in state: TrackSelectionState,
        orderedIDs: [String]
    ) -> TrackSelectionState {
        guard let end = orderedIDs.firstIndex(of: id) else { return state }
        guard let anchor = state.anchor, let start = orderedIDs.firstIndex(of: anchor) else {
            return TrackSelectionState(ids: [id], anchor: state.anchor)
        }
        let lower = min(start, end)
        let upper = max(start, end)
        return TrackSelectionState(ids: Set(orderedIDs[lower...upper]), anchor: anchor)
    }

    /// ⌘A /「全选」. Keeps the anchor. Ids outside `orderedIDs` are dropped.
    public static func selectAll(orderedIDs: [String], state: TrackSelectionState) -> TrackSelectionState {
        TrackSelectionState(ids: Set(orderedIDs), anchor: state.anchor)
    }

    public static func clear() -> TrackSelectionState {
        .empty
    }

    /// ⇧ wins over ⌘. Otherwise ⌘ toggles and a plain click replaces.
    public static func click(
        _ id: String,
        command: Bool,
        shift: Bool,
        state: TrackSelectionState,
        orderedIDs: [String]
    ) -> TrackSelectionState {
        if shift {
            return range(to: id, in: state, orderedIDs: orderedIDs)
        }
        if command {
            return toggle(id, in: state)
        }
        return replace(id)
    }

    public static func prune(_ state: TrackSelectionState, keeping liveIDs: Set<String>) -> TrackSelectionState {
        TrackSelectionState(
            ids: state.ids.intersection(liveIDs),
            anchor: state.anchor.flatMap { liveIDs.contains($0) ? $0 : nil }
        )
    }

    /// Table order, then any selected ids the table doesn't list (sorted).
    public static func orderedIDs(selected: Set<String>, orderedIDs: [String]) -> [String] {
        var seen = Set<String>()
        let inTable = orderedIDs.filter { selected.contains($0) && seen.insert($0).inserted }
        let extras = selected.subtracting(seen).sorted()
        return inTable + extras
    }

    /// Right-click / ⋯ : a row already selected acts on the whole selection; otherwise only that row.
    public static func menuTrackIDs(
        trackID: String,
        selected: Set<String>,
        orderedIDs: [String]
    ) -> [String] {
        guard selected.contains(trackID) else { return [trackID] }
        return Self.orderedIDs(selected: selected, orderedIDs: orderedIDs)
    }
}
