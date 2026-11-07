import SwiftUI

/// In-memory shell state for the UI phase. No scan, playback engine, or network.
@MainActor
final class FakeLibraryStore: ObservableObject {
    @Published var tracks: [Track]
    @Published var artists: [Artist]
    @Published var albums: [Album]
    @Published var playlists: [Playlist]
    @Published var hiddenTrackIDs: Set<String> = []
    @Published var libraryEmpty = false

    @Published var stack: [AppRoute] = [.library]
    @Published var searchText = ""
    private var returnStack: [AppRoute]?
    @Published var selectedTrackId: String?

    @Published var nowPlayingId: String?
    @Published var isPlaying = true
    @Published var positionMs = 108_000
    @Published var shuffleOn = false
    @Published var repeatMode: RepeatMode = .off
    @Published var volume = 0.60
    @Published var queue: [String]
    @Published var queueVisible = false

    @Published var toast: String?
    private var toastToken = 0

    init() {
        let seed = FakeCatalog.make()
        tracks = seed.tracks
        artists = seed.artists
        albums = seed.albums
        playlists = seed.playlists
        let showcase = ["t1", "t2", "t3", "t4", "t5"]
        queue = showcase
        nowPlayingId = "t1"
        selectedTrackId = "t1"
    }

    var route: AppRoute { stack.last ?? .library }

    var currentNav: NavItem { route.nav }

    var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isSearching: Bool { !trimmedQuery.isEmpty }

    var visibleTracks: [Track] {
        tracks.filter { !hiddenTrackIDs.contains($0.id) }
    }

    var searchTracks: [Track] {
        let query = trimmedQuery
        guard !query.isEmpty else { return [] }
        return visibleTracks.filter { track in
            track.title.localizedCaseInsensitiveContains(query)
                || track.english.localizedCaseInsensitiveContains(query)
                || track.artist.localizedCaseInsensitiveContains(query)
                || track.album.localizedCaseInsensitiveContains(query)
        }
    }

    var hasSearchHits: Bool { !searchTracks.isEmpty }

    /// Nil while the empty-library screen is showing, so the transport reads 「—」.
    var shownTrack: Track? {
        if libraryEmpty, !isSearching, route == .library { return nil }
        return track(nowPlayingId)
    }

    var nowPlaying: Track? { shownTrack }

    func track(_ id: String?) -> Track? {
        guard let id else { return nil }
        return tracks.first { $0.id == id }
    }

    func artist(_ id: String) -> Artist? { artists.first { $0.id == id } }

    func album(_ id: String) -> Album? { albums.first { $0.id == id } }

    func playlist(_ id: String) -> Playlist? { playlists.first { $0.id == id } }

    func tracks(forArtist name: String) -> [Track] {
        visibleTracks.filter { $0.artist == name }
    }

    func tracks(forAlbum name: String) -> [Track] {
        visibleTracks.filter { $0.album == name }
    }

    func albums(forArtist name: String) -> [Album] {
        albums.filter { $0.artistName == name }
    }

    func tracks(in playlist: Playlist) -> [Track] {
        playlist.trackIDs.compactMap { id in tracks.first { $0.id == id } }
    }

    func durationMs(of ids: [String]) -> Int {
        ids.reduce(0) { partial, id in partial + (track(id)?.durationMs ?? 0) }
    }

    // MARK: Navigation

    func updateQuery(_ raw: String) {
        let wasEmpty = trimmedQuery.isEmpty
        let nowEmpty = raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !nowEmpty && wasEmpty {
            returnStack = stack
        }
        searchText = raw
        if nowEmpty, let saved = returnStack {
            stack = saved
            returnStack = nil
        }
    }

    func select(_ item: NavItem) {
        returnStack = nil
        searchText = ""
        stack = [item.route]
    }

    func goBack() {
        if isSearching {
            updateQuery("")
            return
        }
        guard stack.count > 1 else { return }
        stack.removeLast()
    }

    func openArtist(_ id: String) {
        returnStack = nil
        searchText = ""
        stack = [.artists, .artist(id)]
    }

    func openAlbum(_ id: String) {
        returnStack = nil
        searchText = ""
        stack = [.albums, .album(id)]
    }

    func openPlaylist(_ id: String) {
        returnStack = nil
        searchText = ""
        stack = [.playlists, .playlist(id)]
    }

    func previewEmptyLibrary() {
        returnStack = nil
        searchText = ""
        libraryEmpty = true
        stack = [.library]
    }

    func restoreLibrary() {
        libraryEmpty = false
        showToast("已添加 ~/Music")
    }

