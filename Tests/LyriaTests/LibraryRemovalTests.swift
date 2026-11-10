import XCTest
import LyriaCore

final class LibraryRemovalTests: XCTestCase {
    func testConfirmCopy() {
        XCTAssertEqual(LibraryRemovalCopy.confirmTitle(count: 1, singleTitle: "歌名"), "从曲库移除「歌名」？")
        XCTAssertEqual(LibraryRemovalCopy.confirmTitle(count: 3, singleTitle: nil), "从曲库移除 3 首？")
        XCTAssertEqual(LibraryRemovalCopy.confirmTitle(count: 1, singleTitle: nil), "从曲库移除？")
        XCTAssertEqual(
            LibraryRemovalCopy.confirmMessage(mentionsICloud: false),
            "也会从播放列表里去掉。文件可以留在磁盘，或移到废纸篓。"
        )
        XCTAssertEqual(
            LibraryRemovalCopy.confirmMessage(mentionsICloud: true),
            "也会从播放列表里去掉。文件可以留在磁盘，或移到废纸篓。其中有 iCloud 文件；若移到废纸篓，其他设备上也会去掉，30 天内可从废纸篓找回。"
        )
    }

    func testTrackOutcomeTreatsMissingAliasesAsSuccess() {
        XCTAssertEqual(LibraryRemovalCopy.trackOutcome(fileResults: []), .missing)
        XCTAssertEqual(LibraryRemovalCopy.trackOutcome(fileResults: [.missing, .missing]), .missing)
        XCTAssertEqual(LibraryRemovalCopy.trackOutcome(fileResults: [.trashed, .missing]), .success)
        XCTAssertEqual(LibraryRemovalCopy.trackOutcome(fileResults: [.trashed]), .success)
        XCTAssertEqual(LibraryRemovalCopy.trackOutcome(fileResults: [.trashed, .failed]), .failed)
        XCTAssertEqual(LibraryRemovalCopy.trackOutcome(fileResults: [.missing, .failed]), .failed)
    }

    func testLibraryOnlyToast() {
        XCTAssertEqual(LibraryRemovalCopy.libraryOnlyToast(count: 1, singleTitle: "歌名"), "已从曲库移除「歌名」")
        XCTAssertEqual(LibraryRemovalCopy.libraryOnlyToast(count: 4, singleTitle: "歌名"), "已从曲库移除 4 首")
        XCTAssertEqual(LibraryRemovalCopy.deleteFailed, "移除曲目失败")
    }

    func testTrashToasts() {
        XCTAssertEqual(
            LibraryRemovalCopy.trashToast(outcomes: [.success], singleTitle: "歌名"),
            "已将「歌名」移到废纸篓"
        )
        XCTAssertEqual(
            LibraryRemovalCopy.trashToast(outcomes: [.success, .success], singleTitle: "歌名"),
            "已移到废纸篓 2 首"
        )
        XCTAssertEqual(
            LibraryRemovalCopy.trashToast(outcomes: [.missing], singleTitle: "歌名"),
            "已从曲库移除「歌名」，找不到文件"
        )
        XCTAssertEqual(
            LibraryRemovalCopy.trashToast(outcomes: [.missing, .missing], singleTitle: "歌名"),
            "已从曲库移除 2 首，找不到文件"
        )
        XCTAssertEqual(
            LibraryRemovalCopy.trashToast(outcomes: [.failed], singleTitle: "歌名"),
            "已从曲库移除「歌名」，没能移到废纸篓"
        )
        XCTAssertEqual(
            LibraryRemovalCopy.trashToast(outcomes: [.failed, .failed], singleTitle: "歌名"),
            "已从曲库移除 2 首，没能移到废纸篓"
        )
        XCTAssertEqual(
            LibraryRemovalCopy.trashToast(outcomes: [.success, .missing], singleTitle: "歌名"),
            "已移到废纸篓 1 首，1 首找不到文件"
        )
        XCTAssertEqual(
            LibraryRemovalCopy.trashToast(outcomes: [.success, .failed], singleTitle: "歌名"),
            "已移到废纸篓 1 首，1 首没能移到废纸篓"
        )
        XCTAssertEqual(
            LibraryRemovalCopy.trashToast(outcomes: [.success, .missing, .failed], singleTitle: "歌名"),
            "已移到废纸篓 1 首，1 首找不到文件，1 首没能移到废纸篓"
        )
        XCTAssertEqual(
            LibraryRemovalCopy.trashToast(outcomes: [.missing, .failed], singleTitle: "歌名"),
            "已从曲库移除 2 首，1 首找不到文件，1 首没能移到废纸篓"
        )
        XCTAssertEqual(LibraryRemovalCopy.trashToast(outcomes: [], singleTitle: "歌名"), "移除曲目失败")
    }
}
