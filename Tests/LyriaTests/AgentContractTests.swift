import XCTest
import LyriaCore

final class AgentContractTests: XCTestCase {
    func testToolNamesIncludeQueueMutations() {
        XCTAssertEqual(AgentCopy.toolNames, [
            "lyria_status",
            "lyria_play",
            "lyria_pause",
            "lyria_toggle",
            "lyria_next",
            "lyria_previous",
            "lyria_seek",
            "lyria_shuffle",
            "lyria_repeat",
            "lyria_search",
            "lyria_queue_list",
            "lyria_queue_add",
            "lyria_queue_clear",
        ])
        XCTAssertFalse(AgentCopy.toolNames.contains("lyria_volume"))
    }

    func testProtocolVersionEchoesASupportedClient() {
        XCTAssertEqual(AgentCopy.negotiatedProtocolVersion("2024-11-05"), "2024-11-05")
        XCTAssertEqual(AgentCopy.negotiatedProtocolVersion("2025-03-26"), "2025-03-26")
        XCTAssertEqual(AgentCopy.negotiatedProtocolVersion("2025-06-18"), "2025-06-18")
        XCTAssertEqual(AgentCopy.negotiatedProtocolVersion("1999-01-01"), "2025-06-18")
        XCTAssertEqual(AgentCopy.negotiatedProtocolVersion(nil), "2025-06-18")
    }

    func testPlayRequestXOR() {
        XCTAssertEqual(AgentContract.parsePlay(id: .absent, uri: .absent), .success(.resume))
        XCTAssertEqual(
            AgentContract.parsePlay(id: .text("trk_a"), uri: .absent),
            .success(.track("trk_a"))
        )
        let file = AgentContract.parsePlay(id: .absent, uri: .text("file:///tmp/a.mp3"))
        guard case .success(.file(let url)) = file else {
            return XCTFail("expected file url, got \(file)")
        }
        XCTAssertEqual(url.path, "/tmp/a.mp3")
        XCTAssertEqual(
            AgentContract.parsePlay(id: .text("trk_a"), uri: .text("file:///tmp/a.mp3")),
            .failure(.badRequest(AgentCopy.idAndURI))
        )
        XCTAssertEqual(
            AgentContract.parsePlay(id: .text("  "), uri: .absent),
            .failure(.badRequest(AgentCopy.emptyID))
        )
        XCTAssertEqual(
            AgentContract.parsePlay(id: .absent, uri: .text("")),
            .failure(.badRequest(AgentCopy.emptyURI))
        )
        XCTAssertEqual(
            AgentContract.parsePlay(id: .absent, uri: .text("https://example.com/a.mp3")),
            .failure(.badRequest(AgentCopy.fileURI))
        )
    }

    func testQueueAddRequiresOneTargetAndAKnownPosition() {
        XCTAssertEqual(
            AgentContract.parseQueueTarget(id: .absent, uri: .absent),
            .failure(.badRequest(AgentCopy.needIDOrURI))
        )
        XCTAssertEqual(
            AgentContract.parseQueueTarget(id: .text("trk_a"), uri: .text("file:///tmp/a.mp3")),
            .failure(.badRequest(AgentCopy.idAndURI))
        )
        XCTAssertEqual(
            AgentContract.parseQueueTarget(id: .text("  "), uri: .absent),
            .failure(.badRequest(AgentCopy.emptyID))
        )
        XCTAssertEqual(
            AgentContract.parseQueueTarget(id: .absent, uri: .text("")),
            .failure(.badRequest(AgentCopy.emptyURI))
        )
        XCTAssertEqual(
            AgentContract.parseQueueTarget(id: .absent, uri: .text("https://example.com/a.mp3")),
            .failure(.badRequest(AgentCopy.fileURI))
        )
        XCTAssertEqual(
            AgentContract.parseQueueTarget(id: .text(" trk_a "), uri: .absent),
            .success(.track("trk_a"))
        )
        let file = AgentContract.parseQueueTarget(id: .absent, uri: .text("file:///tmp/a.mp3"))
        guard case .success(.file(let url)) = file else {
            return XCTFail("expected file url, got \(file)")
        }
        XCTAssertEqual(url.path, "/tmp/a.mp3")

        XCTAssertEqual(AgentContract.parseQueuePosition(.absent), .success(.end))
        XCTAssertEqual(AgentContract.parseQueuePosition(.text("next")), .success(.next))
        XCTAssertEqual(AgentContract.parseQueuePosition(.text("end")), .success(.end))
        XCTAssertEqual(
            AgentContract.parseQueuePosition(.invalid),
            .failure(.badRequest(AgentCopy.badQueuePosition))
        )
        XCTAssertEqual(
            AgentContract.parseQueuePosition(.text("")),
            .failure(.badRequest(AgentCopy.badQueuePosition))
        )
        XCTAssertEqual(
            AgentContract.parseQueuePosition(.text(" end ")),
            .failure(.badRequest(AgentCopy.badQueuePosition))
        )
        XCTAssertEqual(
            AgentContract.parseQueuePosition(.text("End")),
            .failure(.badRequest(AgentCopy.badQueuePosition))
        )
    }

