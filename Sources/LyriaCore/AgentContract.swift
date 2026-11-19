import Foundation

public enum AgentCopy {
    public static let productVersion = "0.1.0"
    public static let notFound = "曲库里没有这首"
    public static let notReady = "没有正在播放的曲目"
    public static let databaseFailed = "曲库数据库打开失败"
    public static let notListening = "Lyria 正在运行，但 MCP 没有在监听"
    public static let launchFailed = "无法启动 Lyria"
    public static let idAndURI = "id 和 uri 只能填一个"
    public static let emptyID = "id 不能为空"
    public static let emptyURI = "uri 不能为空"
    public static let needQ = "需要 q"
    public static let needPosition = "需要 positionMs"
    public static let positionType = "positionMs 必须是数字"
    public static let fileURI = "uri 必须是 file://"
    public static let needEnabled = "需要 enabled"
    public static let badMode = "mode 必须是 off、all 或 one"
    public static let idType = "id 必须是字符串"
    public static let uriType = "uri 必须是字符串"
    public static let limitType = "limit 必须是数字"

    public static let toolNames = [
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
    ]

    public static let supportedProtocolVersions = ["2024-11-05", "2025-03-26", "2025-06-18"]

    public static func negotiatedProtocolVersion(_ requested: String?) -> String {
        if let requested, supportedProtocolVersions.contains(requested) { return requested }
        return "2025-06-18"
    }
}

public struct AgentFailure: Error, Equatable, Sendable {
    public var error: String
    public var message: String

    public init(error: String, message: String) {
        self.error = error
        self.message = message
    }

    public static func badRequest(_ message: String) -> AgentFailure {
        AgentFailure(error: PlaybackErrorCode.badRequest, message: message)
    }

    public func jsonObject() -> [String: Any] {
        ["ok": false, "error": error, "message": message]
    }
}

public enum PlayField: Equatable, Sendable {
    case absent
    case text(String)
}

public enum PlayRequest: Equatable, Sendable {
    case resume
    case track(String)
    case file(URL)
}

/// Continue playback. Unlike the transport button, an already-playing request stays playing.
public enum ResumePlan: Equatable, Sendable {
    case notReady
    case stay
    case resume
    case restartFromEnd
}

public enum BridgeTick: Equatable, Sendable {
    case connected
    case waiting
    case launch
    case fail(String)
}

public enum LibrarySearch {
    public static let defaultLimit = 20
    public static let maxLimit = 100

    public static func matches(query: String, title: String, artist: String, album: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return title.localizedCaseInsensitiveContains(trimmed)
            || artist.localizedCaseInsensitiveContains(trimmed)
            || album.localizedCaseInsensitiveContains(trimmed)
    }

    /// Missing limit uses the default. Values above the max are capped. Below 1 is rejected.
    public static func parseLimit(_ raw: Double?) -> Result<Int, AgentFailure> {
        guard let raw else { return .success(defaultLimit) }
        guard raw.isFinite else { return .failure(.badRequest(AgentCopy.limitType)) }
        let value = Int(raw.rounded(.towardZero))
        guard value >= 1 else { return .failure(.badRequest(AgentCopy.limitType)) }
        return .success(min(value, maxLimit))
    }
}

public enum AgentContract {
    public static func resumePlan(
        hasCurrent: Bool,
        playing: Bool,
        positionMs: Int,
        durationMs: Int
    ) -> ResumePlan {
        guard hasCurrent else { return .notReady }
        if playing { return .stay }
        if durationMs > 0, positionMs >= durationMs { return .restartFromEnd }
        return .resume
    }

    public static func parsePlay(id: PlayField, uri: PlayField) -> Result<PlayRequest, AgentFailure> {
        switch (id, uri) {
        case (.absent, .absent):
            return .success(.resume)
        case (.text(let rawID), .absent):
            let trimmed = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return .failure(.badRequest(AgentCopy.emptyID)) }
            return .success(.track(trimmed))
        case (.absent, .text(let rawURI)):
            let trimmed = rawURI.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return .failure(.badRequest(AgentCopy.emptyURI)) }
            guard let url = URL(string: trimmed), url.isFileURL, !url.path.isEmpty else {
                return .failure(.badRequest(AgentCopy.fileURI))
            }
            return .success(.file(url))
        case (.text, .text):
            return .failure(.badRequest(AgentCopy.idAndURI))
        }
    }

    /// Socket up means pump. A live process with no socket keeps waiting until the budget ends.
    /// A dead process is launched once. After the budget, a live process is "not listening".
    public static func bridgeTick(
        socketConnected: Bool,
        processAlive: Bool,
        launched: Bool,
        budgetExhausted: Bool
    ) -> BridgeTick {
        if socketConnected { return .connected }
        if !budgetExhausted {
            if !processAlive && !launched { return .launch }
            return .waiting
        }
        if processAlive { return .fail(AgentCopy.notListening) }
        return .fail(AgentCopy.launchFailed)
    }
}

public struct AgentTrack: Equatable, Sendable {
    public var id: String?
    public var path: String
    public var uri: String
    public var title: String
    public var artist: String
    public var album: String
    public var durationMs: Int
    public var missing: Bool

    public init(
        id: String?,
        path: String,
        uri: String,
        title: String,
        artist: String,
        album: String,
        durationMs: Int,
        missing: Bool
    ) {
        self.id = id
        self.path = path
        self.uri = uri
        self.title = title
        self.artist = artist
        self.album = album
        self.durationMs = durationMs
        self.missing = missing
    }

    public func jsonObject() -> [String: Any] {
        var object: [String: Any] = [
            "id": id.map { $0 as Any } ?? NSNull(),
            "path": path,
            "uri": uri,
            "title": title,
            "artist": artist,
            "album": album,
            "durationMs": durationMs,
        ]
        if missing { object["missing"] = true }
        return object
    }
}

public struct AgentStatusBody: Equatable, Sendable {
    public var track: AgentTrack?
    public var playing: Bool
    public var positionMs: Int
    public var durationMs: Int
    public var shuffle: Bool
    public var repeatMode: String
    public var volume: Double
    public var queueLength: Int
    public var message: String?

    public init(
        track: AgentTrack?,
        playing: Bool,
        positionMs: Int,
        durationMs: Int,
        shuffle: Bool,
        repeatMode: String,
        volume: Double,
        queueLength: Int,
        message: String? = nil
    ) {
        self.track = track
        self.playing = playing
        self.positionMs = positionMs
        self.durationMs = durationMs
        self.shuffle = shuffle
        self.repeatMode = repeatMode
        self.volume = volume
        self.queueLength = queueLength
        self.message = message
    }

    public func jsonObject() -> [String: Any] {
        var object: [String: Any] = [
            "ok": true,
            "track": track?.jsonObject() ?? NSNull(),
            "playing": playing,
            "positionMs": positionMs,
            "durationMs": durationMs,
            "shuffle": shuffle,
            "repeat": repeatMode,
            "volume": volume,
            "queueLength": queueLength,
        ]
        if let message { object["message"] = message }
        return object
    }
}

public enum AgentJSON {
    public static func text(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8)
        else { return #"{"ok":false,"error":"failed","message":"播放失败"}"# }
        return text
    }
}
