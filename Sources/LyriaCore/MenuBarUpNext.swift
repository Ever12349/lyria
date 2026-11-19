import Foundation

/// Queue indices for the menu-bar 「接下来」 list (HTML `upcomingHTML` algorithm A).
public enum MenuBarUpNext {
    public static let defaultLimit = 3

    /// After the current item, then wrap to the start up to (but not including) current.
    /// No current → first `limit` indices. Only the current row → empty.
    public static func indices(
        count: Int,
        currentIndex: Int?,
        limit: Int = defaultLimit
    ) -> [Int] {
        guard count > 0, limit > 0 else { return [] }
        guard let current = currentIndex, (0..<count).contains(current) else {
            return Array(0..<min(count, limit))
        }
        guard count > 1 else { return [] }

        var ordered: [Int] = []
        if current + 1 < count {
            ordered.append(contentsOf: (current + 1)..<count)
        }
        if current > 0 {
            ordered.append(contentsOf: 0..<current)
        }
        return Array(ordered.prefix(limit))
    }
}
