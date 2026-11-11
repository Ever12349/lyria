import XCTest
import LyriaCore

final class PlaybackQueueTests: XCTestCase {
    private let playable: (String) -> PlaybackBlock? = { id in
        id.hasPrefix("bad") ? .missingFile : nil
    }

    func testMenuPlayReplacesTheListAndCoverOnCurrentToggles() {
        let list = ["a", "b", "c"]
        let played = PlaybackQueueRules.plan(
            intent: .menuPlay, trackID: "b", list: list, currentID: "b", block: nil
        )
        XCTAssertEqual(played, .replace(PlaybackQueue(items: [.track("a"), .track("b"), .track("c")], currentIndex: 1)))
        XCTAssertEqual(
            PlaybackQueueRules.plan(intent: .cover, trackID: "b", list: list, currentID: "b", block: nil),
            .toggle
        )
        XCTAssertEqual(
            PlaybackQueueRules.plan(intent: .doubleClick, trackID: "b", list: list, currentID: "b", block: nil),
            .restart
        )
        XCTAssertEqual(
            PlaybackQueueRules.plan(intent: .cover, trackID: "a", list: list, currentID: "b", block: nil),
            .replace(PlaybackQueue(items: list.map { .track($0) }, currentIndex: 0))
        )
    }

    func testUnplayableRowDoesNotReplaceTheQueue() {
        XCTAssertEqual(
            PlaybackQueueRules.plan(intent: .menuPlay, trackID: "bad", list: ["bad", "a"], currentID: nil, block: .missingFile),
            .refuse(.missingFile)
        )
        XCTAssertNil(PlaybackQueueRules.playAll(ids: ["bad", "bad2"], isPlayable: { self.playable($0) == nil }))
    }

    func testPlayAllSkipsLeadingUnplayableRows() {
        let result = PlaybackQueueRules.playAll(ids: ["bad", "bad2", "ok"], isPlayable: { !$0.hasPrefix("bad") })
        XCTAssertEqual(result?.skipped, 2)
        XCTAssertEqual(result?.queue.currentIndex, 2)
        XCTAssertEqual(result?.queue.items.count, 3)
    }

    func testPlayNextMovesExistingItemsToAfterCurrent() {
        let queue = PlaybackQueue(items: [.track("a"), .track("b"), .track("c")], currentIndex: 1)
        let next = PlaybackQueueRules.playNext(ids: ["c", "d", "c"], queue: queue)
        XCTAssertEqual(next.items, [.track("a"), .track("b"), .track("c"), .track("d")])
        XCTAssertEqual(next.current, .track("b"))
        let head = PlaybackQueueRules.playNext(ids: ["z"], queue: PlaybackQueue(items: [.track("a")], currentIndex: nil))
        XCTAssertEqual(head.items, [.track("z"), .track("a")])
    }

    func testEnqueueDedupesAndReportsWhenNothingWasAdded() {
        let queue = PlaybackQueue(items: [.track("a"), .track("b")], currentIndex: 0)
        let added = PlaybackQueueRules.enqueue(ids: ["b", "c"], queue: queue)
        XCTAssertFalse(added.alreadyAllPresent)
        XCTAssertEqual(added.queue.items, [.track("a"), .track("b"), .track("c")])
        let same = PlaybackQueueRules.enqueue(ids: ["b", "a"], queue: queue)
        XCTAssertTrue(same.alreadyAllPresent)
        XCTAssertEqual(same.queue.items, queue.items)
        XCTAssertEqual(PlaybackCopy.alreadyQueued, "已在队列中")
    }

    func testPreviousRestartsAfterTwoSecondsAndDoesNotWrapTheHead() {
        let queue = PlaybackQueue(items: [.track("a"), .track("bad"), .track("c")], currentIndex: 2)
        XCTAssertEqual(
            PlaybackQueueRules.previous(queue: queue, positionMs: 2_001, isPlayable: playableItem),
            .restart
        )
        XCTAssertEqual(
            PlaybackQueueRules.previous(queue: queue, positionMs: 2_000, isPlayable: playableItem),
            .start(index: 0, skipped: 1)
        )
        let head = PlaybackQueue(items: [.track("a"), .track("b")], currentIndex: 0)
        XCTAssertEqual(
            PlaybackQueueRules.previous(queue: head, positionMs: 0, isPlayable: playableItem),
            .stay(fullCircle: false)
        )
    }

