import Foundation
import LyriaCore

struct ScanOutcome {
    var skipped: Int
    var cancelled: Bool
}

struct ImportOutcome {
    var added: Int
    var already: Int
    var skipped: Int
    var cancelled: Bool
}

private struct ScanCandidate {
    var url: URL
    var path: String
    var size: Int64
    var mtime: Int64
    var placeholder: Bool
}

private struct PreparedItem {
    var failed: Bool
    var seen: SeenFile?
    /// True only when this file minted a fingerprint that was not already in the library.
    var inserted = false
}

enum LibraryScanner {
    /// Fingerprint and tag reads stay off the main actor. At most four files are in flight.
    static func run(
        rootPath: String,
        force: Bool,
        database: LibraryDatabase,
        isCancelled: @escaping @Sendable () -> Bool,
        onProgress: @escaping @Sendable (Int) async -> Void
    ) async throws -> ScanOutcome {
        let candidates = enumerate(rootPath: rootPath)
        let observed = Set(candidates.map(\.path))
        if candidates.isEmpty || isCancelled() {
            try await database.finishScan(root: rootPath, seen: [], seenTrackIDs: [], observedPaths: observed)
            if !isCancelled() {
                await onProgress(100)
            }
            return ScanOutcome(skipped: 0, cancelled: isCancelled())
        }

        var skipped = 0
        var seen: [SeenFile] = []
        var seenIDs = Set<String>()
        let total = candidates.count
        var lastPercent = -1
        var cancelled = false

        try await withThrowingTaskGroup(of: PreparedItem.self) { group in
            var next = 0
            func schedule() {
                guard !isCancelled(), next < candidates.count else { return }
                let candidate = candidates[next]
                next += 1
                group.addTask {
                    await prepare(candidate, force: force, database: database)
                }
            }
            for _ in 0..<min(4, candidates.count) {
                schedule()
            }
            var done = 0
            while let item = try await group.next() {
                if item.failed { skipped += 1 }
                if let file = item.seen {
                    seen.append(file)
                    seenIDs.insert(file.trackID)
                }
                done += 1
                let percent = ScanSession.percent(done: done, total: total)
                if percent != lastPercent {
                    lastPercent = percent
                    await onProgress(percent)
                }
                if isCancelled() {
                    cancelled = true
                } else {
                    schedule()
                }
            }
        }

        if isCancelled() { cancelled = true }
        try await database.finishScan(
            root: rootPath,
            seen: seen,
            seenTrackIDs: seenIDs,
            observedPaths: observed
        )
        if cancelled {
            return ScanOutcome(skipped: skipped, cancelled: true)
        }
        await onProgress(100)
        return ScanOutcome(skipped: skipped, cancelled: false)
    }

    /// Selected files only. Does not call `finishScan`, so nothing outside this list is marked missing.
    static func importFiles(
        urls: [URL],
        database: LibraryDatabase,
        isCancelled: @escaping @Sendable () -> Bool,
        onProgress: @escaping @Sendable (Int) async -> Void
    ) async throws -> ImportOutcome {
        var scoped: [URL] = []
        for url in urls where url.startAccessingSecurityScopedResource() {
            scoped.append(url)
        }
        defer {
            for url in scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        if isCancelled() {
            return ImportOutcome(added: 0, already: 0, skipped: 0, cancelled: true)
        }

        let candidates = urls.compactMap { candidate(for: $0) }
        var skipped = urls.count - candidates.count
        if candidates.isEmpty {
            return ImportOutcome(added: 0, already: 0, skipped: skipped, cancelled: false)
        }

        var added = 0
        var already = 0
        let total = candidates.count
        var lastPercent = -1
        var cancelled = false

        try await withThrowingTaskGroup(of: PreparedItem.self) { group in
            var next = 0
            func schedule() {
                guard !isCancelled(), next < candidates.count else { return }
                let candidate = candidates[next]
                next += 1
                group.addTask {
                    await prepare(candidate, force: false, database: database)
                }
            }
            for _ in 0..<min(4, candidates.count) {
                schedule()
            }
            var done = 0
            while let item = try await group.next() {
                if item.failed || item.seen == nil {
                    skipped += 1
                } else if item.inserted {
                    added += 1
                } else {
                    already += 1
                }
                done += 1
                let percent = ScanSession.percent(done: done, total: total)
                if percent != lastPercent {
                    lastPercent = percent
                    await onProgress(percent)
                }
                if isCancelled() {
                    cancelled = true
                } else {
                    schedule()
                }
            }
        }

        if isCancelled() { cancelled = true }
        if cancelled {
            return ImportOutcome(added: added, already: already, skipped: skipped, cancelled: true)
        }
        await onProgress(100)
        return ImportOutcome(added: added, already: already, skipped: skipped, cancelled: false)
    }

    private static func enumerate(rootPath: String) -> [ScanCandidate] {
        let root = URL(fileURLWithPath: rootPath, isDirectory: true)
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey,
            .fileSizeKey,
            .contentModificationDateKey,
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var files: [ScanCandidate] = []
        for case let url as URL in enumerator {
            if let file = candidate(for: url) {
                files.append(file)
            }
        }
        return files
    }

    private static func candidate(for url: URL) -> ScanCandidate? {
        let ext = url.pathExtension.lowercased()
        guard MetadataReader.audioExtensions.contains(ext) else { return nil }
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey,
            .fileSizeKey,
            .contentModificationDateKey,
        ]
        let values = try? url.resourceValues(forKeys: keys)
        let ubiquitous = values?.isUbiquitousItem == true
        if values?.isRegularFile != true && !ubiquitous { return nil }
        let placeholder: Bool
        if ubiquitous {
            switch values?.ubiquitousItemDownloadingStatus {
            case .current, .downloaded:
                placeholder = false
            default:
                placeholder = true
            }
        } else {
            placeholder = false
        }
        let modified = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
        return ScanCandidate(
            url: url,
            path: PathUtil.standardize(url),
            size: Int64(values?.fileSize ?? 0),
            mtime: Int64(modified),
            placeholder: placeholder
        )
    }

