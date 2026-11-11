import Foundation

public enum LibrarySection: String, CaseIterable, Equatable, Hashable, Sendable {
    case library
    case artists
    case albums
    case playlists
    case settings

    public var root: LibraryPage {
        switch self {
        case .library: return .library
        case .artists: return .artists
        case .albums: return .albums
        case .playlists: return .playlists
        case .settings: return .settings
        }
    }
}

public enum LibraryPage: Equatable, Hashable, Sendable {
    case library
    case artists
    case artist(String)
    case albums
    case album(String)
    case playlists
    case playlist(String)
    case settings

    public var stackKey: String {
        switch self {
        case .library: return "library"
        case .artists: return "artists"
        case .artist(let id): return "artist:\(id)"
        case .albums: return "albums"
        case .album(let id): return "album:\(id)"
        case .playlists: return "playlists"
        case .playlist(let id): return "playlist:\(id)"
        case .settings: return "settings"
        }
    }
}

/// One stack per sidebar section. Not persisted.
public struct SectionNavigation: Equatable, Sendable {
    public private(set) var section: LibrarySection
    public private(set) var stacks: [LibrarySection: [LibraryPage]]
    public private(set) var rootGeneration: [LibrarySection: Int]
    public private(set) var isSearching: Bool

    public init() {
        section = .library
        stacks = Dictionary(uniqueKeysWithValues: LibrarySection.allCases.map { ($0, [$0.root]) })
        rootGeneration = Dictionary(uniqueKeysWithValues: LibrarySection.allCases.map { ($0, 0) })
        isSearching = false
    }

    public var page: LibraryPage {
        stacks[section]?.last ?? section.root
    }

    public func stack(for section: LibrarySection) -> [LibraryPage] {
        stacks[section] ?? [section.root]
    }

    public mutating func select(_ section: LibrarySection) {
        endSearch()
        if self.section == section {
            resetRoot(section)
        } else {
            self.section = section
        }
    }

    /// Logo. Other sections keep their stacks. Already on library resets that list.
    public mutating func showLibraryHome() {
        endSearch()
        resetRoot(.library)
        section = .library
    }

    public mutating func goBack() {
        if isSearching {
            isSearching = false
            return
        }
        var stack = stack(for: section)
        guard stack.count > 1 else { return }
        stack.removeLast()
        stacks[section] = stack
    }

    public mutating func beginSearch() {
        isSearching = true
    }

    public mutating func endSearch() {
        isSearching = false
    }

    public mutating func openArtist(_ id: String) {
        endSearch()
        section = .artists
        stacks[.artists] = [.artists, .artist(id)]
    }

    /// From the artists section, push onto that stack. Search and every other section jump to albums.
    public mutating func openAlbum(_ id: String) {
        let pushOnArtists = !isSearching && section == .artists
        endSearch()
        if pushOnArtists {
            var stack = stack(for: .artists)
            if stack.last != .album(id) {
                stack.append(.album(id))
            }
            stacks[.artists] = stack
            section = .artists
        } else {
            section = .albums
            stacks[.albums] = [.albums, .album(id)]
        }
    }

    public mutating func openPlaylist(_ id: String) {
        endSearch()
        section = .playlists
        stacks[.playlists] = [.playlists, .playlist(id)]
    }

    public mutating func deletedOpenPlaylist(_ id: String) {
        guard stack(for: .playlists).last == .playlist(id) else { return }
        stacks[.playlists] = [.playlists]
    }

    private mutating func resetRoot(_ section: LibrarySection) {
        stacks[section] = [section.root]
        rootGeneration[section, default: 0] += 1
    }
}
