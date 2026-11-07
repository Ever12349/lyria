import SwiftUI

struct ContentView: View {
    @StateObject private var store = FakeLibraryStore()
    @State private var sidebarWidth: CGFloat = 228

    private let sidebarMin: CGFloat = 168
    private let sidebarMax: CGFloat = 320

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: sidebarWidth)
                .padding(.leading, LyriaTheme.sidebarInset)
                .padding(.bottom, LyriaTheme.sidebarInset)
                .ignoresSafeArea(edges: .top)

            SidebarResizeHandle(
                sidebarWidth: $sidebarWidth,
                minWidth: sidebarMin,
                maxWidth: sidebarMax
            )
            .frame(width: 12)
            .frame(maxHeight: .infinity)

            detailColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environmentObject(store)
        .background(windowBackground)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbarColorScheme(.dark, for: .windowToolbar)
        .preferredColorScheme(.dark)
        .background(WindowChromeConfigurer())
    }

    private var windowBackground: some View {
        ZStack {
            LyriaTheme.background
            RadialGradient(
                colors: [LyriaTheme.primaryDeep.opacity(0.22), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 520
            )
            RadialGradient(
                colors: [LyriaTheme.primary.opacity(0.08), .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var detailColumn: some View {
        VStack(spacing: 0) {
            pageHead
            ZStack(alignment: .topTrailing) {
                page
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 4)
                if store.queueVisible {
                    QueuePanel()
                        .frame(width: 280)
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.18), value: store.queueVisible)
            TransportBar()
        }
        .padding(.top, 12)
        .padding(.trailing, 16)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            if let toast = store.toast {
                ToastPill(text: toast)
                    .padding(.bottom, 106)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.18), value: store.toast)
    }

    private var pageHead: some View {
        GeometryReader { geo in
            let searchWidth = min(360, geo.size.width * 0.46)
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 2) {
                        if showsBack {
                            Button { store.goBack() } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(LyriaTheme.text2)
                                    .frame(width: 22, height: 22)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("返回")
                        }
                        Text(headerTitle)
                            .font(.system(size: 22, weight: .semibold))
                            .tracking(-0.4)
                            .foregroundStyle(LyriaTheme.foreground)
                            .lineLimit(1)
                    }
                    Text(headerMeta)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LyriaTheme.text3)
                        .lineLimit(1)
                        .padding(.leading, showsBack ? 20 : 0)
                        .frame(maxWidth: .infinity, minHeight: 16, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                SearchField(text: queryBinding)
                    .frame(width: searchWidth)
            }
        }
        .frame(height: 52)
        .padding(.horizontal, 4)
        .padding(.bottom, 10)
    }

    private var queryBinding: Binding<String> {
        Binding(get: { store.searchText }, set: { store.updateQuery($0) })
    }

    @ViewBuilder
    private var page: some View {
        if store.isSearching {
            SearchResultsView()
        } else {
            switch store.route {
            case .library:
                if store.libraryEmpty || store.visibleTracks.isEmpty {
                    LibraryEmptyView()
                } else {
                    LibraryView()
                }
            case .artists:
                ArtistsView()
            case .artist(let id):
                ArtistDetailView(artistID: id)
            case .albums:
                AlbumsView()
            case .album(let id):
                AlbumDetailView(albumID: id)
            case .playlists:
                PlaylistsView()
            case .playlist(let id):
                PlaylistDetailView(playlistID: id)
            case .settings:
                SettingsView()
            }
        }
    }

    private var showsBack: Bool {
        store.isSearching || store.route.showsBack
    }

    private var headerTitle: String {
        if store.isSearching { return "搜索" }
        switch store.route {
        case .library: return "曲库"
        case .artists, .artist: return "艺人"
        case .albums, .album: return "专辑"
        case .playlists, .playlist: return "播放列表"
        case .settings: return "设置"
        }
    }

    private var headerMeta: String {
        if store.isSearching {
            return store.hasSearchHits ? "\(store.searchTracks.count) 首" : "无结果"
        }
        if case .library = store.route, !store.libraryEmpty, !store.visibleTracks.isEmpty {
            return "\(store.visibleTracks.count) 首"
        }
        return " "
    }
}

#Preview {
    ContentView()
        .frame(width: 1180, height: 760)
}
