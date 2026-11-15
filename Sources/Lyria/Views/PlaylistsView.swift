import SwiftUI

struct PlaylistsView: View {
    @EnvironmentObject private var store: AppSession

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 16)]

    var body: some View {
        ScrollView {
        LazyVGrid(columns: columns, spacing: 16) {
            Button { store.createPlaylist() } label: {
                VStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(LyriaTheme.primary)
                    Text("新建播放列表")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LyriaTheme.foreground)
                }
                .frame(maxWidth: .infinity, minHeight: 196)
                .background(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(LyriaTheme.primary.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            ForEach(store.playlists) { playlist in
                PlaylistCard(playlist: playlist)
            }
        }
        .lyriaChromeContentPadding()
        }
    }
}

private struct PlaylistCard: View {
    let playlist: Playlist
    @EnvironmentObject private var store: AppSession

    var body: some View {
        Button { store.openPlaylist(playlist.id) } label: {
            VStack(alignment: .leading, spacing: 0) {
                CoverArt(seed: playlist.id, systemImage: "music.note.list", cornerRadius: 0)
                    .aspectRatio(1, contentMode: .fit)
                    .opacity(playlist.trackIDs.isEmpty ? 0.35 : 1)
                VStack(alignment: .leading, spacing: 3) {
                    Text(playlist.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LyriaTheme.foreground)
                        .lineLimit(1)
                    Text("\(playlist.trackIDs.count) 首")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(LyriaTheme.text2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(LyriaTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PlaylistDetailView: View {
    let playlistID: String
    @EnvironmentObject private var store: AppSession
    @State private var confirmDelete = false
    @State private var renaming = false
    @State private var nameDraft = ""

    var body: some View {
        if let playlist = store.playlist(playlistID) {
            let songs = store.tracks(in: playlist)
            ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DetailHero(
                    seed: playlist.id,
                    systemImage: "music.note.list",
                    eyebrow: "播放列表",
                    title: playlist.name,
                    subtitle: songs.isEmpty
                        ? "0 首"
                        : "\(songs.count) 首 · \(TimeFormat.words(ms: store.durationMs(of: playlist.trackIDs)))",
                    renaming: renaming ? $nameDraft : nil,
                    onCommitRename: commitRename,
                    onCancelRename: { renaming = false }
                ) {
                    if !songs.isEmpty {
                        PillButton(title: "全部播放", systemImage: "play.fill", prominent: true) {
                            store.playAll(songs)
                        }
                        PillButton(title: "随机", systemImage: "shuffle") {
                            store.playShuffled(songs)
                        }
                    }
                    PillButton(title: "编辑", systemImage: "pencil") {
                        nameDraft = playlist.name
                        renaming = true
                    }
                    PillButton(title: "删除", danger: true) { confirmDelete = true }
                }

                if songs.isEmpty {
                    EmptyState(
                        systemImage: "music.note.list",
                        title: "播放列表是空的",
                        message: "可在曲库里把歌曲加进来"
                    ) {
                        EmptyView()
                    }
                    .frame(minHeight: 220)
                } else {
                    TrackTableColumnHeader(
                        firstIsSelected: songs.first.map { store.selectedTrackIds.contains($0.id) } ?? false
                    )
                    TrackTable(tracks: songs, playlistID: playlist.id, fillsVertically: false)
                }
            }
            .lyriaChromeContentPadding()
            }
            .confirmationDialog("删除这个播放列表？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("删除「\(playlist.name)」", role: .destructive) {
                    store.deletePlaylist(playlist.id)
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("「\(playlist.name)」会从播放列表里移除。曲库里的歌曲还在。")
            }
        } else {
            EmptyState(systemImage: "music.note.list", title: "找不到这个播放列表") { EmptyView() }
                .lyriaChromeContentPadding()
        }
    }

    private func commitRename() {
        guard renaming else { return }
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        renaming = false
        guard !trimmed.isEmpty, let playlist = store.playlist(playlistID), trimmed != playlist.name else { return }
        store.renamePlaylist(playlist.id, to: trimmed)
    }
}
