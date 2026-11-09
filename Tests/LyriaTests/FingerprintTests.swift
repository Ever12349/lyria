import XCTest
import LyriaCore

final class FingerprintTests: XCTestCase {
    func testSHA256KnownVectors() {
        XCTAssertEqual(hex(SHA256.hash(Data())), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        XCTAssertEqual(hex(SHA256.hash(Data("abc".utf8))), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        let longer = Data("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".utf8)
        XCTAssertEqual(hex(SHA256.hash(longer)), "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
    }

    func testMethodBranchesAt32MiB() {
        let threshold = Fingerprint.largeFileThreshold
        XCTAssertEqual(threshold, 32 * 1024 * 1024)
        XCTAssertEqual(Fingerprint.method(forByteCount: 0), .full)
        XCTAssertEqual(Fingerprint.method(forByteCount: threshold - 1), .full)
        XCTAssertEqual(Fingerprint.method(forByteCount: threshold), .headTailSize)
        XCTAssertEqual(Fingerprint.method(forByteCount: threshold + 4096), .headTailSize)
        XCTAssertEqual(FingerprintMethod.headTailSize.rawValue, "head_tail_size")
    }

    func testFullDigestUsesFullMethodAndTrackPrefix() {
        let digest = Fingerprint.digest(contents: Data("hello".utf8))
        XCTAssertEqual(digest.method, .full)
        XCTAssertEqual(digest.sha256.count, 32)
        XCTAssertEqual(digest.trackID, EntityID.track(fromSHA256: digest.sha256))
        XCTAssertTrue(digest.trackID.hasPrefix("trk_"))
        XCTAssertEqual(digest.trackID.count, 26)
    }

    func testHeadTailDigestChangesWhenSizeChanges() {
        let head = Data(repeating: 0x11, count: 32)
        let tail = Data(repeating: 0x22, count: 32)
        let threshold = Fingerprint.largeFileThreshold
        let first = Fingerprint.digestHeadTail(head: head, tail: tail, byteCount: threshold)
        let second = Fingerprint.digestHeadTail(head: head, tail: tail, byteCount: threshold + 1)
        XCTAssertEqual(first.method, .headTailSize)
        XCTAssertEqual(second.method, .headTailSize)
        XCTAssertNotEqual(first.sha256, second.sha256)
        XCTAssertNotEqual(first.trackID, second.trackID)
        XCTAssertNotEqual(first.sha256, Fingerprint.digest(contents: head + tail).sha256)
    }

    func testZeroPrefixStillLocksTrackIDThroughDigestHelper() {
        XCTAssertEqual(
            EntityID.track(fromSHA256: Data(repeating: 0, count: 32)),
            "trk_0000000000000000000000"
        )
    }

    private func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