    private static func prepare(
        _ candidate: ScanCandidate,
        force: Bool,
        database: LibraryDatabase
    ) async -> PreparedItem {
        do {
            if candidate.placeholder {
                if let trackID = try await database.markOfflinePlaceholder(path: candidate.path) {
                    return PreparedItem(
                        failed: false,
                        seen: SeenFile(
                            path: candidate.path,
                            size: candidate.size,
                            mtime: candidate.mtime,
                            trackID: trackID
                        )
                    )
                }
                return PreparedItem(failed: false, seen: nil)
            }

            if !force,
               let trackID = try await database.fastPathTrackID(
                path: candidate.path,
                size: candidate.size,
                mtime: candidate.mtime
               ) {
                return PreparedItem(
                    failed: false,
                    seen: SeenFile(
                        path: candidate.path,
                        size: candidate.size,
                        mtime: candidate.mtime,
                        trackID: trackID
                    )
                )
            }

            let digest: FingerprintDigest
            do {
                digest = try fingerprint(url: candidate.url, byteCount: candidate.size)
            } catch {
                return PreparedItem(failed: true, seen: nil)
            }

            guard let metadata = await MetadataReader.read(url: candidate.url) else {
                return PreparedItem(failed: true, seen: nil)
            }

            let identity = EntityID.decide(
                title: metadata.title,
                artist: metadata.artist,
                album: metadata.album
            )
            let title = identity.normalizedTitle.isEmpty
                ? candidate.url.deletingPathExtension().lastPathComponent
                : identity.normalizedTitle
            let artwork = metadata.artwork ?? MetadataReader.folderArtwork(near: candidate.url)
            var artworkPath: String?
            if let artwork, !artwork.isEmpty {
                artworkPath = try? SupportPaths.writeArtwork(artwork, trackID: digest.trackID)
            }

            let record = IngestRecord(
                path: candidate.path,
                size: candidate.size,
                mtime: candidate.mtime,
                fingerprintHex: hex(digest.sha256),
                method: digest.method.rawValue,
                proposedTrackID: digest.trackID,
                title: title,
                artistName: identity.normalizedArtist,
                albumName: identity.normalizedAlbum,
                artistID: identity.artistID,
                albumID: identity.albumID,
                sortName: identity.sortName,
                year: metadata.year,
                durationMs: metadata.durationMs,
                encodingSuspect: identity.encodingSuspect,
                artworkPath: artworkPath,
                icloudOffline: false
            )
            let preexisting = try await database.fingerprintTrackID(record.fingerprintHex)
            let trackID = try await database.ingest(record)
            if trackID != digest.trackID {
                try? SupportPaths.moveArtwork(from: digest.trackID, to: trackID)
            }
            return PreparedItem(
                failed: false,
                seen: SeenFile(
                    path: candidate.path,
                    size: candidate.size,
                    mtime: candidate.mtime,
                    trackID: trackID
                ),
                inserted: preexisting == nil
            )
        } catch {
            return PreparedItem(failed: true, seen: nil)
        }
    }

    private static func fingerprint(url: URL, byteCount: Int64) throws -> FingerprintDigest {
        if Fingerprint.method(forByteCount: byteCount) == .headTailSize {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let edge = Fingerprint.edgeBytes
            let head = try handle.read(upToCount: edge) ?? Data()
            let tailStart = byteCount > Int64(edge) ? UInt64(byteCount - Int64(edge)) : 0
            try handle.seek(toOffset: tailStart)
            let tail = try handle.read(upToCount: edge) ?? Data()
            return Fingerprint.digestHeadTail(head: head, tail: tail, byteCount: byteCount)
        }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return Fingerprint.digest(contents: data)
    }

    private static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
