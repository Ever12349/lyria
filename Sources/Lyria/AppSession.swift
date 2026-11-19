import AppKit
import Combine
import Foundation
import LyriaCore

struct LibraryRemovalPrompt: Equatable {
    var trackIDs: [String]
    var title: String
    var message: String
}

struct PlaylistComposer: Identifiable, Equatable {
    let id = UUID()
    var suggestedName: String
    var trackIDs: [String]
    var openAfterCreate: Bool
}

/// Navigation, search, selection, and toasts. The database lives on `library`.
@MainActor
final class AppSession: ObservableObject {
    let library: LibraryStore

    @Published private(set) var navigation = SectionNavigation()
    @Published var searchText = ""
    @Published private(set) var selectedTrackIds: Set<String> = []
    private(set) var selectionAnchor: String?
    private(set) var selectionScopeIDs: [String] = []
    /// True after a click or menu on the current track table. ⌘A is ignored unless this is set.
    var trackTableFocused = false
    @Published var libraryRemovalPrompt: LibraryRemovalPrompt?
    @Published var playlistComposer: PlaylistComposer?
    /// Kept beside the prompt so confirm still runs if the dialog clears the prompt first.
    private var libraryRemovalIDs: [String] = []
    private var libraryRemovalRequest = 0
    @Published var queueVisible = false {
        didSet {
            guard !isRestoringUI, oldValue != queueVisible else { return }
            persistUINow()
        }
    }
    @Published var sidebarWidth: CGFloat = CGFloat(UISession.sidebarDefault)
    @Published var toast: String?
    private var toastToken = 0
    private var didBootstrap = false
    private var isRestoringUI = false
    private var liveTrackIDs: Set<String> = []
    private var cancellables = Set<AnyCancellable>()
    private let engine: PlaybackEngine
    let transport: TransportState
    let queueState: PlaybackQueueState
    private var engineMirror: Task<Void, Never>?

    init(engine: PlaybackEngine, transport: TransportState, queueState: PlaybackQueueState) {
        self.engine = engine
        self.transport = transport
        self.queueState = queueState
        let library = LibraryStore()
        self.library = library
        let events = engine.events
        engineMirror = Task { [weak self] in
            for await event in events {
                self?.applyEngine(event)
            }
        }
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

    deinit {
        engineMirror?.cancel()
    }

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        await library.open()
        restoreUISession()
        await restorePlaybackSession()
    }

    func persistUINow() {
        UISessionStore.save(
            UISession(
                sidebarWidth: Double(sidebarWidth),
                queueVisible: queueVisible,
                navigation: navigation
            )
        )
    }

    func commitSidebarWidth() {
        let clamped = CGFloat(UISession.clampedWidth(Double(sidebarWidth)))
        if sidebarWidth != clamped {
            sidebarWidth = clamped
        }
        persistUINow()
    }

    private func restoreUISession() {
        isRestoringUI = true
        defer { isRestoringUI = false }
        guard let saved = UISessionStore.load() else { return }
        sidebarWidth = CGFloat(UISession.clampedWidth(saved.sidebarWidth))
        queueVisible = saved.queueVisible
        navigation.restore(
            section: saved.section,
            stacks: saved.stacks,
            artistIDs: Set(artists.map(\.id)),
            albumIDs: Set(albums.map(\.id)),
            playlistIDs: Set(playlists.map(\.id))
        )
    }

    private func restorePlaybackSession() async {
        guard let saved = PlaybackSessionStore.load(), !saved.isEmpty else { return }
        await engine.restore(
            saved,
            tracks: tracks.map(ResolvedTrack.init),
            shuffle: transport.shuffle,
            repeatMode: transport.repeatMode
        )
    }

    private func persistNavigation() {
        guard !isRestoringUI else { return }
        persistUINow()
    }

    var route: AppRoute { AppRoute(navigation.page) }
    var currentSection: NavItem { NavItem(navigation.section) }
    /// Page-head title follows the top route. Sidebar highlight uses `currentSection`.
    var currentNav: NavItem { currentSection }

    func routes(in item: NavItem) -> [AppRoute] {
        navigation.stack(for: item.section).map(AppRoute.init)
    }

    func pageIdentity(_ item: NavItem, _ route: AppRoute) -> String {
        let section = item.section
        if route == item.route {
            return "\(section.rawValue)-root-\(navigation.rootGeneration[section, default: 0])"
        }
        return "\(section.rawValue)-\(route.stackKey)"
    }
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
    var progressTitle: String { library.progressTitle }

