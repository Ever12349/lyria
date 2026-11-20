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

    func testUnplayableRowStillReplacesTheQueue() {
        XCTAssertEqual(
            PlaybackQueueRules.plan(intent: .menuPlay, trackID: "bad", list: ["bad", "a"], currentID: nil, block: .missingFile),
            .replace(PlaybackQueue(items: [.track("bad"), .track("a")], currentIndex: 0))
        )
        XCTAssertNil(PlaybackQueueRules.playAll(ids: ["bad", "bad2"], isPlayable: { self.playable($0) == nil }))
    }

    func testStartPlaybackSkipsUnplayableAndWraps() {
        let playable: (QueueItem) -> Bool = { item in
            guard let id = item.trackID else { return false }
            return !id.hasPrefix("bad")
        }
        let mid = PlaybackQueue(items: ["bad", "ok", "z"].map { .track($0) }, currentIndex: 0)
        XCTAssertEqual(
            PlaybackQueueRules.startPlayback(queue: mid, isPlayable: playable),
            .play(PlaybackQueue(items: mid.items, currentIndex: 1), skipped: 1)
        )
        let tail = PlaybackQueue(items: ["ok", "bad1", "bad2"].map { .track($0) }, currentIndex: 1)
        XCTAssertEqual(
            PlaybackQueueRules.startPlayback(queue: tail, isPlayable: playable),
            .play(PlaybackQueue(items: tail.items, currentIndex: 0), skipped: 2)
        )
        let none = PlaybackQueue(items: ["bad", "bad2"].map { .track($0) }, currentIndex: 0)
        XCTAssertEqual(PlaybackQueueRules.startPlayback(queue: none, isPlayable: playable), .stop(none))
        let ready = PlaybackQueue(items: ["a", "b"].map { .track($0) }, currentIndex: 1)
        XCTAssertEqual(
            PlaybackQueueRules.startPlayback(queue: ready, isPlayable: playable),
            .play(ready, skipped: 0)
        )
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
            .start(PlaybackQueue(items: [.track("a"), .track("bad"), .track("c")], currentIndex: 0), skipped: 1)
        )
        let head = PlaybackQueue(items: [.track("a"), .track("b")], currentIndex: 0)
        XCTAssertEqual(
            PlaybackQueueRules.previous(queue: head, positionMs: 0, isPlayable: playableItem),
            .stay(fullCircle: false)
        )
    }

    func testNextDoesNotWrapUnlessRepeatIsAll() {
        let queue = PlaybackQueue(items: [.track("a"), .track("bad"), .track("c")], currentIndex: 2)
        XCTAssertEqual(
            PlaybackQueueRules.next(queue: queue, isPlayable: playableItem),
            .stay(fullCircle: false)
        )
        let blocked = PlaybackQueue(items: [.track("a"), .track("bad")], currentIndex: 0)
        XCTAssertEqual(
            PlaybackQueueRules.next(queue: blocked, isPlayable: playableItem),
            .stay(fullCircle: true)
        )
        var repeating = queue
        repeating.repeatMode = .all
        XCTAssertEqual(
            PlaybackQueueRules.next(queue: repeating, isPlayable: playableItem),
            .start(
                PlaybackQueue(items: repeating.items, currentIndex: 0, repeatMode: .all),
                skipped: 0
            )
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

    func testNaturalEndFollowsRepeatAndRepeatOneNextStillMoves() {
        let tail = PlaybackQueue(items: [.track("a"), .track("b")], currentIndex: 1)
        XCTAssertEqual(PlaybackQueueRules.naturalEnd(queue: tail, isPlayable: playableItem), .pauseAtEnd)
        XCTAssertEqual(PlaybackQueueRules.next(queue: tail, isPlayable: playableItem), .stay(fullCircle: false))

        let mid = PlaybackQueue(items: [.track("a"), .track("b"), .track("c")], currentIndex: 1, repeatMode: .one)
        XCTAssertEqual(PlaybackQueueRules.naturalEnd(queue: mid, isPlayable: playableItem), .restart)
        XCTAssertEqual(
            PlaybackQueueRules.next(queue: mid, isPlayable: playableItem),
            .start(PlaybackQueue(items: mid.items, currentIndex: 2, repeatMode: .one), skipped: 0)
        )

        var all = tail
        all.repeatMode = .all
        XCTAssertEqual(
            PlaybackQueueRules.naturalEnd(queue: all, isPlayable: playableItem),
            .start(PlaybackQueue(items: all.items, currentIndex: 0, repeatMode: .all), skipped: 0)
        )
    }

    func testMidPlayFailureDoesNotRetryUnderRepeatOneAndDoesNotWrap() {
        let looping = PlaybackQueue(
            items: [.track("a"), .track("bad"), .track("c")],
            currentIndex: 0,
            repeatMode: .one
        )
        XCTAssertEqual(
            PlaybackQueueRules.advanceAfterFailure(queue: looping, isPlayable: playableItem),
            .start(PlaybackQueue(items: looping.items, currentIndex: 2, repeatMode: .one), skipped: 1)
        )
        let tail = PlaybackQueue(
            items: [.track("a"), .track("b"), .track("c")],
            currentIndex: 2,
            shuffle: true,
            repeatMode: .all
        )
        XCTAssertEqual(
            PlaybackQueueRules.advanceAfterFailure(queue: tail, isPlayable: { _ in true }),
            .stay(fullCircle: false)
        )
        let only = PlaybackQueue(items: [.track("a")], currentIndex: 0, shuffle: true, repeatMode: .all)
        XCTAssertEqual(
            PlaybackQueueRules.advanceAfterFailure(queue: only, isPlayable: { _ in true }),
            .stay(fullCircle: true)
        )
    }

    func testSetShuffleDoesNotReshuffleWhenAlreadySet() {
        let original = PlaybackQueue(items: [.track("a"), .track("b"), .track("c")], currentIndex: 1)
        var unused = ScriptedRNG(values: [0, 0, 0])
        let same = PlaybackQueueRules.setShuffle(enabled: false, queue: original, rng: &unused)
        XCTAssertEqual(same, original)
        XCTAssertEqual(unused.index, 0)

        var first = ScriptedRNG(values: [0, 0])
        let on = PlaybackQueueRules.setShuffle(enabled: true, queue: original, rng: &first)
        var second = ScriptedRNG(values: [9, 9, 9])
        let again = PlaybackQueueRules.setShuffle(enabled: true, queue: on, rng: &second)
        XCTAssertEqual(again.items, on.items)
        XCTAssertEqual(second.index, 0)

        let off = PlaybackQueueRules.setRepeat(mode: .off, queue: original)
        XCTAssertEqual(off, original)
        let all = PlaybackQueueRules.setRepeat(mode: .all, queue: original)
        XCTAssertEqual(all.repeatMode, .all)
        XCTAssertEqual(all.items, original.items)
        XCTAssertEqual(PlaybackQueueRules.setRepeat(mode: .all, queue: all), all)
    }

    func testShuffleToggleKeepsCurrentAndRestoresSource() {
        let original = PlaybackQueue(items: [.track("a"), .track("b"), .track("c"), .track("d")], currentIndex: 2)
        var zeros = ScriptedRNG(values: [0, 0, 0])
        let on = PlaybackQueueRules.toggleShuffle(queue: original, rng: &zeros)
        XCTAssertTrue(on.shuffle)
        XCTAssertEqual(on.current, .track("c"))
        XCTAssertEqual(on.currentIndex, 0)
        XCTAssertEqual(on.items, [.track("c"), .track("b"), .track("d"), .track("a")])
        XCTAssertEqual(on.source, original.items)

        var unused = ScriptedRNG(values: [0])
        let off = PlaybackQueueRules.toggleShuffle(queue: on, rng: &unused)
        XCTAssertFalse(off.shuffle)
        XCTAssertEqual(off.items, original.items)
        XCTAssertEqual(off.source, original.items)
        XCTAssertEqual(off.currentIndex, 2)

        var again = ScriptedRNG(values: [1, 0, 0])
        let reshuffled = PlaybackQueueRules.toggleShuffle(queue: off, rng: &again)
        XCTAssertEqual(reshuffled.current, .track("c"))
        XCTAssertEqual(reshuffled.source, original.items)
        XCTAssertEqual(reshuffled.items, [.track("c"), .track("d"), .track("a"), .track("b")])
        XCTAssertNotEqual(reshuffled.items, on.items)

        let headless = PlaybackQueue(items: [.track("a"), .track("b"), .track("c")], currentIndex: nil)
        var whole = ScriptedRNG(values: [0, 0])
        let shuffledAll = PlaybackQueueRules.toggleShuffle(queue: headless, rng: &whole)
        XCTAssertNil(shuffledAll.currentIndex)
        XCTAssertEqual(shuffledAll.items, [.track("b"), .track("c"), .track("a")])
        XCTAssertEqual(shuffledAll.source, headless.items)
        let restored = PlaybackQueueRules.toggleShuffle(queue: shuffledAll, rng: &unused)
        XCTAssertEqual(restored.items, headless.items)
        XCTAssertFalse(restored.shuffle)

        var empty = PlaybackQueue()
        empty = PlaybackQueueRules.toggleShuffle(queue: empty, rng: &unused)
        XCTAssertTrue(empty.shuffle)
        XCTAssertTrue(empty.items.isEmpty)
        XCTAssertEqual(PlaybackQueueRules.toggleRepeat(queue: empty).repeatMode, .all)
        XCTAssertEqual(
            PlaybackQueueRules.toggleRepeat(queue: PlaybackQueue(repeatMode: .all)).repeatMode,
            .one
        )
        XCTAssertEqual(
            PlaybackQueueRules.toggleRepeat(queue: PlaybackQueue(repeatMode: .one)).repeatMode,
            .off
        )
    }

    func testEnqueueAndPlayNextMutateBothOrders() {
        let queue = PlaybackQueue(
            items: [.track("b"), .track("d"), .track("a"), .track("c")],
            source: [.track("a"), .track("b"), .track("c"), .track("d")],
            currentIndex: 0,
            shuffle: true
        )
        let added = PlaybackQueueRules.enqueue(ids: ["a", "e"], queue: queue)
        XCTAssertFalse(added.alreadyAllPresent)
        XCTAssertEqual(added.queue.items, [.track("b"), .track("d"), .track("a"), .track("c"), .track("e")])
        XCTAssertEqual(added.queue.source, [.track("a"), .track("b"), .track("c"), .track("d"), .track("e")])
        XCTAssertEqual(added.queue.current, .track("b"))
        XCTAssertTrue(added.queue.shuffle)

        let moved = PlaybackQueueRules.playNext(ids: ["c", "e"], queue: queue)
        XCTAssertEqual(moved.items, [.track("b"), .track("c"), .track("e"), .track("d"), .track("a")])
        XCTAssertEqual(moved.source, [.track("a"), .track("b"), .track("c"), .track("e"), .track("d")])
        XCTAssertEqual(moved.current, .track("b"))
        XCTAssertTrue(moved.shuffle)
        var unused = ScriptedRNG(values: [0])
        let restored = PlaybackQueueRules.toggleShuffle(queue: moved, rng: &unused)
        XCTAssertEqual(restored.items, moved.source)
        XCTAssertEqual(restored.current, .track("b"))
        XCTAssertTrue(restored.items.contains(.track("e")))
        XCTAssertTrue(restored.items.contains(.track("c")))
    }

    func testOneShotInsertsIntoBothOrdersAndClearKeepsModes() {
        let file = QueueItem.oneShot("file:///tmp/a.mp3")
        let queue = PlaybackQueue(
            items: [.track("b"), .oneShot("file:///tmp/old.mp3"), .track("a")],
            source: [.track("a"), .track("b"), .oneShot("file:///tmp/old.mp3")],
            currentIndex: 0,
            shuffle: true,
            repeatMode: .all
        )
        let added = PlaybackQueueRules.enqueue(items: [file, .track("a")], queue: queue)
        XCTAssertFalse(added.alreadyAllPresent)
        XCTAssertEqual(
            added.queue.items,
            [.track("b"), .oneShot("file:///tmp/old.mp3"), .track("a"), file]
        )
        XCTAssertEqual(
            added.queue.source,
            [.track("a"), .track("b"), .oneShot("file:///tmp/old.mp3"), file]
        )
        XCTAssertEqual(added.queue.current, .track("b"))
        XCTAssertTrue(added.queue.shuffle)
        XCTAssertEqual(added.queue.repeatMode, .all)

        let again = PlaybackQueueRules.enqueue(items: [file], queue: added.queue)
        XCTAssertTrue(again.alreadyAllPresent)
        XCTAssertEqual(again.queue.items, added.queue.items)
        XCTAssertEqual(again.queue.source, added.queue.source)

        let moved = PlaybackQueueRules.playNext(items: [file], queue: queue)
        XCTAssertEqual(
            moved.items,
            [.track("b"), file, .oneShot("file:///tmp/old.mp3"), .track("a")]
        )
        XCTAssertEqual(
            moved.source,
            [.track("a"), .track("b"), file, .oneShot("file:///tmp/old.mp3")]
        )
        XCTAssertEqual(moved.current, .track("b"))
        XCTAssertTrue(moved.shuffle)
        XCTAssertEqual(moved.repeatMode, .all)

        let cleared = PlaybackQueueRules.cleared(moved)
        XCTAssertEqual(cleared.items, [])
        XCTAssertEqual(cleared.source, [])
        XCTAssertNil(cleared.currentIndex)
        XCTAssertTrue(cleared.shuffle)
        XCTAssertEqual(cleared.repeatMode, .all)
        XCTAssertEqual(PlaybackQueueRules.cleared(cleared), cleared)
    }

    func testReplaceAndPlayAllKeepShuffleAndPutTheStartRowFirst() {
        var rng = ScriptedRNG(values: [0, 0, 0])
        let replaced = PlaybackQueueRules.plan(
            intent: .menuPlay,
            trackID: "b",
            list: ["a", "b", "c", "d"],
            currentID: nil,
            block: nil,
            shuffle: true,
            repeatMode: .one,
            rng: &rng
        )
        XCTAssertEqual(
            replaced,
            .replace(PlaybackQueue(
                items: [.track("b"), .track("c"), .track("d"), .track("a")],
                source: [.track("a"), .track("b"), .track("c"), .track("d")],
                currentIndex: 0,
                shuffle: true,
                repeatMode: .one
            ))
        )
        XCTAssertEqual(
            PlaybackQueueRules.plan(
                intent: .cover, trackID: "b", list: ["a", "b"], currentID: "b", block: nil,
                shuffle: true, repeatMode: .all, rng: &rng
            ),
            .toggle
        )
        XCTAssertEqual(
            PlaybackQueueRules.plan(
                intent: .doubleClick, trackID: "b", list: ["a", "b"], currentID: "b", block: nil,
                shuffle: true, repeatMode: .all, rng: &rng
            ),
            .restart
        )

        var playAllRNG = ScriptedRNG(values: [2, 1])
        let played = PlaybackQueueRules.playAll(
            ids: ["bad", "a", "b"],
            isPlayable: { !$0.hasPrefix("bad") },
            shuffle: true,
            repeatMode: .off,
            rng: &playAllRNG
        )
        XCTAssertEqual(played?.skipped, 1)
        XCTAssertEqual(played?.queue.items, [.track("bad"), .track("a"), .track("b")])
        XCTAssertEqual(played?.queue.source, played?.queue.items)
        XCTAssertEqual(played?.queue.currentIndex, 1)
        XCTAssertEqual(played?.queue.shuffle, true)

        var ordered = ScriptedRNG(values: [0, 0])
        let straight = PlaybackQueueRules.playAll(
            ids: ["bad", "a", "b"],
            isPlayable: { !$0.hasPrefix("bad") },
            shuffle: false,
            repeatMode: .all,
            rng: &ordered
        )
        XCTAssertEqual(straight?.queue.items, [.track("bad"), .track("a"), .track("b")])
        XCTAssertEqual(straight?.queue.currentIndex, 1)
        XCTAssertEqual(straight?.queue.shuffle, false)
        XCTAssertEqual(straight?.queue.repeatMode, .all)
    }

    func testPageShuffleRejectsEmptyOrUnplayableAndLeavesTheQueue() {
        let current = PlaybackQueue(items: [.track("keep")], currentIndex: 0, shuffle: false, repeatMode: .one)
        var rng = ScriptedRNG(values: [0, 1, 2])
        var queue = current
        if let result = PlaybackQueueRules.playShuffled(
            ids: [],
            isPlayable: { _ in true },
            repeatMode: queue.repeatMode,
            rng: &rng
        ) {
            queue = result.queue
        }
        if let result = PlaybackQueueRules.playShuffled(
            ids: ["bad", "bad2"],
            isPlayable: { !$0.hasPrefix("bad") },
            repeatMode: queue.repeatMode,
            rng: &rng
        ) {
            queue = result.queue
        }
        XCTAssertEqual(queue, current)

        let already = PlaybackQueue(
            items: [.track("c"), .track("b"), .track("a")],
            currentIndex: 0,
            shuffle: true,
            repeatMode: .all
        )
        var identity = ScriptedRNG(values: [2, 1])
        let fresh = PlaybackQueueRules.playShuffled(
            ids: ["a", "b", "c"],
            isPlayable: { _ in true },
            repeatMode: already.repeatMode,
            rng: &identity
        )
        XCTAssertEqual(fresh?.queue.shuffle, true)
        XCTAssertEqual(fresh?.queue.repeatMode, .all)
        XCTAssertEqual(fresh?.queue.source, [.track("a"), .track("b"), .track("c")])
        XCTAssertEqual(fresh?.queue.items, [.track("a"), .track("b"), .track("c")])
        XCTAssertNotEqual(fresh?.queue.items, already.items)
        XCTAssertEqual(fresh?.skipped, 0)
        XCTAssertEqual(fresh?.queue.currentIndex, 0)
    }

    func testForwardWrapReshufflesWithTheTrackJustLeftAtTheEnd() {
        let queue = PlaybackQueue(
            items: [.track("a"), .track("b"), .track("c"), .track("d")],
            currentIndex: 0,
            shuffle: true,
            repeatMode: .all
        )
        XCTAssertEqual(
            PlaybackQueueRules.next(queue: queue, isPlayable: { _ in true }),
            .start(
                PlaybackQueue(items: queue.items, currentIndex: 1, shuffle: true, repeatMode: .all),
                skipped: 0
            )
        )

        let tail = PlaybackQueue(
            items: [.track("a"), .track("b"), .track("c"), .track("d")],
            source: [.track("a"), .track("b"), .track("c"), .track("d")],
            currentIndex: 3,
            shuffle: true,
            repeatMode: .all
        )
        var rng = ScriptedRNG(values: [0, 0, 0])
        let move = PlaybackQueueRules.next(queue: tail, isPlayable: { _ in true }, rng: &rng)
        guard case .start(let next, let skipped) = move else {
            XCTFail("expected a new cycle, got \(move)")
            return
        }
        XCTAssertEqual(skipped, 0)
        XCTAssertEqual(next.items, [.track("b"), .track("c"), .track("a"), .track("d")])
        XCTAssertNotEqual(next.items.first, .track("d"))
        XCTAssertEqual(next.items.last, .track("d"))
        XCTAssertEqual(next.current, .track("b"))
        XCTAssertEqual(next.source, tail.source)
        XCTAssertTrue(next.shuffle)

        var same = ScriptedRNG(values: [0, 0, 0])
        XCTAssertEqual(
            PlaybackQueueRules.naturalEnd(queue: tail, isPlayable: { _ in true }, rng: &same),
            move
        )

        let back = PlaybackQueueRules.previous(queue: next, positionMs: 0, isPlayable: { _ in true })
        guard case .start(let returned, _) = back else {
            XCTFail("expected previous to return to the track just left, got \(back)")
            return
        }
        XCTAssertEqual(returned.current, .track("d"))
        XCTAssertEqual(returned.items, next.items)
        let backAgain = PlaybackQueueRules.previous(queue: returned, positionMs: 0, isPlayable: { _ in true })
        guard case .start(let stepped, _) = backAgain else {
            XCTFail("expected a second previous along the new order, got \(backAgain)")
            return
        }
        XCTAssertEqual(stepped.items, next.items)
        XCTAssertEqual(stepped.current, next.items[next.items.count - 2])

        let mixed = PlaybackQueue(
            items: [.track("a"), .track("bad"), .track("c"), .track("d")],
            currentIndex: 3,
            shuffle: true,
            repeatMode: .all
        )
        var mixedRNG = ScriptedRNG(values: [0, 0, 0])
        let mixedMove = PlaybackQueueRules.next(queue: mixed, isPlayable: playableItem, rng: &mixedRNG)
        guard case .start(let mixedNext, _) = mixedMove else {
            XCTFail("expected a cycle that keeps unplayable rows, got \(mixedMove)")
            return
        }
        XCTAssertEqual(mixedNext.items, [.track("c"), .track("bad"), .track("a"), .track("d")])
        XCTAssertEqual(mixedNext.items.last, .track("d"))
        XCTAssertNotEqual(mixedNext.items.first, .track("d"))
        XCTAssertTrue(playableItem(mixedNext.items[0]))
    }

    func testPreviousAtHeadWithShuffleOnAndRepeatOffDoesNotWrap() {
        let queue = PlaybackQueue(
            items: [.track("b"), .track("a"), .track("c")],
            source: [.track("a"), .track("b"), .track("c")],
            currentIndex: 0,
            shuffle: true
        )
        XCTAssertEqual(
            PlaybackQueueRules.previous(queue: queue, positionMs: 0, isPlayable: { _ in true }),
            .stay(fullCircle: false)
        )
        XCTAssertEqual(
            PlaybackQueueRules.previous(queue: queue, positionMs: 2_000, isPlayable: { _ in true }),
            .stay(fullCircle: false)
        )
        XCTAssertEqual(
            PlaybackQueueRules.previous(queue: queue, positionMs: 2_001, isPlayable: { _ in true }),
            .restart
        )
        var repeating = queue
        repeating.repeatMode = .all
        repeating.items = [.track("b"), .track("a"), .track("bad")]
        XCTAssertEqual(
            PlaybackQueueRules.previous(queue: repeating, positionMs: 0, isPlayable: playableItem),
            .start(
                PlaybackQueue(
                    items: repeating.items,
                    source: repeating.source,
                    currentIndex: 1,
                    shuffle: true,
                    repeatMode: .all
                ),
                skipped: 1
            )
        )
    }

    func testSinglePlayableRepeatAllRestartsWithoutTheNothingMoreMove() {
        let queue = PlaybackQueue(items: [.track("a"), .track("bad")], currentIndex: 0, repeatMode: .all)
        XCTAssertEqual(PlaybackQueueRules.next(queue: queue, isPlayable: playableItem), .restart)
        XCTAssertEqual(PlaybackQueueRules.naturalEnd(queue: queue, isPlayable: playableItem), .restart)
        var shuffled = queue
        shuffled.shuffle = true
        XCTAssertEqual(PlaybackQueueRules.next(queue: shuffled, isPlayable: playableItem), .restart)
        XCTAssertNotEqual(
            PlaybackQueueRules.next(queue: shuffled, isPlayable: playableItem),
            .stay(fullCircle: true)
        )
    }

    private func playableItem(_ item: QueueItem) -> Bool {
        guard let id = item.trackID else { return true }
        return playable(id) == nil
    }

    func testPlaybackPreferencesRoundTripAndClamp() throws {
        let prefs = PlaybackPreferences(
            shuffle: true,
            repeatMode: .one,
            volume: 1.8,
            speakerMemory: -1
        )
        XCTAssertEqual(prefs.volume, 1)
        XCTAssertNil(prefs.speakerMemory)
        let data = try JSONEncoder().encode(prefs)
        let loaded = try JSONDecoder().decode(PlaybackPreferences.self, from: data)
        XCTAssertEqual(loaded.shuffle, true)
        XCTAssertEqual(loaded.repeatMode, .one)
        XCTAssertEqual(loaded.volume, 1)
        let partial = try JSONDecoder().decode(PlaybackPreferences.self, from: Data("{}".utf8))
        XCTAssertEqual(partial, .default)
    }
}

private struct ScriptedRNG: RandomNumberGenerator {
    var values: [UInt64]
    var index = 0

    mutating func next() -> UInt64 {
        guard !values.isEmpty else { return 0 }
        let value = values[index % values.count]
        index += 1
        return value
    }
}
