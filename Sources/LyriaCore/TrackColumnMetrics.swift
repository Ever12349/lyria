import Foundation

/// Column widths for a track row, matching the prototype grid
/// `minmax(0, 1.7fr) minmax(0, 1fr) minmax(0, 1fr) 96px` with an 8pt gap.
/// The title share is the whole title cell (36pt cover + title text). Flexible
/// columns may be narrower than their text so the label can ellipsize.
public enum TrackColumnMetrics {
    public static let titleShare: CGFloat = 1.7
    public static let artistShare: CGFloat = 1
    public static let albumShare: CGFloat = 1
    public static let durationWidth: CGFloat = 96
    public static let gutter: CGFloat = 8
    public static let columnCount = 4

    public struct Widths: Equatable, Sendable {
        public var title: CGFloat
        public var artist: CGFloat
        public var album: CGFloat
        public var duration: CGFloat
    }

    public static func widths(rowWidth: CGFloat) -> Widths {
        let gaps = gutter * CGFloat(columnCount - 1)
        let flexible = max(0, rowWidth - durationWidth - gaps)
        let shares = titleShare + artistShare + albumShare
        let unit = flexible / shares
        return Widths(
            title: unit * titleShare,
            artist: unit * artistShare,
            album: unit * albumShare,
            duration: durationWidth
        )
    }
}
