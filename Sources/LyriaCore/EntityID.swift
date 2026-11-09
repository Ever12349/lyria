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

    /// `alb_` hashes `normalize(artist) + NUL + normalize(album)`. Empty or suspect sides mint nothing.
    public static func album(normalizedArtist: String, normalizedAlbum: String) -> String? {
        guard !normalizedArtist.isEmpty, !normalizedAlbum.isEmpty else { return nil }
        if normalizedArtist.contains("\u{FFFD}") || normalizedAlbum.contains("\u{FFFD}") {
            return nil
        }
        var payload = Data(normalizedArtist.utf8)
        payload.append(0)
        payload.append(Data(normalizedAlbum.utf8))
        let digest = SHA256.hash(payload)
        return "alb_" + Crockford.encode(Data(digest.prefix(16)))
    }

    public static func playlist() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        for index in bytes.indices {
            bytes[index] = UInt8.random(in: .min ... .max)
        }
        return "pls_" + Crockford.encode(Data(bytes))
    }

    /// Suspect if any of title / artist / album contains U+FFFD. Suspect or empty names do not mint ids.
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
            albumID: suspect ? nil : album(normalizedArtist: artistName.text, normalizedAlbum: albumName.text)
        )
    }
}