    func testResumePlanDoesNotPause() {
        XCTAssertEqual(
            AgentContract.resumePlan(hasCurrent: false, playing: false, positionMs: 0, durationMs: 0),
            .notReady
        )
        XCTAssertEqual(
            AgentContract.resumePlan(hasCurrent: true, playing: true, positionMs: 10, durationMs: 100),
            .stay
        )
        XCTAssertEqual(
            AgentContract.resumePlan(hasCurrent: true, playing: false, positionMs: 10, durationMs: 100),
            .resume
        )
        XCTAssertEqual(
            AgentContract.resumePlan(hasCurrent: true, playing: false, positionMs: 100, durationMs: 100),
            .restartFromEnd
        )
    }

    func testSearchMatchesDisplayLabelsAndCapsLimit() {
        XCTAssertTrue(LibrarySearch.matches(query: " 未知艺人 ", title: "歌", artist: "未知艺人", album: "专辑"))
        XCTAssertFalse(LibrarySearch.matches(query: "   ", title: "歌", artist: "甲", album: "乙"))
        XCTAssertEqual(try LibrarySearch.parseLimit(nil).get(), 20)
        XCTAssertEqual(try LibrarySearch.parseLimit(100).get(), 100)
        XCTAssertEqual(try LibrarySearch.parseLimit(101).get(), 100)
        XCTAssertEqual(try LibrarySearch.parseLimit(20.9).get(), 20)
        XCTAssertThrowsError(try LibrarySearch.parseLimit(0).get())
        XCTAssertThrowsError(try LibrarySearch.parseLimit(-1).get())
    }

    func testBridgeTick() {
        XCTAssertEqual(
            AgentContract.bridgeTick(socketConnected: true, processAlive: false, launched: false, budgetExhausted: false),
            .connected
        )
        XCTAssertEqual(
            AgentContract.bridgeTick(socketConnected: false, processAlive: false, launched: false, budgetExhausted: false),
            .launch
        )
        XCTAssertEqual(
            AgentContract.bridgeTick(socketConnected: false, processAlive: true, launched: false, budgetExhausted: false),
            .waiting
        )
        XCTAssertEqual(
            AgentContract.bridgeTick(socketConnected: false, processAlive: false, launched: true, budgetExhausted: false),
            .waiting
        )
        XCTAssertEqual(
            AgentContract.bridgeTick(socketConnected: false, processAlive: true, launched: true, budgetExhausted: true),
            .fail(AgentCopy.notListening)
        )
        XCTAssertEqual(
            AgentContract.bridgeTick(socketConnected: false, processAlive: false, launched: true, budgetExhausted: true),
            .fail(AgentCopy.launchFailed)
        )
    }

    func testTrackJSONWritesNullIDAndOmitsMissingFalse() throws {
        let oneShot = AgentTrack(
            id: nil,
            path: "/tmp/a.mp3",
            uri: "file:///tmp/a.mp3",
            title: "a.mp3",
            artist: "",
            album: "",
            durationMs: 0,
            missing: false
        )
        let data = try JSONSerialization.data(withJSONObject: oneShot.jsonObject())
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertTrue(object["id"] is NSNull)
        XCTAssertNil(object["missing"])
        XCTAssertEqual(object["uri"] as? String, "file:///tmp/a.mp3")
        XCTAssertEqual(object["path"] as? String, "/tmp/a.mp3")

        let missing = AgentTrack(
            id: "trk_a",
            path: "/tmp/a.mp3",
            uri: "file:///tmp/a.mp3",
            title: "歌",
            artist: "",
            album: "",
            durationMs: 1,
            missing: true
        )
        XCTAssertEqual(missing.jsonObject()["missing"] as? Bool, true)
    }

    func testStatusOmitsMessageUntilThereIsOne() throws {
        let body = AgentStatusBody(
            track: nil,
            playing: false,
            positionMs: 0,
            durationMs: 0,
            shuffle: false,
            repeatMode: "off",
            volume: 1,
            queueLength: 0
        )
        let data = try JSONSerialization.data(withJSONObject: body.jsonObject())
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["ok"] as? Bool, true)
        XCTAssertTrue(object["track"] is NSNull)
        XCTAssertNil(object["message"])
        XCTAssertEqual(object["repeat"] as? String, "off")
    }
}
