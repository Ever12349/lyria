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

/// Search hidden because a page was pushed from its results. Back to `page` shows it again.
public struct PausedSearch: Equatable, Sendable {
    public var query: String
    public var section: LibrarySection
    public var page: LibraryPage

    public init(query: String, section: LibrarySection, page: LibraryPage) {
        self.query = query
        self.section = section
        self.page = page
    }
}

/// One stack per sidebar section. Not persisted.
public struct SectionNavigation: Equatable, Sendable {
    public private(set) var section: LibrarySection
    public private(set) var stacks: [LibrarySection: [LibraryPage]]
    public private(set) var rootGeneration: [LibrarySection: Int]
    public private(set) var isSearching: Bool
    public private(set) var pausedSearch: PausedSearch?

    public init() {
        section = .library
        stacks = Dictionary(uniqueKeysWithValues: LibrarySection.allCases.map { ($0, [$0.root]) })
        rootGeneration = Dictionary(uniqueKeysWithValues: LibrarySection.allCases.map { ($0, 0) })
        isSearching = false
        pausedSearch = nil
    }

    public var page: LibraryPage {
        stacks[section]?.last ?? section.root
    }

    public func stack(for section: LibrarySection) -> [LibraryPage] {
        stacks[section] ?? [section.root]
    }

    public mutating func select(_ section: LibrarySection) {
        endSearch()
        discardPausedSearch()
        if self.section == section {
            resetRoot(section)
        } else {
            self.section = section
        }
    }

    /// Logo. Other sections keep their stacks. Already on library resets that list.
    public mutating func showLibraryHome() {
        endSearch()
        discardPausedSearch()
        resetRoot(.library)
        section = .library
    }

    /// Clears a visible search without popping. Otherwise pops, then resumes a search
    /// whose results were showing this page. The returned query is that resumed search.
    @discardableResult
    public mutating func goBack() -> String? {
        if isSearching {
            isSearching = false
            return nil
        }
        if let query = takePausedQuery() {
            isSearching = true
            return query
        }
        var stack = stack(for: section)
        guard stack.count > 1 else { return nil }
        stack.removeLast()
        stacks[section] = stack
        if let query = takePausedQuery() {
            isSearching = true
            return query
        }
        return nil
    }

    public mutating func beginSearch() {
        isSearching = true
    }

    public mutating func endSearch() {
        isSearching = false
    }

    /// Pushes onto the current section. Does not switch sidebar section.
    /// Already-top is a no-op. `resumeQuery` is shown again when back returns to this page.
    public mutating func openArtist(_ id: String, resumeQuery: String? = nil) {
        push(.artist(id), resumeQuery: resumeQuery)
    }

    /// Pushes onto the current section. Does not switch sidebar section.
    public mutating func openAlbum(_ id: String, resumeQuery: String? = nil) {
        push(.album(id), resumeQuery: resumeQuery)
    }

    public mutating func openPlaylist(_ id: String) {
        endSearch()
        discardPausedSearch()
        section = .playlists
        stacks[.playlists] = [.playlists, .playlist(id)]
    }

    public mutating func discardPausedSearch() {
        pausedSearch = nil
    }

    private mutating func push(_ page: LibraryPage, resumeQuery: String?) {
        if isSearching {
            if let resumeQuery, !resumeQuery.isEmpty {
                pausedSearch = PausedSearch(query: resumeQuery, section: section, page: self.page)
            }
            isSearching = false
        }
        guard self.page != page else { return }
        var stack = stack(for: section)
        stack.append(page)
        stacks[section] = stack
    }

    private mutating func takePausedQuery() -> String? {
        guard let paused = pausedSearch, paused.section == section, paused.page == page else { return nil }
        pausedSearch = nil
        return paused.query
    }

    public mutating func deletedOpenPlaylist(_ id: String) {
        guard stack(for: .playlists).last == .playlist(id) else { return }
        stacks[.playlists] = [.playlists]
    }

    private mutating func resetRoot(_ section: LibrarySection) {
        stacks[section] = [section.root]
        rootGeneration[section, default: 0] += 1
    }

    /// Drops pages whose records are gone. Does not clear search or change the current section.
    public mutating func pruneInvalidPages(
        artistIDs: Set<String>,
        albumIDs: Set<String>,
        playlistIDs: Set<String>
    ) {
        for item in LibrarySection.allCases {
            var cleaned: [LibraryPage] = []
            for page in stack(for: item) {
                guard let kept = page.kept(
                    artistIDs: artistIDs,
                    albumIDs: albumIDs,
                    playlistIDs: playlistIDs
                ) else { continue }
                if cleaned.last == kept { continue }
                cleaned.append(kept)
            }
            if cleaned.first != item.root {
                cleaned.insert(item.root, at: 0)
            }
            if cleaned.isEmpty {
                cleaned = [item.root]
            }
            stacks[item] = cleaned
        }
        if let paused = pausedSearch {
            let ids: Set<String> = {
                switch paused.page {
                case .artist(let id): return artistIDs.contains(id) ? [id] : []
                case .album(let id): return albumIDs.contains(id) ? [id] : []
                case .playlist(let id): return playlistIDs.contains(id) ? [id] : []
                default: return [""]
                }
            }()
            if case .artist = paused.page, ids.isEmpty { pausedSearch = nil }
            if case .album = paused.page, ids.isEmpty { pausedSearch = nil }
            if case .playlist = paused.page, ids.isEmpty { pausedSearch = nil }
        }
    }

    /// Rebuilds stacks from a saved session. Search is not restored. Invalid pages are dropped.
    public mutating func restore(
        section rawSection: String,
        stacks rawStacks: [String: [String]],
        artistIDs: Set<String>,
        albumIDs: Set<String>,
        playlistIDs: Set<String>
    ) {
        isSearching = false
        pausedSearch = nil
        section = LibrarySection(rawValue: rawSection) ?? .library
        for item in LibrarySection.allCases {
            let parsed = (rawStacks[item.rawValue] ?? []).compactMap(LibraryPage.init(stackKey:))
            var cleaned: [LibraryPage] = []
            for page in parsed {
                guard let kept = page.kept(
                    artistIDs: artistIDs,
                    albumIDs: albumIDs,
                    playlistIDs: playlistIDs
                ) else { continue }
                if cleaned.last == kept { continue }
                cleaned.append(kept)
            }
            if cleaned.first != item.root {
                cleaned.insert(item.root, at: 0)
            }
            if cleaned.isEmpty {
                cleaned = [item.root]
            }
            stacks[item] = cleaned
        }
    }
}
