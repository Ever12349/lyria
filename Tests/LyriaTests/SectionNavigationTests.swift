import XCTest
import LyriaCore

final class SectionNavigationTests: XCTestCase {
    func testSwitchKeepsTheOtherStack() {
        var nav = SectionNavigation()
        nav.select(.artists)
        nav.openArtist("ada")
        nav.select(.albums)
        XCTAssertEqual(nav.section, .albums)
        XCTAssertEqual(nav.page, .albums)
        XCTAssertEqual(nav.stack(for: .artists), [.artists, .artist("ada")])
        nav.select(.artists)
        XCTAssertEqual(nav.page, .artist("ada"))
    }

    func testReselectResetsThatSectionToRoot() {
        var nav = SectionNavigation()
        nav.select(.artists)
        nav.openArtist("ada")
        let generation = nav.rootGeneration[.artists]
        nav.select(.artists)
        XCTAssertEqual(nav.page, .artists)
        XCTAssertEqual(nav.stack(for: .artists), [.artists])
        XCTAssertEqual(nav.rootGeneration[.artists], (generation ?? 0) + 1)
        nav.select(.artists)
        XCTAssertEqual(nav.rootGeneration[.artists], (generation ?? 0) + 2)
    }

    func testLogoGoesHomeWithoutClearingOtherStacks() {
        var nav = SectionNavigation()
        nav.select(.artists)
        nav.openArtist("ada")
        nav.select(.playlists)
        nav.openPlaylist("p1")
        nav.showLibraryHome()
        XCTAssertEqual(nav.section, .library)
        XCTAssertEqual(nav.page, .library)
        XCTAssertEqual(nav.stack(for: .artists), [.artists, .artist("ada")])
        XCTAssertEqual(nav.stack(for: .playlists), [.playlists, .playlist("p1")])
        let generation = nav.rootGeneration[.library]
        nav.showLibraryHome()
        XCTAssertEqual(nav.rootGeneration[.library], (generation ?? 0) + 1)
        XCTAssertEqual(nav.stack(for: .artists), [.artists, .artist("ada")])
    }

    func testAlbumFromArtistsStaysOnArtistsAndBackReturns() {
        var nav = SectionNavigation()
        nav.select(.artists)
        nav.openArtist("ada")
        nav.openAlbum("hits")
        XCTAssertEqual(nav.section, .artists)
        XCTAssertEqual(nav.page, .album("hits"))
        XCTAssertEqual(nav.stack(for: .albums), [.albums])
        nav.goBack()
        XCTAssertEqual(nav.section, .artists)
        XCTAssertEqual(nav.page, .artist("ada"))
    }

    func testAlbumFromSearchStaysOnThatSectionAndBackRestoresTheQuery() {
        var nav = SectionNavigation()
        nav.select(.artists)
        nav.openArtist("ada")
        nav.beginSearch()
        nav.openAlbum("hits", resumeQuery: "ada")
        XCTAssertFalse(nav.isSearching)
        XCTAssertEqual(nav.section, .artists)
        XCTAssertEqual(nav.page, .album("hits"))
        XCTAssertEqual(nav.stack(for: .artists), [.artists, .artist("ada"), .album("hits")])
        XCTAssertEqual(nav.stack(for: .albums), [.albums])
        XCTAssertEqual(nav.goBack(), "ada")
        XCTAssertTrue(nav.isSearching)
        XCTAssertEqual(nav.section, .artists)
        XCTAssertEqual(nav.page, .artist("ada"))
    }

    func testAlbumFromLibraryPushesOnTheLibraryStack() {
        var nav = SectionNavigation()
        nav.openAlbum("hits")
        XCTAssertEqual(nav.section, .library)
        XCTAssertEqual(nav.page, .album("hits"))
        XCTAssertEqual(nav.stack(for: .library), [.library, .album("hits")])
        XCTAssertEqual(nav.stack(for: .albums), [.albums])
        nav.openAlbum("other")
        XCTAssertEqual(nav.stack(for: .library), [.library, .album("hits"), .album("other")])
        nav.goBack()
        XCTAssertEqual(nav.page, .album("hits"))
        nav.goBack()
        XCTAssertEqual(nav.page, .library)
    }

    func testOpenArtistFromLibraryDoesNotSwitchSection() {
        var nav = SectionNavigation()
        nav.openAlbum("hits")
        nav.openArtist("ada")
        XCTAssertEqual(nav.section, .library)
        XCTAssertEqual(nav.page, .artist("ada"))
        XCTAssertEqual(nav.stack(for: .artists), [.artists])
        nav.goBack()
        XCTAssertEqual(nav.page, .album("hits"))
    }

