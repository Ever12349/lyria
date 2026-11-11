import AppKit
import LyriaCore
import SwiftUI

enum TrackMenu {
    @MainActor
    @ViewBuilder
    static func items(track: Track, playlistID: String?, list: [Track]) -> some View {
        TrackMenuItems(track: track, playlistID: playlistID, list: list)
    }
}

private struct TrackMenuItems: View {
    let track: Track
    var playlistID: String?
    let list: [Track]
    @EnvironmentObject private var store: AppSession

    var body: some View {
        let targets = TrackSelection.menuTrackIDs(
            trackID: track.id,
            selected: store.selectedTrackIds,
            orderedIDs: store.selectionScopeIDs
        )
        let artistID = sharedID(in: targets, keyPath: \.artistId)
        let albumID = sharedID(in: targets, keyPath: \.albumId)

        Button("播放") { store.menuPlay(track, in: list) }
        Button("下一首播放") { store.playNext(targets) }
        Button("加入队列") { store.enqueue(targets) }
        Menu("加入播放列表") {
            if store.playlists.isEmpty {
                Button("没有播放列表") {}
                    .disabled(true)
            } else {
                ForEach(store.playlists) { playlist in
                    Button(playlist.name) {
                        store.addToPlaylist(targets, playlistID: playlist.id)
                    }
                }
            }
        }
        Divider()
        Button("前往艺人") {
            if let artistID { store.openArtist(artistID) }
        }
        .disabled(artistID == nil)
        Button("前往专辑") {
            if let albumID { store.openAlbum(albumID) }
        }
        .disabled(albumID == nil)
        if let revealTargets = revealTargets(in: targets), RevealInFinder.canShow(revealTargets) {
            Button("在访达中显示") {
                store.revealInFinder(targets)
            }
        }
        if let playlistID {
            Divider()
            Button("从播放列表移除") {
                store.removeFromPlaylist(targets, playlistID: playlistID)
            }
        }
        Button("从曲库移除", role: .destructive) {
            store.requestLibraryRemoval(targets)
        }
        .onAppear { store.prepareMenu(for: track.id) }
    }

    private func revealTargets(in ids: [String]) -> [RevealTarget]? {
        var rows: [RevealTarget] = []
        rows.reserveCapacity(ids.count)
        for id in ids {
            guard let row = store.track(id) ?? (id == track.id ? track : nil) else { return nil }
            rows.append(RevealTarget(missing: row.missing, path: row.path))
        }
        return rows
    }

    private func sharedID(in ids: [String], keyPath: KeyPath<Track, String?>) -> String? {
        var shared: String?
        for id in ids {
            let row = store.track(id) ?? (id == track.id ? track : nil)
            guard let row, let value = row[keyPath: keyPath] else { return nil }
            if let shared, shared != value { return nil }
            shared = value
        }
        return shared
    }
}

/// Only the table the user can see may publish `selectionScopeIDs`.
private struct TrackTableVisibleKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var trackTableIsVisible: Bool {
        get { self[TrackTableVisibleKey.self] }
        set { self[TrackTableVisibleKey.self] = newValue }
    }
}

/// Shared column geometry for the header and every row.
enum TrackTableMetrics {
    static let paddingH: CGFloat = 8
    static let paddingV: CGFloat = 6
    static let coverSize: CGFloat = 36
    static let coverGap: CGFloat = 10
    static let columnGap: CGFloat = 8
    static let metaMax: CGFloat = 120
    static let durationColumn: CGFloat = 96
    static let durationWidth: CGFloat = 44
    static let missingWidth: CGFloat = 56
    static let menuSize: CGFloat = 28
    static let menuGap: CGFloat = 2
    static let rowHeight: CGFloat = paddingV * 2 + coverSize
    static let headerHeight: CGFloat = 32

    struct Frames {
        var cover: CGRect
        var title: CGRect
        var artist: CGRect
        var album: CGRect
        var duration: CGRect
        var menu: CGRect
        var headerTitle: CGRect
        var headerArtist: CGRect
        var headerAlbum: CGRect
        var headerDuration: CGRect
    }

