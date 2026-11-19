import Foundation

/// Axis-aligned tile inside a square cover. Origin is top-left; +y goes down.
public struct ArtworkTileRect: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Playlist cover paths and adaptive collage geometry (1 / 2 / 3 / 4 tiles, no gaps).
public enum PlaylistArtwork {
    public static let maxTiles = 4

    /// List order, skip nil/empty, dedupe by path, cap at `limit`.
    public static func paths(from orderedArtworkPaths: [String?], limit: Int = maxTiles) -> [String] {
        let cap = max(0, limit)
        guard cap > 0 else { return [] }
        var seen = Set<String>()
        var result: [String] = []
        for path in orderedArtworkPaths {
            guard let path, !path.isEmpty else { continue }
            guard seen.insert(path).inserted else { continue }
            result.append(path)
            if result.count == cap { break }
        }
        return result
    }

    /// Integer tiles that cover `edge`×`edge` with no gaps.
    /// Odd remainders go to the right / bottom side (P-A).
    /// `count` outside 1...4 yields `[]`.
    public static func tiles(count: Int, edge: Double) -> [ArtworkTileRect] {
        guard (1...maxTiles).contains(count), edge > 0 else { return [] }
        switch count {
        case 1:
            return [ArtworkTileRect(x: 0, y: 0, width: edge, height: edge)]
        case 2:
            let left = floorHalf(edge)
            let right = edge - left
            return [
                ArtworkTileRect(x: 0, y: 0, width: left, height: edge),
                ArtworkTileRect(x: left, y: 0, width: right, height: edge),
            ]
        case 3:
            let left = floorHalf(edge)
            let right = edge - left
            let top = floorHalf(edge)
            let bottom = edge - top
            return [
                ArtworkTileRect(x: 0, y: 0, width: left, height: edge),
                ArtworkTileRect(x: left, y: 0, width: right, height: top),
                ArtworkTileRect(x: left, y: top, width: right, height: bottom),
            ]
        default:
            let left = floorHalf(edge)
            let right = edge - left
            let top = floorHalf(edge)
            let bottom = edge - top
            return [
                ArtworkTileRect(x: 0, y: 0, width: left, height: top),
                ArtworkTileRect(x: left, y: 0, width: right, height: top),
                ArtworkTileRect(x: 0, y: top, width: left, height: bottom),
                ArtworkTileRect(x: left, y: top, width: right, height: bottom),
            ]
        }
    }

    private static func floorHalf(_ edge: Double) -> Double {
        (edge / 2).rounded(.down)
    }
}