    func testOpeningThePageAlreadyOnTopDoesNotPushAgain() {
        var nav = SectionNavigation()
        nav.openAlbum("hits")
        nav.openAlbum("hits")
        XCTAssertEqual(nav.stack(for: .library), [.library, .album("hits")])
    }

    func testSearchBackClearsSearchBeforePop() {
        var nav = SectionNavigation()
        nav.select(.artists)
        nav.openArtist("ada")
        nav.beginSearch()
        nav.goBack()
        XCTAssertFalse(nav.isSearching)
        XCTAssertEqual(nav.section, .artists)
        XCTAssertEqual(nav.page, .artist("ada"))
    }

    func testDeletingOpenPlaylistPopsOnlyThatStack() {
        var nav = SectionNavigation()
        nav.select(.artists)
        nav.openArtist("ada")
        nav.openPlaylist("p1")
        nav.deletedOpenPlaylist("p1")
        XCTAssertEqual(nav.stack(for: .playlists), [.playlists])
        XCTAssertEqual(nav.stack(for: .artists), [.artists, .artist("ada")])
    }

    func testSidebarPlaylistHasNoPageUnderIt() {
        var nav = SectionNavigation()
        nav.select(.artists)
        nav.openArtist("ada")
        nav.select(.library)
        nav.showPlaylist("p1")
        XCTAssertEqual(nav.section, .playlists)
        XCTAssertEqual(nav.stack(for: .playlists), [.playlist("p1")])
        XCTAssertEqual(nav.playlistsSidebarPage, .playlist("p1"))
        XCTAssertEqual(nav.stack(for: .artists), [.artists, .artist("ada")])
        XCTAssertFalse(nav.canGoBack)
        nav.goBack()
        XCTAssertEqual(nav.stack(for: .playlists), [.playlist("p1")])
    }

    func testSidebarPlaylistReplacesThePreviousShortcut() {
        var nav = SectionNavigation()
        nav.showPlaylist("p1")
        nav.showPlaylist("p2")
        XCTAssertEqual(nav.stack(for: .playlists), [.playlist("p2")])
        XCTAssertFalse(nav.canGoBack)
        nav.showPlaylist("p2")
        XCTAssertEqual(nav.stack(for: .playlists), [.playlist("p2")])
    }

    func testShowingAPlaylistClearsSearch() {
        var nav = SectionNavigation()
        nav.beginSearch()
        nav.showPlaylist("p1")
        XCTAssertFalse(nav.isSearching)
        XCTAssertFalse(nav.canGoBack)
        XCTAssertNil(nav.pausedSearch)
    }

    func testSearchOnADirectPlaylistShowsBackUntilItEnds() {
        var nav = SectionNavigation()
        nav.showPlaylist("p1")
        nav.beginSearch()
        XCTAssertTrue(nav.canGoBack)
        nav.goBack()
        XCTAssertFalse(nav.isSearching)
        XCTAssertEqual(nav.stack(for: .playlists), [.playlist("p1")])
        XCTAssertFalse(nav.canGoBack)
    }

    func testGridPlaylistKeepsTheGridUnderneath() {
        var nav = SectionNavigation()
        nav.openPlaylist("p1")
        XCTAssertEqual(nav.stack(for: .playlists), [.playlists, .playlist("p1")])
        XCTAssertEqual(nav.playlistsSidebarPage, .playlists)
        XCTAssertTrue(nav.canGoBack)
        nav.goBack()
        XCTAssertEqual(nav.page, .playlists)
        XCTAssertFalse(nav.canGoBack)
    }

    func testSidebarPlaylistDropsTheGridParent() {
        var nav = SectionNavigation()
        nav.openPlaylist("p1")
        nav.showPlaylist("p1")
        XCTAssertEqual(nav.stack(for: .playlists), [.playlist("p1")])
        nav.openPlaylist("p1")
        nav.showPlaylist("p2")
        XCTAssertEqual(nav.stack(for: .playlists), [.playlist("p2")])
    }

    func testAlbumFromADirectPlaylistReturnsToThatPlaylist() {
        var nav = SectionNavigation()
        nav.showPlaylist("p1")
        nav.openAlbum("hits")
        XCTAssertEqual(nav.stack(for: .playlists), [.playlist("p1"), .album("hits")])
        XCTAssertEqual(nav.playlistsSidebarPage, .playlist("p1"))
        XCTAssertTrue(nav.canGoBack)
        nav.goBack()
        XCTAssertEqual(nav.stack(for: .playlists), [.playlist("p1")])
        XCTAssertEqual(nav.playlistsSidebarPage, .playlist("p1"))
        XCTAssertFalse(nav.canGoBack)
    }

