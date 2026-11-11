import SwiftUI

struct ArtistsView: View {
    @EnvironmentObject private var store: AppSession

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 16)]

    var body: some View {
        ScrollView {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(store.artists) { artist in
                let count = store.tracks(artistID: artist.id).count
                Button { store.openArtist(artist.id) } label: {
                    VStack(spacing: 8) {
                        CoverArt(seed: artist.id, systemImage: "person.fill", circle: true)
                            .frame(width: 96, height: 96)
                            .padding(.top, 16)
                        Text(artist.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LyriaTheme.foreground)
                            .lineLimit(1)
                        Text("\(count) 首")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(LyriaTheme.text2)
                            .padding(.bottom, 14)
                    }
                    .frame(maxWidth: .infinity)
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
        }
    }
}

struct ArtistDetailView: View {
    let artistID: String
    @EnvironmentObject private var store: AppSession

    var body: some View {
        if let artist = store.artist(artistID) {
            let songs = store.tracks(artistID: artist.id)
            let albums = store.albums(artistID: artist.id)
            ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DetailHero(
                    seed: artist.id,
                    systemImage: "person.fill",
                    circle: true,
                    eyebrow: "艺人",
                    title: artist.name,
                    subtitle: "\(albums.count) 张专辑 · \(songs.count) 首曲目"
                ) {
                    PillButton(title: "全部播放", systemImage: "play.fill", prominent: true) {
                        store.playAll(songs)
                    }
                    PillButton(title: "随机播放", systemImage: "shuffle") {}
                        .disabled(true)
                }

                SectionLabel(title: "专辑")
                if albums.isEmpty {
                    Text("还没有专辑")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(LyriaTheme.text2)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(albums) { album in
                                AlbumCard(album: album)
                                    .frame(width: 168)
                            }
                        }
                        .padding(.bottom, 4)
                    }
                }

                SectionLabel(title: "热门曲目")
                if songs.isEmpty {
                    Text("曲库里还没有这个艺人的曲目")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(LyriaTheme.text2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                } else {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            TrackTable(tracks: songs, fillsVertically: false)
                        } header: {
                            TrackTableColumnHeader(
                                firstIsSelected: songs.first.map { store.selectedTrackIds.contains($0.id) } ?? false
                            )
                        }
                    }
                }
            }
            }
        } else {
            EmptyState(systemImage: "person", title: "找不到这位艺人") { EmptyView() }
        }
    }
}

struct AlbumCard: View {
    let album: Album
    @EnvironmentObject private var store: AppSession

    var body: some View {
        Button { store.openAlbum(album.id) } label: {
            VStack(alignment: .leading, spacing: 0) {
                CoverArt(seed: album.id, artworkPath: album.artworkPath, cornerRadius: 0)
                    .aspectRatio(1, contentMode: .fit)
                VStack(alignment: .leading, spacing: 3) {
                    Text(album.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LyriaTheme.foreground)
                        .lineLimit(1)
                    Text(album.artistLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(LyriaTheme.text2)
                        .lineLimit(1)
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
