import Foundation

/// Column geometry shared by the track header and every row.
///
/// The header measures the full table width. A row only matches it when its cell
/// is given that same width. `NSTableColumn` defaults to 100pt; at that width the
/// title collapses and the duration sits on top of the cover.
public enum TrackTableLayout {
    public static let paddingH: Double = 8
    public static let paddingV: Double = 6
    public static let coverSize: Double = 36
    public static let coverGap: Double = 10
    public static let columnGap: Double = 8
    public static let metaMax: Double = 120
    public static let durationColumn: Double = 96
    public static let durationWidth: Double = 44
    public static let missingWidth: Double = 56
    public static let menuSize: Double = 28
    public static let menuGap: Double = 2
    public static let rowHeight: Double = paddingV * 2 + coverSize
    public static let headerHeight: Double = 32
    /// AppKit's `NSTableColumn` width before anyone sets it.
    public static let defaultColumnWidth: Double = 100

    public struct Rect: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var width: Double
        public var height: Double

        public var minX: Double { x }
        public var maxX: Double { x + width }

        public init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }
    }

    public struct Frames: Equatable, Sendable {
        public var cover: Rect
        public var title: Rect
        public var artist: Rect
        public var album: Rect
        public var duration: Rect
        public var menu: Rect
        public var headerTitle: Rect
        public var headerArtist: Rect
        public var headerAlbum: Rect
        public var headerDuration: Rect

        public init(
            cover: Rect,
            title: Rect,
            artist: Rect,
            album: Rect,
            duration: Rect,
            menu: Rect,
            headerTitle: Rect,
            headerArtist: Rect,
            headerAlbum: Rect,
            headerDuration: Rect
        ) {
            self.cover = cover
            self.title = title
            self.artist = artist
            self.album = album
            self.duration = duration
            self.menu = menu
            self.headerTitle = headerTitle
            self.headerArtist = headerArtist
            self.headerAlbum = headerAlbum
            self.headerDuration = headerDuration
        }
    }

    public static func frames(width: Double, missing: Bool) -> Frames {
        let textH = 16.0
        let midY = (rowHeight - textH) / 2
        let menu = Rect(
            x: max(paddingH, width - paddingH - menuSize),
            y: (rowHeight - menuSize) / 2,
            width: menuSize,
            height: menuSize
        )
        let durationW = missing ? missingWidth : durationWidth
        let duration = Rect(
            x: menu.minX - menuGap - durationW,
            y: midY,
            width: durationW,
            height: textH
        )
        let rightLimit = width - paddingH - durationColumn - columnGap
        var artistW = metaMax
        var albumW = metaMax
        func titleWidth() -> Double {
            rightLimit - paddingH - (coverSize + coverGap + columnGap + artistW + columnGap + albumW)
        }
        var titleW = titleWidth()
        if titleW < 0 {
            let overflow = -titleW
            artistW = max(0, metaMax - overflow / 2)
            albumW = max(0, metaMax - (overflow - (metaMax - artistW)))
            titleW = max(0, titleWidth())
        }
        let cover = Rect(x: paddingH, y: paddingV, width: coverSize, height: coverSize)
        let title = Rect(x: cover.maxX + coverGap, y: midY, width: titleW, height: textH)
        let artist = Rect(x: title.maxX + columnGap, y: midY, width: artistW, height: textH)
        let album = Rect(x: artist.maxX + columnGap, y: midY, width: albumW, height: textH)
        let headerY = 6.0
        return Frames(
            cover: cover,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            menu: menu,
            headerTitle: Rect(x: title.minX, y: headerY, width: titleW, height: textH),
            headerArtist: Rect(x: artist.minX, y: headerY, width: artistW, height: textH),
            headerAlbum: Rect(x: album.minX, y: headerY, width: albumW, height: textH),
            headerDuration: Rect(x: duration.minX, y: headerY, width: duration.width, height: textH)
        )
    }
}
