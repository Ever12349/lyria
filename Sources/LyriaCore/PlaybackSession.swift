import Foundation

/// Queue and playhead kept across launches. Shuffle, repeat, and volume stay in `PlaybackPreferences`.
public struct PlaybackSession: Equatable, Sendable, Codable {
    public var items: [String]
    public var source: [String]
    public var currentID: String?
    public var positionMs: Int

    public static let empty = PlaybackSession(items: [], source: [], currentID: nil, positionMs: 0)

    public init(items: [String] = [], source: [String] = [], currentID: String? = nil, positionMs: Int = 0) {
        self.items = items
        self.source = source
        self.currentID = currentID
        self.positionMs = max(0, positionMs)
    }

    /// Drops one-shot rows. A session that was only a one-shot becomes empty.
    public init(queue: PlaybackQueue, positionMs: Int) {
        let items = queue.items.compactMap(\.trackID)
        let source = queue.source.compactMap(\.trackID)
        self.init(
            items: items,
            source: source,
            currentID: queue.current?.trackID,
            positionMs: positionMs
        )
    }

    public var isEmpty: Bool { items.isEmpty }

    public func queue(shuffle: Bool, repeatMode: RepeatMode) -> PlaybackQueue {
        PlaybackQueue(
            items: items.map { .track($0) },
            source: source.map { .track($0) },
            currentIndex: currentID.flatMap { items.firstIndex(of: $0) },
            shuffle: shuffle,
            repeatMode: repeatMode
        )
    }

    /// Drops ids no longer in the library. If the current id is still present, it is kept even when unplayable.
    /// If it was removed, the next playable id after its old place is chosen, wrapping to the head; none clears the session.
    public func adopted(existingIDs: Set<String>, isPlayable: (String) -> Bool) -> PlaybackSession {
        let oldItems = items
        let oldIndex = currentID.flatMap { oldItems.firstIndex(of: $0) } ?? 0
        let nextItems = oldItems.filter { existingIDs.contains($0) }
        let nextSource = source.filter { existingIDs.contains($0) }
        if nextItems.isEmpty {
            return .empty
        }
        if let currentID, nextItems.contains(currentID) {
            return PlaybackSession(
                items: nextItems,
                source: nextSource,
                currentID: currentID,
                positionMs: positionMs
            )
        }
        let after = oldItems.dropFirst(oldIndex + 1).filter { nextItems.contains($0) && isPlayable($0) }
        if let id = after.first ?? nextItems.first(where: isPlayable) {
            return PlaybackSession(items: nextItems, source: nextSource, currentID: id, positionMs: 0)
        }
        return .empty
    }
}

public enum PlayAttempt: Equatable, Sendable {
    case play(PlaybackQueue, skipped: Int)
    case stop(PlaybackQueue)
}

extension PlaybackQueueRules {
    /// User-initiated play: start the current item if it can play, otherwise walk forward, wrapping once.
    /// Unplayable current is counted in `skipped`. Repeat mode does not affect the wrap.
    public static func startPlayback(queue: PlaybackQueue, isPlayable: (QueueItem) -> Bool) -> PlayAttempt {
        let items = queue.items
        guard !items.isEmpty else { return .stop(queue) }
        let start = queue.currentIndex.flatMap { items.indices.contains($0) ? $0 : nil } ?? 0
        if isPlayable(items[start]) {
            var next = queue
            next.currentIndex = start
            return .play(next, skipped: 0)
        }
        let count = items.count
        var skipped = 1
        var step = 1
        while step < count {
            let cursor = (start + step) % count
            if isPlayable(items[cursor]) {
                var next = queue
                next.currentIndex = cursor
                return .play(next, skipped: skipped)
            }
            skipped += 1
            step += 1
        }
        return .stop(queue)
    }
}