    func removeFromLibrary(_ id: String) {
        guard let title = track(id)?.title else { return }
        hiddenTrackIDs.insert(id)
        if selectedTrackId == id { selectedTrackId = nil }
        showToast("已从曲库移除「\(title)」")
    }

    func openArtist(named name: String) {
        guard let artist = artists.first(where: { $0.name == name }) else {
            showToast("找不到艺人「\(name)」")
            return
        }
        openArtist(artist.id)
    }

    func openAlbum(named name: String) {
        guard let album = albums.first(where: { $0.name == name }) else {
            showToast("找不到专辑「\(name)」")
            return
        }
        openAlbum(album.id)
    }

    // MARK: Playback facade (visual only)

    func play(_ id: String, announce: Bool = true) {
        guard track(id) != nil else { return }
        if !queue.contains(id) { queue.append(id) }
        nowPlayingId = id
        selectedTrackId = id
        isPlaying = true
        positionMs = 0
        if announce, let title = track(id)?.title {
            showToast("正在播放「\(title)」")
        }
    }

    func togglePlay() {
        guard nowPlayingId != nil else { return }
        isPlaying.toggle()
        showToast(isPlaying ? "继续播放" : "已暂停")
    }

    func skip(_ delta: Int) {
        guard !queue.isEmpty else {
            showToast("队列是空的")
            return
        }
        guard let current = nowPlayingId, let index = queue.firstIndex(of: current) else {
            play(queue[0])
            return
        }
        let nextIndex = index + delta
        guard queue.indices.contains(nextIndex) else {
            showToast(delta > 0 ? "已经是最后一首" : "已经是第一首")
            return
        }
        play(queue[nextIndex])
    }

    func playAll(_ ids: [String], shuffled: Bool) {
        let unique = ids.filter { track($0) != nil }
        guard !unique.isEmpty else {
            showToast("没有可播放的曲目")
            return
        }
        var order = unique
        if shuffled { order.shuffle() }
        queue = order
        shuffleOn = shuffled
        nowPlayingId = order[0]
        selectedTrackId = order[0]
        isPlaying = true
        positionMs = 0
        if shuffled {
            showToast("随机播放 · \(order.count) 首")
        } else if let title = track(order[0])?.title {
            showToast("正在播放「\(title)」")
        }
    }

    func toggleShuffle() {
        shuffleOn.toggle()
        showToast(shuffleOn ? "随机播放已打开" : "随机播放已关闭")
    }

    func cycleRepeat() {
        repeatMode = repeatMode.next
        showToast("重复：\(repeatMode.label)")
    }

    func seek(toProgress progress: Double, durationMs: Int) {
        let clamped = min(max(progress, 0), 1)
        positionMs = Int((clamped * Double(max(durationMs, 0))).rounded())
    }

    // MARK: Queue

    func toggleQueue() {
        queueVisible.toggle()
    }

    func enqueue(_ id: String) {
        guard track(id) != nil else { return }
        if queue.contains(id) {
            showToast("已在队列中")
            return
        }
        queue.append(id)
        showToast("已加入队列")
    }

    func playNext(_ id: String) {
        guard track(id) != nil else { return }
        queue.removeAll { $0 == id }
        if let current = nowPlayingId, let index = queue.firstIndex(of: current) {
            queue.insert(id, at: index + 1)
        } else {
            queue.insert(id, at: 0)
        }
        showToast("将在下一首播放")
    }

    func enqueueAll(_ ids: [String]) {
        var added = 0
        for id in ids where track(id) != nil && !queue.contains(id) {
            queue.append(id)
            added += 1
        }
        showToast(added == 0 ? "这些曲目已在队列中" : "已加入队列 · \(added) 首")
    }

    func removeFromQueue(at index: Int) {
        guard queue.indices.contains(index) else { return }
        let title = track(queue[index])?.title ?? "曲目"
        queue.remove(at: index)
        showToast("已从队列移除「\(title)」")
    }

    // MARK: Playlists

    func createPlaylist() {
        let used = Set(playlists.map(\.name))
        var name = "新播放列表"
        var n = 2
        while used.contains(name) {
            name = "新播放列表 \(n)"
            n += 1
        }
        let playlist = Playlist(id: FakeCatalog.uniquePlaylistID(existing: playlists), name: name, trackIDs: [])
        playlists.insert(playlist, at: 0)
        openPlaylist(playlist.id)
        showToast("已新建「\(name)」")
    }

