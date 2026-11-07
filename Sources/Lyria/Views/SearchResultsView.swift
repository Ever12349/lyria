import SwiftUI

struct SearchResultsView: View {
    @EnvironmentObject private var store: FakeLibraryStore

    var body: some View {
        if hits.isEmpty {
            EmptyState(
                systemImage: "magnifyingglass",
                title: "无搜索结果",
                message: "找不到与「\(store.trimmedQuery)」匹配的音乐、艺人或专辑。"
            ) { EmptyView() }
        } else {
            VStack(alignment: .leading, spacing: 18) {
                if !hits.tracks.isEmpty {
                    SectionLabel(title: "曲目")
                    TrackTable(tracks: hits.tracks)
                }
                if !hits.artists.isEmpty {
                    SectionLabel(title: "艺人")
                    VStack(spacing: 6) {
                        ForEach(hits.artists) { artist in
                            entityRow(
                                seed: artist.id,
                                systemImage: "person.fill",
                                circle: true,
                                title: artist.name,
                                subtitle: "\(store.tracks(forArtist: artist.name).count) 首"
                            ) { store.openArtist(artist.id) }
                        }
                    }
                }
                if !hits.albums.isEmpty {
                    SectionLabel(title: "专辑")
                    VStack(spacing: 6) {
                        ForEach(hits.albums) { album in
                            entityRow(
                                seed: album.id,
                                systemImage: "opticaldisc",
                                title: album.name,
                                subtitle: album.artistName
                            ) { store.openAlbum(album.id) }
                        }
                    }
                }
                if !hits.playlists.isEmpty {
                    SectionLabel(title: "播放列表")
                    VStack(spacing: 6) {
                        ForEach(hits.playlists) { playlist in
                            entityRow(
                                seed: playlist.id,
                                systemImage: "music.note.list",
                                title: playlist.name,
                                subtitle: "\(playlist.trackIDs.count) 首"
                            ) { store.openPlaylist(playlist.id) }
                        }
                    }
                }
            }
        }
    }

    private var hits: Hits {
        let query = store.trimmedQuery
        func matches(_ text: String) -> Bool {
            text.localizedCaseInsensitiveContains(query)
        }
        return Hits(
            tracks: store.tracks.filter { matches($0.title) || matches($0.artist) || matches($0.album) },
            artists: store.artists.filter { matches($0.name) },
            albums: store.albums.filter { matches($0.name) || matches($0.artistName) },
            playlists: store.playlists.filter { matches($0.name) }
        )
    }

    private func entityRow(
        seed: String,
        systemImage: String,
        circle: Bool = false,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                CoverArt(seed: seed, systemImage: systemImage, circle: circle)
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LyriaTheme.foreground)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(LyriaTheme.text2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LyriaTheme.text3)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(LyriaTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private struct Hits {
        var tracks: [Track]
        var artists: [Artist]
        var albums: [Album]
        var playlists: [Playlist]

        var isEmpty: Bool {
            tracks.isEmpty && artists.isEmpty && albums.isEmpty && playlists.isEmpty
        }
    }
}
