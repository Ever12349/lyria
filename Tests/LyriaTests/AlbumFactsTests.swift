import XCTest
import LyriaCore

final class AlbumFactsTests: XCTestCase {
    func testSameNameMergesAndSecondRewriteIsIdentical() {
        let tracks = [
            AlbumRewriteTrack(trackID: "trk_b", albumName: "Hits", normalizedAlbum: "Hits", year: 1999, artistID: "art_bea", artworkPath: nil),
            AlbumRewriteTrack(trackID: "trk_a", albumName: "Hits", normalizedAlbum: "Hits", year: 2001, artistID: "art_ada", artworkPath: "/a.jpg"),
            AlbumRewriteTrack(trackID: "trk_c", albumName: "其他", normalizedAlbum: "其他", year: 0, artistID: nil, artworkPath: nil),
        ]
        let first = AlbumFacts.rewrite(tracks)
        let second = AlbumFacts.rewrite(tracks)
        XCTAssertEqual(first.albumIDByTrack, second.albumIDByTrack)
        XCTAssertEqual(first.albums, second.albums)
        XCTAssertEqual(first.albumIDByTrack["trk_a"], first.albumIDByTrack["trk_b"])
        XCTAssertNotEqual(first.albumIDByTrack["trk_a"], first.albumIDByTrack["trk_c"])
        let hits = first.albums.first { $0.id == first.albumIDByTrack["trk_a"] }
        XCTAssertEqual(hits?.name, "Hits")
        XCTAssertEqual(hits?.year, 2001)
        XCTAssertEqual(hits?.artworkPath, "/a.jpg")
        let hitsID = first.albumIDByTrack["trk_a"] ?? nil
        let otherID = first.albumIDByTrack["trk_c"] ?? nil
        let membership = AlbumFacts.albumIDs(
            forArtist: "art_ada",
            tracks: tracks.map { (first.albumIDByTrack[$0.trackID] ?? nil, $0.artistID) }
        )
        XCTAssertEqual(membership, hitsID.map { [$0] } ?? [])
        XCTAssertNotEqual(hitsID, otherID)
    }

    func testDisplayNameTieBreaksOnSmallestTrackID() {
        let members = [
            AlbumMember(trackID: "trk_b", albumName: "乙", year: 0, artworkPath: nil),
            AlbumMember(trackID: "trk_a", albumName: "甲", year: 0, artworkPath: nil),
        ]
        XCTAssertEqual(AlbumFacts.displayName(members: members), "甲")
    }

    func testYearIgnoresZerosAndArtworkFollowsTrackID() {
        let members = [
            AlbumMember(trackID: "trk_b", albumName: "Hits", year: 1980, artworkPath: "/b.jpg"),
            AlbumMember(trackID: "trk_a", albumName: "Hits", year: 0, artworkPath: "/a.jpg"),
            AlbumMember(trackID: "trk_c", albumName: "Hits", year: 2004, artworkPath: nil),
        ]
        XCTAssertEqual(AlbumFacts.year(members: members), 2004)
        XCTAssertEqual(AlbumFacts.artworkPath(members: members), "/a.jpg")
        XCTAssertEqual(AlbumFacts.year(members: [AlbumMember(trackID: "t", albumName: "H", year: 0, artworkPath: nil)]), 0)
    }

    func testCreditUsesArtistListOrderAndSkipsMissingIDs() {
        let catalog = [
            CreditArtist(id: "art_z", name: "Zoe", sortName: "zoe"),
            CreditArtist(id: "art_a", name: "Ada", sortName: "ada"),
            CreditArtist(id: "art_m", name: "Mia", sortName: "mia"),
        ]
        XCTAssertEqual(
            AlbumFacts.creditLine(participatingArtistIDs: ["art_z", "missing", "art_a", "art_z"], catalog: catalog),
            "Ada、Zoe"
        )
        XCTAssertEqual(AlbumFacts.creditLine(participatingArtistIDs: [], catalog: catalog), "未知艺人")
    }
}
