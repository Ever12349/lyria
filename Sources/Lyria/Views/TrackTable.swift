import SwiftUI

enum TrackMenu {
    @MainActor
    @ViewBuilder
    static func items(track: Track, playlistID: String?, store: FakeLibraryStore) -> some View {
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
            Button("上移") { store.move(trackID: track.id, in: playlistID, direction: -1) }
            Button("下移") { store.move(trackID: track.id, in: playlistID, direction: 1) }
            Button("从播放列表移除") { store.remove(track.id, from: playlistID) }
        }
    }
}

struct TrackTable: View {
    let tracks: [Track]
    var playlistID: String? = nil
    @EnvironmentObject private var store: FakeLibraryStore

    var body: some View {
        VStack(spacing: 6) {
            header
            ForEach(tracks) { track in
                TrackRow(track: track, playlistID: playlistID)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: 40, height: 1)
            Text("标题")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("艺人")
                .frame(width: 120, alignment: .leading)
            Text("专辑")
                .frame(width: 130, alignment: .leading)
            Text("时长")
                .frame(width: 48, alignment: .trailing)
            Color.clear.frame(width: 28, height: 1)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(LyriaTheme.text3)
        .padding(.horizontal, 12)
        .padding(.bottom, 2)
    }
}

private struct TrackRow: View {
    let track: Track
    var playlistID: String? = nil
    @EnvironmentObject private var store: FakeLibraryStore

    private var isNowPlaying: Bool { track.id == store.nowPlayingId }
    private var isSelected: Bool { track.id == store.selectedTrackId }

    var body: some View {
        HStack(spacing: 10) {
            Button { store.play(track.id) } label: {
                CoverArt(seed: track.id)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("播放\(track.title)")

            HStack(spacing: 6) {
                if isNowPlaying {
                    Image(systemName: "waveform")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LyriaTheme.primary)
                        .accessibilityLabel("正在播放")
                }
                Text(track.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LyriaTheme.foreground)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(track.artist)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(LyriaTheme.text2)
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)

            Text(track.album)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(LyriaTheme.text2)
                .lineLimit(1)
                .frame(width: 130, alignment: .leading)

            Text(track.durationLabel)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(LyriaTheme.text3)
                .frame(width: 48, alignment: .trailing)

            Menu {
                TrackMenu.items(track: track, playlistID: playlistID, store: store)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LyriaTheme.text2)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 28, height: 28)
            .accessibilityLabel("更多")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(rowFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isNowPlaying ? LyriaTheme.primary.opacity(0.55) : LyriaTheme.border, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(count: 2) { store.play(track.id) }
        .onTapGesture { store.selectedTrackId = track.id }
        .contextMenu {
            TrackMenu.items(track: track, playlistID: playlistID, store: store)
        }
    }

    private var rowFill: AnyShapeStyle {
        if isNowPlaying { return AnyShapeStyle(LyriaTheme.softAccentGradient) }
        if isSelected { return AnyShapeStyle(Color.white.opacity(0.07)) }
        return AnyShapeStyle(Color.white.opacity(0.03))
    }
}
