import Foundation

public enum HTTPAction: Equatable, Sendable {
    case health
    case status
    case pause
    case toggle
    case next
    case previous
    case seek(Int)
    case shuffle(Bool)
    case repeatMode(RepeatMode)
    case play(PlayRequest)
    case search(query: String, limit: Int)
    case queueList
    case queueAdd(QueueAddTarget, QueueAddPosition)
    case queueClear
}

public struct HTTPResponse: Equatable, Sendable {
    public var status: Int
    public var reason: String
    public var jsonText: String

    public init(status: Int, reason: String, jsonText: String) {
        self.status = status
        self.reason = reason
        self.jsonText = jsonText
    }

    public func encoded() -> Data {
        let body = Data(jsonText.utf8)
        let head = """
        HTTP/1.1 \(status) \(reason)\r
        Content-Type: application/json; charset=utf-8\r
        Content-Length: \(body.count)\r
        Connection: close\r
        \r

        """
        var data = Data(head.utf8)
        data.append(body)
        return data
    }
}

public enum HTTPClassification: Equatable, Sendable {
    case action(HTTPAction)
    case response(HTTPResponse)
}

/// How many body bytes the server must read before classification. GET and DELETE never read a body.
public enum HTTPBodyPlan: Equatable, Sendable {
    case ignore
    case read(Int)
    case reject(HTTPResponse)
}

/// Loopback HTTP request rules. The socket loop lives in the app.
public enum HTTPContract {
    public static let port = 17890
    public static let baseURL = "http://127.0.0.1:\(port)"
    public static let maxBodyBytes = 64 * 1024
    /// Same ceiling as one MCP line.
    public static let maxHeaderBytes = 1 << 20

    public static let methodNotAllowed = "方法不允许"
    public static let unknownRoute = "没有这个接口"
    public static let bodyMustBeObject = "请求必须是 JSON 对象"
    public static let invalidJSON = "请求不是合法的 JSON"
    public static let bodyTooLarge = "请求过大"
    public static let chunkedUnsupported = "不支持分块传输"
    public static let badContentLength = "Content-Length 不合法"
    public static let unreadable = "请求无法解析"
    public static let portInUse = "端口 17890 已被占用"
    public static let listenFailed = "无法开启本地 HTTP"
    public static let copied = "已复制"
    public static let copyFailed = "无法复制"

    public static func malformedRequest() -> HTTPResponse {
        message(status: 400, error: PlaybackErrorCode.badRequest, text: unreadable)
    }

    public static func headerOverflow() -> HTTPResponse {
        message(status: 400, error: PlaybackErrorCode.badRequest, text: bodyTooLarge)
    }

    public static func shortBody() -> HTTPResponse {
        message(status: 400, error: PlaybackErrorCode.badRequest, text: invalidJSON)
    }

    public static func libraryBlocked(_ messageText: String) -> HTTPResponse {
        message(status: 409, error: PlaybackErrorCode.notReady, text: messageText)
    }

    public static func health() -> HTTPResponse {
        success(["ok": true, "version": AgentCopy.productVersion])
    }

    public static func success(_ object: [String: Any]) -> HTTPResponse {
        HTTPResponse(status: 200, reason: "OK", jsonText: AgentJSON.text(object))
    }

    public static func failure(_ failure: AgentFailure) -> HTTPResponse {
        message(status: statusCode(for: failure.error), error: failure.error, text: failure.message)
    }

    public static func statusCode(for error: String) -> Int {
        switch error {
        case PlaybackErrorCode.badRequest:
            return 400
        case PlaybackErrorCode.notFound, PlaybackErrorCode.missingFile:
            return 404
        case PlaybackErrorCode.unsupportedFormat:
            return 415
        case PlaybackErrorCode.notReady:
            return 409
        default:
            return 500
        }
    }

