import SwiftUI

enum TrackMenu {
    @MainActor
    @ViewBuilder
    static func items(
        track: Track,
        playlistID: String?,
        store: FakeLibraryStore,
        requestRemoveFromLibrary: @escaping () -> Void
    ) -> some View {
        Button("播放") { store.play(track.id) }
        Button("下一首播放") { store.playNext(track.id) }
        Button("加入队列") { store.enqueue(track.id) }
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
        Button("前往艺人") { store.openArtist(named: track.artist) }
        Button("前往专辑") { store.openAlbum(named: track.album) }
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
    @EnvironmentObject private var store: FakeLibraryStore

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
    @EnvironmentObject private var store: FakeLibraryStore
    @State private var hovering = false
    @State private var confirmRemove = false

    private var isCurrent: Bool { track.id == store.nowPlayingId && store.shownTrack != nil }
    private var isSelected: Bool { track.id == store.selectedTrackId && !isCurrent }

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

            metaButton(track.artist) { store.openArtist(named: track.artist) }
            metaButton(track.album) { store.openAlbum(named: track.album) }

            HStack(spacing: 2) {
                Text(track.durationLabel)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(LyriaTheme.text3)
                    .frame(width: 44, alignment: .trailing)
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
        .onTapGesture(count: 2) { store.play(track.id, announce: false) }
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
            Text("文件仍会留在磁盘上。")
        }
    }

    private var coverButton: some View {
        let showPause = isCurrent && store.isPlaying
        return Button {
            if isCurrent { store.togglePlay() }
            else { store.play(track.id, announce: false) }
        } label: {
            ZStack {
                if isCurrent {
                    EqBars(live: store.isPlaying)
                        .opacity(hovering ? 0 : 1)
                }
                Image(systemName: showPause ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 10 / 255, green: 11 / 255, blue: 26 / 255).opacity(hovering ? 0.45 : 0))
                    .opacity(hovering || !isCurrent ? (hovering ? 1 : 0) : 0)
            }
            .frame(width: 36, height: 36)
            .background(LyriaTheme.coverGradient(seed: track.albumId))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showPause ? "暂停 \(track.title)" : "播放 \(track.title)")
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

    private func metaButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(LyriaTheme.text2)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

private struct EqBars: View {
    var live: Bool
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            bar(0.40, delay: 0)
            bar(0.90, delay: 0.15)
            bar(0.60, delay: 0.30)
            bar(1.00, delay: 0.08)
        }
        .frame(width: 16, height: 16)
        .onAppear { animating = true }
    }

    private func bar(_ scale: CGFloat, delay: Double) -> some View {
        Capsule()
            .fill(Color.white)
            .frame(width: 3, height: 14 * scale)
            .scaleEffect(y: live && animating ? 1 : 0.35, anchor: .bottom)
            .animation(
                live ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true).delay(delay) : .default,
                value: animating
            )
    }
}
