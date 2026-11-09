import XCTest
import LyriaCore

final class CrockfordTests: XCTestCase {
    func testAllZeroBytesEncodeToTwentyTwoZeros() {
        let encoded = Crockford.encode(Data(repeating: 0, count: 16))
        XCTAssertEqual(encoded, String(repeating: "0", count: 22))
        XCTAssertEqual(encoded.count, 22)
    }

    func testAllZeroDigestIsLockedTrackID() {
        let trackID = EntityID.track(fromSHA256: Data(repeating: 0, count: 16))
        XCTAssertEqual(trackID, "trk_0000000000000000000000")
        XCTAssertEqual(trackID.count, 26)
    }

    func testAllZeroDigestIgnoresBytesPastThePrefix() {
        var digest = Data(repeating: 0, count: 16)
        digest.append(contentsOf: Data(repeating: 0xFF, count: 16))
        XCTAssertEqual(EntityID.track(fromSHA256: digest), "trk_0000000000000000000000")
    }

    func testAllOnesEncodeToZ() {
        let encoded = Crockford.encode(Data(repeating: 0xFF, count: 16))
        XCTAssertEqual(encoded, String(repeating: "Z", count: 22))
    }

    func testHighBitInFirstByte() {
        var bytes = Data(repeating: 0, count: 16)
        bytes[0] = 0x08
        XCTAssertEqual(Crockford.encode(bytes), "1" + String(repeating: "0", count: 21))
    }

    func testDecodeMapsConfusableLettersAndRejectsU() throws {
        XCTAssertEqual(try Crockford.decode("oo"), Data([0x00]))
        XCTAssertEqual(try Crockford.decode("OO"), Data([0x00]))
        XCTAssertEqual(try Crockford.decode("ii"), Data([0x08]))
        XCTAssertEqual(try Crockford.decode("LL"), Data([0x08]))
        XCTAssertEqual(try Crockford.decode("iL"), Data([0x08]))
        XCTAssertThrowsError(try Crockford.decode("U")) { error in
            XCTAssertEqual(error as? CrockfordError, .invalidCharacter("U"))
        }
        XCTAssertThrowsError(try Crockford.decode("u"))
    }

    func testDecodeIsCaseInsensitive() throws {
        let upper = try Crockford.decode(String(repeating: "Z", count: 22))
        let lower = try Crockford.decode(String(repeating: "z", count: 22))
        XCTAssertEqual(upper, lower)
        XCTAssertEqual(upper.prefix(13), Data(repeating: 0xFF, count: 13))
    }

    func testAlphabetExcludesConfusableLetters() {
        XCTAssertEqual(Crockford.alphabet.count, 32)
        XCTAssertFalse(Crockford.alphabet.contains("I"))
        XCTAssertFalse(Crockford.alphabet.contains("L"))
        XCTAssertFalse(Crockford.alphabet.contains("O"))
        XCTAssertFalse(Crockford.alphabet.contains("U"))
    }

    func testPlaylistIDShape() {
        let first = EntityID.playlist()
        let second = EntityID.playlist()
        XCTAssertNotEqual(first, second)
        XCTAssertTrue(first.hasPrefix("pls_"))
        XCTAssertEqual(first.count, 26)
        let body = first.dropFirst(4)
        XCTAssertTrue(body.allSatisfy { Crockford.alphabet.contains($0) })
    }
}