    var recentPlaylists: [Playlist] {
        let ids = PlaylistRecency.recentIDs(playlists.map { PlaylistUse(id: $0.id, lastUsedAt: $0.lastUsedAt) })
        return ids.compactMap { id in playlists.first { $0.id == id } }
    }

    /// Library table. Newest `addedAt` first. The stored catalog stays title-ordered for search.
    var visibleTracks: [Track] {
        AddTimeOrder.newestFirst(tracks) { $0.addedAt }
    }

    var searchTracks: [Track] {
        let query = trimmedQuery
        guard !query.isEmpty else { return [] }
        return tracks.filter { track in
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
        AddTimeOrder.newestFirst(tracks.filter { $0.artistId == artistID }) { $0.addedAt }
    }

    func tracks(albumID: String) -> [Track] {
        AddTimeOrder.newestFirst(tracks.filter { $0.albumId == albumID }) { $0.addedAt }
    }

    func albums(artistID: String) -> [Album] {
        let ids = AlbumFacts.albumIDs(
            forArtist: artistID,
            tracks: tracks.map { ($0.albumId, $0.artistId) }
        )
        return albums.filter { ids.contains($0.id) }
    }

    func tracks(in playlist: Playlist) -> [Track] {
        playlist.trackIDs.map { id in
            track(id) ?? Track.missingPlaceholder(id: id)
        }
    }

    /// Distinct on-disk covers among playlist members, in list order (max 4).
    func artworkPaths(for playlist: Playlist) -> [String] {
        PlaylistArtwork.paths(from: playlist.trackIDs.map { track($0)?.artworkPath })
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
    /// Call only when the menu opens, not while its content is refreshed.
    func prepareMenu(for trackID: String) {
        guard !selectedTrackIds.contains(trackID) else { return }
        guard selectionScopeIDs.contains(trackID) else { return }
        trackTableFocused = true
        apply(TrackSelection.replace(trackID))
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
        if raw.trimmingCharacters(in: .whitespacesAndNewlines) != previous {
            dismissSelectionForNavigation()
        }
        searchText = raw
        if nowEmpty {
            navigation.endSearch()
        } else if previous.isEmpty {
            navigation.beginSearch()
        }
    }

    func select(_ item: NavItem) {
        dismissSelectionForNavigation()
        searchText = ""
        navigation.select(item.section)
        persistNavigation()
    }

    /// Logo. Restores the library list from the top and leaves other sections alone.
    func showLibraryHome() {
        dismissSelectionForNavigation()
        searchText = ""
        navigation.showLibraryHome()
        persistNavigation()
    }

    func goBack() {
        dismissSelectionForNavigation()
        if navigation.isSearching {
            updateQuery("")
            return
        }
        if let query = navigation.goBack() {
            searchText = query
        }
        persistNavigation()
    }

    func openArtist(_ id: String) {
        dismissSelectionForNavigation()
        let query = navigation.isSearching ? trimmedQuery : nil
        navigation.openArtist(id, resumeQuery: query)
        searchText = ""
        persistNavigation()
    }

    func openAlbum(_ id: String) {
        dismissSelectionForNavigation()
        let query = navigation.isSearching ? trimmedQuery : nil
        navigation.openAlbum(id, resumeQuery: query)
        searchText = ""
        persistNavigation()
    }

    func revealInFinder(_ ids: [String]) {
        var targets: [RevealTarget] = []
        targets.reserveCapacity(ids.count)
        for id in ids {
            guard let row = track(id) else { return }
            targets.append(RevealTarget(missing: row.missing, path: row.path))
        }
        switch RevealInFinder.click(targets, fileExists: { FileManager.default.fileExists(atPath: $0) }) {
        case .unavailable:
            return
        case .notFound:
            showToast("找不到文件")
        case .reveal(let path):
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        }
    }

    func openPlaylist(_ id: String) {
        dismissSelectionForNavigation()
        searchText = ""
        navigation.openPlaylist(id)
        persistNavigation()
        // Opening is navigation only. Stamping here reorders the sidebar under the cursor.
    }

    func scanTracks() {
        library.scanTracks()
    }

    func addAudioFiles() {
        library.addAudioFiles()
    }

    func cancelScan() {
        library.cancelScan()
    }

    func requestLibraryRemoval(_ ids: [String]) {
        let ordered = Self.deduped(ids)
        guard !ordered.isEmpty else { return }
        libraryRemovalRequest += 1
        let request = libraryRemovalRequest
        let singleTitle = ordered.count == 1 ? (track(ordered[0])?.title ?? "曲目") : nil
        Task {
            let records = await library.trackPaths(ids: ordered)
            let mentionsICloud = records.contains { record in
                ([record.path] + record.aliases).contains { library.isUbiquitousItem(atPath: $0) }
            }
            guard libraryRemovalRequest == request else { return }
            libraryRemovalIDs = ordered
            libraryRemovalPrompt = LibraryRemovalPrompt(
                trackIDs: ordered,
                title: LibraryRemovalCopy.confirmTitle(count: ordered.count, singleTitle: singleTitle),
                message: LibraryRemovalCopy.confirmMessage(mentionsICloud: mentionsICloud)
            )
        }
    }

    func commitLibraryRemoval() {
        let ids = libraryRemovalIDs
        guard !ids.isEmpty else { return }
        libraryRemovalIDs = []
        libraryRemovalPrompt = nil
        let singleTitle = ids.count == 1 ? (track(ids[0])?.title ?? "曲目") : "曲目"
        Task {
            let removed = await library.deleteTracks(ids: ids)
            guard removed else {
                showToast(LibraryRemovalCopy.deleteFailed)
                return
            }
            showToast(LibraryRemovalCopy.libraryOnlyToast(count: ids.count, singleTitle: singleTitle))
            await engine.removeFromQueue(Set(ids))
        }
    }

    func commitLibraryRemovalToTrash() {
        let ids = libraryRemovalIDs
        guard !ids.isEmpty else { return }
        libraryRemovalIDs = []
        libraryRemovalPrompt = nil
        let singleTitle = ids.count == 1 ? (track(ids[0])?.title ?? "曲目") : "曲目"
        Task {
            guard let outcomes = await library.trashThenDeleteTracks(ids: ids) else {
                showToast(LibraryRemovalCopy.deleteFailed)
                return
            }
            showToast(LibraryRemovalCopy.trashToast(outcomes: outcomes, singleTitle: singleTitle))
            await engine.removeFromQueue(Set(ids))
        }
    }

    func clearFingerprints() {
        Task { await library.clearFingerprints() }
    }

    /// Dashed card. The name dialog opens the new playlist and does not add tracks.
    func createPlaylist() {
        promptNewPlaylist(adding: [], openAfterCreate: true)
    }

    func promptNewPlaylist(adding trackIDs: [String], openAfterCreate: Bool = false) {
        playlistComposer = PlaylistComposer(
            suggestedName: Self.uniquePlaylistName(existing: playlists.map(\.name)),
            trackIDs: trackIDs,
            openAfterCreate: openAfterCreate
        )
    }

    func cancelNewPlaylist() {
        playlistComposer = nil
    }

    func commitNewPlaylist(named raw: String) {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let composer = playlistComposer else { return }
        let trackIDs = composer.trackIDs
        let openAfter = composer.openAfterCreate
        playlistComposer = nil
        let id = EntityID.playlist()
        Task {
            let created = await library.createPlaylist(id: id, name: name)
            guard created else {
                showToast("新建播放列表失败")
                return
            }
            if trackIDs.isEmpty {
                showToast("已新建「\(name)」")
                if openAfter { openPlaylist(id) }
                return
            }
            guard let result = await library.addTracks(trackIDs, to: id) else {
                showToast("加入播放列表失败")
                return
            }
            showToast("已新建「\(name)」并加入 \(result.added) 首")
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
            if navigation.stack(for: .playlists).last == .playlist(id) {
                if navigation.section == .playlists {
                    dismissSelectionForNavigation()
                }
                navigation.deletedOpenPlaylist(id)
                persistNavigation()
            }
            showToast("已删除「\(playlist.name)」")
        }
    }

    func add(_ trackID: String, to playlistID: String) {
        guard let playlist = playlist(playlistID), track(trackID) != nil else { return }
        let already = playlist.trackIDs.contains(trackID)
        let name = playlist.name
        Task {
            await library.stampPlaylistUsed(id: playlistID)
            if already {
                showToast("已在「\(name)」中")
                return
            }
            let added = await library.addTrack(trackID, to: playlistID)
            showToast(added ? "已加入「\(name)」" : "加入播放列表失败")
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
            await library.stampPlaylistUsed(id: playlistID)
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

    func menuPlay(_ track: Track, in list: [Track]) {
        stampIfPlaylistPlaybackStarts(trackID: track.id, intent: .menuPlay)
        let snapshot = list.map(ResolvedTrack.init)
        Task { await engine.play(list: snapshot, startID: track.id, intent: .menuPlay) }
    }

    func coverPressed(_ track: Track, in list: [Track]) {
        stampIfPlaylistPlaybackStarts(trackID: track.id, intent: .cover)
        let snapshot = list.map(ResolvedTrack.init)
        Task { await engine.play(list: snapshot, startID: track.id, intent: .cover) }
    }

    func doubleClicked(_ track: Track, in list: [Track]) {
        stampIfPlaylistPlaybackStarts(trackID: track.id, intent: .doubleClick)
        let snapshot = list.map(ResolvedTrack.init)
        Task { await engine.play(list: snapshot, startID: track.id, intent: .doubleClick) }
    }

    func playAll(_ list: [Track]) {
        stampIfPlaylistPlaybackStarts()
        let snapshot = list.map(ResolvedTrack.init)
        Task { await engine.playAll(snapshot) }
    }

    func playShuffled(_ list: [Track]) {
        stampIfPlaylistPlaybackStarts()
        let snapshot = list.map(ResolvedTrack.init)
        Task { await engine.playShuffled(snapshot) }
    }

    func enqueueAll(_ list: [Track]) {
        let snapshot = list.map(ResolvedTrack.init)
        Task { await engine.enqueue(snapshot) }
    }

    func playNext(_ ids: [String]) {
        let snapshot = resolved(ids)
        guard !snapshot.isEmpty else { return }
        Task { await engine.playNext(snapshot) }
    }

    func enqueue(_ ids: [String]) {
        let snapshot = resolved(ids)
        guard !snapshot.isEmpty else { return }
        Task { await engine.enqueue(snapshot) }
    }

    func playQueueRow(_ index: Int) {
        Task { await engine.playQueueIndex(index) }
    }

    func transportToggle() {
        Task { await engine.toggleTransport() }
    }

    func transportNext() {
        Task { await engine.next() }
    }

    func transportPrevious() {
        Task { await engine.previous() }
    }

    func transportToggleShuffle() {
        Task { await engine.toggleShuffle() }
    }

    func transportToggleRepeat() {
        Task { await engine.toggleRepeat() }
    }

    func transportSeek(ms: Int) {
        Task { await engine.seek(to: ms) }
    }

    func transportSeek(by deltaMs: Int) {
        Task { await engine.seek(by: deltaMs) }
    }

    func transportSetVolume(_ value: Double) {
        Task { await engine.setVolume(value) }
    }

    func transportToggleSpeaker() {
        Task { await engine.toggleSpeaker() }
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

    private func resolved(_ ids: [String]) -> [ResolvedTrack] {
        ids.compactMap { id in
            track(id).map(ResolvedTrack.init)
        }
    }

    private func applyEngine(_ event: EngineEvent) {
        switch event {
        case .toast(let message):
            showToast(message)
        case .showQueue:
            queueVisible = true
        case .state(let snapshot):
            transport.apply(snapshot)
            queueState.apply(snapshot)
        case .position(let ms):
            transport.applyPosition(ms)
        case .volume(let value):
            transport.applyVolume(value)
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
        var nav = navigation
        nav.pruneInvalidPages(
            artistIDs: Set(artists.map(\.id)),
            albumIDs: Set(albums.map(\.id)),
            playlistIDs: Set(playlists.map(\.id))
        )
        if nav != navigation {
            navigation = nav
            persistNavigation()
        }
    }

    private func stampPlaylist(_ id: String) {
        Task { await library.stampPlaylistUsed(id: id) }
    }

    /// Playlist page only. Cover-on-current toggles and double-click-on-current restarts, so those do not count.
    private func stampIfPlaylistPlaybackStarts(trackID: String? = nil, intent: RowPlayIntent? = nil) {
        guard !isSearching, case .playlist(let playlistID) = route else { return }
        if let trackID, let intent, trackID == transport.current?.id {
            if intent == .cover || intent == .doubleClick { return }
        }
        stampPlaylist(playlistID)
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
