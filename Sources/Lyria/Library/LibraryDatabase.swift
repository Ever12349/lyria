import Foundation
import LyriaCore
import SQLite3

struct IngestRecord {
    var path: String
    var size: Int64
    var mtime: Int64
    var fingerprintHex: String
    var method: String
    var proposedTrackID: String
    var title: String
    var artistName: String
    var albumName: String
    var artistID: String?
    var albumID: String?
    var sortName: String
    var year: Int
    var durationMs: Int
    var encodingSuspect: Bool
    var artworkPath: String?
    var icloudOffline: Bool
}

struct SeenFile {
    var path: String
    var size: Int64
    var mtime: Int64
    var trackID: String
}

struct StoredScanRoot {
    var path: String
    var bookmark: Data?
}

struct StoredTrackPaths {
    var id: String
    var path: String
    var aliases: [String]
}

struct LibrarySnapshot {
    var tracks: [Track]
    var artists: [Artist]
    var albums: [Album]
    var playlists: [Playlist]
}

struct PlaylistBatchAdd: Equatable {
    var added: Int
    var skipped: Int
}

/// Serial SQLite writer. Readers go through the same actor.
actor LibraryDatabase {
    private let connection = SQLiteConnection()
    private var isOpen = false

    func open(path: String) throws {
        if isOpen { return }
        try connection.open(path: path)
        try connection.migrate()
        try ensureTrackYearColumn()
        try migrateAlbumsToNameIDsIfNeeded()
        isOpen = true
    }

    func snapshot() throws -> LibrarySnapshot {
        let tracks = try loadTracks()
        let artists = try loadArtists()
        let albums = try loadAlbums().map { album in
            let participants = tracks.filter { $0.albumId == album.id }.compactMap(\.artistId)
            let line = AlbumFacts.creditLine(
                participatingArtistIDs: participants,
                catalog: artists.map { CreditArtist(id: $0.id, name: $0.name, sortName: $0.sortName) }
            )
            return Album(
                id: album.id,
                name: album.name,
                artistId: nil,
                artistName: line == AlbumFacts.unknownArtist ? "" : line,
                year: album.year,
                artworkPath: album.artworkPath
            )
        }
        let playlists = try loadPlaylists()
        return LibrarySnapshot(tracks: tracks, artists: artists, albums: albums, playlists: playlists)
    }

    func setScanRoot(path: String, bookmark: Data?) throws {
        try connection.transaction {
            try connection.run("DELETE FROM scan_roots")
            try connection.run(
                "INSERT INTO scan_roots (id, path, bookmark, enabled) VALUES (1, ?, ?, 1)",
                [.text(path), bookmark.map(SQLValue.blob) ?? .null]
            )
        }
    }

    func scanRoot() throws -> StoredScanRoot? {
        var found: StoredScanRoot?
        try connection.run("SELECT path, bookmark FROM scan_roots WHERE enabled = 1 ORDER BY id LIMIT 1") { statement in
            let path = SQLiteConnection.text(statement, 0)
            let bookmark = SQLiteConnection.blob(statement, 1)
            found = StoredScanRoot(path: path, bookmark: bookmark)
        }
        return found
    }

    /// Incremental hit: same primary path, size, and mtime, and the file is local.
    func fastPathTrackID(path: String, size: Int64, mtime: Int64) throws -> String? {
        var trackID: String?
        try connection.run(
            """
            SELECT id FROM tracks
            WHERE path = ? AND size = ? AND mtime = ? AND missing = 0
            LIMIT 1
            """,
            [.text(path), .int(size), .int(mtime)]
        ) { statement in
            trackID = SQLiteConnection.text(statement, 0)
        }
        if let trackID {
            try connection.run(
                "UPDATE tracks SET icloud_offline = 0 WHERE id = ?",
                [.text(trackID)]
            )
        }
        return trackID
    }

    /// Already-imported path that is now an iCloud placeholder. Counts as seen, not missing.
    func markOfflinePlaceholder(path: String) throws -> String? {
        guard let trackID = try trackID(referencing: path) else { return nil }
        try connection.run(
            "UPDATE tracks SET missing = 0, icloud_offline = 1, updated_at = ? WHERE id = ?",
            [.int(Self.now), .text(trackID)]
        )
        return trackID
    }

    func ingest(_ record: IngestRecord) throws -> String {
        try connection.transaction {
            let mapped = try optionalText(
                "SELECT track_id FROM fingerprints WHERE fingerprint = ?",
                [.text(record.fingerprintHex)]
            )
            let trackID = mapped ?? record.proposedTrackID
            let previousAlbumID = try optionalText(
                "SELECT album_id FROM tracks WHERE id = ?",
                [.text(trackID)]
            )
            if mapped == nil {
                try connection.run(
                    "INSERT INTO fingerprints (fingerprint, track_id, method, created_at) VALUES (?, ?, ?, ?)",
                    [.text(record.fingerprintHex), .text(trackID), .text(record.method), .int(Self.now)]
                )
            }

            try connection.run(
                "UPDATE tracks SET missing = 1, updated_at = ? WHERE path = ? AND id != ? AND missing = 0",
                [.int(Self.now), .text(record.path), .text(trackID)]
            )
            try stripAlias(record.path, except: trackID)

            if let existing = try trackCore(id: trackID) {
                var aliases = Self.decodeAliases(existing.aliasesJSON)
                aliases.removeAll { $0 == record.path }
                var primary = existing.path
                var size = existing.size
                var mtime = existing.mtime
                if primary != record.path {
                    let primaryGone = existing.missing != 0 || primary.isEmpty
                    if primaryGone {
                        if !primary.isEmpty { aliases.append(primary) }
                        primary = record.path
                        size = record.size
                        mtime = record.mtime
                    } else if !aliases.contains(record.path) {
                        aliases.append(record.path)
                    }
                } else {
                    size = record.size
                    mtime = record.mtime
                }
                aliases = Array(Set(aliases)).filter { $0 != primary }.sorted()
                try connection.run(
                    """
                    UPDATE tracks SET
                      path = ?, aliases_json = ?, title = ?, artist_name = ?, album_name = ?,
                      artist_id = ?, album_id = ?, duration_ms = ?, year = ?, size = ?, mtime = ?,
                      missing = 0, encoding_suspect = ?, icloud_offline = ?, updated_at = ?
                    WHERE id = ?
                    """,
                    [
                        .text(primary),
                        .text(Self.encodeAliases(aliases)),
                        .text(record.title),
                        .text(record.artistName),
                        .text(record.albumName),
                        record.artistID.map(SQLValue.text) ?? .null,
                        record.albumID.map(SQLValue.text) ?? .null,
                        .int(Int64(record.durationMs)),
                        .int(Int64(record.year)),
                        .int(size),
                        .int(mtime),
                        .int(record.encodingSuspect ? 1 : 0),
                        .int(record.icloudOffline ? 1 : 0),
                        .int(Self.now),
                        .text(trackID),
                    ]
                )
            } else {
                try connection.run(
                    """
                    INSERT INTO tracks (
                      id, path, aliases_json, title, artist_name, album_name, artist_id, album_id,
                      duration_ms, year, size, mtime, missing, encoding_suspect, icloud_offline, updated_at
                    ) VALUES (?, ?, '[]', ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?)
                    """,
                    [
                        .text(trackID),
                        .text(record.path),
                        .text(record.title),
                        .text(record.artistName),
                        .text(record.albumName),
                        record.artistID.map(SQLValue.text) ?? .null,
                        record.albumID.map(SQLValue.text) ?? .null,
                        .int(Int64(record.durationMs)),
                        .int(Int64(record.year)),
                        .int(record.size),
                        .int(record.mtime),
                        .int(record.encodingSuspect ? 1 : 0),
                        .int(record.icloudOffline ? 1 : 0),
                        .int(Self.now),
                    ]
                )
            }

            if let artistID = record.artistID, !record.artistName.isEmpty {
                try connection.run(
                    """
                    INSERT INTO artists (id, name, sort_name, track_count) VALUES (?, ?, ?, 0)
                    ON CONFLICT(id) DO UPDATE SET name = excluded.name, sort_name = excluded.sort_name
                    """,
                    [.text(artistID), .text(record.artistName), .text(record.sortName)]
                )
            }
            if let previousAlbumID, previousAlbumID != record.albumID {
                try refreshAlbum(previousAlbumID)
            }
            if let albumID = record.albumID {
                try refreshAlbum(albumID)
            }
            return trackID
        }
    }

    func finishScan(root: String, seen: [SeenFile], seenTrackIDs: Set<String>, observedPaths: Set<String>) throws {
        let seenByPath = Dictionary(seen.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        let rows = try allTrackPaths()
        try connection.transaction {
            for row in rows {
                let aliases = Self.decodeAliases(row.aliasesJSON)
                let related = [row.path] + aliases
                let underRoot = related.contains { PathUtil.isUnderRoot($0, root: root) }
                guard underRoot else { continue }
                let primaryUnderRoot = PathUtil.isUnderRoot(row.path, root: root)
                let aliasUnderRoot = aliases.contains { PathUtil.isUnderRoot($0, root: root) }
                let primaryObserved = observedPaths.contains(row.path)
                let observedAlias = aliases.first { PathUtil.isUnderRoot($0, root: root) && observedPaths.contains($0) }
                if seenTrackIDs.contains(row.id) {
                    let primaryGone = !FileManager.default.fileExists(atPath: row.path)
                    if primaryGone,
                       let replacement = aliases.first(where: { observedPaths.contains($0) }),
                       let stat = seenByPath[replacement] {
                        var nextAliases = aliases.filter { $0 != replacement }
                        if !row.path.isEmpty { nextAliases.append(row.path) }
                        nextAliases = Array(Set(nextAliases)).filter { $0 != replacement }.sorted()
                        try connection.run(
                            """
                            UPDATE tracks
                            SET path = ?, aliases_json = ?, size = ?, mtime = ?, missing = 0, updated_at = ?
                            WHERE id = ?
                            """,
                            [
                                .text(replacement),
                                .text(Self.encodeAliases(nextAliases)),
                                .int(stat.size),
                                .int(stat.mtime),
                                .int(Self.now),
                                .text(row.id),
                            ]
                        )
                    } else {
                        try connection.run(
                            "UPDATE tracks SET missing = 0 WHERE id = ? AND missing != 0",
                            [.text(row.id)]
                        )
                    }
                } else if primaryObserved || observedAlias != nil {
                    continue
                } else if !primaryUnderRoot && FileManager.default.fileExists(atPath: row.path) {
                    continue
                } else if primaryUnderRoot || aliasUnderRoot {
                    try connection.run(
                        "UPDATE tracks SET missing = 1, icloud_offline = 0, updated_at = ? WHERE id = ?",
                        [.int(Self.now), .text(row.id)]
                    )
                }
            }
            try recomputeCounts()
        }
    }

    /// Deletes the track row and playlist links. The fingerprint row stays so re-import keeps `trk_`.
    func deleteTrack(id: String) throws {
        try deleteTracks(ids: [id])
    }

    /// Primary path plus `aliases_json` for the ids that still exist, in request order.
    func trackPaths(ids: [String]) throws -> [StoredTrackPaths] {
        let unique = Self.uniquePreservingOrder(ids)
        var found: [String: StoredTrackPaths] = [:]
        for id in unique {
            try connection.run(
                "SELECT path, aliases_json FROM tracks WHERE id = ?",
                [.text(id)]
            ) { statement in
                found[id] = StoredTrackPaths(
                    id: id,
                    path: SQLiteConnection.text(statement, 0),
                    aliases: Self.decodeAliases(SQLiteConnection.text(statement, 1))
                )
            }
        }
        return unique.compactMap { found[$0] }
    }

    /// One transaction for the whole batch, then a single `recomputeCounts`. Fingerprints stay.
    func deleteTracks(ids: [String]) throws {
        let unique = Self.uniquePreservingOrder(ids)
        guard !unique.isEmpty else { return }
        try connection.transaction {
            var albumIDs: [String] = []
            for id in unique {
                let albumID = try optionalText(
                    "SELECT album_id FROM tracks WHERE id = ?",
                    [.text(id)]
                )
                if let albumID, !albumID.isEmpty { albumIDs.append(albumID) }
                try connection.run("DELETE FROM playlist_tracks WHERE track_id = ?", [.text(id)])
                try connection.run("DELETE FROM tracks WHERE id = ?", [.text(id)])
            }
            for albumID in Set(albumIDs) {
                try refreshAlbum(albumID)
            }
            try recomputeCounts()
        }
    }

    /// Drops fingerprints and track index. Playlists remain; their track ids become missing.
    func clearLibraryIndex() throws {
        try connection.transaction {
            try connection.run("DELETE FROM fingerprints")
            try connection.run("DELETE FROM tracks")
            try connection.run("DELETE FROM artists")
            try connection.run("DELETE FROM albums")
        }
    }

    func createPlaylist(id: String, name: String) throws {
        let stamp = Self.now
        try connection.run(
            "INSERT INTO playlists (id, name, created_at, updated_at, last_used_at) VALUES (?, ?, ?, ?, ?)",
            [.text(id), .text(name), .int(stamp), .int(stamp), .int(stamp)]
        )
    }

    /// Use, not a rename. `updated_at` stays put. Nil when the playlist is already gone.
    func stampPlaylistUsed(id: String) throws -> Int64? {
        let exists = try count("SELECT COUNT(*) FROM playlists WHERE id = ?", [.text(id)]) > 0
        guard exists else { return nil }
        let stamp = Self.now
        try connection.run(
            "UPDATE playlists SET last_used_at = ? WHERE id = ?",
            [.int(stamp), .text(id)]
        )
        return stamp
    }

    func fingerprintTrackID(_ fingerprint: String) throws -> String? {
        try optionalText(
            "SELECT track_id FROM fingerprints WHERE fingerprint = ?",
            [.text(fingerprint)]
        )
    }

    func renamePlaylist(id: String, name: String) throws {
        try connection.run(
            "UPDATE playlists SET name = ?, updated_at = ? WHERE id = ?",
            [.text(name), .int(Self.now), .text(id)]
        )
    }

    func deletePlaylist(id: String) throws {
        try connection.run("DELETE FROM playlists WHERE id = ?", [.text(id)])
    }

    /// False when the track is already in the playlist or either id is unknown.
    func addTrack(_ trackID: String, to playlistID: String) throws -> Bool {
        let playlistExists = try count("SELECT COUNT(*) FROM playlists WHERE id = ?", [.text(playlistID)]) > 0
        let trackExists = try count("SELECT COUNT(*) FROM tracks WHERE id = ?", [.text(trackID)]) > 0
        guard playlistExists, trackExists else { return false }
        let already = try count(
            "SELECT COUNT(*) FROM playlist_tracks WHERE playlist_id = ? AND track_id = ?",
            [.text(playlistID), .text(trackID)]
        ) > 0
        if already { return false }
        let position = try count(
            "SELECT COALESCE(MAX(position), -1) + 1 FROM playlist_tracks WHERE playlist_id = ?",
            [.text(playlistID)]
        )
        try connection.run(
            "INSERT INTO playlist_tracks (playlist_id, track_id, position) VALUES (?, ?, ?)",
            [.text(playlistID), .text(trackID), .int(position)]
        )
        try connection.run(
            "UPDATE playlists SET updated_at = ? WHERE id = ?",
            [.int(Self.now), .text(playlistID)]
        )
        return true
    }

    func removeTrack(_ trackID: String, from playlistID: String) throws {
        try connection.run(
            "DELETE FROM playlist_tracks WHERE playlist_id = ? AND track_id = ?",
            [.text(playlistID), .text(trackID)]
        )
    }

    /// Inserts in `trackIDs` order (the current table, top to bottom). One transaction.
    /// `skipped` counts tracks already in the playlist. Unknown track ids are ignored.
    func addTracks(_ trackIDs: [String], to playlistID: String) throws -> PlaylistBatchAdd {
        let unique = Self.uniquePreservingOrder(trackIDs)
        return try connection.transaction {
            let playlistExists = try count("SELECT COUNT(*) FROM playlists WHERE id = ?", [.text(playlistID)]) > 0
            guard playlistExists else {
                throw SQLiteError(message: "找不到播放列表")
            }
            var position = try count(
                "SELECT COALESCE(MAX(position), -1) + 1 FROM playlist_tracks WHERE playlist_id = ?",
                [.text(playlistID)]
            )
            var added = 0
            var skipped = 0
            for trackID in unique {
                let trackExists = try count("SELECT COUNT(*) FROM tracks WHERE id = ?", [.text(trackID)]) > 0
                guard trackExists else { continue }
                let already = try count(
                    "SELECT COUNT(*) FROM playlist_tracks WHERE playlist_id = ? AND track_id = ?",
                    [.text(playlistID), .text(trackID)]
                ) > 0
                if already {
                    skipped += 1
                    continue
                }
                try connection.run(
                    "INSERT INTO playlist_tracks (playlist_id, track_id, position) VALUES (?, ?, ?)",
                    [.text(playlistID), .text(trackID), .int(position)]
                )
                position += 1
                added += 1
            }
            if added > 0 {
                try connection.run(
                    "UPDATE playlists SET updated_at = ? WHERE id = ?",
                    [.int(Self.now), .text(playlistID)]
                )
            }
            return PlaylistBatchAdd(added: added, skipped: skipped)
        }
    }

    /// One transaction. Returns how many of `trackIDs` were actually linked.
    func removeTracksFromPlaylist(_ trackIDs: [String], playlistID: String) throws -> Int {
        let unique = Self.uniquePreservingOrder(trackIDs)
        return try connection.transaction {
            var removed = 0
            for trackID in unique {
                let linked = try count(
                    "SELECT COUNT(*) FROM playlist_tracks WHERE playlist_id = ? AND track_id = ?",
                    [.text(playlistID), .text(trackID)]
                )
                guard linked > 0 else { continue }
                try connection.run(
                    "DELETE FROM playlist_tracks WHERE playlist_id = ? AND track_id = ?",
                    [.text(playlistID), .text(trackID)]
                )
                removed += 1
            }
            return removed
        }
    }

    private struct TrackCore {
        var path: String
        var aliasesJSON: String
        var size: Int64
        var mtime: Int64
        var missing: Int64
    }

    private struct TrackPathRow {
        var id: String
        var path: String
        var aliasesJSON: String
    }

    private func trackCore(id: String) throws -> TrackCore? {
        var found: TrackCore?
        try connection.run(
            "SELECT path, aliases_json, size, mtime, missing FROM tracks WHERE id = ?",
            [.text(id)]
        ) { statement in
            found = TrackCore(
                path: SQLiteConnection.text(statement, 0),
                aliasesJSON: SQLiteConnection.text(statement, 1),
                size: sqlite3_column_int64(statement, 2),
                mtime: sqlite3_column_int64(statement, 3),
                missing: sqlite3_column_int64(statement, 4)
            )
        }
        return found
    }

    private func allTrackPaths() throws -> [TrackPathRow] {
        var rows: [TrackPathRow] = []
        try connection.run("SELECT id, path, aliases_json FROM tracks") { statement in
            rows.append(TrackPathRow(
                id: SQLiteConnection.text(statement, 0),
                path: SQLiteConnection.text(statement, 1),
                aliasesJSON: SQLiteConnection.text(statement, 2)
            ))
        }
        return rows
    }

    private func trackID(referencing path: String) throws -> String? {
        if let primary = try optionalText(
            "SELECT id FROM tracks WHERE path = ? LIMIT 1",
            [.text(path)]
        ) {
            return primary
        }
        var match: String?
        try connection.run("SELECT id, aliases_json FROM tracks") { statement in
            guard match == nil else { return }
            let aliases = Self.decodeAliases(SQLiteConnection.text(statement, 1))
            if aliases.contains(path) {
                match = SQLiteConnection.text(statement, 0)
            }
        }
        return match
    }

    private func stripAlias(_ path: String, except trackID: String) throws {
        var edits: [(String, String)] = []
        try connection.run("SELECT id, aliases_json FROM tracks WHERE id != ?", [.text(trackID)]) { statement in
            let id = SQLiteConnection.text(statement, 0)
            let raw = SQLiteConnection.text(statement, 1)
            var aliases = Self.decodeAliases(raw)
            let before = aliases.count
            aliases.removeAll { $0 == path }
            if aliases.count != before {
                edits.append((id, Self.encodeAliases(aliases)))
            }
        }
        for edit in edits {
            try connection.run(
                "UPDATE tracks SET aliases_json = ? WHERE id = ?",
                [.text(edit.1), .text(edit.0)]
            )
        }
    }

    private func ensureTrackYearColumn() throws {
        var names: [String] = []
        try connection.run("PRAGMA table_info(tracks)") { statement in
            names.append(SQLiteConnection.text(statement, 1))
        }
        if !names.contains("year") {
            try connection.run("ALTER TABLE tracks ADD COLUMN year INTEGER NOT NULL DEFAULT 0")
        }
    }

    /// One-shot. Later opens see the settings flag and leave ids alone.
    private func migrateAlbumsToNameIDsIfNeeded() throws {
        let flag = try optionalText(
            "SELECT value FROM settings WHERE key = ?",
            [.text("album_by_name")]
        )
        if flag == "1" { return }
        try connection.transaction {
            try connection.run(
                """
                UPDATE tracks SET year = COALESCE((
                  SELECT albums.year FROM albums WHERE albums.id = tracks.album_id
                ), 0)
                WHERE year = 0
                """
            )
            var rows: [(id: String, albumName: String)] = []
            try connection.run("SELECT id, album_name FROM tracks") { statement in
                rows.append((
                    SQLiteConnection.text(statement, 0),
                    SQLiteConnection.text(statement, 1)
                ))
            }
            for row in rows {
                let normalized = NameNormalizer.normalize(row.albumName).text
                let albumID = EntityID.album(normalizedName: normalized)
                try connection.run(
                    "UPDATE tracks SET album_id = ? WHERE id = ?",
                    [albumID.map(SQLValue.text) ?? .null, .text(row.id)]
                )
            }
            var albumIDs: [String] = []
            try connection.run(
                "SELECT DISTINCT album_id FROM tracks WHERE album_id IS NOT NULL"
            ) { statement in
                albumIDs.append(SQLiteConnection.text(statement, 0))
            }
            try connection.run("DELETE FROM albums")
            for albumID in albumIDs where !albumID.isEmpty {
                try refreshAlbum(albumID)
            }
            try recomputeCounts()
            try connection.run(
                "INSERT INTO settings (key, value) VALUES ('album_by_name', '1')"
            )
        }
    }

    /// Name, year, and artwork from member tracks so a later scan does not reshuffle them.
    private func refreshAlbum(_ albumID: String) throws {
        var members: [AlbumMember] = []
        try connection.run(
            "SELECT id, album_name, year FROM tracks WHERE album_id = ? ORDER BY id",
            [.text(albumID)]
        ) { statement in
            let trackID = SQLiteConnection.text(statement, 0)
            members.append(AlbumMember(
                trackID: trackID,
                albumName: SQLiteConnection.text(statement, 1),
                year: Int(sqlite3_column_int64(statement, 2)),
                artworkPath: SupportPaths.existingArtwork(trackID: trackID)
            ))
        }
        guard !members.isEmpty else {
            try connection.run("DELETE FROM albums WHERE id = ?", [.text(albumID)])
            return
        }
        let artwork = AlbumFacts.artworkPath(members: members)
        try connection.run(
            """
            INSERT INTO albums (id, name, artist_id, year, track_count, artwork_path)
            VALUES (?, ?, NULL, ?, 0, ?)
            ON CONFLICT(id) DO UPDATE SET
              name = excluded.name,
              artist_id = NULL,
              year = excluded.year,
              artwork_path = excluded.artwork_path
            """,
            [
                .text(albumID),
                .text(AlbumFacts.displayName(members: members)),
                .int(Int64(AlbumFacts.year(members: members))),
                artwork.map(SQLValue.text) ?? .null,
            ]
        )
    }

    private func recomputeCounts() throws {
        try connection.run(
            """
            UPDATE artists SET track_count = (
              SELECT COUNT(*) FROM tracks WHERE tracks.artist_id = artists.id
            )
            """
        )
        try connection.run("DELETE FROM artists WHERE track_count = 0")
        try connection.run(
            """
            UPDATE albums SET track_count = (
              SELECT COUNT(*) FROM tracks WHERE tracks.album_id = albums.id
            )
            """
        )
        try connection.run("DELETE FROM albums WHERE track_count = 0")
    }

    private func loadTracks() throws -> [Track] {
        var tracks: [Track] = []
        try connection.run(
            """
            SELECT id, path, title, artist_name, album_name, artist_id, album_id,
                   duration_ms, missing, encoding_suspect
            FROM tracks
            ORDER BY title COLLATE NOCASE, id
            """
        ) { statement in
            let id = SQLiteConnection.text(statement, 0)
            tracks.append(Track(
                id: id,
                title: SQLiteConnection.text(statement, 2),
                artist: SQLiteConnection.text(statement, 3),
                artistId: SQLiteConnection.optionalText(statement, 5),
                album: SQLiteConnection.text(statement, 4),
                albumId: SQLiteConnection.optionalText(statement, 6),
                durationMs: Int(sqlite3_column_int64(statement, 7)),
                missing: sqlite3_column_int64(statement, 8) != 0,
                encodingSuspect: sqlite3_column_int64(statement, 9) != 0,
                path: SQLiteConnection.text(statement, 1),
                artworkPath: SupportPaths.existingArtwork(trackID: id)
            ))
        }
        return tracks
    }

    private func loadArtists() throws -> [Artist] {
        var artists: [Artist] = []
        try connection.run(
            "SELECT id, name, sort_name, track_count FROM artists ORDER BY sort_name COLLATE NOCASE, name"
        ) { statement in
            artists.append(Artist(
                id: SQLiteConnection.text(statement, 0),
                name: SQLiteConnection.text(statement, 1),
                sortName: SQLiteConnection.text(statement, 2),
                trackCount: Int(sqlite3_column_int64(statement, 3))
            ))
        }
        return artists
    }

    private func loadAlbums() throws -> [Album] {
        var albums: [Album] = []
        try connection.run(
            """
            SELECT albums.id, albums.name, albums.artist_id, COALESCE(artists.name, ''),
                   albums.year, albums.artwork_path
            FROM albums
            LEFT JOIN artists ON artists.id = albums.artist_id
            ORDER BY albums.name COLLATE NOCASE, albums.id
            """
        ) { statement in
            let artwork = SQLiteConnection.optionalText(statement, 5)
            let usable = artwork.flatMap { FileManager.default.fileExists(atPath: $0) ? $0 : nil }
            albums.append(Album(
                id: SQLiteConnection.text(statement, 0),
                name: SQLiteConnection.text(statement, 1),
                artistId: SQLiteConnection.optionalText(statement, 2),
                artistName: SQLiteConnection.text(statement, 3),
                year: Int(sqlite3_column_int64(statement, 4)),
                artworkPath: usable
            ))
        }
        return albums
    }

    private func loadPlaylists() throws -> [Playlist] {
        var playlists: [Playlist] = []
        try connection.run(
            "SELECT id, name, last_used_at FROM playlists ORDER BY created_at DESC, id"
        ) { statement in
            let lastUsed: Int64?
            if sqlite3_column_type(statement, 2) == SQLITE_NULL {
                lastUsed = nil
            } else {
                lastUsed = sqlite3_column_int64(statement, 2)
            }
            playlists.append(Playlist(
                id: SQLiteConnection.text(statement, 0),
                name: SQLiteConnection.text(statement, 1),
                trackIDs: [],
                lastUsedAt: lastUsed
            ))
        }
        var links: [String: [(Int64, String)]] = [:]
        try connection.run(
            "SELECT playlist_id, track_id, position FROM playlist_tracks ORDER BY playlist_id, position"
        ) { statement in
            let playlistID = SQLiteConnection.text(statement, 0)
            let trackID = SQLiteConnection.text(statement, 1)
            let position = sqlite3_column_int64(statement, 2)
            links[playlistID, default: []].append((position, trackID))
        }
        for index in playlists.indices {
            let pairs = links[playlists[index].id] ?? []
            playlists[index].trackIDs = pairs.sorted { $0.0 < $1.0 }.map(\.1)
        }
        return playlists
    }

    private func optionalText(_ sql: String, _ values: [SQLValue]) throws -> String? {
        var found: String?
        try connection.run(sql, values) { statement in
            if found == nil {
                found = SQLiteConnection.text(statement, 0)
            }
        }
        return found
    }

    private func count(_ sql: String, _ values: [SQLValue]) throws -> Int64 {
        var found: Int64 = 0
        try connection.run(sql, values) { statement in
            found = sqlite3_column_int64(statement, 0)
        }
        return found
    }

    private static var now: Int64 { Int64(Date().timeIntervalSince1970) }

    static func decodeAliases(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [String]
        else { return [] }
        return array
    }

    static func uniquePreservingOrder(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { seen.insert($0).inserted }
    }

    static func encodeAliases(_ paths: [String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: paths),
              let text = String(data: data, encoding: .utf8)
        else { return "[]" }
        return text
    }
}

enum SQLValue {
    case text(String)
    case int(Int64)
    case blob(Data)
    case null
}

final class SQLiteConnection: @unchecked Sendable {
    private var handle: OpaquePointer?
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    deinit {
        if let handle {
            sqlite3_close(handle)
        }
    }

    func open(path: String) throws {
        if handle != nil { return }
        var opened: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let result = path.withCString { pointer in
            sqlite3_open_v2(pointer, &opened, flags, nil)
        }
        guard result == SQLITE_OK, let opened else {
            throw SQLiteError(message: "无法打开曲库数据库")
        }
        handle = opened
        try run("PRAGMA journal_mode = WAL")
        try run("PRAGMA foreign_keys = ON")
        try run("PRAGMA busy_timeout = 5000")
    }

    func migrate() throws {
        var version = try userVersion()
        if version < 1 {
            try exec(Schema.v1)
            try exec("PRAGMA user_version = 1")
            version = 1
        }
        if version < 2 {
            try exec(Schema.v2)
            try exec("PRAGMA user_version = 2")
        }
    }

    func exec(_ sql: String) throws {
        guard let handle else { throw SQLiteError(message: "数据库还没有打开") }
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(handle, sql, nil, nil, &errorMessage)
        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? "SQL 失败"
            sqlite3_free(errorMessage)
            throw SQLiteError(message: message)
        }
    }

    func transaction<T>(_ body: () throws -> T) throws -> T {
        try run("BEGIN IMMEDIATE")
        do {
            let value = try body()
            try run("COMMIT")
            return value
        } catch {
            sqlite3_exec(handle, "ROLLBACK", nil, nil, nil)
            throw error
        }
    }

    func run(_ sql: String, _ values: [SQLValue] = [], _ row: ((OpaquePointer) throws -> Void)? = nil) throws {
        guard let handle else { throw SQLiteError(message: "数据库还没有打开") }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SQLiteError(message: String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(statement) }
        for (offset, value) in values.enumerated() {
            try bind(statement, Int32(offset + 1), value)
        }
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                try row?(statement)
            } else if result == SQLITE_DONE {
                return
            } else {
                throw SQLiteError(message: String(cString: sqlite3_errmsg(handle)))
            }
        }
    }

    static func text(_ statement: OpaquePointer, _ index: Int32) -> String {
        guard let pointer = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: pointer)
    }

    static func optionalText(_ statement: OpaquePointer, _ index: Int32) -> String? {
        if sqlite3_column_type(statement, index) == SQLITE_NULL { return nil }
        let value = text(statement, index)
        return value
    }

    static func blob(_ statement: OpaquePointer, _ index: Int32) -> Data? {
        if sqlite3_column_type(statement, index) == SQLITE_NULL { return nil }
        guard let pointer = sqlite3_column_blob(statement, index) else { return nil }
        let count = Int(sqlite3_column_bytes(statement, index))
        return Data(bytes: pointer, count: count)
    }

    private func bind(_ statement: OpaquePointer, _ index: Int32, _ value: SQLValue) throws {
        let result: Int32
        switch value {
        case .null:
            result = sqlite3_bind_null(statement, index)
        case .int(let int):
            result = sqlite3_bind_int64(statement, index, int)
        case .text(let text):
            result = text.withCString { pointer in
                sqlite3_bind_text(statement, index, pointer, -1, transient)
            }
        case .blob(let data):
            result = data.withUnsafeBytes { buffer in
                sqlite3_bind_blob(
                    statement,
                    index,
                    buffer.baseAddress,
                    Int32(buffer.count),
                    transient
                )
            }
        }
        guard result == SQLITE_OK else {
            throw SQLiteError(message: "写入数据库参数失败")
        }
    }

    private func userVersion() throws -> Int64 {
        var version: Int64 = 0
        try run("PRAGMA user_version") { statement in
            version = sqlite3_column_int64(statement, 0)
        }
        return version
    }
}

struct SQLiteError: Error, CustomStringConvertible {
    var message: String
    var description: String { message }
}
