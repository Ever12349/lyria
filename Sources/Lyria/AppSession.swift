import Combine
import Foundation
import LyriaCore

struct LibraryRemovalPrompt: Equatable {
    var trackIDs: [String]
    var title: String
    var message: String
}

/// Navigation, search, selection, and toasts. The database lives on `library`.
@MainActor
final class AppSession: ObservableObject {
    let library: LibraryStore

    @Published var stack: [AppRoute] = [.library]
    @Published var searchText = ""
    private var returnStack: [AppRoute]?
    @Published private(set) var selectedTrackIds: Set<String> = []
    private(set) var selectionAnchor: String?
    private(set) var selectionScopeIDs: [String] = []
    /// True after a click or menu on the current track table. ⌘A is ignored unless this is set.
    var trackTableFocused = false
    @Published var libraryRemovalPrompt: LibraryRemovalPrompt?
    /// Kept beside the prompt so confirm still runs if the dialog clears the prompt first.
    private var libraryRemovalIDs: [String] = []
    @Published var queueVisible = false
    @Published var toast: String?
    private var toastToken = 0
    private var didBootstrap = false
    private var liveTrackIDs: Set<String> = []
    /// Bumped on navigation so a menu-open selection update cannot land on the next page.
    private var menuEpoch = 0
    private var cancellables = Set<AnyCancellable>()

