import XCTest
import LyriaCore

final class HTTPContractTests: XCTestCase {
    func testHealthVersionMatchesTheProduct() throws {
        XCTAssertEqual(action(classify("GET", "/health")), .health)
        let response = HTTPContract.health()
        XCTAssertEqual(response.status, 200)
        let object = try json(response)
        XCTAssertEqual(object["ok"] as? Bool, true)
        XCTAssertEqual(object["version"] as? String, AgentCopy.productVersion)
        let encoded = String(data: response.encoded(), encoding: .utf8)
        XCTAssertTrue(encoded?.hasPrefix("HTTP/1.1 200 OK\r\n") == true)
        XCTAssertTrue(encoded?.contains("Content-Type: application/json; charset=utf-8\r\n") == true)
        XCTAssertTrue(encoded?.contains("Connection: close\r\n") == true)
    }

    func testRoutesRejectTheWrongMethodAndUnknownPaths() throws {
        let wrongMethod = try fields(response(classify("POST", "/health")))
        XCTAssertEqual(wrongMethod.status, 405)
        XCTAssertEqual(wrongMethod.error, PlaybackErrorCode.badRequest)
        XCTAssertEqual(wrongMethod.message, HTTPContract.methodNotAllowed)

        let missing = try fields(response(classify("GET", "/nope")))
        XCTAssertEqual(missing.status, 404)
        XCTAssertEqual(missing.error, PlaybackErrorCode.notFound)
        XCTAssertEqual(missing.message, HTTPContract.unknownRoute)

        let slash = try fields(response(classify("GET", "/status/")))
        XCTAssertEqual(slash.status, 404)
        XCTAssertEqual(slash.message, HTTPContract.unknownRoute)

        let absolute = try fields(response(classify("GET", "http://127.0.0.1:17890/status")))
        XCTAssertEqual(absolute.status, 404)
        XCTAssertEqual(absolute.message, HTTPContract.unknownRoute)
    }

    func testUnreadableRequestLine() throws {
        let response = HTTPContract.classify(headerBlock: "GET /health HTTP/2.0", body: Data())
        let fields = try fields(self.response(response))
        XCTAssertEqual(fields.status, 400)
        XCTAssertEqual(fields.message, HTTPContract.unreadable)
    }

