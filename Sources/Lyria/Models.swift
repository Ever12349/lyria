import Foundation

struct Track: Identifiable, Hashable {
    let id: String
    /// Chinese title. The English line is stored for search only and is not shown.
    let title: String
    let english: String
    let artist: String
    let artistId: String
    let album: String
    let albumId: String
    let durationMs: Int

    var durationLabel: String { TimeFormat.label(ms: durationMs) }
}

struct Artist: Identifiable, Hashable {
    let id: String
    let name: String
}

struct Album: Identifiable, Hashable {
    let id: String
    let name: String
    let artistName: String
    let year: Int
}

struct Playlist: Identifiable, Hashable {
    let id: String
    var name: String
    var trackIDs: [String]
}

enum RepeatMode: String, CaseIterable {
    case off
    case all
    case one

    var label: String {
        switch self {
        case .off: return "关闭"
        case .all: return "全部"
        case .one: return "单曲"
        }
    }

    var systemImage: String {
        switch self {
        case .off, .all: return "repeat"
        case .one: return "repeat.1"
        }
    }

    var tooltip: String {
        switch self {
        case .off: return "重复关闭"
        case .all: return "重复全部"
        case .one: return "单曲循环"
        }
    }

    var next: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }
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
}

enum NavItem: String, CaseIterable, Identifiable {
    case library = "曲库"
    case artists = "艺人"
    case albums = "专辑"
    case playlists = "播放列表"
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
