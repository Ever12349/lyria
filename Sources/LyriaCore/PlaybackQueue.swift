import Foundation

public enum QueueItem: Hashable, Sendable {
    case track(String)
    case oneShot(String)

    public var trackID: String? {
        if case .track(let id) = self { return id }
        return nil
    }
}

public enum RepeatMode: String, CaseIterable, Sendable {
    case off
    case all
    case one

    public var label: String {
        switch self {
        case .off: return "关闭"
        case .all: return "全部"
        case .one: return "单曲"
        }
    }

    public var systemImage: String {
        switch self {
        case .off, .all: return "repeat"
        case .one: return "repeat.1"
        }
    }

    public var tooltip: String {
        switch self {
        case .off: return "重复关闭"
        case .all: return "重复全部"
        case .one: return "单曲循环"
        }
    }

    public var next: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }
}

public struct PlaybackQueue: Equatable, Sendable {
    /// Playback order. Equals `source` while shuffle is off.
    public var items: [QueueItem]
    /// Unshuffled queue order. Shuffle never discards this.
    public var source: [QueueItem]
    public var currentIndex: Int?
    public var shuffle: Bool
    public var repeatMode: RepeatMode

    public init(
        items: [QueueItem] = [],
        source: [QueueItem]? = nil,
        currentIndex: Int? = nil,
        shuffle: Bool = false,
        repeatMode: RepeatMode = .off
    ) {
        self.items = items
        self.source = source ?? items
        self.currentIndex = currentIndex
        self.shuffle = shuffle
        self.repeatMode = repeatMode
    }

    public var current: QueueItem? {
        guard let currentIndex, items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }
}

public enum PlaybackBlock: Equatable, Sendable {
    case missingFile
    case notDownloaded
    case unsupportedFormat
    case failed
}

public enum PlaybackErrorCode {
    public static let unsupportedFormat = "unsupported_format"
    public static let missingFile = "missing_file"
    public static let badRequest = "bad_request"
    public static let notReady = "not_ready"
    public static let failed = "failed"
    public static let notFound = "not_found"

    public static func code(for block: PlaybackBlock) -> String {
        switch block {
        case .missingFile: return missingFile
        case .notDownloaded: return missingFile
        case .unsupportedFormat: return unsupportedFormat
        case .failed: return failed
        }
    }
}

public enum PlaybackCopy {
    public static let alreadyQueued = "已在队列中"
    public static let nothingMore = "没有更多可播放的曲目"
    public static let nothingPlayable = "没有可播放的曲目"
    public static let notDownloaded = "文件尚未下载"
    public static let missingFile = "找不到文件"
    public static let unsupportedFormat = "无法播放此格式"
    public static let failed = "播放失败"

    public static func skipped(_ count: Int) -> String {
        "已跳过 \(count) 首无法播放的曲目"
    }

    public static func message(for block: PlaybackBlock) -> String {
        switch block {
        case .missingFile: return missingFile
        case .notDownloaded: return notDownloaded
        case .unsupportedFormat: return unsupportedFormat
        case .failed: return failed
        }
    }

    public static func message(forCode code: String) -> String {
        switch code {
        case PlaybackErrorCode.unsupportedFormat: return unsupportedFormat
        case PlaybackErrorCode.missingFile: return missingFile
        case PlaybackErrorCode.notReady, PlaybackErrorCode.failed, PlaybackErrorCode.badRequest, PlaybackErrorCode.notFound:
            return failed
        default:
            return failed
        }
    }
}

public enum AudioContainer: Equatable, Sendable {
    case supported
    case flac
    case unsupported

    public static func classify(path: String) -> AudioContainer {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "mp3", "m4a", "aac", "aiff", "aif", "wav":
            return .supported
        case "flac":
            return .flac
        default:
            return .unsupported
        }
    }
}

public enum TrackPlayability {
    /// Missing wins over iCloud. An undownloaded ubiquitous file is not “找不到文件”.
    public static func assess(
        missing: Bool,
        path: String,
        fileExists: Bool,
        ubiquitousNotDownloaded: Bool,
        flacPlayable: Bool
    ) -> PlaybackBlock? {
        if missing || path.isEmpty { return .missingFile }
        if ubiquitousNotDownloaded { return .notDownloaded }
        if !fileExists { return .missingFile }
        switch AudioContainer.classify(path: path) {
        case .supported:
            return nil
        case .flac:
            return flacPlayable ? nil : .unsupportedFormat
        case .unsupported:
            return .unsupportedFormat
        }
    }
}

