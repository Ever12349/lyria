import Foundation

/// One playlist's recency stamp. `nil` means the row has never been used.
public struct PlaylistUse: Equatable, Sendable {
    public var id: String
    public var lastUsedAt: Int64?

    public init(id: String, lastUsedAt: Int64?) {
        self.id = id
        self.lastUsedAt = lastUsedAt
    }
}

/// Sidebar shortcuts. The all-playlists grid keeps its own `created_at` order.
public enum PlaylistRecency {
    public static let sidebarLimit = 5

    /// Non-null `lastUsedAt` descending, then id ascending. Unused rows are left out.
    public static func recentIDs(_ playlists: [PlaylistUse], limit: Int = sidebarLimit) -> [String] {
        let cap = max(0, limit)
        return playlists
            .compactMap { playlist -> (id: String, stamp: Int64)? in
                guard let stamp = playlist.lastUsedAt else { return nil }
                return (playlist.id, stamp)
            }
            .sorted { lhs, rhs in
                if lhs.stamp != rhs.stamp { return lhs.stamp > rhs.stamp }
                return lhs.id < rhs.id
            }
            .prefix(cap)
            .map(\.id)
    }
}