    init() {
        let library = LibraryStore()
        self.library = library
        library.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        // dropFirst skips the synchronous current-value event during init.
        library.$tracks.dropFirst().sink { [weak self] tracks in
            self?.libraryTracksChanged(tracks)
        }.store(in: &cancellables)
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
    var showsBatchBar: Bool { selectedTrackIds.count >= 2 }

    var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isSearching: Bool { !trimmedQuery.isEmpty }

    var tracks: [Track] { library.tracks }
    var artists: [Artist] { library.artists }
    var albums: [Album] { library.albums }
    var playlists: [Playlist] { library.playlists }
    var scanSession: ScanSession { library.scanSession }

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

    func orderedSelectionIDs() -> [String] {
        TrackSelection.orderedIDs(selected: selectedTrackIds, orderedIDs: selectionScopeIDs)
    }

    func noteSelectionScope(_ ids: [String]) {
        if ids != selectionScopeIDs {
            selectionScopeIDs = ids
        }
        apply(TrackSelection.prune(selectionState, keeping: Set(ids)))
    }

    func clickTrack(_ id: String, command: Bool, shift: Bool) {
        trackTableFocused = true
        apply(TrackSelection.click(
            id,
            command: command,
            shift: shift,
            state: selectionState,
            orderedIDs: selectionScopeIDs
        ))
    }

    /// Right-click / ⋯ on an unselected row replaces the selection with that row.
    func prepareMenu(for trackID: String) {
        guard !selectedTrackIds.contains(trackID) else { return }
        guard selectionScopeIDs.contains(trackID) else { return }
        apply(TrackSelection.replace(trackID))
    }

    func scheduleMenuSelection(for trackID: String) {
        let needsSelection = !selectedTrackIds.contains(trackID)
        guard needsSelection || !trackTableFocused else { return }
        let epoch = menuEpoch
        DispatchQueue.main.async { [weak self] in
            guard let self, self.menuEpoch == epoch else { return }
            self.prepareMenu(for: trackID)
            self.trackTableFocused = true
        }
    }

    func selectAllInScope() {
        guard !selectionScopeIDs.isEmpty else { return }
        apply(TrackSelection.selectAll(orderedIDs: selectionScopeIDs, state: selectionState))
    }

    func clearSelection() {
        apply(TrackSelection.clear())
    }

    func updateQuery(_ raw: String) {
        let previous = trimmedQuery
        let nowEmpty = raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !nowEmpty && previous.isEmpty {
            returnStack = stack
        }
        if raw.trimmingCharacters(in: .whitespacesAndNewlines) != previous {
            dismissSelectionForNavigation()
        }
        searchText = raw
        if nowEmpty, let saved = returnStack {
            stack = saved
            returnStack = nil
        }
    }

    func select(_ item: NavItem) {
        dismissSelectionForNavigation()
        returnStack = nil
        searchText = ""
        stack = [item.route]
    }

    func goBack() {
        dismissSelectionForNavigation()
        if isSearching {
            updateQuery("")
            return
        }
        guard stack.count > 1 else { return }
        stack.removeLast()
    }

    func openArtist(_ id: String) {
        dismissSelectionForNavigation()
        returnStack = nil
        searchText = ""
        stack = [.artists, .artist(id)]
    }

    func openAlbum(_ id: String) {
        dismissSelectionForNavigation()
        returnStack = nil
        searchText = ""
        stack = [.albums, .album(id)]
    }

    func openPlaylist(_ id: String) {
        dismissSelectionForNavigation()
        returnStack = nil
        searchText = ""
        stack = [.playlists, .playlist(id)]
    }

    func scanTracks() {
        library.scanTracks()
    }

    func cancelScan() {
        library.cancelScan()
    }

    func requestLibraryRemoval(_ ids: [String]) {
        let ordered = Self.deduped(ids)
        guard !ordered.isEmpty else { return }
        let title: String
        let message: String
        if ordered.count == 1 {
            let name = track(ordered[0])?.title ?? "曲目"
            title = "从曲库移除「\(name)」？"
            message = "文件会留在磁盘上。这一首会从曲库和播放列表里删掉，再次导入仍使用原来的 id。"
        } else {
            title = "从曲库移除 \(ordered.count) 首？"
            message = "文件会留在磁盘上。这些曲目会从曲库和播放列表里删掉，再次导入仍使用原来的 id。"
        }
        libraryRemovalIDs = ordered
        libraryRemovalPrompt = LibraryRemovalPrompt(trackIDs: ordered, title: title, message: message)
    }

    func commitLibraryRemoval() {
        let ids = libraryRemovalIDs
        guard !ids.isEmpty else { return }
        libraryRemovalIDs = []
        libraryRemovalPrompt = nil
        let singleTitle = ids.count == 1 ? (track(ids[0])?.title ?? "曲目") : nil
        Task {
            let removed = await library.deleteTracks(ids: ids)
            guard removed else {
                showToast("移除曲目失败")
                return
            }
            if let singleTitle {
                showToast("已从曲库移除「\(singleTitle)」")
            } else {
                showToast("已从曲库移除 \(ids.count) 首")
            }
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
                dismissSelectionForNavigation()
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

    func addToPlaylist(_ ids: [String], playlistID: String) {
        let ordered = Self.deduped(ids)
        guard let playlist = playlist(playlistID), !ordered.isEmpty else { return }
        if ordered.count == 1 {
            add(ordered[0], to: playlistID)
            return
        }
        let name = playlist.name
        Task {
            guard let result = await library.addTracks(ordered, to: playlistID) else {
                showToast("加入播放列表失败")
                return
            }
            // Selection stays; a single-track add does not clear it either.
            if result.added == 0, result.skipped > 0 {
                showToast("已在「\(name)」中")
            } else if result.added > 0, result.skipped > 0 {
                showToast("已加入 \(result.added) 首到「\(name)」，跳过 \(result.skipped) 首（已在列表）")
            } else if result.added > 0 {
                showToast("已加入 \(result.added) 首到「\(name)」")
            } else {
                showToast("加入播放列表失败")
            }
        }
    }

    func remove(_ trackID: String, from playlistID: String) {
        Task {
            let removed = await library.removeTrackFromPlaylist(trackID, playlistID: playlistID)
            showToast(removed ? "已从播放列表移除" : "从播放列表移除失败")
        }
    }

    func removeFromPlaylist(_ ids: [String], playlistID: String) {
        let ordered = Self.deduped(ids)
        guard !ordered.isEmpty else { return }
        if ordered.count == 1 {
            remove(ordered[0], from: playlistID)
            return
        }
        Task {
            guard let removed = await library.removeTracksFromPlaylist(ordered, playlistID: playlistID) else {
                showToast("从播放列表移除失败")
                return
            }
            showToast(removed > 0 ? "已从播放列表移除 \(removed) 首" : "从播放列表移除失败")
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

    private var selectionState: TrackSelectionState {
        TrackSelectionState(ids: selectedTrackIds, anchor: selectionAnchor)
    }

    private func apply(_ state: TrackSelectionState) {
        selectionAnchor = state.anchor
        if selectedTrackIds != state.ids {
            selectedTrackIds = state.ids
        }
    }

    private func dismissSelectionForNavigation() {
        menuEpoch += 1
        clearSelection()
        trackTableFocused = false
    }

    /// Playlist placeholders live only in the current table, so a reload must not drop them.
    /// Ids that disappeared from the library are removed even if the table scope is still stale.
    private func libraryTracksChanged(_ tracks: [Track]) {
        let live = Set(tracks.map(\.id))
        let scope = Set(selectionScopeIDs)
        let placeholders = scope.subtracting(liveTrackIDs).subtracting(live)
        liveTrackIDs = live
        apply(TrackSelection.prune(selectionState, keeping: live.union(placeholders)))
    }

    private static func deduped(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { seen.insert($0).inserted }
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
