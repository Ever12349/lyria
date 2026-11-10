import XCTest
import LyriaCore

final class TrackColumnMetricsTests: XCTestCase {
    func testFlexibleColumnsUseOnePointSevenToOneToOne() {
        let row = TrackColumnMetrics.durationWidth + TrackColumnMetrics.gutter * 3 + 370
        let widths = TrackColumnMetrics.widths(rowWidth: row)
        XCTAssertEqual(widths.title, 170, accuracy: 0.001)
        XCTAssertEqual(widths.artist, 100, accuracy: 0.001)
        XCTAssertEqual(widths.album, 100, accuracy: 0.001)
        XCTAssertEqual(widths.duration, 96, accuracy: 0.001)
        XCTAssertEqual(widths.title / widths.artist, 1.7, accuracy: 0.001)
        let used = widths.title + widths.artist + widths.album + widths.duration + TrackColumnMetrics.gutter * 3
        XCTAssertEqual(used, row, accuracy: 0.001)
    }

    func testColumnsCanShrinkBelowIntrinsicText() {
        let row = TrackColumnMetrics.durationWidth + TrackColumnMetrics.gutter * 3 + 37
        let widths = TrackColumnMetrics.widths(rowWidth: row)
        XCTAssertEqual(widths.title, 17, accuracy: 0.001)
        XCTAssertEqual(widths.artist, 10, accuracy: 0.001)
        XCTAssertEqual(widths.album, 10, accuracy: 0.001)
        XCTAssertLessThan(widths.title, 40)
        XCTAssertLessThan(widths.artist, 40)
    }

    func testNarrowRowClampsFlexibleColumnsAtZero() {
        let widths = TrackColumnMetrics.widths(rowWidth: 40)
        XCTAssertEqual(widths.title, 0, accuracy: 0.001)
        XCTAssertEqual(widths.artist, 0, accuracy: 0.001)
        XCTAssertEqual(widths.album, 0, accuracy: 0.001)
        XCTAssertEqual(widths.duration, TrackColumnMetrics.durationWidth, accuracy: 0.001)
    }
}