public struct VolumeSession: Equatable, Sendable {
    public var level: Double
    /// Set only by the speaker button, never by dragging the slider to 0.
    public private(set) var speakerMemory: Double?

    public init(level: Double = 1) {
        self.level = Self.clamp(level)
    }

    public mutating func setSlider(_ value: Double) {
        level = Self.clamp(value)
    }

    public mutating func toggleSpeaker() {
        if level > 0 {
            speakerMemory = level
            level = 0
        } else {
            level = speakerMemory ?? 0.6
        }
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

public enum RowPlayIntent: Equatable, Sendable {
    case menuPlay
    case cover
    case doubleClick
}

public enum RowPlayPlan: Equatable, Sendable {
    case refuse(PlaybackBlock)
    case toggle
    case restart
    case replace(PlaybackQueue)
}

public enum PlayPausePlan: Equatable, Sendable {
    case noop
    case pause
    case resume
    case restartFromEnd
}

public enum QueueRemoval: Equatable, Sendable {
    case kept(PlaybackQueue)
    case play(PlaybackQueue, index: Int)
    case stopped(PlaybackQueue)
}

public enum PlaybackMove: Equatable, Sendable {
    case restart
    /// `queue` is the order to adopt, including an updated `currentIndex`.
    case start(PlaybackQueue, skipped: Int)
    case stay(fullCircle: Bool)
    /// Natural end with nothing playable ahead. No toast.
    case pauseAtEnd
    case none
}

public enum PlaybackQueueRules {
    public static let previousRestartThresholdMs = 2_000

    public static func plan(
        intent: RowPlayIntent,
        trackID: String,
        list: [String],
        currentID: String?,
        block: PlaybackBlock?
    ) -> RowPlayPlan {
        var rng = SystemRandomNumberGenerator()
        return plan(
            intent: intent,
            trackID: trackID,
            list: list,
            currentID: currentID,
            block: block,
            shuffle: false,
            repeatMode: .off,
            rng: &rng
        )
    }

    /// Cover-on-current toggles and double-click-on-current restarts before any shuffle.
    /// A replace while shuffle is on keeps `list` as `source`, starts `trackID`, and shuffles the rest after it.
    public static func plan<R: RandomNumberGenerator>(
        intent: RowPlayIntent,
        trackID: String,
        list: [String],
        currentID: String?,
        block: PlaybackBlock?,
        shuffle: Bool,
        repeatMode: RepeatMode,
        rng: inout R
    ) -> RowPlayPlan {
        if let block { return .refuse(block) }
        if intent == .cover, trackID == currentID { return .toggle }
        if intent == .doubleClick, trackID == currentID { return .restart }
        guard let index = list.firstIndex(of: trackID) else { return .refuse(.failed) }
        let source = list.map { QueueItem.track($0) }
        if shuffle {
            let current = source[index]
            var rest = source
            rest.remove(at: index)
            let items = [current] + shuffled(rest, using: &rng)
            return .replace(PlaybackQueue(
                items: items,
                source: source,
                currentIndex: 0,
                shuffle: true,
                repeatMode: repeatMode
            ))
        }
        return .replace(PlaybackQueue(
            items: source,
            source: source,
            currentIndex: index,
            shuffle: false,
            repeatMode: repeatMode
        ))
    }

    /// Nil when nothing is playable. `skipped` counts unplayable rows before the first playable one.
    public static func playAll(ids: [String], isPlayable: (String) -> Bool) -> (queue: PlaybackQueue, skipped: Int)? {
        var rng = SystemRandomNumberGenerator()
        return playAll(ids: ids, isPlayable: isPlayable, shuffle: false, repeatMode: .off, rng: &rng)
    }

    /// Shuffle off keeps table order. Shuffle on shuffles the whole table, then starts the first playable in that order.
    public static func playAll<R: RandomNumberGenerator>(
        ids: [String],
        isPlayable: (String) -> Bool,
        shuffle: Bool,
        repeatMode: RepeatMode,
        rng: inout R
    ) -> (queue: PlaybackQueue, skipped: Int)? {
        let source = ids.map { QueueItem.track($0) }
        let items = shuffle ? shuffled(source, using: &rng) : source
        guard let start = items.firstIndex(where: { playableID($0, isPlayable) }) else { return nil }
        return (PlaybackQueue(
            items: items,
            source: source,
            currentIndex: start,
            shuffle: shuffle,
            repeatMode: repeatMode
        ), start)
    }

    /// Page 「随机」/「随机播放」. Nil leaves the caller's queue and shuffle flag alone.
    /// A hit always draws a new permutation and turns shuffle on.
    public static func playShuffled<R: RandomNumberGenerator>(
        ids: [String],
        isPlayable: (String) -> Bool,
        repeatMode: RepeatMode,
        rng: inout R
    ) -> (queue: PlaybackQueue, skipped: Int)? {
        playAll(ids: ids, isPlayable: isPlayable, shuffle: true, repeatMode: repeatMode, rng: &rng)
    }

    public static func playNext(ids: [String], queue: PlaybackQueue) -> PlaybackQueue {
        let unique = uniqueIDs(ids)
        guard !unique.isEmpty else { return queue }
        let current = queue.current
        let items = insertingPlayNext(queue.items, current: current, ids: unique)
        let source = insertingPlayNext(queue.source, current: current, ids: unique)
        return PlaybackQueue(
            items: items,
            source: source,
            currentIndex: current.flatMap { items.firstIndex(of: $0) },
            shuffle: queue.shuffle,
            repeatMode: queue.repeatMode
        )
    }

    /// `alreadyAllPresent` is true only when every requested id was already queued.
    public static func enqueue(ids: [String], queue: PlaybackQueue) -> (queue: PlaybackQueue, alreadyAllPresent: Bool) {
        let unique = uniqueIDs(ids)
        guard !unique.isEmpty else { return (queue, false) }
        var items = queue.items
        var source = queue.source
        var added = 0
        for id in unique {
            let item = QueueItem.track(id)
            if items.contains(item) { continue }
            items.append(item)
            source.append(item)
            added += 1
        }
        let next = PlaybackQueue(
            items: items,
            source: source,
            currentIndex: queue.current.flatMap { items.firstIndex(of: $0) },
            shuffle: queue.shuffle,
            repeatMode: queue.repeatMode
        )
        return (next, added == 0)
    }

    public static func toggleShuffle<R: RandomNumberGenerator>(
        queue: PlaybackQueue,
        rng: inout R
    ) -> PlaybackQueue {
        var next = queue
        if queue.shuffle {
            next.items = queue.source
            next.currentIndex = queue.current.flatMap { queue.source.firstIndex(of: $0) }
            next.shuffle = false
            return next
        }
        next.shuffle = true
        guard let index = queue.currentIndex, queue.items.indices.contains(index) else {
            next.items = shuffled(queue.items, using: &rng)
            next.currentIndex = nil
            return next
        }
        let current = queue.items[index]
        var rest = queue.items
        rest.remove(at: index)
        next.items = [current] + shuffled(rest, using: &rng)
        next.currentIndex = 0
        return next
    }

    public static func toggleRepeat(queue: PlaybackQueue) -> PlaybackQueue {
        var next = queue
        next.repeatMode = queue.repeatMode.next
        return next
    }

    public static func previous(
        queue: PlaybackQueue,
        positionMs: Int,
        isPlayable: (QueueItem) -> Bool
    ) -> PlaybackMove {
        guard let index = queue.currentIndex, queue.items.indices.contains(index) else { return .none }
        if positionMs > previousRestartThresholdMs { return .restart }
        let wrap = queue.repeatMode == .all
        var skipped = 0
        var cursor = index
        let limit = wrap ? max(queue.items.count - 1, 0) : index
        var steps = 0
        while steps < limit {
            cursor -= 1
            if cursor < 0 { cursor = queue.items.count - 1 }
            steps += 1
            if isPlayable(queue.items[cursor]) {
                var next = queue
                next.currentIndex = cursor
                return .start(next, skipped: skipped)
            }
            skipped += 1
        }
        return .stay(fullCircle: onlyPlayableIsCurrent(queue: queue, isPlayable: isPlayable))
    }

    public static func next<R: RandomNumberGenerator>(
        queue: PlaybackQueue,
        isPlayable: (QueueItem) -> Bool,
        rng: inout R
    ) -> PlaybackMove {
        let wrap = queue.repeatMode == .all
        return forward(
            queue: queue,
            isPlayable: isPlayable,
            wrap: wrap,
            reshuffleOnWrap: wrap && queue.shuffle,
            end: .stay,
            rng: &rng
        )
    }

    public static func next(queue: PlaybackQueue, isPlayable: (QueueItem) -> Bool) -> PlaybackMove {
        var rng = SystemRandomNumberGenerator()
        return next(queue: queue, isPlayable: isPlayable, rng: &rng)
    }

    public static func naturalEnd<R: RandomNumberGenerator>(
        queue: PlaybackQueue,
        isPlayable: (QueueItem) -> Bool,
        rng: inout R
    ) -> PlaybackMove {
        guard queue.current != nil else { return .none }
        switch queue.repeatMode {
        case .one:
            return .restart
        case .off:
            return forward(
                queue: queue,
                isPlayable: isPlayable,
                wrap: false,
                reshuffleOnWrap: false,
                end: .pauseAtEnd,
                rng: &rng
            )
        case .all:
            return forward(
                queue: queue,
                isPlayable: isPlayable,
                wrap: true,
                reshuffleOnWrap: queue.shuffle,
                end: .pauseAtEnd,
                rng: &rng
            )
        }
    }

    public static func naturalEnd(queue: PlaybackQueue, isPlayable: (QueueItem) -> Bool) -> PlaybackMove {
        var rng = SystemRandomNumberGenerator()
        return naturalEnd(queue: queue, isPlayable: isPlayable, rng: &rng)
    }

    /// Mid-play failure: toast is the engine's job. Advance like repeat-off (no wrap, no new cycle, no repeat-one retry).
    public static func advanceAfterFailure(
        queue: PlaybackQueue,
        isPlayable: (QueueItem) -> Bool
    ) -> PlaybackMove {
        var rng = SystemRandomNumberGenerator()
        return forward(
            queue: queue,
            isPlayable: isPlayable,
            wrap: false,
            reshuffleOnWrap: false,
            end: .stay,
            rng: &rng
        )
    }

    public static func remove(ids: Set<String>, from queue: PlaybackQueue, isPlayable: (QueueItem) -> Bool) -> QueueRemoval {
        let current = queue.current
        let currentRemoved: Bool = {
            guard let id = current?.trackID else { return false }
            return ids.contains(id)
        }()
        func keep(_ item: QueueItem) -> Bool {
            guard let id = item.trackID else { return true }
            return !ids.contains(id)
        }
        let items = queue.items.filter(keep)
        let source = queue.source.filter(keep)
        func rebuilt(_ index: Int?) -> PlaybackQueue {
            PlaybackQueue(
                items: items,
                source: source,
                currentIndex: index,
                shuffle: queue.shuffle,
                repeatMode: queue.repeatMode
            )
        }
        if !currentRemoved {
            return .kept(rebuilt(current.flatMap { items.firstIndex(of: $0) }))
        }
        let after = queue.items.dropFirst((queue.currentIndex ?? -1) + 1).filter(keep)
        if let next = after.first(where: isPlayable), let index = items.firstIndex(of: next) {
            return .play(rebuilt(index), index: index)
        }
        return .stopped(rebuilt(nil))
    }

    public static func playPause(hasCurrent: Bool, playing: Bool, positionMs: Int, durationMs: Int) -> PlayPausePlan {
        guard hasCurrent else { return .noop }
        if playing { return .pause }
        if durationMs > 0, positionMs >= durationMs { return .restartFromEnd }
        return .resume
    }

    private enum ForwardEnd {
        case stay
        case pauseAtEnd
    }

    private static func forward<R: RandomNumberGenerator>(
        queue: PlaybackQueue,
        isPlayable: (QueueItem) -> Bool,
        wrap: Bool,
        reshuffleOnWrap: Bool,
        end: ForwardEnd,
        rng: inout R
    ) -> PlaybackMove {
        guard let index = queue.currentIndex, queue.items.indices.contains(index) else { return .none }
        let count = queue.items.count
        var skipped = 0
        var cursor = index
        let limit = wrap ? max(count - 1, 0) : max(0, count - index - 1)
        var steps = 0
        while steps < limit {
            let nextCursor = cursor + 1
            if nextCursor >= count {
                if reshuffleOnWrap {
                    return cycleOrRestart(queue: queue, isPlayable: isPlayable, end: end, rng: &rng)
                }
                cursor = 0
            } else {
                cursor = nextCursor
            }
            steps += 1
            if isPlayable(queue.items[cursor]) {
                var next = queue
                next.currentIndex = cursor
                return .start(next, skipped: skipped)
            }
            skipped += 1
        }
        if wrap {
            if !hasOtherPlayable(queue: queue, isPlayable: isPlayable),
               let current = queue.current, isPlayable(current) {
                return .restart
            }
        }
        switch end {
        case .pauseAtEnd:
            return .pauseAtEnd
        case .stay:
            return .stay(fullCircle: !hasOtherPlayable(queue: queue, isPlayable: isPlayable))
        }
    }

    /// Forward wrap with shuffle on. Two or more playable items start a new cycle; one restarts.
    private static func cycleOrRestart<R: RandomNumberGenerator>(
        queue: PlaybackQueue,
        isPlayable: (QueueItem) -> Bool,
        end: ForwardEnd,
        rng: inout R
    ) -> PlaybackMove {
        guard let index = queue.currentIndex, let current = queue.current else { return .none }
        let playableIndices = queue.items.indices.filter { isPlayable(queue.items[$0]) }
        let otherPlayable = playableIndices.filter { $0 != index }
        if otherPlayable.isEmpty {
            if playableIndices.contains(index) { return .restart }
            switch end {
            case .pauseAtEnd: return .pauseAtEnd
            case .stay: return .stay(fullCircle: true)
            }
        }
        if playableIndices.count >= 2 {
            return reshuffleCycle(queue: queue, justLeft: current, justLeftIndex: index, isPlayable: isPlayable, rng: &rng)
        }
        var next = queue
        next.currentIndex = otherPlayable[0]
        return .start(next, skipped: 0)
    }

    private static func reshuffleCycle<R: RandomNumberGenerator>(
        queue: PlaybackQueue,
        justLeft: QueueItem,
        justLeftIndex: Int,
        isPlayable: (QueueItem) -> Bool,
        rng: inout R
    ) -> PlaybackMove {
        var pool = queue.items
        pool.remove(at: justLeftIndex)
        let shuffledPool = shuffled(pool, using: &rng)
        guard let firstPlayable = shuffledPool.firstIndex(where: isPlayable) else { return .restart }
        let newFirst = shuffledPool[firstPlayable]
        var middle = shuffledPool
        middle.remove(at: firstPlayable)
        var next = queue
        next.items = [newFirst] + middle + [justLeft]
        next.currentIndex = 0
        return .start(next, skipped: 0)
    }

    /// Fisher–Yates. `rng.next() % (i + 1)` so tests can pin the permutation.
    private static func shuffled<T, R: RandomNumberGenerator>(_ items: [T], using rng: inout R) -> [T] {
        var copy = items
        var index = copy.count - 1
        while index > 0 {
            let choice = Int(rng.next() % UInt64(index + 1))
            if choice != index { copy.swapAt(index, choice) }
            index -= 1
        }
        return copy
    }

    private static func insertingPlayNext(_ items: [QueueItem], current: QueueItem?, ids: [String]) -> [QueueItem] {
        var items = items.filter { item in
            guard let id = item.trackID else { return true }
            return !ids.contains(id)
        }
        let insertAt: Int
        if let current, let index = items.firstIndex(of: current) {
            insertAt = index + 1
        } else {
            insertAt = 0
        }
        items.insert(contentsOf: ids.map { QueueItem.track($0) }, at: insertAt)
        return items
    }

    private static func playableID(_ item: QueueItem, _ isPlayable: (String) -> Bool) -> Bool {
        guard let id = item.trackID else { return true }
        return isPlayable(id)
    }

    private static func uniqueIDs(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { seen.insert($0).inserted }
    }

    private static func hasOtherPlayable(queue: PlaybackQueue, isPlayable: (QueueItem) -> Bool) -> Bool {
        guard let index = queue.currentIndex else { return queue.items.contains(where: isPlayable) }
        return queue.items.enumerated().contains { $0.offset != index && isPlayable($0.element) }
    }

    private static func onlyPlayableIsCurrent(queue: PlaybackQueue, isPlayable: (QueueItem) -> Bool) -> Bool {
        guard let current = queue.current, isPlayable(current) else { return false }
        return queue.items.allSatisfy { $0 == current || !isPlayable($0) }
    }
}