    func testPlayBodyUsesTheSameXORRules() throws {
        XCTAssertEqual(action(classify("POST", "/play", body: "{}")), .play(.resume))
        XCTAssertEqual(action(classify("POST", "/play", body: "")), .play(.resume))
        let both = try fields(response(classify(
            "POST",
            "/play?id=trk_from_query",
            body: #"{"id":"trk_body","uri":"file:///tmp/a.mp3"}"#
        )))
        XCTAssertEqual(both.status, 400)
        XCTAssertEqual(both.message, AgentCopy.idAndURI)
        let typed = try fields(response(classify("POST", "/play", body: #"{"id":1}"#)))
        XCTAssertEqual(typed.message, AgentCopy.idType)
        XCTAssertEqual(
            action(classify("POST", "/pause", body: #"{"ignored":true}"#)),
            .pause
        )
        let list = try fields(response(classify("POST", "/pause", body: "[]")))
        XCTAssertEqual(list.message, HTTPContract.bodyMustBeObject)
        let broken = try fields(response(classify("POST", "/next", body: "{")))
        XCTAssertEqual(broken.message, HTTPContract.invalidJSON)
    }

    func testSearchQueryKeepsPlusAndTheFirstValue() throws {
        XCTAssertEqual(
            action(classify("GET", "/library/search?q=a+b&q=two&limit=20.9&limit=9")),
            .search(query: "a+b", limit: 20)
        )
        XCTAssertEqual(
            action(classify("GET", "/library/search?q=song&limit=1e2")),
            .search(query: "song", limit: 100)
        )
        let blank = try fields(response(classify("GET", "/library/search?q=%20")))
        XCTAssertEqual(blank.message, AgentCopy.needQ)
        let zero = try fields(response(classify("GET", "/library/search?q=song&limit=0")))
        XCTAssertEqual(zero.message, AgentCopy.limitType)
        let missing = try fields(response(classify("GET", "/library/search")))
        XCTAssertEqual(missing.message, AgentCopy.needQ)
    }

    func testQueueAndTransportBodies() throws {
        XCTAssertEqual(
            action(classify("POST", "/queue", body: #"{"id":"trk_a"}"#)),
            .queueAdd(.track("trk_a"), .end)
        )
        XCTAssertEqual(
            action(classify("POST", "/queue", body: #"{"uri":"file:///tmp/a.mp3","position":"next"}"#)),
            .queueAdd(.file(URL(string: "file:///tmp/a.mp3")!), .next)
        )
        let badPosition = try fields(response(classify("POST", "/queue", body: #"{"id":"trk_a","position":null}"#)))
        XCTAssertEqual(badPosition.message, AgentCopy.badQueuePosition)
        XCTAssertEqual(action(classify("POST", "/seek", body: #"{"positionMs":1500.9}"#)), .seek(1500))
        XCTAssertEqual(action(classify("POST", "/shuffle", body: #"{"enabled":true}"#)), .shuffle(true))
        let number = try fields(response(classify("POST", "/shuffle", body: #"{"enabled":1}"#)))
        XCTAssertEqual(number.message, AgentCopy.needEnabled)
        XCTAssertEqual(action(classify("POST", "/repeat", body: #"{"mode":"all"}"#)), .repeatMode(.all))
        XCTAssertEqual(action(classify("DELETE", "/queue")), .queueClear)
        XCTAssertEqual(action(classify("GET", "/queue")), .queueList)
        XCTAssertEqual(action(classify("GET", "/status")), .status)
    }

    func testBodyPlanRejectsChunkedAndOversizedLengths() throws {
        XCTAssertEqual(plan("GET", "/status", headers: ["Transfer-Encoding: chunked"]), .ignore)
        let chunked = try rejected(plan("POST", "/pause", headers: ["Transfer-Encoding: chunked"]))
        XCTAssertEqual(chunked.message, HTTPContract.chunkedUnsupported)
        let bad = try rejected(plan("POST", "/pause", headers: ["Content-Length: -1"]))
        XCTAssertEqual(bad.message, HTTPContract.badContentLength)
        let twice = try rejected(plan("POST", "/pause", headers: ["Content-Length: 1", "Content-Length: 2"]))
        XCTAssertEqual(twice.message, HTTPContract.badContentLength)
        let huge = try rejected(plan("POST", "/pause", headers: ["Content-Length: 65537"]))
        XCTAssertEqual(huge.message, HTTPContract.bodyTooLarge)
        XCTAssertEqual(plan("POST", "/pause", headers: ["Transfer-Encoding: identity"]), .read(0))
        XCTAssertEqual(plan("POST", "/pause", headers: ["Content-Length: 4"]), .read(4))
        XCTAssertEqual(HTTPContract.maxHeaderBytes, 1 << 20)
        XCTAssertEqual(HTTPContract.maxBodyBytes, 64 * 1024)
        XCTAssertEqual(HTTPContract.baseURL, "http://127.0.0.1:17890")
    }

    func testErrorStatusCodes() {
        XCTAssertEqual(HTTPContract.statusCode(for: PlaybackErrorCode.badRequest), 400)
        XCTAssertEqual(HTTPContract.statusCode(for: PlaybackErrorCode.notFound), 404)
        XCTAssertEqual(HTTPContract.statusCode(for: PlaybackErrorCode.missingFile), 404)
        XCTAssertEqual(HTTPContract.statusCode(for: PlaybackErrorCode.unsupportedFormat), 415)
        XCTAssertEqual(HTTPContract.statusCode(for: PlaybackErrorCode.notReady), 409)
        XCTAssertEqual(HTTPContract.statusCode(for: PlaybackErrorCode.failed), 500)
        XCTAssertEqual(HTTPContract.libraryBlocked(AgentCopy.databaseFailed).status, 409)
        XCTAssertEqual(HTTPContract.shortBody().jsonText.contains(HTTPContract.invalidJSON), true)
        XCTAssertEqual(HTTPContract.headerOverflow().jsonText.contains(HTTPContract.bodyTooLarge), true)
    }

    private func classify(_ method: String, _ target: String, headers: [String] = [], body: String = "") -> HTTPClassification {
        var lines = ["\(method) \(target) HTTP/1.1"]
        if !body.isEmpty && !headers.contains(where: { $0.lowercased().hasPrefix("content-length") }) {
            lines.append("Content-Length: \(Data(body.utf8).count)")
        }
        lines.append(contentsOf: headers)
        return HTTPContract.classify(headerBlock: lines.joined(separator: "\r\n"), body: Data(body.utf8))
    }

    private func plan(_ method: String, _ target: String, headers: [String] = []) -> HTTPBodyPlan {
        let lines = ["\(method) \(target) HTTP/1.1"] + headers
        return HTTPContract.bodyPlan(for: lines.joined(separator: "\r\n"))
    }

    private func action(_ classification: HTTPClassification) -> HTTPAction? {
        if case .action(let action) = classification { return action }
        return nil
    }

    private func response(_ classification: HTTPClassification) throws -> HTTPResponse {
        guard case .response(let response) = classification else {
            XCTFail("expected a response, got \(classification)")
            throw TestError.notAResponse
        }
        return response
    }

    private func rejected(_ plan: HTTPBodyPlan) throws -> HTTPFields {
        guard case .reject(let response) = plan else {
            XCTFail("expected a rejection, got \(plan)")
            throw TestError.notAResponse
        }
        return try fields(response)
    }

    private func fields(_ response: HTTPResponse) throws -> HTTPFields {
        let object = try json(response)
        return HTTPFields(
            status: response.status,
            error: object["error"] as? String ?? "",
            message: object["message"] as? String ?? ""
        )
    }

    private func json(_ response: HTTPResponse) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(response.jsonText.utf8)) as? [String: Any])
    }
}

private struct HTTPFields {
    var status: Int
    var error: String
    var message: String
}

private enum TestError: Error {
    case notAResponse
}
