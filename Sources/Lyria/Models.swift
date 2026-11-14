import Foundation
import LyriaCore

struct Track: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let artistId: String?
    let album: String
    let albumId: String?
    let durationMs: Int
    let missing: Bool
    let encodingSuspect: Bool
    let path: String
    let artworkPath: String?

    var durationLabel: String { TimeFormat.label(ms: durationMs) }
    var artistLabel: String { artist.isEmpty ? "未知艺人" : artist }
    var albumLabel: String { album.isEmpty ? "未知专辑" : album }
    var canOpenArtist: Bool { artistId != nil }
    var canOpenAlbum: Bool { albumId != nil }

    static func missingPlaceholder(id: String) -> Track {
        Track(
            id: id,
            title: "文件缺失",
            artist: "",
            artistId: nil,
            album: "",
            albumId: nil,
            durationMs: 0,
            missing: true,
            encodingSuspect: false,
            path: "",
            artworkPath: nil
        )
    }
}

struct Artist: Identifiable, Hashable {
    let id: String
    let name: String
    let sortName: String
    let trackCount: Int
}

struct Album: Identifiable, Hashable {
    let id: String
    let name: String
    let artistId: String?
    let artistName: String
    let year: Int
    let artworkPath: String?

    var artistLabel: String { artistName.isEmpty ? "未知艺人" : artistName }
}

struct Playlist: Identifiable, Hashable {
    let id: String
    var name: String
    var trackIDs: [String]
    /// Unix seconds. Nil until the playlist is opened, created, added to, or played from.
    var lastUsedAt: Int64?
}

enum AppRoute: Hashable {
    case library
    case artists
    case artist(String)
    case albums
    case album(String)
    case playlists
    case playlist(String)
    case settings

    var nav: NavItem {
        switch self {
        case .library: return .library
        case .artists, .artist: return .artists
        case .albums, .album: return .albums
        case .playlists, .playlist: return .playlists
        case .settings: return .settings
        }
    }

    var showsBack: Bool {
        switch self {
        case .artist, .album, .playlist: return true
        default: return false
        }
    }

    var stackKey: String {
        switch self {
        case .library: return "library"
        case .artists: return "artists"
        case .artist(let id): return "artist:\(id)"
        case .albums: return "albums"
        case .album(let id): return "album:\(id)"
        case .playlists: return "playlists"
        case .playlist(let id): return "playlist:\(id)"
        case .settings: return "settings"
        }
    }

    init(_ page: LibraryPage) {
        switch page {
        case .library: self = .library
        case .artists: self = .artists
        case .artist(let id): self = .artist(id)
        case .albums: self = .albums
        case .album(let id): self = .album(id)
        case .playlists: self = .playlists
        case .playlist(let id): self = .playlist(id)
        case .settings: self = .settings
        }
    }
}

enum NavItem: String, CaseIterable, Identifiable {
    case library = "曲库"
    case artists = "艺人"
    case albums = "专辑"
    case playlists = "全部播放列表"
    case settings = "设置"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .library: return "house.fill"
        case .artists: return "person.fill"
        case .albums: return "opticaldisc"
        case .playlists: return "list.bullet"
        case .settings: return "gearshape.fill"
        }
    }

    var route: AppRoute {
        switch self {
        case .library: return .library
        case .artists: return .artists
        case .albums: return .albums
        case .playlists: return .playlists
        case .settings: return .settings
        }
    }

    static var primaryItems: [NavItem] { [.library, .artists, .albums, .playlists] }

    var section: LibrarySection {
        switch self {
        case .library: return .library
        case .artists: return .artists
        case .albums: return .albums
        case .playlists: return .playlists
        case .settings: return .settings
        }
    }

    init(_ section: LibrarySection) {
        switch section {
        case .library: self = .library
        case .artists: self = .artists
        case .albums: self = .albums
        case .playlists: self = .playlists
        case .settings: self = .settings
        }
    }
}

enum TimeFormat {
    static func label(ms: Int) -> String {
        let total = max(ms, 0) / 1000
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func words(ms: Int) -> String {
        let minutes = max(ms, 0) / 60_000
        if minutes < 60 { return "约 \(max(minutes, 1)) 分钟" }
        return "约 \(minutes / 60) 小时 \(minutes % 60) 分"
    }
}
