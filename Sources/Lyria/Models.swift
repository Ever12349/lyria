import Foundation

struct Track: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let artist: String
    let album: String
    let durationMs: Int

    var durationLabel: String {
        let total = max(durationMs, 0) / 1000
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
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

    /// Primary nav vs bottom-pinned settings.
    static var primaryItems: [NavItem] { [.library, .artists, .albums, .playlists] }
}

enum FakeData {
    static let tracks: [Track] = [
        Track(id: "trk_01J9X2K4M7NQP8RSTUVWYA", title: "星际旅行", subtitle: "Interstellar Voyage", artist: "The Paper Kites", album: "States", durationMs: 272_000),
        Track(id: "trk_01J9X2K4M7NQP8RSTUVWXY", title: "夜航星", subtitle: "Night Voyager", artist: "陈绮贞", album: "太阳", durationMs: 268_000),
        Track(id: "trk_01J9X2K4M7NQP8RSTUVWXZ", title: "挪威的森林", subtitle: "Norwegian Wood", artist: "伍佰", album: "浪人情歌", durationMs: 312_000),
        Track(id: "trk_01J9X2K4M7NQP8RSTUVWYB", title: "平凡之路", subtitle: "Ordinary Road", artist: "朴树", album: "猎人手记", durationMs: 298_000),
        Track(id: "trk_01J9X2K4M7NQP8RSTUVWYC", title: "午夜城市", subtitle: "Midnight City", artist: "M83", album: "Hurry Up, We're Dreaming", durationMs: 243_000),
        Track(id: "trk_01J9X2K4M7NQP8RSTUVWYD", title: "起风了", subtitle: "The Wind Rises", artist: "买辣椒也用券", album: "起风了", durationMs: 325_000),
        Track(id: "trk_01J9X2K4M7NQP8RSTUVWYE", title: "全新世", subtitle: "Holocene", artist: "Bon Iver", album: "Bon Iver", durationMs: 336_000),
        Track(id: "trk_01J9X2K4M7NQP8RSTUVWYF", title: "海阔天空", subtitle: "Boundless Oceans", artist: "Beyond", album: "乐与怒", durationMs: 326_000),
        Track(id: "trk_01J9X2K4M7NQP8RSTUVWYG", title: "序曲", subtitle: "Intro", artist: "The xx", album: "xx", durationMs: 127_000),
        Track(id: "trk_01J9X2K4M7NQP8RSTUVWYH", title: "光辉岁月", subtitle: "Glorious Years", artist: "Beyond", album: "命运派对", durationMs: 299_000),
        Track(id: "trk_01J9X2K4M7NQP8RSTUVWYI", title: "土星", subtitle: "Saturn", artist: "Sleeping At Last", album: "Atlas: Space", durationMs: 289_000),
        Track(id: "trk_01J9X2K4M7NQP8RSTUVWYJ", title: "成全", subtitle: "Make It Complete", artist: "林宥嘉", album: "大小说家", durationMs: 274_000),
    ]

    static let nowPlayingId = tracks[0].id
}
