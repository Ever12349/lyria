import Foundation
import LyriaCore
import Observation

struct NowPlaying: Equatable {
    var id: String?
    var title: String
    var artist: String
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
    var artworkPath: String?
    var hasCurrent: Bool
    var playing: Bool
    var positionMs: Int
    var durationMs: Int
    var volume: Double
    var queueCount: Int
    var currentIndex: Int?
    var rows: [QueueRowSnapshot]
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
        if snapshot.hasCurrent {
            current = NowPlaying(
                id: snapshot.currentID,
                title: snapshot.title,
                artist: snapshot.artist,
                artworkPath: snapshot.artworkPath
            )
        } else {
            current = nil
        }
        playing = snapshot.playing
        positionMs = snapshot.positionMs
        durationMs = snapshot.durationMs
        volume = snapshot.volume
        queueCount = snapshot.queueCount
        lastError = snapshot.lastError
        shuffle = false
        repeatMode = .off
    }
}

@MainActor
@Observable
final class PlaybackQueueState {
    var rows: [QueueRowState] = []
    var currentIndex: Int?

    func apply(_ snapshot: TransportSnapshot) {
        rows = snapshot.rows.map {
            QueueRowState(item: $0.item, title: $0.title, artist: $0.artist, missing: $0.missing)
        }
        currentIndex = snapshot.currentIndex
    }
}
