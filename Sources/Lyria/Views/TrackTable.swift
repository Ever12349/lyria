import SwiftUI

enum TrackMenu {
    @MainActor
    @ViewBuilder
    static func items(
        track: Track,
        playlistID: String?,
        store: AppSession,
        requestRemoveFromLibrary: @escaping () -> Void
    ) -> some View {
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
                    Button(playlist.name) { store.add(track.id, to: playlist.id) }
                }
            }
        }
        Divider()
        Button("前往艺人") {
            if let id = track.artistId { store.openArtist(id) }
        }
        .disabled(!track.canOpenArtist)
        Button("前往专辑") {
            if let id = track.albumId { store.openAlbum(id) }
        }
        .disabled(!track.canOpenAlbum)
        if let playlistID {
            Divider()
            Button("从播放列表移除") { store.remove(track.id, from: playlistID) }
        }
        Button("从曲库移除", role: .destructive) { requestRemoveFromLibrary() }
    }
}

struct TrackTable: View {
    let tracks: [Track]
    var playlistID: String? = nil
    var scrolls = true
    @EnvironmentObject private var store: AppSession

    var body: some View {
        if scrolls {
            ScrollView {
                rows
            }
        } else {
            rows
        }
    }

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
    @State private var confirmRemove = false

    private var isCurrent: Bool { false }
    private var isSelected: Bool { track.id == store.selectedTrackId }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 10) {
                coverButton
                Text(track.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LyriaTheme.foreground)
                    .lineLimit(1)
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
                moreMenu
            }
            .frame(width: 96, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
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
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { store.selectedTrackId = track.id }
        .contextMenu {
            TrackMenu.items(track: track, playlistID: playlistID, store: store) {
                confirmRemove = true
            }
        }
        .confirmationDialog("从曲库移除「\(track.title)」？", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("从曲库移除", role: .destructive) { store.removeFromLibrary(track.id) }
            Button("取消", role: .cancel) {}
        } message: {
            Text("文件会留在磁盘上。这一首会从曲库和播放列表里删掉，再次导入仍使用原来的 id。")
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
            TrackMenu.items(track: track, playlistID: playlistID, store: store) {
                confirmRemove = true
            }
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
}

