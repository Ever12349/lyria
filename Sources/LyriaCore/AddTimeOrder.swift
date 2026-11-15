import Foundation

/// Newest add time first, for the library and for one playlist.
/// Equal stamps are not broken by id, rowid, or insert sequence.
public enum AddTimeOrder {
    public static func newestFirst<T>(_ items: [T], addedAt: (T) -> Int64) -> [T] {
        items.sorted { addedAt($0) > addedAt($1) }
    }
}
