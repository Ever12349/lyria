import Foundation

/// Sidebar width, queue panel, and per-section navigation stacks kept across launches.
/// Search, selection, and scroll position are not stored.
public struct UISession: Equatable, Sendable, Codable {
    public var sidebarWidth: Double
    public var queueVisible: Bool
    public var section: String
    public var stacks: [String: [String]]

    public static let sidebarMin: Double = 168
    public static let sidebarMax: Double = 320
    public static let sidebarDefault: Double = 228

    public init(
        sidebarWidth: Double = UISession.sidebarDefault,
        queueVisible: Bool = false,
        section: String = LibrarySection.library.rawValue,
        stacks: [String: [String]] = [:]
    ) {
        self.sidebarWidth = Self.clampedWidth(sidebarWidth)
        self.queueVisible = queueVisible
        self.section = section
        self.stacks = stacks
    }

    public init(sidebarWidth: Double, queueVisible: Bool, navigation: SectionNavigation) {
        self.init(
            sidebarWidth: sidebarWidth,
            queueVisible: queueVisible,
            section: navigation.section.rawValue,
            stacks: Dictionary(
                uniqueKeysWithValues: LibrarySection.allCases.map { section in
                    (section.rawValue, navigation.stack(for: section).map(\.stackKey))
                }
            )
        )
    }

    public static func clampedWidth(_ value: Double) -> Double {
        min(max(value, sidebarMin), sidebarMax)
    }
}

extension LibraryPage {
    public init?(stackKey: String) {
        switch stackKey {
        case "library": self = .library
        case "artists": self = .artists
        case "albums": self = .albums
        case "playlists": self = .playlists
        case "settings": self = .settings
        default:
            if stackKey.hasPrefix("artist:") {
                let id = String(stackKey.dropFirst("artist:".count))
                guard !id.isEmpty else { return nil }
                self = .artist(id)
            } else if stackKey.hasPrefix("album:") {
                let id = String(stackKey.dropFirst("album:".count))
                guard !id.isEmpty else { return nil }
                self = .album(id)
            } else if stackKey.hasPrefix("playlist:") {
                let id = String(stackKey.dropFirst("playlist:".count))
                guard !id.isEmpty else { return nil }
                self = .playlist(id)
            } else {
                return nil
            }
        }
    }

    public func kept(
        artistIDs: Set<String>,
        albumIDs: Set<String>,
        playlistIDs: Set<String>
    ) -> LibraryPage? {
        switch self {
        case .library, .artists, .albums, .playlists, .settings:
            return self
        case .artist(let id):
            return artistIDs.contains(id) ? self : nil
        case .album(let id):
            return albumIDs.contains(id) ? self : nil
        case .playlist(let id):
            return playlistIDs.contains(id) ? self : nil
        }
    }
}
