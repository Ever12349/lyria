import Foundation

public struct IdentityDecision: Equatable {
    public var normalizedTitle: String
    public var normalizedArtist: String
    public var normalizedAlbum: String
    /// `sort_name = normalize(name)` for the artist.
    public var sortName: String
    public var encodingSuspect: Bool
    public var artistID: String?
    public var albumID: String?
}

public enum EntityID {
    /// `trk_` + Crockford(first 16 bytes). 16 zero bytes → `trk_` and 22 zeros.
    public static func track(fromSHA256 sha256: Data) -> String {
        "trk_" + Crockford.encode(Data(sha256.prefix(16)))
    }

    public static func artist(normalizedName: String) -> String? {
        guard !normalizedName.isEmpty, !normalizedName.contains("\u{FFFD}") else { return nil }
        let digest = SHA256.hash(Data(normalizedName.utf8))
        return "art_" + Crockford.encode(Data(digest.prefix(16)))
    }

    /// `alb_` hashes the normalized album name only. Empty or U+FFFD album names mint nothing.
    public static func album(normalizedName: String) -> String? {
        guard !normalizedName.isEmpty, !normalizedName.contains("\u{FFFD}") else { return nil }
        let digest = SHA256.hash(Data(normalizedName.utf8))
        return "alb_" + Crockford.encode(Data(digest.prefix(16)))
    }

    public static func playlist() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        for index in bytes.indices {
            bytes[index] = UInt8.random(in: .min ... .max)
        }
        return "pls_" + Crockford.encode(Data(bytes))
    }

    /// Suspect if any of title / artist / album contains U+FFFD.
    /// Title or artist U+FFFD blocks `art_`. A usable album name still mints `alb_`.
    public static func decide(title: String, artist artistRaw: String, album albumRaw: String) -> IdentityDecision {
        let titleName = NameNormalizer.normalize(title)
        let artistName = NameNormalizer.normalize(artistRaw)
        let albumName = NameNormalizer.normalize(albumRaw)
        let suspect = titleName.encodingSuspect || artistName.encodingSuspect || albumName.encodingSuspect
        return IdentityDecision(
            normalizedTitle: titleName.text,
            normalizedArtist: artistName.text,
            normalizedAlbum: albumName.text,
            sortName: artistName.text,
            encodingSuspect: suspect,
            artistID: suspect ? nil : artist(normalizedName: artistName.text),
            albumID: album(normalizedName: albumName.text)
        )
    }
}
