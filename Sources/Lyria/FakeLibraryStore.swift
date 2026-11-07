import SwiftUI

/// In-memory shell state for the UI phase. No scan, playback engine, or network.
@MainActor
final class FakeLibraryStore: ObservableObject {
    @Published var tracks: [Track]
    @Published var artists: [Artist]
    @Published var albums: [Album]
    @Published var playlists: [Playlist]

    @Published var stack: [AppRoute] = [.library]
    @Published var searchText = ""
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
        queue = seed.tracks.map(\.id)
        nowPlayingId = seed.tracks.first?.id
        selectedTrackId = seed.tracks.first?.id
    }

    var route: AppRoute { stack.last ?? .library }

    var currentNav: NavItem { route.nav }

    var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isSearching: Bool { !trimmedQuery.isEmpty }

    var hasSearchHits: Bool {
        let query = trimmedQuery
        guard !query.isEmpty else { return false }
        func matches(_ text: String) -> Bool { text.localizedCaseInsensitiveContains(query) }
        if tracks.contains(where: { matches($0.title) || matches($0.artist) || matches($0.album) }) { return true }
        if artists.contains(where: { matches($0.name) }) { return true }
        if albums.contains(where: { matches($0.name) || matches($0.artistName) }) { return true }
        if playlists.contains(where: { matches($0.name) }) { return true }
        return false
    }

    var nowPlaying: Track? { track(nowPlayingId) }

    func track(_ id: String?) -> Track? {
        guard let id else { return nil }
        return tracks.first { $0.id == id }
    }

    func artist(_ id: String) -> Artist? { artists.first { $0.id == id } }

    func album(_ id: String) -> Album? { albums.first { $0.id == id } }

    func playlist(_ id: String) -> Playlist? { playlists.first { $0.id == id } }

    func tracks(forArtist name: String) -> [Track] {
        tracks.filter { $0.artist == name }
    }

    func tracks(forAlbum name: String) -> [Track] {
        tracks.filter { $0.album == name }
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

    func select(_ item: NavItem) {
        searchText = ""
        stack = [item.route]
    }

    func goBack() {
        if isSearching {
            searchText = ""
            return
        }
        guard stack.count > 1 else { return }
        stack.removeLast()
    }

    func openArtist(_ id: String) {
        searchText = ""
        stack = [.artists, .artist(id)]
    }

    func openAlbum(_ id: String) {
        searchText = ""
        stack = [.albums, .album(id)]
    }

    func openPlaylist(_ id: String) {
        searchText = ""
        stack = [.playlists, .playlist(id)]
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
        let tracks = [
            Track(id: "trk_01J9X2K4M7NQP8RSTUVWXY", title: "星际旅行", artist: "Dreamscape", album: "银河边缘", durationMs: 272_000),
            Track(id: "trk_01J9X2K4M7NQP8RSTUVWYA", title: "午夜信号", artist: "Aurora Line", album: "夜航电台", durationMs: 228_000),
            Track(id: "trk_01J9X2K4M7NQP8RSTUVWYB", title: "漂浮的城市", artist: "Neon Harbor", album: "云端漫步", durationMs: 302_000),
            Track(id: "trk_01J9X2K4M7NQP8RSTUVWYC", title: "光的碎片", artist: "Lumen", album: "星尘集", durationMs: 251_000),
            Track(id: "trk_01J9X2K4M7NQP8RSTUVWYD", title: "深空静默", artist: "Void Choir", album: "深空静默", durationMs: 380_000),
        ]
        let ids = tracks.map(\.id)

        let artistNames = ["Dreamscape", "Aurora Line", "Neon Harbor", "Lumen", "Void Choir", "The Paper Kites", "M83", "Bon Iver"]
        let artists = artistNames.enumerated().map { index, name in
            Artist(id: String(format: "art_01J9X2K4M7NQP8RSTVA%03d", index + 1), name: name)
        }

        let albumRows: [(String, String)] = [
            ("银河边缘", "Dreamscape"),
            ("夜航电台", "Aurora Line"),
            ("云端漫步", "Neon Harbor"),
            ("星尘集", "Lumen"),
            ("深空静默", "Void Choir"),
            ("挪威的森林", "Beyond"),
            ("Ordinary Road", "朴树"),
            ("Night Voyager", "M83"),
        ]
        let albums = albumRows.enumerated().map { index, row in
            Album(
                id: String(format: "alb_01J9X2K4M7NQP8RSTVB%03d", index + 1),
                name: row.0,
                artistName: row.1,
                year: 2024
            )
        }

        let playlists = [
            Playlist(id: "pls_01J9X2K4M7NQP8RSTVC001", name: "深夜航行", trackIDs: ids),
            Playlist(id: "pls_01J9X2K4M7NQP8RSTVC002", name: "专注深空", trackIDs: Array(ids.prefix(3))),
            Playlist(id: "pls_01J9X2K4M7NQP8RSTVC003", name: "收藏夹", trackIDs: ids),
            Playlist(id: "pls_01J9X2K4M7NQP8RSTVC004", name: "周末漫游", trackIDs: Array(ids.dropFirst(2).prefix(2))),
            Playlist(id: "pls_01J9X2K4M7NQP8RSTVC005", name: "星尘精选", trackIDs: Array(ids.suffix(2))),
            Playlist(id: "pls_01J9X2K4M7NQP8RSTVC006", name: "通勤波段", trackIDs: [ids[0], ids[2], ids[4]]),
            Playlist(id: "pls_01J9X2K4M7NQP8RSTVC007", name: "雨夜电台", trackIDs: [ids[1]]),
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
