import Foundation
import LyriaCore

enum AgentReply {
    case success([String: Any])
    case failure(AgentFailure)
}

/// Playback and library commands shared by MCP and HTTP. The engine remains the only writer.
@MainActor
final class AgentCommands {
    private let engine: PlaybackEngine
    private weak var session: AppSession?

    init(engine: PlaybackEngine) {
        self.engine = engine
    }

    func bind(_ session: AppSession) {
        self.session = session
    }

    func execute(_ action: HTTPAction) async -> AgentReply {
        switch action {
        case .health:
            return .success(["ok": true, "version": AgentCopy.productVersion])
        case .status:
            return await statusReply()
        case .pause:
            return await playback(engine.agentPause())
        case .toggle:
            return await playback(engine.agentToggle())
        case .next:
            return await playback(engine.agentNext())
        case .previous:
            return await playback(engine.agentPrevious())
        case .seek(let ms):
            return await playback(engine.agentSeek(ms: ms))
        case .shuffle(let enabled):
            return await playback(engine.agentSetShuffle(enabled))
        case .repeatMode(let mode):
            return await playback(engine.agentSetRepeat(mode))
        case .play(let request):
            return await play(request)
        case .search(let query, let limit):
            return search(query: query, limit: limit)
        case .queueList:
            return await queueList()
        case .queueAdd(let target, let position):
            return await queueAdd(target, position: position)
        case .queueClear:
            return await playback(engine.agentQueueClear())
        }
    }

    /// `nil` means the tool name is not a product tool. MCP turns that into a protocol error.
    func executeTool(name: String, arguments: [String: Any]) async -> AgentReply? {
        switch name {
        case "lyria_status":
            return await statusReply()
        case "lyria_pause":
            return await playback(engine.agentPause())
        case "lyria_toggle":
            return await playback(engine.agentToggle())
        case "lyria_next":
            return await playback(engine.agentNext())
        case "lyria_previous":
            return await playback(engine.agentPrevious())
        case "lyria_seek":
            guard let raw = arguments["positionMs"] else {
                return .failure(.badRequest(AgentCopy.needPosition))
            }
            guard let number = AgentJSONFields.number(raw), let ms = AgentJSONFields.int(number) else {
                return .failure(.badRequest(AgentCopy.positionType))
            }
            return await playback(engine.agentSeek(ms: ms))
        case "lyria_shuffle":
            guard let enabled = AgentJSONFields.bool(arguments["enabled"]) else {
                return .failure(.badRequest(AgentCopy.needEnabled))
            }
            return await playback(engine.agentSetShuffle(enabled))
        case "lyria_repeat":
            guard let raw = arguments["mode"] as? String, let mode = RepeatMode(rawValue: raw) else {
                return .failure(.badRequest(AgentCopy.badMode))
            }
            return await playback(engine.agentSetRepeat(mode))
        case "lyria_play":
            return await play(arguments)
        case "lyria_search":
            return search(arguments)
        case "lyria_queue_list":
            return await queueList()
        case "lyria_queue_add":
            return await queueAdd(arguments)
        case "lyria_queue_clear":
            return await playback(engine.agentQueueClear())
        default:
            return nil
        }
    }

    private func play(_ arguments: [String: Any]) async -> AgentReply {
        let id: PlayField
        let uri: PlayField
        switch AgentJSONFields.playField(arguments, "id") {
        case .failure(let failure): return .failure(failure)
        case .success(let field): id = field
        }
        switch AgentJSONFields.playField(arguments, "uri") {
        case .failure(let failure): return .failure(failure)
        case .success(let field): uri = field
        }
        switch AgentContract.parsePlay(id: id, uri: uri) {
        case .failure(let failure):
            return .failure(failure)
        case .success(let request):
            return await play(request)
        }
    }

    private func play(_ request: PlayRequest) async -> AgentReply {
        switch request {
        case .resume:
            return await playback(engine.agentResume())
        case .track(let trackID):
            guard let session, session.track(trackID) != nil else {
                return .failure(AgentFailure(error: PlaybackErrorCode.notFound, message: AgentCopy.notFound))
            }
            let list = session.visibleTracks.map(ResolvedTrack.init)
            return await playback(engine.agentPlay(list: list, startID: trackID))
        case .file(let url):
            return await playback(engine.agentPlay(uri: url))
        }
    }

