import AppKit
import Foundation
import LyriaCore
import UniformTypeIdentifiers

enum LibraryActivityKind: Equatable {
    case scan
    case add
}

/// Library database façade. Scanning never starts by itself.
@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var tracks: [Track] = []
    @Published private(set) var artists: [Artist] = []
    @Published private(set) var albums: [Album] = []
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var scanSession = ScanSession.idle
    @Published private(set) var activityKind: LibraryActivityKind = .scan

    var progressTitle: String {
        switch activityKind {
        case .scan:
            return "正在扫描曲库 · \(scanSession.percent)%"
        case .add:
            return "正在添加曲目 · \(scanSession.percent)%"
        }
    }

    var onToast: ((String) -> Void)?
    /// Runs after the database is open and before the catalog snapshot, so MCP can listen within the bridge budget.
    var onDatabaseReady: (() async -> Void)?
    var onLibraryFailed: (() -> Void)?

    private let database = LibraryDatabase()
    private let securityScope = SecurityScope()
    private var rootPath: String?
    private var didOpen = false
    private var scanCancellation = ScanCancellation()
    private var lastReloadAt: TimeInterval?

    func open() async {
        guard !didOpen else { return }
        didOpen = true
        do {
            let url = try SupportPaths.databaseURL()
            try await database.open(path: url.path)
            await onDatabaseReady?()
            try await reload()
            if let stored = try await database.scanRoot() {
                let resolved = stored.bookmark.flatMap { BookmarkData.resolve($0) }
                if let resolved {
                    securityScope.replace(with: resolved)
                }
                let path = resolved.map { PathUtil.standardize($0) } ?? stored.path
                if let resolved, path != stored.path {
                    let bookmark = BookmarkData.make(for: resolved) ?? stored.bookmark
                    try? await database.setScanRoot(path: path, bookmark: bookmark)
                }
                rootPath = path
            }
        } catch {
            onToast?(AgentCopy.databaseFailed)
            onLibraryFailed?()
        }
    }

    func isMCPEnabled() async -> Bool {
        let value = try? await database.setting("mcp_enabled")
        return value != "0"
    }

    func setMCPEnabled(_ enabled: Bool) async throws {
        try await database.setSetting("mcp_enabled", enabled ? "1" : "0")
    }

    func isHTTPEnabled() async -> Bool {
        let value = try? await database.setting("http_enabled")
        return value == "1"
    }

    func setHTTPEnabled(_ enabled: Bool) async throws {
        try await database.setSetting("http_enabled", enabled ? "1" : "0")
    }

    /// Folder picker, then an incremental scan. Also used by the empty-library button.
    func scanTracks() {
        guard !scanSession.isRunning else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "扫描"
        panel.message = "选择曲库文件夹"
        if let rootPath {
            panel.directoryURL = URL(fileURLWithPath: rootPath, isDirectory: true)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        securityScope.replace(with: url)
        let path = PathUtil.standardize(url)
        let bookmark = BookmarkData.make(for: url)
        guard let cancellation = beginActivity(.scan) else { return }
        Task {
            do {
                try await database.setScanRoot(path: path, bookmark: bookmark)
                rootPath = path
                if cancellation.isCancelled {
                    scanSession = ScanSession(phase: .cancelled, percent: 0)
                    onToast?("已取消扫描")
                    return
                }
                launchScan(rootPath: path, force: false, cancellation: cancellation)
            } catch {
                scanSession = ScanSession(phase: .failed, percent: 0)
                onToast?("无法保存曲库路径")
            }
        }
    }

    /// Files only. Does not change the scan root and does not call `finishScan`.
    func addAudioFiles() {
        guard !scanSession.isRunning else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.allowsOtherFileTypes = false
        panel.prompt = "添加"
        panel.message = "选择曲目"
        panel.allowedContentTypes = MetadataReader.audioExtensions.compactMap { UTType(filenameExtension: $0) }
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls.filter { url in
            MetadataReader.audioExtensions.contains(url.pathExtension.lowercased())
        }
        guard !urls.isEmpty else { return }
        guard let cancellation = beginActivity(.add) else { return }
        launchImport(urls: urls, cancellation: cancellation)
    }

    func cancelScan() {
        guard scanSession.isRunning else { return }
        scanCancellation.cancel()
    }

    func deleteTrack(id: String) async -> Bool {
        await deleteTracks(ids: [id])
    }

    func trackPaths(ids: [String]) async -> [StoredTrackPaths] {
        (try? await database.trackPaths(ids: ids)) ?? []
    }

    /// `URLResourceValues.isUbiquitousItem`. A failed lookup is not ubiquitous.
    func isUbiquitousItem(atPath path: String) -> Bool {
        guard !path.isEmpty else { return false }
        let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.isUbiquitousItemKey])
        return values?.isUbiquitousItem == true
    }

    /// Trash recorded audio paths, then the existing library delete. `deleteTracks` itself does not trash.
    func trashThenDeleteTracks(ids: [String]) async -> [LibraryRemovalTrackOutcome]? {
        let records = await trackPaths(ids: ids)
        let byID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        var resultByPath: [String: LibraryRemovalFileResult] = [:]
        var orderedPaths: [String] = []
        var seen = Set<String>()
        for id in ids {
            for path in Self.recordedPaths(byID[id]) where seen.insert(path).inserted {
                orderedPaths.append(path)
            }
        }
        for path in orderedPaths {
            resultByPath[path] = Self.trashRecordedFile(at: path)
        }
        let outcomes = ids.map { id -> LibraryRemovalTrackOutcome in
            let results = Self.recordedPaths(byID[id]).map { resultByPath[$0] ?? .missing }
            return LibraryRemovalCopy.trackOutcome(fileResults: results)
        }
        let removed = await deleteTracks(ids: ids)
        return removed ? outcomes : nil
    }

    /// One transaction, then one reload. Artwork files are removed only after the commit.
    func deleteTracks(ids: [String]) async -> Bool {
        guard !ids.isEmpty else { return false }
        do {
            try await database.deleteTracks(ids: ids)
            for id in ids {
                SupportPaths.deleteArtwork(trackID: id)
            }
            try await reload()
            return true
        } catch {
            return false
        }
    }

    func clearFingerprints() async {
        do {
            try await database.clearLibraryIndex()
            SupportPaths.deleteAllArtwork()
            try await reload()
            onToast?("已清除指纹缓存")
        } catch {
            onToast?("清除指纹缓存失败")
        }
    }

    func stampPlaylistUsed(id: String) async {
        do {
            guard let stamp = try await database.stampPlaylistUsed(id: id) else { return }
            guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
            var next = playlists
            next[index].lastUsedAt = stamp
            playlists = next
        } catch {}
    }

    func createPlaylist(id: String, name: String) async -> Bool {
        do {
            try await database.createPlaylist(id: id, name: name)
            try await reload()
            return true
        } catch {
            return false
        }
    }

    func renamePlaylist(id: String, name: String) async -> Bool {
        do {
            try await database.renamePlaylist(id: id, name: name)
            try await reload()
            return true
        } catch {
            return false
        }
    }

    func deletePlaylist(id: String) async -> Bool {
        do {
            try await database.deletePlaylist(id: id)
            try await reload()
            return true
        } catch {
            return false
        }
    }

    func addTrack(_ trackID: String, to playlistID: String) async -> Bool {
        do {
            let added = try await database.addTrack(trackID, to: playlistID)
            if added { try await reload() }
            return added
        } catch {
            return false
        }
    }

    func removeTrackFromPlaylist(_ trackID: String, playlistID: String) async -> Bool {
        do {
            try await database.removeTrack(trackID, from: playlistID)
            try await reload()
            return true
        } catch {
            return false
        }
    }

    /// Reloads only when at least one track was newly inserted.
    func addTracks(_ trackIDs: [String], to playlistID: String) async -> PlaylistBatchAdd? {
        do {
            let result = try await database.addTracks(trackIDs, to: playlistID)
            if result.added > 0 {
                try await reload()
            }
            return result
        } catch {
            return nil
        }
    }

    /// Reloads only when a link was removed. `nil` is a database error.
    func removeTracksFromPlaylist(_ trackIDs: [String], playlistID: String) async -> Int? {
        do {
            let removed = try await database.removeTracksFromPlaylist(trackIDs, playlistID: playlistID)
            if removed > 0 {
                try await reload()
            }
            return removed
        } catch {
            return nil
        }
    }

    private func beginActivity(_ kind: LibraryActivityKind) -> ScanCancellation? {
        guard !scanSession.isRunning else { return nil }
        let cancellation = ScanCancellation()
        scanCancellation = cancellation
        activityKind = kind
        scanSession = ScanSession(phase: .running, percent: 0)
        lastReloadAt = nil
        return cancellation
    }

    private func launchScan(rootPath: String, force: Bool, cancellation: ScanCancellation) {
        let database = self.database
        Task.detached(priority: .utility) { [weak self] in
            do {
                let outcome = try await LibraryScanner.run(
                    rootPath: rootPath,
                    force: force,
                    database: database,
                    isCancelled: { cancellation.isCancelled }
                ) { percent in
                    guard let store = self else { return }
                    await store.noteProgress(percent)
                }
                guard let store = self else { return }
                await store.completeScan(outcome)
            } catch {
                guard let store = self else { return }
                await store.failScan()
            }
        }
    }

    private func launchImport(urls: [URL], cancellation: ScanCancellation) {
        let database = self.database
        Task.detached(priority: .utility) { [weak self] in
            do {
                let outcome = try await LibraryScanner.importFiles(
                    urls: urls,
                    database: database,
                    isCancelled: { cancellation.isCancelled }
                ) { percent in
                    guard let store = self else { return }
                    await store.noteProgress(percent)
                }
                guard let store = self else { return }
                await store.completeImport(outcome)
            } catch {
                guard let store = self else { return }
                await store.failImport()
            }
        }
    }

    private func noteProgress(_ percent: Int) async {
        guard scanSession.isRunning else { return }
        scanSession = ScanSession(phase: .running, percent: percent)
        let now = Date().timeIntervalSinceReferenceDate
        guard ScanSession.shouldReload(now: now, lastReload: lastReloadAt) else { return }
        lastReloadAt = now
        try? await reload()
    }

    private func completeScan(_ outcome: ScanOutcome) async {
        do {
            try await reload()
        } catch {
            scanSession = ScanSession(phase: .failed, percent: scanSession.percent)
            onToast?("扫描失败")
            return
        }
        if outcome.cancelled {
            scanSession = ScanSession(phase: .cancelled, percent: scanSession.percent)
            onToast?("已取消扫描")
            return
        }
        scanSession = ScanSession(phase: .completed, percent: 100)
        let count = tracks.filter { !$0.missing }.count
        if outcome.skipped > 0 {
            onToast?("扫描完成 · \(count) 首，跳过 \(outcome.skipped) 个")
        } else {
            onToast?("扫描完成 · \(count) 首")
        }
    }

    private func failScan() async {
        try? await reload()
        scanSession = ScanSession(phase: .failed, percent: scanSession.percent)
        onToast?("扫描失败")
    }

    private func completeImport(_ outcome: ImportOutcome) async {
        do {
            try await reload()
        } catch {
            scanSession = ScanSession(phase: .failed, percent: scanSession.percent)
            onToast?("添加失败")
            return
        }
        if outcome.cancelled {
            scanSession = ScanSession(phase: .cancelled, percent: scanSession.percent)
            onToast?("已取消添加")
            return
        }
        scanSession = ScanSession(phase: .completed, percent: 100)
        onToast?(LibraryAdditionCopy.toast(
            added: outcome.added,
            already: outcome.already,
            skipped: outcome.skipped
        ))
    }

    private func failImport() async {
        try? await reload()
        scanSession = ScanSession(phase: .failed, percent: scanSession.percent)
        onToast?("添加失败")
    }

    private func reload() async throws {
        let snapshot = try await database.snapshot()
        tracks = snapshot.tracks
        artists = snapshot.artists
        albums = snapshot.albums
        playlists = snapshot.playlists
    }

}

extension LibraryStore {
    /// Primary path, then aliases. Empty strings and duplicates are dropped.
    fileprivate static func recordedPaths(_ record: StoredTrackPaths?) -> [String] {
        guard let record else { return [] }
        var seen = Set<String>()
        return ([record.path] + record.aliases).filter { path in
            !path.isEmpty && seen.insert(path).inserted
        }
    }

    fileprivate static func trashRecordedFile(at path: String) -> LibraryRemovalFileResult {
        guard FileManager.default.fileExists(atPath: path) else { return .missing }
        do {
            var resulting: NSURL?
            try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: &resulting)
            return .trashed
        } catch {
            return .failed
        }
    }
}

/// Holds the scan-root security scope for the life of the store.
private final class SecurityScope: @unchecked Sendable {
    private var url: URL?

    func replace(with url: URL) {
        if self.url == url { return }
        self.url?.stopAccessingSecurityScopedResource()
        self.url = nil
        if url.startAccessingSecurityScopedResource() {
            self.url = url
        }
    }

    deinit {
        url?.stopAccessingSecurityScopedResource()
    }
}

private final class ScanCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
}
