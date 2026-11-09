import Foundation

enum SupportPaths {
    static func directory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("Lyria", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: directory.appendingPathComponent("Artwork", isDirectory: true),
            withIntermediateDirectories: true
        )
        return directory
    }

    static func databaseURL() throws -> URL {
        try directory().appendingPathComponent("library.sqlite")
    }

    static func artworkFile(trackID: String) throws -> URL {
        try directory()
            .appendingPathComponent("Artwork", isDirectory: true)
            .appendingPathComponent(trackID + ".jpg")
    }

    static func writeArtwork(_ data: Data, trackID: String) throws -> String {
        let url = try artworkFile(trackID: trackID)
        try data.write(to: url, options: .atomic)
        return url.path
    }

    static func moveArtwork(from sourceID: String, to destinationID: String) throws {
        let source = try artworkFile(trackID: sourceID)
        let destination = try artworkFile(trackID: destinationID)
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: source, to: destination)
    }

    static func deleteArtwork(trackID: String) {
        guard let url = try? artworkFile(trackID: trackID) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func deleteAllArtwork() {
        guard let directory = try? directory().appendingPathComponent("Artwork", isDirectory: true),
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return }
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }

    static func existingArtwork(trackID: String) -> String? {
        guard let url = try? artworkFile(trackID: trackID),
              FileManager.default.fileExists(atPath: url.path)
        else { return nil }
        return url.path
    }
}

enum PathUtil {
    static func standardize(_ url: URL) -> String {
        var path = url.standardizedFileURL.resolvingSymlinksInPath().path
        if path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }

    static func abbreviate(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == home { return "~" }
        let prefix = home.hasSuffix("/") ? home : home + "/"
        if path.hasPrefix(prefix) {
            return "~/" + path.dropFirst(prefix.count)
        }
        return path
    }

    static func isUnderRoot(_ path: String, root: String) -> Bool {
        if path == root { return true }
        let prefix = root.hasSuffix("/") ? root : root + "/"
        return path.hasPrefix(prefix)
    }
}

enum BookmarkData {
    /// Sandbox is off. Still persist a bookmark so a later sandbox can resolve the root.
    static func make(for url: URL) -> Data? {
        if let scoped = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            return scoped
        }
        return try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    static func resolve(_ data: Data) -> URL? {
        var stale = false
        if let scoped = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) {
            return scoped
        }
        stale = false
        return try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
    }
}
