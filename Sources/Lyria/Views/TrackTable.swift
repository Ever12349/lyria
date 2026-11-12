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
    static let paddingH = CGFloat(TrackTableLayout.paddingH)
    static let paddingV = CGFloat(TrackTableLayout.paddingV)
    static let coverSize = CGFloat(TrackTableLayout.coverSize)
    static let coverGap = CGFloat(TrackTableLayout.coverGap)
    static let columnGap = CGFloat(TrackTableLayout.columnGap)
    static let metaMax = CGFloat(TrackTableLayout.metaMax)
    static let durationColumn = CGFloat(TrackTableLayout.durationColumn)
    static let durationWidth = CGFloat(TrackTableLayout.durationWidth)
    static let missingWidth = CGFloat(TrackTableLayout.missingWidth)
    static let menuSize = CGFloat(TrackTableLayout.menuSize)
    static let menuGap = CGFloat(TrackTableLayout.menuGap)
    static let rowHeight = CGFloat(TrackTableLayout.rowHeight)
    static let headerHeight = CGFloat(TrackTableLayout.headerHeight)

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
        let laidOut = TrackTableLayout.frames(width: Double(width), missing: missing)
        return Frames(
            cover: rect(laidOut.cover),
            title: rect(laidOut.title),
            artist: rect(laidOut.artist),
            album: rect(laidOut.album),
            duration: rect(laidOut.duration),
            menu: rect(laidOut.menu),
            headerTitle: rect(laidOut.headerTitle),
            headerArtist: rect(laidOut.headerArtist),
            headerAlbum: rect(laidOut.headerAlbum),
            headerDuration: rect(laidOut.headerDuration)
        )
    }

    private static func rect(_ source: TrackTableLayout.Rect) -> CGRect {
        CGRect(
            x: CGFloat(source.x),
            y: CGFloat(source.y),
            width: CGFloat(source.width),
            height: CGFloat(source.height)
        )
    }
}

struct TrackTableColumnHeader: View {
    var firstIsSelected: Bool
    var showsHairline = true
    var fillsBackground = true

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
        .background(fillsBackground ? LyriaTheme.background : Color.clear)
        .overlay(alignment: .bottom) {
            if showsHairline {
                Rectangle()
                    .fill(Color.white.opacity(firstIsSelected ? 0.2 : 0.12))
                    .frame(height: 1)
                    .allowsHitTesting(false)
            }
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

/// Shared track list. `fillsVertically` scrolls inside the page with a top inset under the title bar; otherwise the table is only as tall as its rows.
struct TrackTable: View {
    let tracks: [Track]
    var playlistID: String? = nil
    var fillsVertically = true
    @EnvironmentObject private var store: AppSession
    @Environment(TransportState.self) private var transport
    @Environment(\.trackTableIsVisible) private var isVisible
    @Environment(\.lyriaChromeTopInset) private var chromeTop

    var body: some View {
        TrackTableRepresentable(
            tracks: tracks,
            playlistID: playlistID,
            fillsVertically: fillsVertically,
            chromeTop: fillsVertically ? chromeTop : 0,
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
