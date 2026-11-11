import Foundation

/// One menu target. Only the primary path is considered; aliases are not.
public struct RevealTarget: Equatable, Sendable {
    public var missing: Bool
    public var path: String

    public init(missing: Bool, path: String) {
        self.missing = missing
        self.path = path
    }
}

/// Whether 「在访达中显示」 is shown, and what a click should do. Does not open Finder.
public enum RevealInFinder {
    public enum Click: Equatable, Sendable {
        case unavailable
        case notFound
        case reveal(path: String)
    }

    /// Shown for exactly one track that is not marked missing and has a primary path.
    public static func canShow(_ targets: [RevealTarget]) -> Bool {
        guard targets.count == 1, let target = targets.first else { return false }
        return !target.missing && !target.path.isEmpty
    }

    /// Click-time existence check. A missing file does not change the library's missing flag.
    public static func click(_ targets: [RevealTarget], fileExists: (String) -> Bool) -> Click {
        guard canShow(targets), let path = targets.first?.path else { return .unavailable }
        if fileExists(path) { return .reveal(path: path) }
        return .notFound
    }
}
