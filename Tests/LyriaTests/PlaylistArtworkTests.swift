import XCTest
import LyriaCore

final class PlaylistArtworkTests: XCTestCase {
    func testPathsSkipEmptyDedupeAndCap() {
        XCTAssertEqual(
            PlaylistArtwork.paths(from: [nil, "", "/a.jpg", "/a.jpg", "/b.jpg", "/c.jpg", "/d.jpg", "/e.jpg"]),
            ["/a.jpg", "/b.jpg", "/c.jpg", "/d.jpg"]
        )
    }

    func testPathsPreserveListOrder() {
        XCTAssertEqual(
            PlaylistArtwork.paths(from: ["/z.jpg", nil, "/a.jpg", "/z.jpg"]),
            ["/z.jpg", "/a.jpg"]
        )
    }

    func testPathsRespectCustomLimit() {
        XCTAssertEqual(
            PlaylistArtwork.paths(from: ["/a.jpg", "/b.jpg", "/c.jpg"], limit: 2),
            ["/a.jpg", "/b.jpg"]
        )
        XCTAssertEqual(PlaylistArtwork.paths(from: ["/a.jpg"], limit: 0), [])
    }

    func testTilesRejectInvalidCountOrEdge() {
        XCTAssertEqual(PlaylistArtwork.tiles(count: 0, edge: 100), [])
        XCTAssertEqual(PlaylistArtwork.tiles(count: 5, edge: 100), [])
        XCTAssertEqual(PlaylistArtwork.tiles(count: 2, edge: 0), [])
        XCTAssertEqual(PlaylistArtwork.tiles(count: 2, edge: -4), [])
    }

    func testOneTileFillsTheSquare() {
        XCTAssertEqual(
            PlaylistArtwork.tiles(count: 1, edge: 160),
            [ArtworkTileRect(x: 0, y: 0, width: 160, height: 160)]
        )
    }

    func testTwoTilesSplitLeftRight() {
        let tiles = PlaylistArtwork.tiles(count: 2, edge: 160)
        XCTAssertEqual(tiles, [
            ArtworkTileRect(x: 0, y: 0, width: 80, height: 160),
            ArtworkTileRect(x: 80, y: 0, width: 80, height: 160),
        ])
        assertCoversSquare(tiles, edge: 160)
    }

    func testThreeTilesLeftLargeRightStack() {
        let tiles = PlaylistArtwork.tiles(count: 3, edge: 160)
        XCTAssertEqual(tiles, [
            ArtworkTileRect(x: 0, y: 0, width: 80, height: 160),
            ArtworkTileRect(x: 80, y: 0, width: 80, height: 80),
            ArtworkTileRect(x: 80, y: 80, width: 80, height: 80),
        ])
        assertCoversSquare(tiles, edge: 160)
    }

    func testFourTilesRowMajor() {
        let tiles = PlaylistArtwork.tiles(count: 4, edge: 160)
        XCTAssertEqual(tiles, [
            ArtworkTileRect(x: 0, y: 0, width: 80, height: 80),
            ArtworkTileRect(x: 80, y: 0, width: 80, height: 80),
            ArtworkTileRect(x: 0, y: 80, width: 80, height: 80),
            ArtworkTileRect(x: 80, y: 80, width: 80, height: 80),
        ])
        assertCoversSquare(tiles, edge: 160)
    }

    func testOddEdgeGivesRemainderToRightAndBottom() {
        let two = PlaylistArtwork.tiles(count: 2, edge: 25)
        XCTAssertEqual(two, [
            ArtworkTileRect(x: 0, y: 0, width: 12, height: 25),
            ArtworkTileRect(x: 12, y: 0, width: 13, height: 25),
        ])
        assertCoversSquare(two, edge: 25)

        let three = PlaylistArtwork.tiles(count: 3, edge: 25)
        XCTAssertEqual(three, [
            ArtworkTileRect(x: 0, y: 0, width: 12, height: 25),
            ArtworkTileRect(x: 12, y: 0, width: 13, height: 12),
            ArtworkTileRect(x: 12, y: 12, width: 13, height: 13),
        ])
        assertCoversSquare(three, edge: 25)

        let four = PlaylistArtwork.tiles(count: 4, edge: 25)
        XCTAssertEqual(four, [
            ArtworkTileRect(x: 0, y: 0, width: 12, height: 12),
            ArtworkTileRect(x: 12, y: 0, width: 13, height: 12),
            ArtworkTileRect(x: 0, y: 12, width: 12, height: 13),
            ArtworkTileRect(x: 12, y: 12, width: 13, height: 13),
        ])
        assertCoversSquare(four, edge: 25)
    }
}

private extension PlaylistArtworkTests {
    /// Every pixel of the square is covered exactly once (integer grid).
    func assertCoversSquare(_ tiles: [ArtworkTileRect], edge: Double, file: StaticString = #filePath, line: UInt = #line) {
        let size = Int(edge)
        var hit = Array(repeating: Array(repeating: 0, count: size), count: size)
        for tile in tiles {
            let x0 = Int(tile.x)
            let y0 = Int(tile.y)
            let x1 = Int(tile.x + tile.width)
            let y1 = Int(tile.y + tile.height)
            XCTAssertEqual(Double(x0), tile.x, file: file, line: line)
            XCTAssertEqual(Double(y0), tile.y, file: file, line: line)
            for y in y0..<y1 {
                for x in x0..<x1 {
                    hit[y][x] += 1
                }
            }
        }
        for y in 0..<size {
            for x in 0..<size {
                XCTAssertEqual(hit[y][x], 1, "pixel (\(x),\(y))", file: file, line: line)
            }
        }
    }
}