    /// Decide the body before reading it. A rejected plan is already a full response.
    public static func bodyPlan(for headerBlock: String) -> HTTPBodyPlan {
        switch parseHead(headerBlock) {
        case .failure(let response):
            return .reject(response)
        case .success(let head):
            guard head.method == "POST" else { return .ignore }
            if let rejected = rejectedTransfer(head.headers) { return .reject(rejected) }
            switch contentLength(head.headers) {
            case .failure(let response):
                return .reject(response)
            case .success(let length):
                return .read(length)
            }
        }
    }

    public static func classify(headerBlock: String, body: Data) -> HTTPClassification {
        switch parseHead(headerBlock) {
        case .failure(let response):
            return .response(response)
        case .success(let head):
            return classify(head, body: body)
        }
    }

    private struct Head {
        var method: String
        var target: String
        var headers: [(String, String)]
    }

    private enum OrReject<Value> {
        case success(Value)
        case failure(HTTPResponse)
    }

    private static func classify(_ head: Head, body: Data) -> HTTPClassification {
        let target = head.target
        guard target.hasPrefix("/") else {
            return .response(message(status: 404, error: PlaybackErrorCode.notFound, text: unknownRoute))
        }
        guard let parts = splitTarget(target) else {
            return .response(message(status: 400, error: PlaybackErrorCode.badRequest, text: unreadable))
        }
        guard let methods = routes[parts.path] else {
            return .response(message(status: 404, error: PlaybackErrorCode.notFound, text: unknownRoute))
        }
        guard methods.contains(head.method) else {
            return .response(message(status: 405, error: PlaybackErrorCode.badRequest, text: methodNotAllowed))
        }
        switch (head.method, parts.path) {
        case ("GET", "/health"):
            return .action(.health)
        case ("GET", "/status"):
            return .action(.status)
        case ("POST", "/pause"):
            return emptyOrObject(body, .pause)
        case ("POST", "/toggle"):
            return emptyOrObject(body, .toggle)
        case ("POST", "/next"):
            return emptyOrObject(body, .next)
        case ("POST", "/previous"):
            return emptyOrObject(body, .previous)
        case ("POST", "/queue"):
            return queueAdd(body)
        case ("DELETE", "/queue"):
            return .action(.queueClear)
        case ("GET", "/queue"):
            return .action(.queueList)
        case ("GET", "/library/search"):
            return search(parts.query)
        case ("POST", "/seek"):
            return seek(body)
        case ("POST", "/shuffle"):
            return shuffle(body)
        case ("POST", "/repeat"):
            return repeatMode(body)
        case ("POST", "/play"):
            return play(body)
        default:
            return .response(message(status: 404, error: PlaybackErrorCode.notFound, text: unknownRoute))
        }
    }

    private static let routes: [String: Set<String>] = [
        "/health": ["GET"],
        "/status": ["GET"],
        "/play": ["POST"],
        "/pause": ["POST"],
        "/toggle": ["POST"],
        "/next": ["POST"],
        "/previous": ["POST"],
        "/seek": ["POST"],
        "/shuffle": ["POST"],
        "/repeat": ["POST"],
        "/library/search": ["GET"],
        "/queue": ["GET", "POST", "DELETE"],
    ]

    private static func parseHead(_ headerBlock: String) -> OrReject<Head> {
        if headerBlock.replacingOccurrences(of: "\r\n", with: "").contains("\n") {
            return .failure(message(status: 400, error: PlaybackErrorCode.badRequest, text: unreadable))
        }
        let lines = headerBlock.split(separator: "\r\n", omittingEmptySubsequences: false).map(String.init)
        guard let request = lines.first, !request.isEmpty else {
            return .failure(message(status: 400, error: PlaybackErrorCode.badRequest, text: unreadable))
        }
        let parts = request.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3, !parts[0].isEmpty, !parts[1].isEmpty else {
            return .failure(message(status: 400, error: PlaybackErrorCode.badRequest, text: unreadable))
        }
        guard parts[2] == "HTTP/1.0" || parts[2] == "HTTP/1.1" else {
            return .failure(message(status: 400, error: PlaybackErrorCode.badRequest, text: unreadable))
        }
        var headers: [(String, String)] = []
        for line in lines.dropFirst() {
            if line.isEmpty { continue }
            if line.first == " " || line.first == "\t" {
                return .failure(message(status: 400, error: PlaybackErrorCode.badRequest, text: unreadable))
            }
            guard let colon = line.firstIndex(of: ":") else {
                return .failure(message(status: 400, error: PlaybackErrorCode.badRequest, text: unreadable))
            }
            let name = String(line[..<colon])
            guard !name.isEmpty, !name.contains(" ") else {
                return .failure(message(status: 400, error: PlaybackErrorCode.badRequest, text: unreadable))
            }
            let rawValue = line[line.index(after: colon)...]
            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            headers.append((name, value))
        }
        return .success(Head(method: parts[0], target: parts[1], headers: headers))
    }

