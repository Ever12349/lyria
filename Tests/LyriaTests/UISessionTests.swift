import XCTest
import LyriaCore

final class UISessionTests: XCTestCase {
    func testClampedWidthStaysInsideRange() {
        XCTAssertEqual(UISession.clampedWidth(100), 168)
        XCTAssertEqual(UISession.clampedWidth(400), 320)
        XCTAssertEqual(UISession.clampedWidth(200), 200)
    }

    func testRestoreDropsMissingPagesAndClearsSearch() {
        var navigation = SectionNavigation()
        navigation.select(.albums)
        navigation.openAlbum("keep")
        navigation.openAlbum("gone")
        navigation.beginSearch()
        navigation.restore(
            section: "albums",
            stacks: [
                "albums": ["albums", "album:keep", "album:gone", "album:keep"],
                "library": ["library", "album:also-gone"],
                "playlists": ["playlists", "playlist:p1"],
            ],
            artistIDs: [],
            albumIDs: ["keep"],
            playlistIDs: ["p1"]
        )
        XCTAssertEqual(navigation.section, .albums)
        XCTAssertEqual(navigation.stack(for: .albums), [.albums, .album("keep")])
        XCTAssertEqual(navigation.stack(for: .library), [.library])
        XCTAssertEqual(navigation.stack(for: .playlists), [.playlists, .playlist("p1")])
        XCTAssertFalse(navigation.isSearching)
        XCTAssertNil(navigation.pausedSearch)
    }

    func testRestoreFallsBackToLibraryForUnknownSection() {
        var navigation = SectionNavigation()
        navigation.restore(
            section: "nope",
            stacks: [:],
            artistIDs: [],
            albumIDs: [],
            playlistIDs: []
        )
        XCTAssertEqual(navigation.section, .library)
        XCTAssertEqual(navigation.page, .library)
    }

    func testSessionRoundTripEncodesStacks() {
        var navigation = SectionNavigation()
        navigation.select(.artists)
        navigation.openArtist("ar1")
        let session = UISession(sidebarWidth: 500, queueVisible: true, navigation: navigation)
        XCTAssertEqual(session.sidebarWidth, 320)
        XCTAssertTrue(session.queueVisible)
        XCTAssertEqual(session.section, "artists")
        XCTAssertEqual(session.stacks["artists"], ["artists", "artist:ar1"])
        let data = try! JSONEncoder().encode(session)
        let loaded = try! JSONDecoder().decode(UISession.self, from: data)
        XCTAssertEqual(loaded, session)
    }
}
