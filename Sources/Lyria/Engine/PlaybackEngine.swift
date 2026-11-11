import AVFoundation
import Foundation
import LyriaCore
import UniformTypeIdentifiers

/// Serial playback writer. Views enqueue work here and only read `TransportState`.
actor PlaybackEngine {
    nonisolated let events: AsyncStream<EngineEvent>
    private let continuation: AsyncStream<EngineEvent>.Continuation
    private let host = PlayerHost()
    private var queue = PlaybackQueue()
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

    init() {
        var continuation: AsyncStream<EngineEvent>.Continuation!
        let stream = AsyncStream<EngineEvent> { continuation = $0 }
        events = stream
        self.continuation = continuation
        host.install(owner: self)
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
            block: block
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
        guard let result = PlaybackQueueRules.playAll(ids: list.map(\.id), isPlayable: { self.blocker(forID: $0) == nil }) else {
            emit(.toast(PlaybackCopy.nothingPlayable))
            return
        }
        await commitAndPlay(result.queue, tracks: list)
        if result.skipped > 0 {
            emit(.toast(PlaybackCopy.skipped(result.skipped)))
        }
    }

    func playNext(_ list: [ResolvedTrack]) async {
        remember(list)
        queue = PlaybackQueueRules.playNext(ids: list.map(\.id), queue: queue)
        publish()
    }

    func enqueue(_ list: [ResolvedTrack]) async {
        remember(list)
        let result = PlaybackQueueRules.enqueue(ids: list.map(\.id), queue: queue)
        if result.alreadyAllPresent {
            emit(.toast(PlaybackCopy.alreadyQueued))
            return
        }
        queue = result.queue
        publish()
        emit(.showQueue)
    }

    func playQueueIndex(_ index: Int) async {
        prepareAudio()
        guard let track = currentTrack(at: index) else { return }
        if let block = blocker(for: track) {
            refuse(block)
            return
        }
        let previous = queue
        queue.currentIndex = index
        let token = nextGeneration()
        guard await start(track, token: token) else {
            queue = previous
            publish()
            return
        }
        publish()
    }

    func toggleTransport() async {
        await applyPlayPause(restartAtEnd: true)
    }

    func next() async {
        await step(PlaybackQueueRules.next(queue: queue, isPlayable: itemPlayable))
    }

    func previous() async {
        await step(PlaybackQueueRules.previous(queue: queue, positionMs: positionMs, isPlayable: itemPlayable))
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
        publish()
    }

    func setVolume(_ value: Double) async {
        volume.setSlider(value)
        host.player.volume = Float(volume.level)
        publish()
    }

    func toggleSpeaker() async {
        volume.toggleSpeaker()
        host.player.volume = Float(volume.level)
        publish()
    }

    func removeFromQueue(_ ids: Set<String>) async {
        switch PlaybackQueueRules.remove(ids: ids, from: queue, isPlayable: itemPlayable) {
        case .kept(let next):
            queue = next
            publish()
        case .stopped(let next):
            queue = next
            host.player.pause()
            playing = false
            positionMs = 0
            durationMs = 0
            publish()
        case .play(let next, _):
            queue = next
            guard let track = currentTrack() else {
                publish()
                return
            }
            let token = nextGeneration()
            if await start(track, token: token) == false {
                host.player.pause()
                playing = false
                queue.currentIndex = nil
            }
            publish()
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
        let proposed = PlaybackQueue(items: [.oneShot(uri.absoluteString)], currentIndex: 0)
        queue = proposed
        let token = nextGeneration()
        if await start(track, token: token) == false {
            queue = PlaybackQueue()
        }
        publish()
    }

    func noteClock(_ ms: Int) {
        guard playing, !ignoreClock else { return }
        positionMs = max(0, ms)
        publish()
    }

    func noteEnded(token: Int) {
        guard token == generation else { return }
        host.player.pause()
        playing = false
        if durationMs > 0 { positionMs = durationMs }
        publish()
    }

    func noteFailedMidPlay(token: Int) async {
        guard token == generation else { return }
        host.player.pause()
        playing = false
        emit(.toast(PlaybackCopy.failed))
        lastError = PlaybackErrorCode.failed
        await step(PlaybackQueueRules.next(queue: queue, isPlayable: itemPlayable))
    }

    private func commitAndPlay(_ proposed: PlaybackQueue, tracks: [ResolvedTrack]) async {
        guard let index = proposed.currentIndex,
              let id = proposed.items[safe: index]?.trackID,
              let track = tracks.first(where: { $0.id == id }) ?? catalog[id]
        else { return }
        let token = nextGeneration()
        let previous = queue
        queue = proposed
        guard await start(track, token: token) else {
            queue = previous
            publish()
            return
        }
        publish()
    }

    private func step(_ move: PlaybackMove) async {
        guard queue.current != nil else { return }
        switch move {
        case .none:
            return
        case .restart:
            await restartCurrent()
        case .stay(let fullCircle):
            if fullCircle { emit(.toast(PlaybackCopy.nothingMore)) }
        case .start(let index, let skipped):
            guard let track = currentTrack(at: index) else { return }
            let previous = queue
            queue.currentIndex = index
            let token = nextGeneration()
            guard await start(track, token: token) else {
                queue = previous
                publish()
                return
            }
            publish()
            if skipped > 0 { emit(.toast(PlaybackCopy.skipped(skipped))) }
        }
    }

    private func restartCurrent() async {
        guard let track = currentTrack() else { return }
        if let block = blocker(for: track) {
            refuse(block)
            return
        }
        let token = nextGeneration()
        _ = await start(track, token: token)
        publish()
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
        case .resume:
            host.player.play()
            playing = true
        case .restartFromEnd:
            guard restartAtEnd else {
                host.player.play()
                playing = true
                break
            }
            await seek(to: 0)
            host.player.play()
            playing = true
        }
        publish()
    }

    private func start(_ track: ResolvedTrack, token: Int) async -> Bool {
        if let block = blocker(for: track) {
            refuse(block)
            return false
        }
        let asset = AVURLAsset(url: URL(fileURLWithPath: track.path))
        let playable = (try? await asset.load(.isPlayable)) ?? false
        guard token == generation else { return false }
        guard playable else {
            refuse(.unsupportedFormat)
            return false
        }
        let item = AVPlayerItem(asset: asset)
        let ready = await host.waitUntilReady(item)
        guard token == generation else { return false }
        guard ready else {
            refuse(.failed)
            return false
        }
        host.player.replaceCurrentItem(with: item)
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

    private func prepareAudio() {
        guard !audioPrepared else { return }
        audioPrepared = true
        if let flac = UTType(filenameExtension: "flac") {
            flacPlayable = AVURLAsset.audiovisualContentTypes.contains(flac)
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
        emit(.toast(PlaybackCopy.message(for: block)))
        publish()
    }

    private func publish() {
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
        continuation.yield(.state(TransportSnapshot(
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
            lastError: lastError
        )))
    }

    private func emit(_ event: EngineEvent) {
        continuation.yield(event)
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
    let player = AVPlayer()
    private var timeToken: Any?
    private var endToken: NSObjectProtocol?
    private var failToken: NSObjectProtocol?

    func install(owner: PlaybackEngine) {
        let interval = CMTime(seconds: 0.3, preferredTimescale: 600)
        timeToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
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
        ) { _ in
            Task { await owner.noteEnded(token: token) }
        }
        failToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
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
