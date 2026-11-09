import Foundation

public struct NormalizedName: Equatable {
    public var text: String
    public var encodingSuspect: Bool
}

public enum NameNormalizer {
    /// NFC, trim, and collapse runs of whitespace to a single space.
    /// `encodingSuspect` is true only when the string contains U+FFFD.
    public static func normalize(_ raw: String) -> NormalizedName {
        let composed = raw.precomposedStringWithCanonicalMapping
        let text = collapseWhitespace(composed)
        let suspect = raw.unicodeScalars.contains(where: isReplacement)
            || text.unicodeScalars.contains(where: isReplacement)
        return NormalizedName(text: text, encodingSuspect: suspect)
    }

    public static func sortName(_ raw: String) -> String {
        normalize(raw).text
    }

    private static func isReplacement(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value == 0xFFFD
    }

    private static func collapseWhitespace(_ text: String) -> String {
        var result = ""
        var pendingSpace = false
        var started = false
        for scalar in text.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                if started { pendingSpace = true }
                continue
            }
            if pendingSpace {
                result.unicodeScalars.append(" ")
                pendingSpace = false
            }
            result.unicodeScalars.append(scalar)
            started = true
        }
        return result
    }
}

public enum YearParser {
    /// First 4-digit year in 1000...2999, otherwise 0.
    public static func parse(_ raw: String?) -> Int {
        guard let raw else { return 0 }
        let scalars = Array(raw.unicodeScalars)
        var index = 0
        while index < scalars.count {
            if isASCIIDigit(scalars[index]) {
                let start = index
                while index < scalars.count, isASCIIDigit(scalars[index]) {
                    index += 1
                }
                if index - start == 4 {
                    let token = String(String.UnicodeScalarView(scalars[start..<index]))
                    if let year = Int(token), (1000...2999).contains(year) {
                        return year
                    }
                }
            } else {
                index += 1
            }
        }
        return 0
    }

    private static func isASCIIDigit(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value >= 48 && scalar.value <= 57
    }
}
