import Foundation
import LyriaCore
import Observation

struct NowPlaying: Equatable {
    var id: String?
    var title: String
    var artist: String
    var album: String
    var artworkPath: String?

    var artistLabel: String { artist.isEmpty ? "未知艺人" : artist }
}

struct QueueRowState: Identifiable, Equatable {
    var item: QueueItem
    var title: String
    var artist: String
    var missing: Bool

    var id: String {
        switch item {
        case .track(let id): return id
        case .oneShot(let uri): return uri
        }
    }
}

struct TransportSnapshot: Sendable {
    var currentID: String?
    var title: String
    var artist: String
    var album: String
    var artworkPath: String?
    var hasCurrent: Bool
    var playing: Bool
    var positionMs: Int
    var durationMs: Int
    var volume: Double
    var queueCount: Int
    var currentIndex: Int?
    var rows: [QueueRowSnapshot]
    var shuffle: Bool
    var repeatMode: RepeatMode
    var lastError: String?
}

struct QueueRowSnapshot: Sendable, Equatable {
    var item: QueueItem
    var title: String
    var artist: String
    var missing: Bool
}

enum EngineEvent: Sendable {
    case state(TransportSnapshot)
    case position(Int)
    case volume(Double)
    case toast(String)
    case showQueue
}

/// UI mirror. The playback actor is the only thing that decides these values.
@MainActor
@Observable
final class TransportState {
    var current: NowPlaying?
    var playing = false
    var positionMs = 0
    var durationMs = 0
    var shuffle = false
    var repeatMode: RepeatMode = .off
    var volume = 1.0
    var queueCount = 0
    var engineAvailable = true
    var lastError: String?

    var fraction: Double {
        guard durationMs > 0 else { return 0 }
        return min(1, max(0, Double(positionMs) / Double(durationMs)))
    }

    func apply(_ snapshot: TransportSnapshot) {
        let nextCurrent: NowPlaying? = snapshot.hasCurrent
            ? NowPlaying(
                id: snapshot.currentID,
                title: snapshot.title,
                artist: snapshot.artist,
                album: snapshot.album,
                artworkPath: snapshot.artworkPath
            )
            : nil
        if current != nextCurrent { current = nextCurrent }
        if playing != snapshot.playing { playing = snapshot.playing }
        if positionMs != snapshot.positionMs { positionMs = snapshot.positionMs }
        if durationMs != snapshot.durationMs { durationMs = snapshot.durationMs }
        if volume != snapshot.volume { volume = snapshot.volume }
        if queueCount != snapshot.queueCount { queueCount = snapshot.queueCount }
        if lastError != snapshot.lastError { lastError = snapshot.lastError }
        if shuffle != snapshot.shuffle { shuffle = snapshot.shuffle }
        if repeatMode != snapshot.repeatMode { repeatMode = snapshot.repeatMode }
    }

    func applyPosition(_ ms: Int) {
        if positionMs != ms { positionMs = ms }
    }

    func applyVolume(_ value: Double) {
        if volume != value { volume = value }
    }
}

@MainActor
@Observable
final class PlaybackQueueState {
    var rows: [QueueRowState] = []
    var currentIndex: Int?

    func apply(_ snapshot: TransportSnapshot) {
        let next = snapshot.rows.map {
            QueueRowState(item: $0.item, title: $0.title, artist: $0.artist, missing: $0.missing)
        }
        if rows != next { rows = next }
        if currentIndex != snapshot.currentIndex { currentIndex = snapshot.currentIndex }
    }
}