    private static func rejectedTransfer(_ headers: [(String, String)]) -> HTTPResponse? {
        let values = headerValues(headers, "transfer-encoding")
        guard !values.isEmpty else { return nil }
        let identity = values.allSatisfy(isIdentity)
        guard identity else {
            return message(status: 400, error: PlaybackErrorCode.badRequest, text: chunkedUnsupported)
        }
        return nil
    }

    private static func isIdentity(_ value: String) -> Bool {
        let tokens = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !tokens.isEmpty, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return tokens.allSatisfy { token in
            let coding = token.split(separator: ";").first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return coding == "identity"
        }
    }

    private enum LengthRead {
        case success(Int)
        case failure(HTTPResponse)
    }

    /// Missing Content-Length is an empty body. More than one, or a value that is not digits, is rejected.
    private static func contentLength(_ headers: [(String, String)]) -> LengthRead {
        let values = headerValues(headers, "content-length")
        if values.isEmpty { return .success(0) }
        guard values.count == 1, let length = nonNegativeInteger(values[0]) else {
            return .failure(message(status: 400, error: PlaybackErrorCode.badRequest, text: badContentLength))
        }
        if length > maxBodyBytes {
            return .failure(message(status: 400, error: PlaybackErrorCode.badRequest, text: bodyTooLarge))
        }
        return .success(length)
    }

    private static func nonNegativeInteger(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.unicodeScalars.allSatisfy({ ("0"..."9").contains(Character($0)) }) else { return nil }
        return Int(trimmed)
    }

    private static func headerValues(_ headers: [(String, String)], _ name: String) -> [String] {
        headers.compactMap { header in
            header.0.lowercased() == name ? header.1 : nil
        }
    }

    private static func splitTarget(_ target: String) -> (path: String, query: [URLQueryItem])? {
        guard target.hasPrefix("/") else { return nil }
        guard let components = URLComponents(string: "http://127.0.0.1" + target) else { return nil }
        return (components.path, components.queryItems ?? [])
    }

    private static func emptyOrObject(_ body: Data, _ action: HTTPAction) -> HTTPClassification {
        switch jsonObject(body) {
        case .failure(let response):
            return .response(response)
        case .success:
            return .action(action)
        }
    }

    private static func play(_ body: Data) -> HTTPClassification {
        switch jsonObject(body) {
        case .failure(let response):
            return .response(response)
        case .success(let object):
            switch playRequest(object) {
            case .failure(let failure):
                return .response(HTTPContract.failure(failure))
            case .success(let request):
                return .action(.play(request))
            }
        }
    }

    private static func queueAdd(_ body: Data) -> HTTPClassification {
        switch jsonObject(body) {
        case .failure(let response):
            return .response(response)
        case .success(let object):
            let id: PlayField
            let uri: PlayField
            switch AgentJSONFields.playField(object, "id") {
            case .failure(let failure): return .response(HTTPContract.failure(failure))
            case .success(let field): id = field
            }
            switch AgentJSONFields.playField(object, "uri") {
            case .failure(let failure): return .response(HTTPContract.failure(failure))
            case .success(let field): uri = field
            }
            let target: QueueAddTarget
            switch AgentContract.parseQueueTarget(id: id, uri: uri) {
            case .failure(let failure): return .response(HTTPContract.failure(failure))
            case .success(let value): target = value
            }
            switch AgentContract.parseQueuePosition(AgentJSONFields.suppliedText(object, "position")) {
            case .failure(let failure): return .response(HTTPContract.failure(failure))
            case .success(let position): return .action(.queueAdd(target, position))
            }
        }
    }

