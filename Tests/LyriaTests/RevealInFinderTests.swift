import XCTest
import LyriaCore

final class RevealInFinderTests: XCTestCase {
    func testShowsOnlyASinglePresentPrimaryPath() {
        let present = RevealTarget(missing: false, path: "/Music/a.mp3")
        XCTAssertTrue(RevealInFinder.canShow([present]))
        XCTAssertFalse(RevealInFinder.canShow([]))
        XCTAssertFalse(RevealInFinder.canShow([present, RevealTarget(missing: false, path: "/Music/b.mp3")]))
        XCTAssertFalse(RevealInFinder.canShow([RevealTarget(missing: true, path: "/Music/a.mp3")]))
        XCTAssertFalse(RevealInFinder.canShow([RevealTarget(missing: false, path: "")]))
        XCTAssertFalse(RevealInFinder.canShow([RevealTarget(missing: true, path: "")]))
    }

    func testClickReportsAMissingFileWithoutRevealing() {
        let target = RevealTarget(missing: false, path: "/Music/gone.mp3")
        XCTAssertEqual(
            RevealInFinder.click([target], fileExists: { _ in false }),
            .notFound
        )
        XCTAssertEqual(
            RevealInFinder.click([target], fileExists: { $0 == "/Music/gone.mp3" }),
            .reveal(path: "/Music/gone.mp3")
        )
        let hidden = [
            target,
            RevealTarget(missing: false, path: "/Music/b.mp3"),
        ]
        XCTAssertEqual(
            RevealInFinder.click(hidden, fileExists: { _ in true }),
            .unavailable
        )
    }
}