    func testNextWrapsAndFullCircleStays() {
        let queue = PlaybackQueue(items: [.track("a"), .track("bad"), .track("c")], currentIndex: 2)
        XCTAssertEqual(
            PlaybackQueueRules.next(queue: queue, isPlayable: playableItem),
            .start(index: 0, skipped: 0)
        )
        let blocked = PlaybackQueue(items: [.track("a"), .track("bad")], currentIndex: 0)
        XCTAssertEqual(
            PlaybackQueueRules.next(queue: blocked, isPlayable: playableItem),
            .stay(fullCircle: true)
        )
        XCTAssertEqual(PlaybackCopy.nothingMore, "没有更多可播放的曲目")
        XCTAssertEqual(PlaybackCopy.skipped(2), "已跳过 2 首无法播放的曲目")
        XCTAssertEqual(PlaybackCopy.nothingPlayable, "没有可播放的曲目")
    }

    func testRemovalDropsIdsAndFollowsWithTheNextPlayable() {
        let queue = PlaybackQueue(items: [.track("a"), .track("b"), .track("bad"), .track("c")], currentIndex: 1)
        let played = PlaybackQueueRules.remove(ids: ["b"], from: queue, isPlayable: playableItem)
        XCTAssertEqual(played, .play(PlaybackQueue(items: [.track("a"), .track("bad"), .track("c")], currentIndex: 2), index: 2))
        let stopped = PlaybackQueueRules.remove(ids: ["c"], from: PlaybackQueue(items: [.track("c")], currentIndex: 0), isPlayable: playableItem)
        XCTAssertEqual(stopped, .stopped(PlaybackQueue()))
        let kept = PlaybackQueueRules.remove(ids: ["a"], from: queue, isPlayable: playableItem)
        XCTAssertEqual(kept, .kept(PlaybackQueue(items: [.track("b"), .track("bad"), .track("c")], currentIndex: 0)))
    }

    func testPlayPauseAtTheEndRestartsTheSameTrack() {
        XCTAssertEqual(PlaybackQueueRules.playPause(hasCurrent: false, playing: false, positionMs: 0, durationMs: 0), .noop)
        XCTAssertEqual(PlaybackQueueRules.playPause(hasCurrent: true, playing: true, positionMs: 10, durationMs: 100), .pause)
        XCTAssertEqual(PlaybackQueueRules.playPause(hasCurrent: true, playing: false, positionMs: 40, durationMs: 100), .resume)
        XCTAssertEqual(PlaybackQueueRules.playPause(hasCurrent: true, playing: false, positionMs: 100, durationMs: 100), .restartFromEnd)
    }

    func testVolumeSpeakerMemoryIgnoresTheSlider() {
        var volume = VolumeSession()
        XCTAssertEqual(volume.level, 1)
        volume.setSlider(0)
        XCTAssertNil(volume.speakerMemory)
        volume.toggleSpeaker()
        XCTAssertEqual(volume.level, 0.6)
        volume.setSlider(0.25)
        volume.toggleSpeaker()
        XCTAssertEqual(volume.speakerMemory, 0.25)
        XCTAssertEqual(volume.level, 0)
        volume.toggleSpeaker()
        XCTAssertEqual(volume.level, 0.25)
    }

    func testPlayabilityAndToastCopy() {
        XCTAssertEqual(AudioContainer.classify(path: "/a/b.MP3"), .supported)
        XCTAssertEqual(AudioContainer.classify(path: "/a/b.flac"), .flac)
        XCTAssertEqual(AudioContainer.classify(path: "/a/b.ogg"), .unsupported)
        XCTAssertNil(TrackPlayability.assess(missing: false, path: "/a.mp3", fileExists: true, ubiquitousNotDownloaded: false, flacPlayable: false))
        XCTAssertEqual(
            TrackPlayability.assess(missing: true, path: "/a.mp3", fileExists: true, ubiquitousNotDownloaded: true, flacPlayable: true),
            .missingFile
        )
        XCTAssertEqual(
            TrackPlayability.assess(missing: false, path: "/a.mp3", fileExists: true, ubiquitousNotDownloaded: true, flacPlayable: false),
            .notDownloaded
        )
        XCTAssertEqual(
            TrackPlayability.assess(missing: false, path: "/a.flac", fileExists: true, ubiquitousNotDownloaded: false, flacPlayable: false),
            .unsupportedFormat
        )
        XCTAssertEqual(PlaybackCopy.message(for: .notDownloaded), "文件尚未下载")
        XCTAssertEqual(PlaybackCopy.message(for: .missingFile), "找不到文件")
        XCTAssertEqual(PlaybackCopy.message(for: .unsupportedFormat), "无法播放此格式")
        XCTAssertEqual(PlaybackCopy.message(forCode: PlaybackErrorCode.failed), "播放失败")
        XCTAssertEqual(PlaybackCopy.message(forCode: PlaybackErrorCode.notReady), "播放失败")
    }

    private func playableItem(_ item: QueueItem) -> Bool {
        guard let id = item.trackID else { return true }
        return playable(id) == nil
    }
}
