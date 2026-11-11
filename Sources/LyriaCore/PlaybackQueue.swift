import Foundation

public enum QueueItem: Hashable, Sendable {
    case track(String)
    case oneShot(String)

    public var trackID: String? {
        if case .track(let id) = self { return id }
        return nil
    }
}

public struct PlaybackQueue: Equatable, Sendable {
    public var items: [QueueItem]
    public var currentIndex: Int?

    public init(items: [QueueItem] = [], currentIndex: Int? = nil) {
        self.items = items
        self.currentIndex = currentIndex
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
    case start(index: Int, skipped: Int)
    case stay(fullCircle: Bool)
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
        if let block { return .refuse(block) }
        if intent == .cover, trackID == currentID { return .toggle }
        if intent == .doubleClick, trackID == currentID { return .restart }
        guard let index = list.firstIndex(of: trackID) else { return .refuse(.failed) }
        return .replace(PlaybackQueue(items: list.map { .track($0) }, currentIndex: index))
    }

    /// Nil when nothing is playable. `skipped` counts unplayable rows before the first playable one.
    public static func playAll(ids: [String], isPlayable: (String) -> Bool) -> (queue: PlaybackQueue, skipped: Int)? {
        guard let start = ids.firstIndex(where: isPlayable) else { return nil }
        return (PlaybackQueue(items: ids.map { .track($0) }, currentIndex: start), start)
    }

    public static func playNext(ids: [String], queue: PlaybackQueue) -> PlaybackQueue {
        let unique = uniqueIDs(ids)
        guard !unique.isEmpty else { return queue }
        let current = queue.current
        var items = queue.items.filter { item in
            guard let id = item.trackID else { return true }
            return !unique.contains(id)
        }
        let insertAt: Int
        if let current, let index = items.firstIndex(of: current) {
            insertAt = index + 1
        } else {
            insertAt = 0
        }
        items.insert(contentsOf: unique.map { QueueItem.track($0) }, at: insertAt)
        let currentIndex = current.flatMap { items.firstIndex(of: $0) }
        return PlaybackQueue(items: items, currentIndex: currentIndex)
    }

    /// `alreadyAllPresent` is true only when every requested id was already queued.
    public static func enqueue(ids: [String], queue: PlaybackQueue) -> (queue: PlaybackQueue, alreadyAllPresent: Bool) {
        let unique = uniqueIDs(ids)
        guard !unique.isEmpty else { return (queue, false) }
        var items = queue.items
        var added = 0
        for id in unique {
            let item = QueueItem.track(id)
            if items.contains(item) { continue }
            items.append(item)
            added += 1
        }
        let currentIndex = queue.current.flatMap { items.firstIndex(of: $0) }
        let next = PlaybackQueue(items: items, currentIndex: currentIndex)
        return (next, added == 0)
    }

    public static func previous(
        queue: PlaybackQueue,
        positionMs: Int,
        isPlayable: (QueueItem) -> Bool
    ) -> PlaybackMove {
        guard let index = queue.currentIndex, queue.items.indices.contains(index) else { return .none }
        if positionMs > previousRestartThresholdMs { return .restart }
        var skipped = 0
        var cursor = index - 1
        while cursor >= 0 {
            if isPlayable(queue.items[cursor]) {
                return .start(index: cursor, skipped: skipped)
            }
            skipped += 1
            cursor -= 1
        }
        return .stay(fullCircle: onlyPlayableIsCurrent(queue: queue, isPlayable: isPlayable))
    }

    public static func next(queue: PlaybackQueue, isPlayable: (QueueItem) -> Bool) -> PlaybackMove {
        guard let index = queue.currentIndex, queue.items.indices.contains(index) else { return .none }
        if queue.items.count <= 1 {
            return .stay(fullCircle: true)
        }
        var skipped = 0
        var cursor = index
        var steps = 0
        while steps < queue.items.count - 1 {
            cursor += 1
            if cursor == queue.items.count { cursor = 0 }
            steps += 1
            if isPlayable(queue.items[cursor]) {
                return .start(index: cursor, skipped: skipped)
            }
            skipped += 1
        }
        return .stay(fullCircle: true)
    }

    public static func remove(ids: Set<String>, from queue: PlaybackQueue, isPlayable: (QueueItem) -> Bool) -> QueueRemoval {
        let current = queue.current
        let currentRemoved: Bool = {
            guard let id = current?.trackID else { return false }
            return ids.contains(id)
        }()
        let items = queue.items.filter { item in
            guard let id = item.trackID else { return true }
            return !ids.contains(id)
        }
        if !currentRemoved {
            let index = current.flatMap { items.firstIndex(of: $0) }
            return .kept(PlaybackQueue(items: items, currentIndex: index))
        }
        let after = queue.items.dropFirst((queue.currentIndex ?? -1) + 1).filter { item in
            guard let id = item.trackID else { return true }
            return !ids.contains(id)
        }
        if let next = after.first(where: isPlayable), let index = items.firstIndex(of: next) {
            return .play(PlaybackQueue(items: items, currentIndex: index), index: index)
        }
        return .stopped(PlaybackQueue(items: items, currentIndex: nil))
    }

    public static func playPause(hasCurrent: Bool, playing: Bool, positionMs: Int, durationMs: Int) -> PlayPausePlan {
        guard hasCurrent else { return .noop }
        if playing { return .pause }
        if durationMs > 0, positionMs >= durationMs { return .restartFromEnd }
        return .resume
    }

    private static func uniqueIDs(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { seen.insert($0).inserted }
    }

    private static func onlyPlayableIsCurrent(queue: PlaybackQueue, isPlayable: (QueueItem) -> Bool) -> Bool {
        guard let current = queue.current, isPlayable(current) else { return false }
        return queue.items.allSatisfy { $0 == current || !isPlayable($0) }
    }
}
