import AppKit
import LyriaCore
import SwiftUI

enum TrackMenu {
    @MainActor
    @ViewBuilder
    static func items(track: Track, playlistID: String?) -> some View {
        TrackMenuItems(track: track, playlistID: playlistID)
    }
}

private struct TrackMenuItems: View {
    let track: Track
    var playlistID: String?
    @EnvironmentObject private var store: AppSession

    var body: some View {
        let targets = beginMenu()
        let artistID = sharedID(in: targets, keyPath: \.artistId)
        let albumID = sharedID(in: targets, keyPath: \.albumId)

        // TODO(engine): play, queue, and play-next.
        Button("播放") {}
            .disabled(true)
        Button("下一首播放") {}
            .disabled(true)
        Button("加入队列") {}
            .disabled(true)
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
        if let playlistID {
            Divider()
            Button("从播放列表移除") {
                store.removeFromPlaylist(targets, playlistID: playlistID)
            }
        }
        Button("从曲库移除", role: .destructive) {
            store.requestLibraryRemoval(targets)
        }
    }

    /// Menu contents follow the selection rule immediately. Highlight catches up on the next turn
    /// so opening the menu does not publish state during the menu's view update.
    private func beginMenu() -> [String] {
        let targets = TrackSelection.menuTrackIDs(
            trackID: track.id,
            selected: store.selectedTrackIds,
            orderedIDs: store.selectionScopeIDs
        )
        store.scheduleMenuSelection(for: track.id)
        return targets
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

struct TrackTable: View {
    let tracks: [Track]
    var playlistID: String? = nil
    var scrolls = true
    @EnvironmentObject private var store: AppSession
    @State private var scopeActive = false

    var body: some View {
        Group {
            if scrolls {
                ScrollView { rows }
            } else {
                rows
            }
        }
        .onAppear {
            scopeActive = true
            store.noteSelectionScope(trackIDs)
        }
        .onChange(of: trackIDs) { _, ids in
            guard scopeActive else { return }
            store.noteSelectionScope(ids)
        }
        .onDisappear {
            scopeActive = false
            store.trackTableFocused = false
        }
    }

    private var trackIDs: [String] { tracks.map(\.id) }

    private var rows: some View {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            Section {
                ForEach(tracks) { track in
                    TrackRow(track: track, playlistID: playlistID)
                }
            } header: {
                header
                    .background(LyriaTheme.background)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 10) {
                Color.clear.frame(width: 36, height: 1)
                Text("标题")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("艺人")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("专辑")
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 2) {
                Text("时长")
                    .frame(width: 44, alignment: .trailing)
                Color.clear.frame(width: 28, height: 1)
            }
            .frame(width: 96, alignment: .trailing)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(LyriaTheme.text3)
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
        }
    }
}

private struct TrackRow: View {
    let track: Track
    var playlistID: String? = nil
    @EnvironmentObject private var store: AppSession
    @State private var hovering = false

    private var isCurrent: Bool { false }
    private var isSelected: Bool { store.selectedTrackIds.contains(track.id) }

    var body: some View {
        rowContent
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                RowClickCatcher { flags in
                    select(flags: flags)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background {
                if isCurrent {
                    LyriaTheme.softAccentGradient
                } else if isSelected {
                    Color.white.opacity(0.07)
                } else if hovering {
                    Color.white.opacity(0.04)
                }
            }
            .overlay(alignment: .bottom) {
                if !isCurrent {
                    Rectangle()
                        .fill(Color.white.opacity(isSelected ? 0.2 : 0.08))
                        .frame(height: 1)
                }
            }
            .onHover { hovering = $0 }
            .contextMenu {
                TrackMenu.items(track: track, playlistID: playlistID)
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            HStack(spacing: 10) {
                coverButton
                Text(track.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LyriaTheme.foreground)
                    .lineLimit(1)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            metaButton(track.artistLabel, enabled: track.canOpenArtist) {
                if let id = track.artistId { store.openArtist(id) }
            }
            metaButton(track.albumLabel, enabled: track.canOpenAlbum) {
                if let id = track.albumId { store.openAlbum(id) }
            }

            HStack(spacing: 2) {
                Text(track.missing ? "文件缺失" : track.durationLabel)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(track.missing ? LyriaTheme.danger : LyriaTheme.text3)
                    .frame(width: track.missing ? 56 : 44, alignment: .trailing)
                    .allowsHitTesting(false)
                moreMenu
            }
            .frame(width: 96, alignment: .trailing)
        }
    }

    private var coverButton: some View {
        // TODO(engine): cover button plays or pauses.
        Button {} label: {
            CoverArt(seed: track.albumId ?? track.id, artworkPath: track.artworkPath, cornerRadius: 8)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .disabled(true)
        .accessibilityLabel(track.title)
    }

    private var moreMenu: some View {
        Menu {
            TrackMenu.items(track: track, playlistID: playlistID)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(hovering ? Color.white : LyriaTheme.text3)
                .frame(width: 28, height: 28)
                .opacity(hovering ? 1 : 0.45)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 28, height: 28)
        .accessibilityLabel("更多操作")
    }

    private func metaButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(enabled ? LyriaTheme.text2 : LyriaTheme.text3)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func select(flags: NSEvent.ModifierFlags) {
        let modifiers = flags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.control) { return }
        resignTextInput()
        store.clickTrack(
            track.id,
            command: modifiers.contains(.command),
            shift: modifiers.contains(.shift)
        )
    }

    private func resignTextInput() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        let responder = window.firstResponder
        if responder is NSTextView || responder is NSTextField {
            window.makeFirstResponder(nil)
        }
    }
}

/// Left clicks report modifier flags. Right-clicks pass upward so the row context menu can open.
private struct RowClickCatcher: NSViewRepresentable {
    var onClick: (NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> RowClickCatcherView {
        let view = RowClickCatcherView()
        view.onClick = onClick
        return view
    }

    func updateNSView(_ nsView: RowClickCatcherView, context: Context) {
        nsView.onClick = onClick
    }
}

private final class RowClickCatcherView: NSView {
    var onClick: ((NSEvent.ModifierFlags) -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            rightMouseDown(with: event)
            return
        }
        onClick?(event.modifierFlags)
    }

    override func rightMouseDown(with event: NSEvent) {
        superview?.rightMouseDown(with: event)
    }
}
