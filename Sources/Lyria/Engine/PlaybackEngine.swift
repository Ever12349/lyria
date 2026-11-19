import AVFoundation
import Foundation
import LyriaCore
import UniformTypeIdentifiers

struct AgentCommandResult: Sendable {
    var snapshot: TransportSnapshot
    var errorCode: String?
    var message: String?
    var notice: String?
}

final class PlaybackSessionCache: @unchecked Sendable {
    private let lock = NSLock()
    private var session = PlaybackSession.empty
    private let persist: @Sendable (PlaybackSession) -> Void

    init(persist: @escaping @Sendable (PlaybackSession) -> Void) {
        self.persist = persist
    }

    func update(_ session: PlaybackSession, write: Bool) {
        lock.lock()
        self.session = session
        lock.unlock()
        if write { persist(session) }
    }

    func flush() {
        lock.lock()
        let session = self.session
        lock.unlock()
        persist(session)
    }
}

/// Serial playback writer. Views enqueue work here and only read `TransportState`.
actor PlaybackEngine {
    nonisolated let events: AsyncStream<EngineEvent>
    private let continuation: AsyncStream<EngineEvent>.Continuation
    private let host = PlayerHost()
    private var queue = PlaybackQueue()
    private var rng = SystemRandomNumberGenerator()
    private var catalog: [String: ResolvedTrack] = [:]
    private var volume = VolumeSession()
    private var playing = false
    private var positionMs = 0
    private var durationMs = 0
    private var generation = 0
    private var ignoreClock = false
    private var flacPlayable = false
    private var audioPrepared = false
    private var lastError: String?
    private var commandFailed = false
    private var commandNotice: String?
    private let persistPreferences: @Sendable (PlaybackPreferences) -> Void
    nonisolated let sessionCache: PlaybackSessionCache
    private var lastPositionPersist = Date.distantPast

    init(
        preferences: PlaybackPreferences = .default,
        persist: @escaping @Sendable (PlaybackPreferences) -> Void = { _ in },
        persistSession: @escaping @Sendable (PlaybackSession) -> Void = { _ in }
    ) {
        var continuation: AsyncStream<EngineEvent>.Continuation!
        let stream = AsyncStream<EngineEvent>(bufferingPolicy: .bufferingNewest(16)) { continuation = $0 }
        events = stream
        self.continuation = continuation
        self.persistPreferences = persist
        self.sessionCache = PlaybackSessionCache(persist: persistSession)
        queue = PlaybackQueue(shuffle: preferences.shuffle, repeatMode: preferences.repeatMode)
        volume = VolumeSession(level: preferences.volume, speakerMemory: preferences.speakerMemory)
        let level = volume.level
        host.install(owner: self)
        host.player.volume = Float(level)
    }

    private func writePreferences() {
        persistPreferences(
            PlaybackPreferences(
                shuffle: queue.shuffle,
                repeatMode: queue.repeatMode,
                volume: volume.level,
                speakerMemory: volume.speakerMemory
            )
        )
    }

    private func touchSession(write: Bool) {
        sessionCache.update(PlaybackSession(queue: queue, positionMs: positionMs), write: write)
        if write {
            lastPositionPersist = Date()
        }
    }

    /// Rebuild the queue without starting playback. Unplayable current stays put.
    func restore(_ session: PlaybackSession, tracks: [ResolvedTrack], shuffle: Bool, repeatMode: RepeatMode) async {
        remember(tracks)
        prepareAudio()
        let existing = Set(tracks.map(\.id))
        let adopted = session.adopted(existingIDs: existing, isPlayable: { self.blocker(forID: $0) == nil })
        queue = adopted.queue(shuffle: shuffle, repeatMode: repeatMode)
        playing = false
        lastError = nil
        guard let track = currentTrack() else {
            positionMs = 0
            durationMs = 0
            touchSession(write: true)
            publish()
            return
        }
        positionMs = adopted.positionMs
        durationMs = max(0, track.durationMs)
        if blocker(for: track) != nil {
            if durationMs > 0 {
                positionMs = min(positionMs, durationMs)
            }
            touchSession(write: true)
            publish()
            return
        }
        let token = nextGeneration()
        let loaded = await loadPaused(track, token: token, positionMs: adopted.positionMs)
        if !loaded {
            durationMs = max(0, track.durationMs)
            positionMs = durationMs > 0 ? min(adopted.positionMs, durationMs) : adopted.positionMs
            playing = false
        }
        touchSession(write: true)
        publish()
    }

    /// Shared play path: try the current item, then skip forward (wrapping) until something starts.
    func beginPlayback() async {
        prepareAudio()
        var rejected: Set<QueueItem> = []
        var skippedTotal = 0
        func isCandidate(_ item: QueueItem) -> Bool {
            if rejected.contains(item) { return false }
            return itemPlayable(item)
        }
        while true {
            switch PlaybackQueueRules.startPlayback(queue: queue, isPlayable: isCandidate) {
            case .stop(let next):
                queue = next
                host.player.pause()
                playing = false
                touchSession(write: true)
                publish()
                return
            case .play(let next, let skipped):
                queue = next
                skippedTotal += skipped
                guard let track = currentTrack() else {
                    host.player.pause()
                    playing = false
                    touchSession(write: true)
                    publish()
                    return
                }
                let token = nextGeneration()
                if await start(track, token: token) {
                    if skippedTotal > 0 {
                        announce(PlaybackCopy.skipped(skippedTotal))
                    }
                    touchSession(write: true)
                    publish()
                    return
                }
                if let current = queue.current {
                    rejected.insert(current)
                }
            }
        }
    }

    func play(list: [ResolvedTrack], startID: String, intent: RowPlayIntent) async {
        prepareAudio()
        remember(list)
        let block = list.first { $0.id == startID }.flatMap { blocker(for: $0) }
        switch PlaybackQueueRules.plan(
            intent: intent,
            trackID: startID,
            list: list.map(\.id),
            currentID: queue.current?.trackID,
            block: block,
            shuffle: queue.shuffle,
            repeatMode: queue.repeatMode,
            rng: &rng
        ) {
        case .refuse(let reason):
            refuse(reason)
        case .toggle:
            await applyPlayPause(restartAtEnd: false)
        case .restart:
            await restartCurrent()
        case .replace(let proposed):
            await commitAndPlay(proposed, tracks: list)
        }
    }

    func playAll(_ list: [ResolvedTrack]) async {
        prepareAudio()
        remember(list)
        guard let result = PlaybackQueueRules.playAll(
            ids: list.map(\.id),
            isPlayable: { self.blocker(forID: $0) == nil },
            shuffle: queue.shuffle,
            repeatMode: queue.repeatMode,
            rng: &rng
        ) else {
            announce(PlaybackCopy.nothingPlayable)
            return
        }
        guard await commitAndPlay(result.queue, tracks: list) else { return }
        if result.skipped > 0 {
            announce(PlaybackCopy.skipped(result.skipped))
        }
    }

    func playShuffled(_ list: [ResolvedTrack]) async {
        prepareAudio()
        remember(list)
        guard let result = PlaybackQueueRules.playShuffled(
            ids: list.map(\.id),
            isPlayable: { self.blocker(forID: $0) == nil },
            repeatMode: queue.repeatMode,
            rng: &rng
        ) else {
            announce(PlaybackCopy.nothingPlayable)
            return
        }
        guard await commitAndPlay(result.queue, tracks: list) else { return }
        if result.skipped > 0 {
            announce(PlaybackCopy.skipped(result.skipped))
        }
    }

    func playNext(_ list: [ResolvedTrack]) async {
        remember(list)
        queue = PlaybackQueueRules.playNext(ids: list.map(\.id), queue: queue)
        touchSession(write: true)
        publish()
    }

    func enqueue(_ list: [ResolvedTrack]) async {
        remember(list)
        let result = PlaybackQueueRules.enqueue(ids: list.map(\.id), queue: queue)
        if result.alreadyAllPresent {
            announce(PlaybackCopy.alreadyQueued)
            return
        }
        queue = result.queue
        touchSession(write: true)
        publish()
        emit(.showQueue)
    }

    func playQueueIndex(_ index: Int) async {
        guard queue.items.indices.contains(index) else { return }
        queue.currentIndex = index
        await beginPlayback()
    }

    func toggleTransport() async {
        await applyPlayPause(restartAtEnd: true)
    }

    func next() async {
        await step(PlaybackQueueRules.next(queue: queue, isPlayable: itemPlayable, rng: &rng))
    }

    func previous() async {
        await step(PlaybackQueueRules.previous(queue: queue, positionMs: positionMs, isPlayable: itemPlayable))
    }

    func toggleShuffle() {
        queue = PlaybackQueueRules.toggleShuffle(queue: queue, rng: &rng)
        writePreferences()
        touchSession(write: true)
        publish()
    }

    func toggleRepeat() {
        queue = PlaybackQueueRules.toggleRepeat(queue: queue)
        writePreferences()
        publish()
    }

    func seek(by deltaMs: Int) async {
        guard queue.current != nil else { return }
        await seek(to: positionMs + deltaMs)
    }

    func seek(to ms: Int) async {
        guard queue.current != nil else { return }
        let upper = max(durationMs, 0)
        let clamped = min(max(0, ms), upper)
        positionMs = clamped
        ignoreClock = true
        publish()
        let time = CMTime(seconds: Double(clamped) / 1000, preferredTimescale: 600)
        await host.seek(to: time)
        ignoreClock = false
        touchSession(write: true)
        publish()
    }

    func setVolume(_ value: Double) async {
        volume.setSlider(value)
        host.player.volume = Float(volume.level)
        writePreferences()
        continuation.yield(.volume(volume.level))
    }

    func toggleSpeaker() async {
        volume.toggleSpeaker()
        host.player.volume = Float(volume.level)
        writePreferences()
        continuation.yield(.volume(volume.level))
    }

    func removeFromQueue(_ ids: Set<String>) async {
        switch PlaybackQueueRules.remove(ids: ids, from: queue, isPlayable: itemPlayable) {
        case .kept(let next):
            queue = next
            touchSession(write: true)
            publish()
        case .stopped(let next):
            queue = next
            host.player.pause()
            playing = false
            positionMs = 0
            durationMs = 0
            touchSession(write: true)
            publish()
        case .play(let next, _):
            queue = next
            await beginPlayback()
        }
    }

    /// Later MCP/one-shot entry. No Open Panel in this slice.
    func play(uri: URL) async {
        prepareAudio()
        let path = uri.path
        let track = ResolvedTrack(
            id: uri.absoluteString,
            path: path,
            missing: false,
            title: uri.lastPathComponent,
            artist: "",
            artworkPath: nil
        )
        if let block = blocker(for: track) {
            refuse(block)
            return
        }
        catalog[track.id] = track
        let proposed = PlaybackQueue(
            items: [.oneShot(uri.absoluteString)],
            currentIndex: 0,
            shuffle: queue.shuffle,
            repeatMode: queue.repeatMode
        )
        queue = proposed
        await beginPlayback()
    }

    func agentSnapshot() -> TransportSnapshot {
        makeSnapshot()
    }

    func agentResume() async -> AgentCommandResult {
        switch AgentContract.resumePlan(
            hasCurrent: queue.current != nil,
            playing: playing,
            positionMs: positionMs,
            durationMs: durationMs
        ) {
        case .notReady:
            return notReadyResult()
        case .stay:
            return AgentCommandResult(snapshot: makeSnapshot(), errorCode: nil, message: nil, notice: nil)
        case .resume, .restartFromEnd:
            beginCommand()
            await applyPlayPause(restartAtEnd: true)
            return finishCommand()
        }
    }

    func agentPause() async -> AgentCommandResult {
        if playing {
            host.player.pause()
            playing = false
            touchSession(write: true)
            publish()
        }
        return AgentCommandResult(snapshot: makeSnapshot(), errorCode: nil, message: nil, notice: nil)
    }

    func agentToggle() async -> AgentCommandResult {
        guard queue.current != nil else { return notReadyResult() }
        beginCommand()
        await toggleTransport()
        return finishCommand()
    }

    func agentPlay(track: ResolvedTrack) async -> AgentCommandResult {
        beginCommand()
        await play(list: [track], startID: track.id, intent: .menuPlay)
        return finishCommand()
    }

    func agentPlay(uri: URL) async -> AgentCommandResult {
        beginCommand()
        await play(uri: uri)
        return finishCommand()
    }

    func agentNext() async -> AgentCommandResult {
        guard queue.current != nil else { return notReadyResult() }
        beginCommand()
        await next()
        return finishCommand()
    }

    func agentPrevious() async -> AgentCommandResult {
        guard queue.current != nil else { return notReadyResult() }
        beginCommand()
        await previous()
        return finishCommand()
    }

    func agentSeek(ms: Int) async -> AgentCommandResult {
        guard queue.current != nil else { return notReadyResult() }
        beginCommand()
        await seek(to: ms)
        return finishCommand()
    }

    func agentSetShuffle(_ enabled: Bool) async -> AgentCommandResult {
        let updated = PlaybackQueueRules.setShuffle(enabled: enabled, queue: queue, rng: &rng)
        if updated != queue {
            queue = updated
            writePreferences()
            touchSession(write: true)
            publish()
        }
        return AgentCommandResult(snapshot: makeSnapshot(), errorCode: nil, message: nil, notice: nil)
    }

    func agentSetRepeat(_ mode: RepeatMode) async -> AgentCommandResult {
        let updated = PlaybackQueueRules.setRepeat(mode: mode, queue: queue)
        if updated != queue {
            queue = updated
            writePreferences()
            publish()
        }
        return AgentCommandResult(snapshot: makeSnapshot(), errorCode: nil, message: nil, notice: nil)
    }

    func noteClock(_ ms: Int) {
        guard playing, !ignoreClock else { return }
        positionMs = max(0, ms)
        continuation.yield(.position(positionMs))
        if Date().timeIntervalSince(lastPositionPersist) >= 2 {
            touchSession(write: true)
        } else {
            touchSession(write: false)
        }
    }

    func noteEnded(token: Int) async {
        guard token == generation else { return }
        playing = false
        let move = PlaybackQueueRules.naturalEnd(queue: queue, isPlayable: itemPlayable, rng: &rng)
        switch move {
        case .start, .restart:
            await step(move)
        case .pauseAtEnd, .stay, .none:
            host.player.pause()
            if durationMs > 0 { positionMs = durationMs }
            touchSession(write: true)
            publish()
        }
    }

    func noteFailedMidPlay(token: Int) async {
        guard token == generation else { return }
        host.player.pause()
        playing = false
        announce(PlaybackCopy.failed)
        lastError = PlaybackErrorCode.failed
        await step(PlaybackQueueRules.advanceAfterFailure(queue: queue, isPlayable: itemPlayable))
        publish()
    }

    /// Adopts `proposed`, then starts playback through the shared skip path.
    private func commitAndPlay(_ proposed: PlaybackQueue, tracks: [ResolvedTrack]) async -> Bool {
        remember(tracks)
        queue = proposed
        await beginPlayback()
        return playing
    }

    private func step(_ move: PlaybackMove) async {
        guard queue.current != nil else { return }
        switch move {
        case .none:
            return
        case .restart:
            await restartCurrent()
        case .stay(let fullCircle):
            if fullCircle { announce(PlaybackCopy.nothingMore) }
        case .pauseAtEnd:
            host.player.pause()
            playing = false
            if durationMs > 0 { positionMs = durationMs }
            touchSession(write: true)
            publish()
        case .start(let nextQueue, let skipped):
            guard let index = nextQueue.currentIndex else { return }
            let previous = queue
            queue = nextQueue
            guard let track = currentTrack(at: index) else {
                queue = previous
                publish()
                return
            }
            let token = nextGeneration()
            guard await start(track, token: token) else {
                queue = previous
                if host.player.currentItem == nil { playing = false }
                publish()
                return
            }
            touchSession(write: true)
            publish()
            if skipped > 0 { announce(PlaybackCopy.skipped(skipped)) }
        }
    }

    private func restartCurrent() async {
        guard currentTrack() != nil else { return }
        await beginPlayback()
    }

    private func applyPlayPause(restartAtEnd: Bool) async {
        let plan = PlaybackQueueRules.playPause(
            hasCurrent: queue.current != nil,
            playing: playing,
            positionMs: positionMs,
            durationMs: durationMs
        )
        switch plan {
        case .noop:
            return
        case .pause:
            host.player.pause()
            playing = false
            touchSession(write: true)
            publish()
        case .resume:
            if canResumeCurrent {
                host.player.play()
                playing = true
                touchSession(write: true)
                publish()
            } else {
                await beginPlayback()
            }
        case .restartFromEnd:
            if canResumeCurrent {
                if restartAtEnd {
                    await seek(to: 0)
                }
                host.player.play()
                playing = true
                touchSession(write: true)
                publish()
            } else {
                await beginPlayback()
            }
        }
    }

    private var canResumeCurrent: Bool {
        guard let track = currentTrack(), blocker(for: track) == nil else { return false }
        guard let item = host.player.currentItem, item.status != .failed else { return false }
        return true
    }

    private func start(_ track: ResolvedTrack, token: Int) async -> Bool {
        if let block = blocker(for: track) {
            refuse(block)
            return false
        }
        let item = AVPlayerItem(url: URL(fileURLWithPath: track.path))
        host.player.replaceCurrentItem(with: item)
        let ready = await host.waitUntilReady(item)
        let owns = token == generation
        guard owns, ready else {
            if host.player.currentItem === item {
                host.player.replaceCurrentItem(with: nil)
            }
            if owns {
                let unsupported = item.status == .failed && Self.isUnsupportedFormat(item.error)
                refuse(unsupported ? .unsupportedFormat : .failed)
            }
            return false
        }
        host.observeEnd(of: item, owner: self, token: token)
        let seconds = item.duration.seconds
        durationMs = seconds.isFinite && seconds > 0 ? Int((seconds * 1000).rounded()) : 0
        positionMs = 0
        host.player.volume = Float(volume.level)
        host.player.play()
        playing = true
        lastError = nil
        return true
    }

    private func loadPaused(_ track: ResolvedTrack, token: Int, positionMs saved: Int) async -> Bool {
        if let block = blocker(for: track) {
            lastError = PlaybackErrorCode.code(for: block)
            return false
        }
        let item = AVPlayerItem(url: URL(fileURLWithPath: track.path))
        host.player.replaceCurrentItem(with: item)
        let ready = await host.waitUntilReady(item)
        let owns = token == generation
        guard owns, ready else {
            if host.player.currentItem === item {
                host.player.replaceCurrentItem(with: nil)
            }
            if owns {
                lastError = PlaybackErrorCode.code(
                    for: item.status == .failed && Self.isUnsupportedFormat(item.error) ? .unsupportedFormat : .failed
                )
            }
            return false
        }
        host.observeEnd(of: item, owner: self, token: token)
        let seconds = item.duration.seconds
        durationMs = seconds.isFinite && seconds > 0 ? Int((seconds * 1000).rounded()) : max(0, track.durationMs)
        positionMs = durationMs > 0 ? min(max(0, saved), durationMs) : max(0, saved)
        host.player.volume = Float(volume.level)
        host.player.pause()
        playing = false
        lastError = nil
        if durationMs > 0, positionMs > 0 {
            ignoreClock = true
            let time = CMTime(seconds: Double(positionMs) / 1000, preferredTimescale: 600)
            await host.seek(to: time)
            ignoreClock = false
        }
        return true
    }

    private func prepareAudio() {
        guard !audioPrepared else { return }
        audioPrepared = true
        if let flac = UTType(filenameExtension: "flac") {
            let flacType = AVFileType(flac.identifier)
            flacPlayable = AVURLAsset.audiovisualTypes().contains(flacType)
        }
    }

    private func nextGeneration() -> Int {
        generation += 1
        return generation
    }

    private func remember(_ tracks: [ResolvedTrack]) {
        for track in tracks {
            catalog[track.id] = track
        }
    }

    private func blocker(for track: ResolvedTrack) -> PlaybackBlock? {
        TrackPlayability.assess(
            missing: track.missing,
            path: track.path,
            fileExists: FileManager.default.fileExists(atPath: track.path),
            ubiquitousNotDownloaded: Self.ubiquitousNotDownloaded(track.path),
            flacPlayable: flacPlayable
        )
    }

    private func blocker(forID id: String) -> PlaybackBlock? {
        guard let track = catalog[id] else { return .missingFile }
        return blocker(for: track)
    }

    private func itemPlayable(_ item: QueueItem) -> Bool {
        guard let id = item.trackID else { return true }
        return blocker(forID: id) == nil
    }

    private func currentTrack() -> ResolvedTrack? {
        currentTrack(at: queue.currentIndex)
    }

    private func currentTrack(at index: Int?) -> ResolvedTrack? {
        guard let index, let item = queue.items[safe: index] else { return nil }
        switch item {
        case .track(let id):
            return catalog[id]
        case .oneShot(let uri):
            return catalog[uri]
        }
    }

    private func refuse(_ block: PlaybackBlock) {
        lastError = PlaybackErrorCode.code(for: block)
        commandFailed = true
        announce(PlaybackCopy.message(for: block))
        publish()
    }

    private func announce(_ message: String) {
        commandNotice = message
        emit(.toast(message))
    }

    private func beginCommand() {
        commandFailed = false
        commandNotice = nil
    }

    private func notReadyResult() -> AgentCommandResult {
        AgentCommandResult(
            snapshot: makeSnapshot(),
            errorCode: PlaybackErrorCode.notReady,
            message: AgentCopy.notReady,
            notice: nil
        )
    }

    private func finishCommand() -> AgentCommandResult {
        let snapshot = makeSnapshot()
        if commandFailed {
            return AgentCommandResult(
                snapshot: snapshot,
                errorCode: lastError ?? PlaybackErrorCode.failed,
                message: commandNotice ?? PlaybackCopy.failed,
                notice: nil
            )
        }
        return AgentCommandResult(snapshot: snapshot, errorCode: nil, message: nil, notice: commandNotice)
    }

    private func publish() {
        continuation.yield(.state(makeSnapshot()))
    }

    private func makeSnapshot() -> TransportSnapshot {
        let current = currentTrack()
        let currentID: String? = {
            if case .track(let id) = queue.current { return id }
            return nil
        }()
        let rows = queue.items.map { item -> QueueRowSnapshot in
            if let id = item.trackID, let track = catalog[id] {
                return QueueRowSnapshot(item: item, title: track.title, artist: track.artist, missing: track.missing || blocker(for: track) == .missingFile)
            }
            if case .oneShot(let uri) = item {
                return QueueRowSnapshot(item: item, title: URL(string: uri)?.lastPathComponent ?? uri, artist: "", missing: false)
            }
            return QueueRowSnapshot(item: item, title: "文件缺失", artist: "", missing: true)
        }
        return TransportSnapshot(
            currentID: currentID,
            title: current?.title ?? "",
            artist: current?.artist ?? "",
            artworkPath: current?.artworkPath,
            hasCurrent: current != nil && queue.current != nil,
            playing: playing,
            positionMs: positionMs,
            durationMs: durationMs,
            volume: volume.level,
            queueCount: queue.items.count,
            currentIndex: queue.currentIndex,
            rows: rows,
            shuffle: queue.shuffle,
            repeatMode: queue.repeatMode,
            lastError: lastError
        )
    }

    private func emit(_ event: EngineEvent) {
        continuation.yield(event)
    }

    /// Format failures only. Permission and I/O errors stay `.failed`.
    private static func isUnsupportedFormat(_ error: Error?) -> Bool {
        guard let error = error as NSError? else { return false }
        if error.domain == AVFoundationErrorDomain {
            switch AVError.Code(rawValue: error.code) {
            case .fileFormatNotRecognized, .decoderNotFound, .undecodableMediaData:
                return true
            default:
                break
            }
        }
        if error.domain == NSOSStatusErrorDomain {
            switch error.code {
            case 1_954_115_647, 1_718_449_215:
                return true
            default:
                break
            }
        }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
            return isUnsupportedFormat(underlying)
        }
        return false
    }

    private static func ubiquitousNotDownloaded(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: [
            .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey,
        ])
        guard values?.isUbiquitousItem == true else { return false }
        return values?.ubiquitousItemDownloadingStatus == .notDownloaded
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private final class PlayerHost: @unchecked Sendable {
    let player: AVPlayer = {
        let player = AVPlayer()
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.allowsExternalPlayback = false
        return player
    }()
    private var timeToken: Any?
    private var endToken: NSObjectProtocol?
    private var failToken: NSObjectProtocol?

    deinit {
        if let timeToken { player.removeTimeObserver(timeToken) }
        if let endToken { NotificationCenter.default.removeObserver(endToken) }
        if let failToken { NotificationCenter.default.removeObserver(failToken) }
    }

    func install(owner: PlaybackEngine) {
        if let timeToken {
            player.removeTimeObserver(timeToken)
            self.timeToken = nil
        }
        let interval = CMTime(seconds: 0.3, preferredTimescale: 600)
        timeToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak owner] time in
            guard let owner else { return }
            let seconds = time.seconds
            guard seconds.isFinite else { return }
            let ms = Int((seconds * 1000).rounded())
            Task { await owner.noteClock(ms) }
        }
    }

    func observeEnd(of item: AVPlayerItem, owner: PlaybackEngine, token: Int) {
        if let endToken { NotificationCenter.default.removeObserver(endToken) }
        if let failToken { NotificationCenter.default.removeObserver(failToken) }
        endToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak owner] _ in
            guard let owner else { return }
            Task { await owner.noteEnded(token: token) }
        }
        failToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak owner] _ in
            guard let owner else { return }
            Task { await owner.noteFailedMidPlay(token: token) }
        }
    }

    func seek(to time: CMTime) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                continuation.resume()
            }
        }
    }

    func waitUntilReady(_ item: AVPlayerItem) async -> Bool {
        if item.status == .readyToPlay { return true }
        if item.status == .failed { return false }
        let box = ReadyBox()
        return await withCheckedContinuation { continuation in
            box.start(item: item, continuation: continuation)
        }
    }
}

private final class ReadyBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Bool, Never>?
    private var observation: NSKeyValueObservation?

    func start(item: AVPlayerItem, continuation: CheckedContinuation<Bool, Never>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
        observation = item.observe(\.status) { [weak self] item, _ in
            switch item.status {
            case .readyToPlay: self?.finish(true)
            case .failed: self?.finish(false)
            default: break
            }
        }
        switch item.status {
        case .readyToPlay: finish(true)
        case .failed: finish(false)
        default: break
        }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            self?.finish(false)
        }
    }

    private func finish(_ value: Bool) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        guard let continuation else { return }
        observation?.invalidate()
        observation = nil
        continuation.resume(returning: value)
    }
}