    func testAlbumFromAGridPlaylistReturnsThroughThePlaylistToTheGrid() {
        var nav = SectionNavigation()
        nav.openPlaylist("p1")
        nav.openAlbum("hits")
        XCTAssertEqual(nav.stack(for: .playlists), [.playlists, .playlist("p1"), .album("hits")])
        XCTAssertEqual(nav.playlistsSidebarPage, .playlists)
        nav.goBack()
        XCTAssertEqual(nav.page, .playlist("p1"))
        nav.goBack()
        XCTAssertEqual(nav.page, .playlists)
    }

    func testSelectingPlaylistsFromAnotherSectionShowsTheGridWithoutRemounting() {
        var nav = SectionNavigation()
        nav.select(.artists)
        nav.openArtist("ada")
        nav.showPlaylist("p1")
        let generation = nav.rootGeneration[.playlists]
        nav.select(.library)
        nav.select(.playlists)
        XCTAssertEqual(nav.section, .playlists)
        XCTAssertEqual(nav.page, .playlists)
        XCTAssertEqual(nav.stack(for: .playlists), [.playlists])
        XCTAssertEqual(nav.rootGeneration[.playlists], generation)
        XCTAssertEqual(nav.stack(for: .artists), [.artists, .artist("ada")])
    }

    func testSelectingThePlaylistsGridFromElsewhereDoesNotRemountIt() {
        var nav = SectionNavigation()
        nav.select(.playlists)
        let generation = nav.rootGeneration[.playlists]
        nav.select(.library)
        nav.select(.playlists)
        XCTAssertEqual(nav.page, .playlists)
        XCTAssertEqual(nav.rootGeneration[.playlists], generation)
    }

    func testReselectingPlaylistsWhileOnADetailRemountsTheGrid() {
        var nav = SectionNavigation()
        nav.showPlaylist("p1")
        let generation = nav.rootGeneration[.playlists]
        nav.select(.playlists)
        XCTAssertEqual(nav.page, .playlists)
        XCTAssertEqual(nav.stack(for: .playlists), [.playlists])
        XCTAssertEqual(nav.rootGeneration[.playlists], (generation ?? 0) + 1)
    }

    func testLogoLeavesADirectPlaylistInPlace() {
        var nav = SectionNavigation()
        nav.showPlaylist("p1")
        nav.showLibraryHome()
        XCTAssertEqual(nav.section, .library)
        XCTAssertEqual(nav.stack(for: .playlists), [.playlist("p1")])
    }

    func testPruneAndRestoreKeepADirectPlaylistAsTheRoot() {
        var nav = SectionNavigation()
        nav.showPlaylist("p1")
        nav.openAlbum("hits")
        nav.pruneInvalidPages(artistIDs: [], albumIDs: ["hits"], playlistIDs: ["p1"])
        XCTAssertEqual(nav.stack(for: .playlists), [.playlist("p1"), .album("hits")])

        nav.restore(
            section: "playlists",
            stacks: ["playlists": ["playlist:p1"]],
            artistIDs: [],
            albumIDs: ["hits"],
            playlistIDs: ["p1"]
        )
        XCTAssertEqual(nav.stack(for: .playlists), [.playlist("p1")])

        nav.restore(
            section: "playlists",
            stacks: ["playlists": ["playlist:p1", "album:hits"]],
            artistIDs: [],
            albumIDs: ["hits"],
            playlistIDs: ["p1"]
        )
        XCTAssertEqual(nav.stack(for: .playlists), [.playlist("p1"), .album("hits")])
    }

    func testRestoreDropsAMissingDirectPlaylistBackToTheGrid() {
        var nav = SectionNavigation()
        nav.restore(
            section: "playlists",
            stacks: ["playlists": ["playlist:gone"]],
            artistIDs: [],
            albumIDs: [],
            playlistIDs: []
        )
        XCTAssertEqual(nav.stack(for: .playlists), [.playlists])
    }

    func testRestoreKeepsASavedGridParent() {
        var nav = SectionNavigation()
        nav.restore(
            section: "playlists",
            stacks: ["playlists": ["playlists", "playlist:p1"]],
            artistIDs: [],
            albumIDs: [],
            playlistIDs: ["p1"]
        )
        XCTAssertEqual(nav.stack(for: .playlists), [.playlists, .playlist("p1")])
    }
}
