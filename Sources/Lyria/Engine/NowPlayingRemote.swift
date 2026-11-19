import AppKit
import Foundation
import MediaPlayer

/// Pushes transport state to the system Now Playing widget and routes remote commands
/// back into `PlaybackEngine` (the sole playback writer).
final class NowPlayingRemote: @unchecked Sendable {
    private let lock = NSLock()
    private var installed = false
    private var lastElapsedPush = Date.distantPast
    private var artworkToken = 0
    private var lastArtworkPath: String?

    private static let elapsedInterval: TimeInterval = 1.0

    func install(engine: PlaybackEngine) {
        lock.lock()
        defer { lock.unlock() }
        guard !installed else { return }
        installed = true

        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
        center.changePlaybackPositionCommand.isEnabled = true

        center.playCommand.addTarget { _ in
            Task { await engine.remotePlay() }
            return .success
        }
        center.pauseCommand.addTarget { _ in
            Task { await engine.remotePause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { _ in
            Task { await engine.toggleTransport() }
            return .success
        }
        center.nextTrackCommand.addTarget { _ in
            Task { await engine.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { _ in
            Task { await engine.previous() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let ms = Int((event.positionTime * 1000).rounded())
            Task { await engine.seek(to: ms) }
            return .success
        }
    }

    /// Full refresh from a transport snapshot (track change, play/pause, seek).
    func apply(_ snapshot: TransportSnapshot) {
        DispatchQueue.main.async { [weak self] in
            self?.applyOnMain(snapshot, forceElapsed: true)
        }
    }

    /// Throttled elapsed-time updates while playing (~1s).
    func tickElapsed(hasCurrent: Bool, playing: Bool, positionMs: Int, durationMs: Int) {
        guard hasCurrent, playing else { return }
        let now = Date()
        lock.lock()
        let due = now.timeIntervalSince(lastElapsedPush) >= Self.elapsedInterval
        if due { lastElapsedPush = now }
        lock.unlock()
        guard due else { return }

        DispatchQueue.main.async {
            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(positionMs) / 1000
            info[MPMediaItemPropertyPlaybackDuration] = Double(max(durationMs, 0)) / 1000
            info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            MPNowPlayingInfoCenter.default().playbackState = .playing
        }
    }

    /// Drop the system widget (no current track, or app quitting).
    func clear() {
        DispatchQueue.main.async { [weak self] in
            self?.clearOnMain()
        }
    }

    private func clearOnMain() {
        lock.lock()
        artworkToken += 1
        lastArtworkPath = nil
        lastElapsedPush = .distantPast
        lock.unlock()
        MPNowPlayingInfoCenter.default().playbackState = .stopped
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func applyOnMain(_ snapshot: TransportSnapshot, forceElapsed: Bool) {
        guard snapshot.hasCurrent else {
            clearOnMain()
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: snapshot.title,
            MPMediaItemPropertyArtist: snapshot.artist,
            MPMediaItemPropertyAlbumTitle: snapshot.album,
            MPMediaItemPropertyPlaybackDuration: Double(max(snapshot.durationMs, 0)) / 1000,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: Double(max(snapshot.positionMs, 0)) / 1000,
            MPNowPlayingInfoPropertyPlaybackRate: snapshot.playing ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
        ]

        if let existing = MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtwork] {
            info[MPMediaItemPropertyArtwork] = existing
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = snapshot.playing ? .playing : .paused

        if forceElapsed {
            lock.lock()
            lastElapsedPush = Date()
            lock.unlock()
        }

        loadArtworkIfNeeded(path: snapshot.artworkPath)
    }

    private func loadArtworkIfNeeded(path: String?) {
        lock.lock()
        let samePath = path == lastArtworkPath
        if samePath {
            lock.unlock()
            return
        }
        lastArtworkPath = path
        artworkToken += 1
        let token = artworkToken
        lock.unlock()

        guard let path, !path.isEmpty else { return }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let image = NSImage(contentsOfFile: path) else { return }
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            DispatchQueue.main.async {
                guard let self else { return }
                self.lock.lock()
                let current = self.artworkToken
                self.lock.unlock()
                guard current == token else { return }
                var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                info[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
        }
    }
}
