import XCTest
import LyriaCore

final class TrackTableLayoutTests: XCTestCase {
    func testHeaderAndRowShareOriginsAtTheMeasuredTableWidth() {
        let frames = TrackTableLayout.frames(width: 1236, missing: false)

        XCTAssertEqual(frames.headerTitle.x, frames.title.x)
        XCTAssertEqual(frames.headerArtist.x, frames.artist.x)
        XCTAssertEqual(frames.headerAlbum.x, frames.album.x)
        XCTAssertEqual(frames.headerDuration.x, frames.duration.x)

        XCTAssertEqual(frames.title.x, 54)
        XCTAssertEqual(frames.title.width, 814)
        XCTAssertEqual(frames.artist.x, 876)
        XCTAssertEqual(frames.artist.width, 120)
        XCTAssertEqual(frames.album.x, 1004)
        XCTAssertEqual(frames.album.width, 120)
        XCTAssertEqual(frames.duration.x, 1154)
        XCTAssertEqual(frames.duration.width, 44)
        XCTAssertGreaterThan(frames.duration.x, frames.cover.maxX)
        XCTAssertGreaterThan(frames.menu.x, frames.duration.maxX)
    }

    func testHeaderOriginsMatchRowOriginsAcrossWidths() {
        var width = 40.0
        while width <= 2000 {
            let frames = TrackTableLayout.frames(width: width, missing: false)
            XCTAssertEqual(frames.headerTitle.x, frames.title.x, "title \(width)")
            XCTAssertEqual(frames.headerArtist.x, frames.artist.x, "artist \(width)")
            XCTAssertEqual(frames.headerAlbum.x, frames.album.x, "album \(width)")
            XCTAssertEqual(frames.headerDuration.x, frames.duration.x, "duration \(width)")
            XCTAssertEqual(frames.headerTitle.width, frames.title.width, "title width \(width)")
            XCTAssertEqual(frames.headerArtist.width, frames.artist.width, "artist width \(width)")
            XCTAssertEqual(frames.headerAlbum.width, frames.album.width, "album width \(width)")
            XCTAssertEqual(frames.headerDuration.width, frames.duration.width, "duration width \(width)")
            width += 37
        }
    }

    func testDefaultColumnWidthPacksTheRowOntoTheCover() {
        let frames = TrackTableLayout.frames(width: TrackTableLayout.defaultColumnWidth, missing: false)

        XCTAssertEqual(frames.title.width, 0)
        XCTAssertEqual(frames.artist.width, 0)
        XCTAssertEqual(frames.album.width, 0)
        XCTAssertLessThan(frames.duration.x, frames.cover.maxX)
        XCTAssertEqual(frames.duration.x, 18)

        let fitted = TrackTableLayout.frames(width: 1236, missing: false)
        XCTAssertNotEqual(frames.title.x + frames.title.width, fitted.title.x + fitted.title.width)
        XCTAssertNotEqual(frames.artist.x, fitted.artist.x)
        XCTAssertNotEqual(frames.duration.x, fitted.duration.x)
    }

    func testMissingRowKeepsTheTitleColumnsAndWidensDuration() {
        let header = TrackTableLayout.frames(width: 900, missing: false)
        let row = TrackTableLayout.frames(width: 900, missing: true)

        XCTAssertEqual(row.title.x, header.title.x)
        XCTAssertEqual(row.artist.x, header.artist.x)
        XCTAssertEqual(row.album.x, header.album.x)
        XCTAssertEqual(row.duration.width, TrackTableLayout.missingWidth)
        XCTAssertEqual(row.duration.x, header.duration.x - (TrackTableLayout.missingWidth - TrackTableLayout.durationWidth))
    }
}
