import Foundation
import LyriaCore

/// Display fields the engine remembers for queue rows. Playback decisions stay in LyriaCore.
struct ResolvedTrack: Sendable, Equatable {
    var id: String
    var path: String
    var missing: Bool
    var title: String
    var artist: String
    var artworkPath: String?
    var durationMs: Int

    init(id: String, path: String, missing: Bool, title: String, artist: String, artworkPath: String?, durationMs: Int = 0) {
        self.id = id
        self.path = path
        self.missing = missing
        self.title = title
        self.artist = artist
        self.artworkPath = artworkPath
        self.durationMs = max(0, durationMs)
    }

    init(track: Track) {
        self.init(
            id: track.id,
            path: track.path,
            missing: track.missing,
            title: track.title,
            artist: track.artistLabel,
            artworkPath: track.artworkPath,
            durationMs: track.durationMs
        )
    }
}
