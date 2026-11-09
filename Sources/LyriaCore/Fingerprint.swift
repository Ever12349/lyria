import Foundation

public enum FingerprintMethod: String, Equatable {
    case full
    case headTailSize = "head_tail_size"
}

public struct FingerprintDigest: Equatable {
    public var sha256: Data
    public var method: FingerprintMethod
    public var trackID: String
}

public enum Fingerprint {
    /// Files at least this large use `head_tail_size`. The threshold is permanent.
    public static let largeFileThreshold: Int64 = 32 * 1024 * 1024
    public static let edgeBytes = 64 * 1024

    public static func method(forByteCount count: Int64) -> FingerprintMethod {
        count >= largeFileThreshold ? .headTailSize : .full
    }

    public static func digest(contents: Data) -> FingerprintDigest {
        make(SHA256.hash(contents), method: .full)
    }

    /// SHA-256 of `head || tail || 8-byte big-endian byte count`.
    public static func digestHeadTail(head: Data, tail: Data, byteCount: Int64) -> FingerprintDigest {
        var payload = Data()
        payload.reserveCapacity(head.count + tail.count + 8)
        payload.append(head)
        payload.append(tail)
        var size = UInt64(bitPattern: byteCount).bigEndian
        withUnsafeBytes(of: &size) { payload.append(contentsOf: $0) }
        return make(SHA256.hash(payload), method: .headTailSize)
    }

    private static func make(_ sha256: Data, method: FingerprintMethod) -> FingerprintDigest {
        FingerprintDigest(sha256: sha256, method: method, trackID: EntityID.track(fromSHA256: sha256))
    }
}
