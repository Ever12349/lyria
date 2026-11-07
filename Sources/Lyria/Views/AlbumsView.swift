import SwiftUI

struct AlbumsView: View {
    @EnvironmentObject private var store: FakeLibraryStore

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(store.albums) { album in
                    AlbumCard(album: album)
                }
            }
        }
    }
}

struct AlbumDetailView: View {
    let albumID: String
    @EnvironmentObject private var store: FakeLibraryStore

    var body: some View {
        if let album = store.album(albumID) {
            let songs = store.tracks(forAlbum: album.name)
            ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DetailHero(
                    seed: album.id,
                    eyebrow: "专辑",
                    title: album.name,
                    subtitle: "\(album.artistName) · \(album.year) · \(songs.count) 首"
                ) {
                    PillButton(title: "全部播放", systemImage: "play.fill", prominent: true) {
                        store.playAll(songs.map(\.id), shuffled: false)
                    }
                    PillButton(title: "随机", systemImage: "shuffle") {
                        store.playAll(songs.map(\.id), shuffled: true)
                    }
                    PillButton(title: "加入队列", systemImage: "plus") {
                        store.enqueueAll(songs.map(\.id))
                    }
                }

                if songs.isEmpty {
                    Text("这张专辑还没有曲目")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(LyriaTheme.text2)
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    TrackTable(tracks: songs, scrolls: false)
                }
            }
            }
        } else {
            EmptyState(systemImage: "opticaldisc", title: "找不到这张专辑") { EmptyView() }
        }
    }
}
