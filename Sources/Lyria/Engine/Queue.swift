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

    init(track: Track) {
        id = track.id
        path = track.path
        missing = track.missing
        title = track.title
        artist = track.artistLabel
        artworkPath = track.artworkPath
    }
}
