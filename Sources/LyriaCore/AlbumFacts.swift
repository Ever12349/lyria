import Foundation

public struct AlbumMember: Equatable, Sendable {
    public var trackID: String
    public var albumName: String
    public var year: Int
    /// Non-nil only when the file is still on disk.
    public var artworkPath: String?

    public init(trackID: String, albumName: String, year: Int, artworkPath: String?) {
        self.trackID = trackID
        self.albumName = albumName
        self.year = year
        self.artworkPath = artworkPath
    }
}

public struct CreditArtist: Equatable, Sendable {
    public var id: String
    public var name: String
    public var sortName: String

    public init(id: String, name: String, sortName: String) {
        self.id = id
        self.name = name
        self.sortName = sortName
    }
}

public struct AlbumRewriteTrack: Equatable, Sendable {
    public var trackID: String
    public var albumName: String
    public var normalizedAlbum: String
    public var year: Int
    public var artistID: String?
    public var artworkPath: String?

    public init(
        trackID: String,
        albumName: String,
        normalizedAlbum: String,
        year: Int,
        artistID: String?,
        artworkPath: String?
    ) {
        self.trackID = trackID
        self.albumName = albumName
        self.normalizedAlbum = normalizedAlbum
        self.year = year
        self.artistID = artistID
        self.artworkPath = artworkPath
    }
}

public struct RewrittenAlbum: Equatable, Sendable {
    public var id: String
    public var name: String
    public var year: Int
    public var artworkPath: String?

    public init(id: String, name: String, year: Int, artworkPath: String?) {
        self.id = id
        self.name = name
        self.year = year
        self.artworkPath = artworkPath
    }
}

/// Display rules for an album grouped by name.
public enum AlbumFacts {
    public static let unknownArtist = "未知艺人"

    /// Most common `album_name`. Ties go to the name on the smallest track id.
    public static func displayName(members: [AlbumMember]) -> String {
        var counts: [String: Int] = [:]
        var earliest: [String: String] = [:]
        for member in members {
            counts[member.albumName, default: 0] += 1
            if let known = earliest[member.albumName] {
                if member.trackID < known { earliest[member.albumName] = member.trackID }
            } else {
                earliest[member.albumName] = member.trackID
            }
        }
        return counts.keys.max { lhs, rhs in
            let left = counts[lhs] ?? 0
            let right = counts[rhs] ?? 0
            if left != right { return left < right }
            return (earliest[lhs] ?? "") > (earliest[rhs] ?? "")
        } ?? ""
    }

    public static func year(members: [AlbumMember]) -> Int {
        members.map(\.year).filter { $0 != 0 }.max() ?? 0
    }

    /// First on-disk artwork among members ordered by track id.
    public static func artworkPath(members: [AlbumMember]) -> String? {
        members.sorted { $0.trackID < $1.trackID }.compactMap(\.artworkPath).first
    }

    /// Artists-list order (`sort_name` case-insensitive, then `name`). Skip missing ids.
    public static func creditLine(participatingArtistIDs: [String], catalog: [CreditArtist]) -> String {
        let wanted = Set(participatingArtistIDs.filter { !$0.isEmpty })
        let names = catalog
            .sorted(by: artistOrder)
            .filter { wanted.contains($0.id) && !$0.name.isEmpty }
            .map(\.name)
        if names.isEmpty { return unknownArtist }
        return names.joined(separator: "、")
    }

    public static func albumIDs(forArtist artistID: String, tracks: [(albumID: String?, artistID: String?)]) -> Set<String> {
        Set(tracks.compactMap { track in
            guard track.artistID == artistID, let albumID = track.albumID, !albumID.isEmpty else { return nil }
            return albumID
        })
    }

    /// Name-only album ids. Applying twice is the same assignment and the same album rows.
    public static func rewrite(_ tracks: [AlbumRewriteTrack]) -> (albumIDByTrack: [String: String?], albums: [RewrittenAlbum]) {
        var ids: [String: String?] = [:]
        var grouped: [String: [AlbumMember]] = [:]
        for track in tracks {
            let albumID = EntityID.album(normalizedName: track.normalizedAlbum)
            ids[track.trackID] = albumID
            guard let albumID else { continue }
            grouped[albumID, default: []].append(AlbumMember(
                trackID: track.trackID,
                albumName: track.albumName,
                year: track.year,
                artworkPath: track.artworkPath
            ))
        }
        let albums = grouped.keys.sorted().map { id in
            let members = grouped[id] ?? []
            return RewrittenAlbum(
                id: id,
                name: displayName(members: members),
                year: year(members: members),
                artworkPath: artworkPath(members: members)
            )
        }
        return (ids, albums)
    }

    private static func artistOrder(_ lhs: CreditArtist, _ rhs: CreditArtist) -> Bool {
        let sort = lhs.sortName.localizedCaseInsensitiveCompare(rhs.sortName)
        if sort != .orderedSame { return sort == .orderedAscending }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
