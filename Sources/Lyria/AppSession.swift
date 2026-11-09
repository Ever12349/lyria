import Combine
import Foundation
import LyriaCore

/// Navigation, search, selection, and toasts. The database lives on `library`.
@MainActor
final class AppSession: ObservableObject {
    let library: LibraryStore

    @Published var stack: [AppRoute] = [.library]
    @Published var searchText = ""
    private var returnStack: [AppRoute]?
    @Published var selectedTrackId: String?
    @Published var queueVisible = false
    @Published var toast: String?
    private var toastToken = 0
    private var didBootstrap = false
    private var libraryTicket: AnyCancellable?

    init() {
        let library = LibraryStore()
        self.library = library
        libraryTicket = library.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        library.onToast = { [weak self] message in
            self?.showToast(message)
        }
    }

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        await library.open()
    }

    var route: AppRoute { stack.last ?? .library }
    var currentNav: NavItem { route.nav }

    var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isSearching: Bool { !trimmedQuery.isEmpty }

    var tracks: [Track] { library.tracks }
    var artists: [Artist] { library.artists }
    var albums: [Album] { library.albums }
    var playlists: [Playlist] { library.playlists }
    var rootLabel: String { library.rootLabel }
    var isScanning: Bool { library.isScanning }
    var scanPercent: Int { library.scanPercent }

    var visibleTracks: [Track] { tracks }

    var searchTracks: [Track] {
        let query = trimmedQuery
        guard !query.isEmpty else { return [] }
        return visibleTracks.filter { track in
            track.title.localizedCaseInsensitiveContains(query)
                || track.artistLabel.localizedCaseInsensitiveContains(query)
                || track.albumLabel.localizedCaseInsensitiveContains(query)
        }
    }

    var hasSearchHits: Bool { !searchTracks.isEmpty }

    func track(_ id: String?) -> Track? {
        guard let id else { return nil }
        return tracks.first { $0.id == id }
    }

    func artist(_ id: String) -> Artist? { artists.first { $0.id == id } }
    func album(_ id: String) -> Album? { albums.first { $0.id == id } }
    func playlist(_ id: String) -> Playlist? { playlists.first { $0.id == id } }

    func tracks(artistID: String) -> [Track] {
        tracks.filter { $0.artistId == artistID }
    }

    func tracks(albumID: String) -> [Track] {
        tracks.filter { $0.albumId == albumID }
    }

    func albums(artistID: String) -> [Album] {
        albums.filter { $0.artistId == artistID }
    }

    func tracks(in playlist: Playlist) -> [Track] {
        playlist.trackIDs.map { id in
            track(id) ?? Track.missingPlaceholder(id: id)
        }
    }

    func durationMs(of ids: [String]) -> Int {
        ids.reduce(0) { partial, id in
            partial + (track(id)?.durationMs ?? 0)
        }
    }

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

    func chooseRootAndScan() {
        library.chooseRootAndScan(force: false)
    }

    func rescanNow() {
        library.rescanNow()
    }

    func removeFromLibrary(_ id: String) {
        let title = track(id)?.title ?? "曲目"
        Task {
            let removed = await library.deleteTrack(id: id)
            guard removed else {
                showToast("移除曲目失败")
                return
            }
            if selectedTrackId == id { selectedTrackId = nil }
            showToast("已从曲库移除「\(title)」")
        }
    }

    func clearFingerprints() {
        Task { await library.clearFingerprints() }
    }

    func createPlaylist() {
        let name = Self.uniquePlaylistName(existing: playlists.map(\.name))
        let id = EntityID.playlist()
        Task {
            let created = await library.createPlaylist(id: id, name: name)
            guard created else {
                showToast("新建播放列表失败")
                return
            }
            openPlaylist(id)
            showToast("已新建「\(name)」")
        }
    }

    func renamePlaylist(_ id: String, to name: String) {
        Task {
            let renamed = await library.renamePlaylist(id: id, name: name)
            showToast(renamed ? "已重命名为「\(name)」" : "重命名失败")
        }
    }

    func deletePlaylist(_ id: String) {
        guard let playlist = playlist(id) else { return }
        Task {
            let deleted = await library.deletePlaylist(id: id)
            guard deleted else {
                showToast("删除播放列表失败")
                return
            }
            if case .playlist(let current) = route, current == id {
                stack = [.playlists]
            }
            showToast("已删除「\(playlist.name)」")
        }
    }

    func add(_ trackID: String, to playlistID: String) {
        guard let playlist = playlist(playlistID), track(trackID) != nil else { return }
        if playlist.trackIDs.contains(trackID) {
            showToast("已在「\(playlist.name)」中")
            return
        }
        Task {
            let added = await library.addTrack(trackID, to: playlistID)
            showToast(added ? "已加入「\(playlist.name)」" : "加入播放列表失败")
        }
    }

    func remove(_ trackID: String, from playlistID: String) {
        Task {
            let removed = await library.removeTrackFromPlaylist(trackID, playlistID: playlistID)
            showToast(removed ? "已从播放列表移除" : "从播放列表移除失败")
        }
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

    private static func uniquePlaylistName(existing: [String]) -> String {
        let used = Set(existing)
        if !used.contains("新播放列表") { return "新播放列表" }
        var number = 2
        while used.contains("新播放列表 \(number)") {
            number += 1
        }
        return "新播放列表 \(number)"
    }
}
