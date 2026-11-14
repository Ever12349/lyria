import XCTest
import LyriaCore

final class PlaylistRecencyTests: XCTestCase {
    func testUnusedPlaylistsStayOutOfTheSidebar() {
        let ids = PlaylistRecency.recentIDs([
            PlaylistUse(id: "b", lastUsedAt: nil),
            PlaylistUse(id: "a", lastUsedAt: nil),
        ])
        XCTAssertEqual(ids, [])
    }

    func testNewerStampWinsAndIdBreaksTies() {
        let ids = PlaylistRecency.recentIDs([
            PlaylistUse(id: "c", lastUsedAt: 10),
            PlaylistUse(id: "b", lastUsedAt: 30),
            PlaylistUse(id: "a", lastUsedAt: 30),
            PlaylistUse(id: "d", lastUsedAt: nil),
            PlaylistUse(id: "e", lastUsedAt: 20),
        ])
        XCTAssertEqual(ids, ["a", "b", "e", "c"])
    }

    func testSidebarStopsAtFive() {
        let playlists = (0..<8).map { index in
            PlaylistUse(id: "p\(index)", lastUsedAt: Int64(index + 1))
        }
        XCTAssertEqual(
            PlaylistRecency.recentIDs(playlists),
            ["p7", "p6", "p5", "p4", "p3"]
        )
    }

    func testFewerThanFiveAreAllKept() {
        let ids = PlaylistRecency.recentIDs([
            PlaylistUse(id: "z", lastUsedAt: 1),
            PlaylistUse(id: "a", lastUsedAt: 2),
        ])
        XCTAssertEqual(ids, ["a", "z"])
    }

    func testInputOrderDoesNotMatter() {
        let first = PlaylistRecency.recentIDs([
            PlaylistUse(id: "m", lastUsedAt: 5),
            PlaylistUse(id: "a", lastUsedAt: 5),
        ])
        let second = PlaylistRecency.recentIDs([
            PlaylistUse(id: "a", lastUsedAt: 5),
            PlaylistUse(id: "m", lastUsedAt: 5),
        ])
        XCTAssertEqual(first, second)
        XCTAssertEqual(first, ["a", "m"])
    }
}