    func deletePlaylist(_ id: String) {
        guard let playlist = playlist(id) else { return }
        playlists.removeAll { $0.id == id }
        if case .playlist(let current) = route, current == id {
            stack = [.playlists]
        }
        showToast("已删除「\(playlist.name)」")
    }

    func add(_ trackID: String, to playlistID: String) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }), track(trackID) != nil else { return }
        if playlists[index].trackIDs.contains(trackID) {
            showToast("已在「\(playlists[index].name)」中")
            return
        }
        playlists[index].trackIDs.append(trackID)
        showToast("已加入「\(playlists[index].name)」")
    }

    func remove(_ trackID: String, from playlistID: String) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[index].trackIDs.removeAll { $0 == trackID }
        showToast("已从播放列表移除")
    }

    func move(trackID: String, in playlistID: String, direction: Int) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }),
              let from = playlists[index].trackIDs.firstIndex(of: trackID) else { return }
        let dest = from + direction
        guard playlists[index].trackIDs.indices.contains(dest) else { return }
        playlists[index].trackIDs.swapAt(from, dest)
        showToast("已调整顺序")
    }

    func showToast(_ message: String) {
        toastToken += 1
        let token = toastToken
        toast = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if toastToken == token { toast = nil }
        }
    }
}

enum FakeCatalog {
    struct Seed {
        var tracks: [Track]
        var artists: [Artist]
        var albums: [Album]
        var playlists: [Playlist]
    }