    private func queueAdd(_ arguments: [String: Any]) async -> AgentReply {
        let id: PlayField
        let uri: PlayField
        switch AgentJSONFields.playField(arguments, "id") {
        case .failure(let failure): return .failure(failure)
        case .success(let field): id = field
        }
        switch AgentJSONFields.playField(arguments, "uri") {
        case .failure(let failure): return .failure(failure)
        case .success(let field): uri = field
        }
        let target: QueueAddTarget
        switch AgentContract.parseQueueTarget(id: id, uri: uri) {
        case .failure(let failure): return .failure(failure)
        case .success(let value): target = value
        }
        let position: QueueAddPosition
        switch AgentContract.parseQueuePosition(AgentJSONFields.suppliedText(arguments, "position")) {
        case .failure(let failure): return .failure(failure)
        case .success(let value): position = value
        }
        return await queueAdd(target, position: position)
    }

    private func queueAdd(_ target: QueueAddTarget, position: QueueAddPosition) async -> AgentReply {
        switch target {
        case .track(let trackID):
            guard let track = session?.track(trackID) else {
                return .failure(AgentFailure(error: PlaybackErrorCode.notFound, message: AgentCopy.notFound))
            }
            return await playback(engine.agentQueueAdd(
                track: ResolvedTrack(track: track),
                item: .track(track.id),
                position: position
            ))
        case .file(let url):
            return await playback(engine.agentQueueAdd(uri: url, position: position))
        }
    }

    private func search(_ arguments: [String: Any]) -> AgentReply {
        guard let query = arguments["q"] as? String,
              !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return .failure(.badRequest(AgentCopy.needQ)) }
        let limit: Int
        if let raw = arguments["limit"] {
            guard let number = AgentJSONFields.number(raw) else {
                return .failure(.badRequest(AgentCopy.limitType))
            }
            switch LibrarySearch.parseLimit(number) {
            case .failure(let failure): return .failure(failure)
            case .success(let value): limit = value
            }
        } else {
            limit = LibrarySearch.defaultLimit
        }
        return search(query: query, limit: limit)
    }

    private func search(query: String, limit: Int) -> AgentReply {
        let tracks = session?.tracks ?? []
        let hits = tracks.filter {
            LibrarySearch.matches(query: query, title: $0.title, artist: $0.artistLabel, album: $0.albumLabel)
        }.prefix(limit)
        let objects = hits.map { libraryTrack($0).jsonObject() }
        return .success(["ok": true, "tracks": objects])
    }

    private func queueList() async -> AgentReply {
        let snapshot = await engine.agentSnapshot()
        let items = snapshot.rows.enumerated().map { index, row in
            track(row, snapshot: snapshot, isCurrent: snapshot.currentIndex == index).jsonObject()
        }
        return .success(["ok": true, "items": items])
    }

    private func statusReply() async -> AgentReply {
        let snapshot = await engine.agentSnapshot()
        return .success(status(snapshot, notice: nil).jsonObject())
    }

    private func playback(_ result: AgentCommandResult) -> AgentReply {
        if let code = result.errorCode {
            return .failure(AgentFailure(error: code, message: result.message ?? PlaybackCopy.failed))
        }
        return .success(status(result.snapshot, notice: result.notice).jsonObject())
    }

    private func status(_ snapshot: TransportSnapshot, notice: String?) -> AgentStatusBody {
        let track: AgentTrack?
        if snapshot.hasCurrent, let index = snapshot.currentIndex, snapshot.rows.indices.contains(index) {
            track = self.track(snapshot.rows[index], snapshot: snapshot, isCurrent: true)
        } else {
            track = nil
        }
        return AgentStatusBody(
            track: track,
            playing: snapshot.playing,
            positionMs: snapshot.positionMs,
            durationMs: snapshot.durationMs,
            shuffle: snapshot.shuffle,
            repeatMode: snapshot.repeatMode.rawValue,
            volume: snapshot.volume,
            queueLength: snapshot.queueCount,
            message: notice
        )
    }

    private func track(_ row: QueueRowSnapshot, snapshot: TransportSnapshot, isCurrent: Bool) -> AgentTrack {
        switch row.item {
        case .track(let id):
            if let track = session?.track(id) {
                return libraryTrack(track, missing: track.missing || row.missing)
            }
            return AgentTrack(
                id: id,
                path: "",
                uri: "",
                title: row.title,
                artist: row.artist,
                album: "",
                durationMs: 0,
                missing: true
            )
        case .oneShot(let uri):
            let url = URL(string: uri)
            return AgentTrack(
                id: nil,
                path: url?.path ?? "",
                uri: uri,
                title: row.title,
                artist: "",
                album: "",
                durationMs: isCurrent ? snapshot.durationMs : 0,
                missing: row.missing
            )
        }
    }

    private func libraryTrack(_ track: Track, missing: Bool? = nil) -> AgentTrack {
        AgentTrack(
            id: track.id,
            path: track.path,
            uri: URL(fileURLWithPath: track.path).absoluteString,
            title: track.title,
            artist: track.artist,
            album: track.album,
            durationMs: track.durationMs,
            missing: missing ?? track.missing
        )
    }
}
