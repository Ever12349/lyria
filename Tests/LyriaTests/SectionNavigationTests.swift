import XCTest
import LyriaCore

final class SectionNavigationTests: XCTestCase {
    func testSwitchKeepsTheOtherStack() {
        var nav = SectionNavigation()
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
        nav.openArtist("ada")
        nav.openAlbum("hits")
        XCTAssertEqual(nav.section, .artists)
        XCTAssertEqual(nav.page, .album("hits"))
        XCTAssertEqual(nav.stack(for: .albums), [.albums])
        nav.goBack()
        XCTAssertEqual(nav.section, .artists)
        XCTAssertEqual(nav.page, .artist("ada"))
    }

    func testAlbumFromSearchOnArtistsJumpsToAlbums() {
        var nav = SectionNavigation()
        nav.openArtist("ada")
        nav.beginSearch()
        nav.openAlbum("hits")
        XCTAssertFalse(nav.isSearching)
        XCTAssertEqual(nav.section, .albums)
        XCTAssertEqual(nav.stack(for: .albums), [.albums, .album("hits")])
        XCTAssertEqual(nav.stack(for: .artists), [.artists, .artist("ada")])
    }

    func testAlbumFromLibraryJumpsToAlbumsStack() {
        var nav = SectionNavigation()
        nav.openAlbum("hits")
        XCTAssertEqual(nav.section, .albums)
        XCTAssertEqual(nav.page, .album("hits"))
        XCTAssertEqual(nav.stack(for: .albums), [.albums, .album("hits")])
        nav.openAlbum("other")
        XCTAssertEqual(nav.stack(for: .albums), [.albums, .album("other")])
    }

    func testSearchBackClearsSearchBeforePop() {
        var nav = SectionNavigation()
        nav.openArtist("ada")
        nav.beginSearch()
        nav.goBack()
        XCTAssertFalse(nav.isSearching)
        XCTAssertEqual(nav.page, .artist("ada"))
    }

    func testDeletingOpenPlaylistPopsOnlyThatStack() {
        var nav = SectionNavigation()
        nav.openArtist("ada")
        nav.openPlaylist("p1")
        nav.deletedOpenPlaylist("p1")
        XCTAssertEqual(nav.stack(for: .playlists), [.playlists])
        XCTAssertEqual(nav.stack(for: .artists), [.artists, .artist("ada")])
    }
}
