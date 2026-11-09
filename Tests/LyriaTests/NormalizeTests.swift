import XCTest
import LyriaCore

final class NormalizeTests: XCTestCase {
    func testTrimsAndCollapsesWhitespace() {
        let name = NameNormalizer.normalize(" \t\n 名字  \n 甲 \t")
        XCTAssertEqual(name.text, "名字 甲")
        XCTAssertFalse(name.encodingSuspect)
    }

    func testCanonicalComposition() {
        let name = NameNormalizer.normalize("e\u{0301}")
        XCTAssertEqual(name.text, "\u{00E9}")
        XCTAssertFalse(name.encodingSuspect)
    }

    func testReplacementCharacterIsSuspect() {
        let name = NameNormalizer.normalize("bad\u{FFFD}name")
        XCTAssertTrue(name.encodingSuspect)
        XCTAssertTrue(name.text.contains("\u{FFFD}"))
    }

    func testChineseIsNotSuspect() {
        let name = NameNormalizer.normalize("周杰伦")
        XCTAssertEqual(name.text, "周杰伦")
        XCTAssertFalse(name.encodingSuspect)
    }

    func testLatin1MojibakeIsNotSuspect() {
        let name = NameNormalizer.normalize("Ã©Ã¨ÃªÃ«")
        XCTAssertFalse(name.encodingSuspect)
    }

    func testBlankBecomesEmpty() {
        let name = NameNormalizer.normalize("  \n\t ")
        XCTAssertEqual(name.text, "")
        XCTAssertFalse(name.encodingSuspect)
    }

    func testSortNameIsNormalizedName() {
        XCTAssertEqual(NameNormalizer.sortName("  Sigur   Rós "), "Sigur Rós")
    }

    func testEmptyArtistAndAlbumMintNoIDs() {
        let decision = EntityID.decide(title: "Song", artist: "   ", album: "Greatest Hits")
        XCTAssertNil(decision.artistID)
        XCTAssertNil(decision.albumID)
        XCTAssertEqual(decision.normalizedArtist, "")
        XCTAssertEqual(decision.sortName, "")
        XCTAssertFalse(decision.encodingSuspect)
    }

    func testEmptyAlbumMintsArtistOnly() {
        let decision = EntityID.decide(title: "Song", artist: "Ada", album: "")
        XCTAssertNotNil(decision.artistID)
        XCTAssertNil(decision.albumID)
        XCTAssertTrue(decision.artistID?.hasPrefix("art_") == true)
    }

    func testSuspectTitleSuppressesArtistAndAlbumIDs() {
        let decision = EntityID.decide(title: "坏\u{FFFD}题", artist: "周杰伦", album: "叶惠美")
        XCTAssertTrue(decision.encodingSuspect)
        XCTAssertNil(decision.artistID)
        XCTAssertNil(decision.albumID)
        XCTAssertEqual(decision.normalizedArtist, "周杰伦")
    }

    func testSameAlbumNameDifferentArtists() {
        let left = EntityID.album(normalizedArtist: "Ada", normalizedAlbum: "Greatest Hits")
        let right = EntityID.album(normalizedArtist: "Bea", normalizedAlbum: "Greatest Hits")
        XCTAssertNotNil(left)
        XCTAssertNotNil(right)
        XCTAssertNotEqual(left, right)
        XCTAssertTrue(left?.hasPrefix("alb_") == true)
    }

    func testArtistIDStable() {
        let first = EntityID.artist(normalizedName: "周杰伦")
        let second = EntityID.artist(normalizedName: "周杰伦")
        XCTAssertEqual(first, second)
        XCTAssertNil(EntityID.artist(normalizedName: ""))
        XCTAssertNil(EntityID.artist(normalizedName: "a\u{FFFD}"))
    }

    func testYearParser() {
        XCTAssertEqual(YearParser.parse("2020"), 2020)
        XCTAssertEqual(YearParser.parse("2020-05-01"), 2020)
        XCTAssertEqual(YearParser.parse("May 1994"), 1994)
        XCTAssertEqual(YearParser.parse("12"), 0)
        XCTAssertEqual(YearParser.parse("not a year"), 0)
        XCTAssertEqual(YearParser.parse(""), 0)
        XCTAssertEqual(YearParser.parse(nil), 0)
        XCTAssertEqual(YearParser.parse("20201"), 0)
    }
}
