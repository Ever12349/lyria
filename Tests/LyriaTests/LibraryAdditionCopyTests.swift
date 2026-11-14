import XCTest
import LyriaCore

final class LibraryAdditionCopyTests: XCTestCase {
    func testAllNew() {
        XCTAssertEqual(LibraryAdditionCopy.toast(added: 3, already: 0, skipped: 0), "已添加 3 首")
    }

    func testSomeFailed() {
        XCTAssertEqual(LibraryAdditionCopy.toast(added: 2, already: 0, skipped: 1), "已添加 2 首，跳过 1 个")
    }

    func testAllAlreadyInLibrary() {
        XCTAssertEqual(LibraryAdditionCopy.toast(added: 0, already: 4, skipped: 0), "已在曲库中")
    }

    func testNewAndAlready() {
        XCTAssertEqual(
            LibraryAdditionCopy.toast(added: 2, already: 3, skipped: 0),
            "已添加 2 首，3 首已在曲库"
        )
    }

    func testNothingImported() {
        XCTAssertEqual(LibraryAdditionCopy.toast(added: 0, already: 0, skipped: 0), "添加失败")
    }

    func testFailuresTakeTheSkipSentence() {
        XCTAssertEqual(
            LibraryAdditionCopy.toast(added: 1, already: 2, skipped: 3),
            "已添加 1 首，跳过 3 个"
        )
    }
}