    private static func seek(_ body: Data) -> HTTPClassification {
        switch jsonObject(body) {
        case .failure(let response):
            return .response(response)
        case .success(let object):
            guard let raw = object["positionMs"] else {
                return .response(failure(.badRequest(AgentCopy.needPosition)))
            }
            guard let number = AgentJSONFields.number(raw), let ms = AgentJSONFields.int(number) else {
                return .response(failure(.badRequest(AgentCopy.positionType)))
            }
            return .action(.seek(ms))
        }
    }

    private static func shuffle(_ body: Data) -> HTTPClassification {
        switch jsonObject(body) {
        case .failure(let response):
            return .response(response)
        case .success(let object):
            guard let enabled = AgentJSONFields.bool(object["enabled"]) else {
                return .response(failure(.badRequest(AgentCopy.needEnabled)))
            }
            return .action(.shuffle(enabled))
        }
    }

    private static func repeatMode(_ body: Data) -> HTTPClassification {
        switch jsonObject(body) {
        case .failure(let response):
            return .response(response)
        case .success(let object):
            guard let raw = object["mode"] as? String, let mode = RepeatMode(rawValue: raw) else {
                return .response(failure(.badRequest(AgentCopy.badMode)))
            }
            return .action(.repeatMode(mode))
        }
    }

    private static func search(_ query: [URLQueryItem]) -> HTTPClassification {
        guard let text = first(query, "q"),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return .response(failure(.badRequest(AgentCopy.needQ)))
        }
        let limit: Int
        if let raw = first(query, "limit") {
            guard let number = Double(raw) else {
                return .response(failure(.badRequest(AgentCopy.limitType)))
            }
            switch LibrarySearch.parseLimit(number) {
            case .failure(let failure):
                return .response(HTTPContract.failure(failure))
            case .success(let value):
                limit = value
            }
        } else {
            limit = LibrarySearch.defaultLimit
        }
        return .action(.search(query: text, limit: limit))
    }

    private static func first(_ items: [URLQueryItem], _ name: String) -> String? {
        items.first { $0.name == name }?.value
    }

    private static func playRequest(_ object: [String: Any]) -> Result<PlayRequest, AgentFailure> {
        let id: PlayField
        let uri: PlayField
        switch AgentJSONFields.playField(object, "id") {
        case .failure(let failure): return .failure(failure)
        case .success(let field): id = field
        }
        switch AgentJSONFields.playField(object, "uri") {
        case .failure(let failure): return .failure(failure)
        case .success(let field): uri = field
        }
        return AgentContract.parsePlay(id: id, uri: uri)
    }

    private static func jsonObject(_ data: Data) -> OrReject<[String: Any]> {
        if data.isEmpty { return .success([:]) }
        guard let parsed = try? JSONSerialization.jsonObject(with: data) else {
            return .failure(message(status: 400, error: PlaybackErrorCode.badRequest, text: invalidJSON))
        }
        guard let object = parsed as? [String: Any] else {
            return .failure(message(status: 400, error: PlaybackErrorCode.badRequest, text: bodyMustBeObject))
        }
        return .success(object)
    }

    private static func message(status: Int, error: String, text: String) -> HTTPResponse {
        let body = AgentFailure(error: error, message: text).jsonObject()
        return HTTPResponse(status: status, reason: reason(status), jsonText: AgentJSON.text(body))
    }

    private static func reason(_ status: Int) -> String {
        switch status {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 409: return "Conflict"
        case 415: return "Unsupported Media Type"
        default: return "Internal Server Error"
        }
    }
}
