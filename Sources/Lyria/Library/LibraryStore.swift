import AppKit
import Foundation

/// Library database façade. Scanning never starts by itself.
@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var tracks: [Track] = []
    @Published private(set) var artists: [Artist] = []
    @Published private(set) var albums: [Album] = []
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var rootLabel = "未选择"
    @Published private(set) var isScanning = false
    @Published private(set) var scanPercent = 0

    var onToast: ((String) -> Void)?

    private let database = LibraryDatabase()
    private var rootPath: String?
    private var didOpen = false

    func open() async {
        guard !didOpen else { return }
        didOpen = true
        do {
            let url = try SupportPaths.databaseURL()
            try await database.open(path: url.path)
            try await reload()
            if let stored = try await database.scanRoot() {
                let resolved = stored.bookmark.flatMap { BookmarkData.resolve($0) }
                let path = resolved.map { PathUtil.standardize($0) } ?? stored.path
                if let resolved, path != stored.path {
                    let bookmark = BookmarkData.make(for: resolved) ?? stored.bookmark
                    try? await database.setScanRoot(path: path, bookmark: bookmark)
                }
                applyRoot(path)
            }
        } catch {
            onToast?("曲库数据库打开失败")
        }
    }

    func chooseRootAndScan(force: Bool) {
        guard !isScanning else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "选择"
        panel.message = "选择曲库文件夹"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let path = PathUtil.standardize(url)
        let bookmark = BookmarkData.make(for: url)
        Task {
            do {
                try await database.setScanRoot(path: path, bookmark: bookmark)
                applyRoot(path)
                scan(force: force)
            } catch {
                onToast?("无法保存曲库路径")
            }
        }
    }

    func rescanNow() {
        if rootPath == nil {
            chooseRootAndScan(force: true)
        } else {
            scan(force: true)
        }
    }

    func deleteTrack(id: String) async -> Bool {
        do {
            try await database.deleteTrack(id: id)
            SupportPaths.deleteArtwork(trackID: id)
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

    private func scan(force: Bool) {
        guard !isScanning, let rootPath else { return }
        isScanning = true
        scanPercent = 0
        onToast?("开始扫描")
        let database = self.database
        Task.detached(priority: .utility) { [weak self] in
            do {
                let outcome = try await LibraryScanner.run(
                    rootPath: rootPath,
                    force: force,
                    database: database
                ) { percent in
                    guard let store = self else { return }
                    await store.setScanPercent(percent)
                }
                guard let store = self else { return }
                await store.completeScan(skipped: outcome.skipped)
            } catch {
                guard let store = self else { return }
                await store.failScan()
            }
        }
    }

    private func setScanPercent(_ value: Int) {
        scanPercent = value
    }

    private func completeScan(skipped: Int) async {
        do {
            try await reload()
        } catch {
            onToast?("扫描结果读取失败")
        }
        isScanning = false
        scanPercent = 100
        let count = tracks.filter { !$0.missing }.count
        if skipped > 0 {
            onToast?("扫描完成 · \(count) 首，跳过 \(skipped) 个")
        } else {
            onToast?("扫描完成 · \(count) 首")
        }
    }

    private func failScan() {
        isScanning = false
        onToast?("扫描失败")
    }

    private func reload() async throws {
        let snapshot = try await database.snapshot()
        tracks = snapshot.tracks
        artists = snapshot.artists
        albums = snapshot.albums
        playlists = snapshot.playlists
    }

    private func applyRoot(_ path: String) {
        rootPath = path
        rootLabel = PathUtil.abbreviate(path)
    }
}