    static func make() -> Seed {
        var tracks: [Track] = [
            Track(id: "t1", title: "星际旅行", english: "Interstellar Voyage", artist: "Dreamscape", artistId: "dreamscape", album: "银河边缘", albumId: "edge", durationMs: 272_000),
            Track(id: "t2", title: "午夜信号", english: "Midnight Signal", artist: "Aurora Line", artistId: "aurora", album: "夜航电台", albumId: "radio", durationMs: 228_000),
            Track(id: "t3", title: "漂浮的城市", english: "Floating Cities", artist: "Neon Harbor", artistId: "neon", album: "云端漫步", albumId: "cloud", durationMs: 302_000),
            Track(id: "t4", title: "光的碎片", english: "Fragments of Light", artist: "Lumen", artistId: "lumen", album: "星尘集", albumId: "dust", durationMs: 251_000),
            Track(id: "t5", title: "深空静默", english: "Silent Deep Space", artist: "Void Choir", artistId: "void", album: "深空静默", albumId: "silence", durationMs: 380_000),
        ]

        let artistRows: [(String, String)] = [
            ("dreamscape", "Dreamscape"), ("aurora", "Aurora Line"), ("neon", "Neon Harbor"),
            ("lumen", "Lumen"), ("void", "Void Choir"), ("paper", "The Paper Kites"),
            ("m83", "M83"), ("boniver", "Bon Iver"), ("beyond", "Beyond"), ("pushu", "朴树"),
            ("nova", "Nova Relay"), ("tide", "Tide Theory"), ("glass", "Glass Ocean"),
            ("north", "Northroom"), ("lantern", "Lantern Kids"), ("staticg", "Static Garden"),
        ]
        let artists = artistRows.map { Artist(id: $0.0, name: $0.1) }

        let albumRows: [(String, String, String, String, Int)] = [
            ("edge", "银河边缘", "Dreamscape", "dreamscape", 2024),
            ("radio", "夜航电台", "Aurora Line", "aurora", 2024),
            ("cloud", "云端漫步", "Neon Harbor", "neon", 2023),
            ("dust", "星尘集", "Lumen", "lumen", 2024),
            ("silence", "深空静默", "Void Choir", "void", 2022),
            ("forest", "挪威的森林", "Beyond", "beyond", 1993),
            ("ordinary", "Ordinary Road", "朴树", "pushu", 1994),
            ("voyager", "Night Voyager", "M83", "m83", 2011),
            ("orbit", "轨道余温", "Dreamscape", "dreamscape", 2023),
            ("letters", "极光来信", "Aurora Line", "aurora", 2022),
            ("harbor", "港湾夜色", "Neon Harbor", "neon", 2021),
            ("prism", "棱镜", "Lumen", "lumen", 2020),
            ("echo", "回声大厅", "Void Choir", "void", 2023),
            ("kites", "纸鸢", "The Paper Kites", "paper", 2018),
            ("hurry", "Hurry Up", "M83", "m83", 2005),
            ("emma", "For Emma", "Bon Iver", "boniver", 2007),
        ]
        let albums = albumRows.map {
            Album(id: $0.0, name: $0.1, artistName: $0.2, year: $0.4)
        }
        let albumArtist: [String: (name: String, id: String)] = Dictionary(uniqueKeysWithValues: albumRows.map {
            ($0.0, (name: $0.2, id: $0.3))
        })

        let songbook: [String: [(String, String)]] = [
            "edge": [("返航", "Return Path"), ("失重", "Weightless"), ("舷窗", "Porthole"), ("暗物质", "Dark Matter")],
            "radio": [("呼号", "Call Sign"), ("夜班", "Night Shift"), ("短波", "Shortwave"), ("无人应答", "No Answer")],
            "cloud": [("云层", "Cloud Layer"), ("霓虹雨", "Neon Rain"), ("高架", "Overpass"), ("回港", "Back to Harbor")],
            "dust": [("折射", "Refraction"), ("尘埃", "Dust"), ("白噪", "White Noise"), ("余光", "Afterglow")],
            "silence": [("无声", "No Sound"), ("低语", "Undertone"), ("空舱", "Empty Cabin"), ("远星", "Far Star")],
            "forest": [("海阔天空", "Boundless"), ("光辉岁月", "Glorious Years"), ("情人", "Lover"), ("真的爱你", "Truly Love You")],
            "ordinary": [("平凡之路", "Ordinary Road"), ("白桦林", "White Birch"), ("那些花儿", "Those Flowers"), ("生如夏花", "Life Like Summer")],
            "voyager": [("Midnight City", "Midnight City"), ("Outro", "Outro"), ("Wait", "Wait"), ("Intro", "Intro")],
            "orbit": [("余温", "Afterheat"), ("滑行", "Glide"), ("近地点", "Perigee"), ("关机", "Power Down")],
            "letters": [("未寄出", "Unsent"), ("极光", "Aurora"), ("回信", "Reply"), ("邮票", "Postage")],
            "harbor": [("潮灯", "Tide Light"), ("缆绳", "Mooring"), ("雾笛", "Foghorn"), ("靠岸", "Docking")],
            "prism": [("光谱", "Spectrum"), ("切面", "Facet"), ("色散", "Dispersion"), ("焦点", "Focus")],
            "echo": [("回声", "Echo"), ("穹顶", "Dome"), ("合唱", "Chorus"), ("尾音", "Cadence")],
            "kites": [("纸鸢", "Paper Kite"), ("风", "Wind"), ("线", "String"), ("草地", "Grass")],
            "hurry": [("Teenagers", "Teenagers"), ("Kim & Jessie", "Kim & Jessie"), ("Wait", "Wait"), ("Graveyard Girl", "Graveyard Girl")],
            "emma": [("Flume", "Flume"), ("Skinny Love", "Skinny Love"), ("The Wolves", "The Wolves"), ("Re: Stacks", "Re: Stacks")],
        ]

        for album in albums {
            let pairs = songbook[album.id] ?? []
            guard let who = albumArtist[album.id] else { continue }
            for (index, pair) in pairs.enumerated() {
                let length = tracks.count
                let seconds = 154 + ((length * 29 + index * 11) % 246)
                tracks.append(Track(
                    id: "t\(length + 1)",
                    title: pair.0,
                    english: pair.1,
                    artist: who.name,
                    artistId: who.id,
                    album: album.name,
                    albumId: album.id,
                    durationMs: seconds * 1000
                ))
            }
        }

        let showcase = ["t1", "t2", "t3", "t4", "t5"]
        let playlists = [
            Playlist(id: "pls_night", name: "深夜航行", trackIDs: showcase),
            Playlist(id: "pls_focus", name: "专注深空", trackIDs: ["t5", "t2", "t4"]),
            Playlist(id: "pls_fav", name: "收藏夹", trackIDs: tracks.map(\.id)),
            Playlist(id: "pls_weekend", name: "周末漫游", trackIDs: ["t3", "t1"]),
            Playlist(id: "pls_dust", name: "星尘精选", trackIDs: ["t4", "t1"]),
            Playlist(id: "pls_commute", name: "通勤波段", trackIDs: ["t2", "t3"]),
            Playlist(id: "pls_rain", name: "雨夜电台", trackIDs: ["t5", "t2"]),
        ]
        return Seed(tracks: tracks, artists: artists, albums: albums, playlists: playlists)
    }

    static func uniquePlaylistID(existing: [Playlist]) -> String {
        let used = Set(existing.map(\.id))
        var n = existing.count + 1
        while true {
            let id = String(format: "pls_01J9X2K4M7NQP8RSTVN%03d", n)
            if !used.contains(id) { return id }
            n += 1
        }
    }
}
