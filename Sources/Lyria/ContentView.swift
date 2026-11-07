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
                .padding(.vertical, LyriaTheme.sidebarInset)

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
            HStack {
                Spacer(minLength: 0)
                SearchField(text: $store.searchText)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 36)
            .padding(.bottom, 8)

            PageHeader(
                title: headerTitle,
                subtitle: headerSubtitle,
                showsBack: showsBack,
                onBack: { store.goBack() }
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            ZStack(alignment: .topTrailing) {
                contentPanel
                if store.queueVisible {
                    QueuePanel()
                        .frame(width: 280)
                        .padding(.trailing, 8)
                        .padding(.vertical, 6)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .animation(.easeOut(duration: 0.18), value: store.queueVisible)

            TransportBar()
        }
        .overlay(alignment: .bottom) {
            if let toast = store.toast {
                ToastPill(text: toast)
                    .padding(.bottom, 118)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.18), value: store.toast)
    }

    private var contentPanel: some View {
        GeometryReader { geo in
            ScrollView {
                page
                    .padding(centersContent ? 0 : 12)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: max(geo.size.height - (centersContent ? 0 : 24), 0),
                        alignment: centersContent ? .center : .topLeading
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: LyriaTheme.radiusMD, style: .continuous)
                .fill(LyriaTheme.panel.opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LyriaTheme.radiusMD, style: .continuous)
                .strokeBorder(LyriaTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: LyriaTheme.radiusMD, style: .continuous))
    }

    @ViewBuilder
    private var page: some View {
        if store.isSearching {
            SearchResultsView()
        } else {
            switch store.route {
            case .library:
                if store.tracks.isEmpty {
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

    private var centersContent: Bool {
        if store.isSearching { return !store.hasSearchHits }
        if case .library = store.route { return store.tracks.isEmpty }
        return false
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

    private var headerSubtitle: String? {
        if store.isSearching { return "「\(store.trimmedQuery)」" }
        switch store.route {
        case .library where !store.tracks.isEmpty:
            return "\(store.tracks.count) 首"
        case .artists:
            return "\(store.artists.count) 位"
        case .albums:
            return "\(store.albums.count) 张"
        case .playlists:
            return "\(store.playlists.count) 个"
        default:
            return nil
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 1180, height: 760)
}
