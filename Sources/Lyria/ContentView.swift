import SwiftUI

struct ContentView: View {
    @State private var selection: NavItem = .library
    @State private var sidebarWidth: CGFloat = 228
    @State private var selectedTrackId: String? = FakeData.nowPlayingId
    @State private var isPlaying = true
    @State private var progress = 0.37
    @State private var volume = 0.72
    @State private var shuffleOn = false
    @State private var repeatOn = true
    @State private var searchText = ""

    private let sidebarMin: CGFloat = 168
    private let sidebarMax: CGFloat = 320

    private var nowPlaying: Track? {
        FakeData.tracks.first { $0.id == FakeData.nowPlayingId }
    }

    private var filteredTracks: [Track] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return FakeData.tracks }
        return FakeData.tracks.filter {
            $0.title.localizedCaseInsensitiveContains(q)
                || $0.subtitle.localizedCaseInsensitiveContains(q)
                || $0.artist.localizedCaseInsensitiveContains(q)
                || $0.album.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selection: $selection)
                .frame(width: sidebarWidth)
                .frame(maxHeight: .infinity)

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
        .background(
            ZStack {
                LyriaTheme.background
                RadialGradient(
                    colors: [LyriaTheme.primaryDeep.opacity(0.18), .clear],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 520
                )
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        )
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbarColorScheme(.dark, for: .windowToolbar)
        .preferredColorScheme(.dark)
        .background(WindowChromeConfigurer())
    }

    private var detailColumn: some View {
        VStack(spacing: 0) {
            Group {
                switch selection {
                case .library:
                    LibraryView(
                        tracks: filteredTracks,
                        nowPlayingId: FakeData.nowPlayingId,
                        selectedTrackId: $selectedTrackId,
                        searchText: $searchText
                    )
                case .artists, .albums, .playlists, .settings:
                    placeholder(for: selection)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TransportBar(
                track: nowPlaying,
                isPlaying: $isPlaying,
                progress: $progress,
                volume: $volume,
                shuffleOn: $shuffleOn,
                repeatOn: $repeatOn
            )
            .frame(minHeight: 96)
        }
        .background(LyriaTheme.background.opacity(0.82))
    }

    private func placeholder(for item: NavItem) -> some View {
        VStack(spacing: 14) {
            Image(systemName: item.systemImage)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(LyriaTheme.primary)
            Text(item.rawValue)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(LyriaTheme.foreground)
            Text("静态样例页 · 尚未实现")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(LyriaTheme.mutedForeground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .frame(width: 1180, height: 760)
}