    static func frames(width: CGFloat, missing: Bool) -> Frames {
        let textH: CGFloat = 16
        let midY = (rowHeight - textH) / 2
        let menu = CGRect(
            x: max(paddingH, width - paddingH - menuSize),
            y: (rowHeight - menuSize) / 2,
            width: menuSize,
            height: menuSize
        )
        let durationW = missing ? missingWidth : durationWidth
        let duration = CGRect(
            x: menu.minX - menuGap - durationW,
            y: midY,
            width: durationW,
            height: textH
        )
        let rightLimit = width - paddingH - durationColumn - columnGap
        var artistW = metaMax
        var albumW = metaMax
        func titleWidth() -> CGFloat {
            rightLimit - paddingH - (coverSize + coverGap + columnGap + artistW + columnGap + albumW)
        }
        var titleW = titleWidth()
        if titleW < 0 {
            let overflow = -titleW
            artistW = max(0, metaMax - overflow / 2)
            albumW = max(0, metaMax - (overflow - (metaMax - artistW)))
            titleW = max(0, titleWidth())
        }
        let cover = CGRect(x: paddingH, y: paddingV, width: coverSize, height: coverSize)
        let title = CGRect(x: cover.maxX + coverGap, y: midY, width: titleW, height: textH)
        let artist = CGRect(x: title.maxX + columnGap, y: midY, width: artistW, height: textH)
        let album = CGRect(x: artist.maxX + columnGap, y: midY, width: albumW, height: textH)
        let headerY: CGFloat = 6
        return Frames(
            cover: cover,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            menu: menu,
            headerTitle: CGRect(x: title.minX, y: headerY, width: titleW, height: textH),
            headerArtist: CGRect(x: artist.minX, y: headerY, width: artistW, height: textH),
            headerAlbum: CGRect(x: album.minX, y: headerY, width: albumW, height: textH),
            headerDuration: CGRect(x: duration.minX, y: headerY, width: duration.width, height: textH)
        )
    }
}

struct TrackTableColumnHeader: View {
    var firstIsSelected: Bool

    var body: some View {
        GeometryReader { geo in
            let frames = TrackTableMetrics.frames(width: geo.size.width, missing: false)
            ZStack(alignment: .topLeading) {
                headerText("标题", frame: frames.headerTitle)
                headerText("艺人", frame: frames.headerArtist)
                headerText("专辑", frame: frames.headerAlbum)
                headerText("时长", frame: frames.headerDuration, trailing: true)
            }
        }
        .frame(height: TrackTableMetrics.headerHeight)
        .background(LyriaTheme.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(firstIsSelected ? 0.2 : 0.12))
                .frame(height: 1)
                .allowsHitTesting(false)
        }
    }

    private func headerText(_ title: String, frame: CGRect, trailing: Bool = false) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(LyriaTheme.text3)
            .lineLimit(1)
            .frame(width: frame.width, height: frame.height, alignment: trailing ? .trailing : .leading)
            .offset(x: frame.minX, y: frame.minY)
    }
}

/// Shared track list. `fillsVertically` scrolls inside the page; otherwise the table is only as tall as its rows.
struct TrackTable: View {
    let tracks: [Track]
    var playlistID: String? = nil
    var fillsVertically = true
    @EnvironmentObject private var store: AppSession
    @Environment(TransportState.self) private var transport
    @Environment(\.trackTableIsVisible) private var isVisible

    var body: some View {
        TrackTableRepresentable(
            tracks: tracks,
            playlistID: playlistID,
            fillsVertically: fillsVertically,
            selectedIDs: store.selectedTrackIds,
            currentID: transport.current?.id,
            playing: transport.playing,
            store: store
        )
        .frame(maxWidth: .infinity, maxHeight: fillsVertically ? .infinity : nil)
        .frame(height: fillsVertically ? nil : TrackTableMetrics.rowHeight * CGFloat(tracks.count))
        .onAppear(perform: publishScope)
        .onChange(of: isVisible) { _, _ in publishScope() }
        .onChange(of: tracks.map(\.id)) { _, _ in publishScope() }
    }

    private func publishScope() {
        guard isVisible else { return }
        store.noteSelectionScope(tracks.map(\.id))
    }
}
