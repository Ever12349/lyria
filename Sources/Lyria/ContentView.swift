import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var store: AppSession

    init(store: AppSession) {
        _store = StateObject(wrappedValue: store)
    }
    @State private var sidebarWidth: CGFloat = 228
    @State private var keyMonitor: Any?
    @State private var searchFieldExpanded = false
    @State private var batchCapsuleWidth: CGFloat = 0

    private let sidebarMin: CGFloat = 168
    private let sidebarMax: CGFloat = 320

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            SidebarView()
                .frame(width: sidebarWidth)
                .padding(.leading, LyriaTheme.sidebarInset)
                .padding(.top, LyriaTheme.sidebarInset)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environmentObject(store)
        .background(windowBackground)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbarColorScheme(.dark, for: .windowToolbar)
        .preferredColorScheme(.dark)
        .background(WindowChromeConfigurer())
        .task { await store.bootstrap() }
        .onAppear(perform: installKeyMonitor)
        .onDisappear(perform: removeKeyMonitor)
        .confirmationDialog(
            store.libraryRemovalPrompt?.title ?? "从曲库移除？",
            isPresented: removalPresented,
            titleVisibility: .visible
        ) {
            Button("取消", role: .cancel) {}
            Button("仅从曲库移除") { store.commitLibraryRemoval() }
            Button("移到废纸篓", role: .destructive) { store.commitLibraryRemovalToTrash() }
        } message: {
            Text(store.libraryRemovalPrompt?.message ?? "")
        }
    }

    private var removalPresented: Binding<Bool> {
        Binding(
            get: { store.libraryRemovalPrompt != nil },
            set: { presented in
                if !presented { store.libraryRemovalPrompt = nil }
            }
        )
    }

    private func installKeyMonitor() {
        KeyMonitor.session = store
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Local monitors run on the main thread and must return synchronously.
            MainActor.assumeIsolated {
                KeyMonitor.handle(event)
            }
        }
    }

    private func removeKeyMonitor() {
        KeyMonitor.session = nil
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
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
            if showsScanProgress {
                ScanProgressBar(percent: store.scanSession.percent, onCancel: store.cancelScan)
            }
            ZStack(alignment: .topTrailing) {
                page
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 4)
                    .animation(nil, value: store.queueVisible)
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
            ZStack {
                if let toast = store.toast {
                    ToastPill(text: toast)
                        .padding(.bottom, 106)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeOut(duration: 0.18), value: store.toast)
        }
    }

    private var pageHead: some View {
        GeometryReader { geo in
            let restingSearchWidth = min(360, geo.size.width * 0.46)
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
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .layoutPriority(0)

                if store.showsBatchBar {
                    BatchActionBar(playlistID: batchPlaylistID)
                        .background {
                            GeometryReader { proxy in
                                Color.clear.preference(key: BatchCapsuleWidthKey.self, value: proxy.size.width)
                            }
                        }
                        .layoutPriority(2)
                        .transition(.opacity)
                        .animation(.easeOut(duration: 0.18), value: store.showsBatchBar)
                }

                SearchField(
                    text: queryBinding,
                    allowsCompact: store.showsBatchBar,
                    expanded: $searchFieldExpanded
                )
                .frame(width: searchLayoutWidth(rowWidth: geo.size.width, resting: restingSearchWidth))
                .layoutPriority(1)
            }
            .onPreferenceChange(BatchCapsuleWidthKey.self) { width in
                guard width > 1, abs(width - batchCapsuleWidth) > 0.5 else { return }
                batchCapsuleWidth = width
            }
            .animation(.easeOut(duration: 0.18), value: store.showsBatchBar)
            .animation(.easeOut(duration: 0.18), value: searchFieldExpanded)
        }
        .frame(height: 52)
        .padding(.horizontal, 4)
        .padding(.bottom, 10)
    }

    /// Resting search keeps the 46% / 360 cap. With the capsule, an empty field is 36pt; otherwise it uses leftover space up to 360.
    private func searchLayoutWidth(rowWidth: CGFloat, resting: CGFloat) -> CGFloat {
        if !store.showsBatchBar { return resting }
        if store.searchText.isEmpty && !searchFieldExpanded { return 36 }
        let gaps: CGFloat = 16 * 2
        let titleFloor: CGFloat = 88
        let leftover = rowWidth - batchCapsuleWidth - titleFloor - gaps
        return min(360, max(36, leftover))
    }

    private var queryBinding: Binding<String> {
        Binding(get: { store.searchText }, set: { store.updateQuery($0) })
    }

    private var page: some View {
        ZStack {
            ForEach(NavItem.allCases) { item in
                mountedSection(item)
            }
            if store.isSearching {
                SearchResultsView()
            }
        }
    }

    private func mountedSection(_ item: NavItem) -> some View {
        let routes = store.routes(in: item)
        let active = store.currentSection == item && !store.isSearching
        return ZStack {
            ForEach(routes, id: \.stackKey) { route in
                routePage(route)
                    .id(store.pageIdentity(item, route))
                    .opacity(active && route == routes.last ? 1 : 0)
                    .allowsHitTesting(active && route == routes.last)
                    .accessibilityHidden(!active || route != routes.last)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(active)
        .accessibilityHidden(!active)
    }

    @ViewBuilder
    private func routePage(_ route: AppRoute) -> some View {
        switch route {
        case .library:
            if store.visibleTracks.isEmpty {
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

    private var showsScanProgress: Bool {
        store.route == .library && !store.isSearching && store.scanSession.isRunning
    }

    /// Playlist removal is only offered on that playlist's own table, not in search.
    private var batchPlaylistID: String? {
        guard !store.isSearching, case .playlist(let id) = store.route else { return nil }
        return id
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
        if case .library = store.route, !store.visibleTracks.isEmpty {
            return "\(store.visibleTracks.count) 首"
        }
        return " "
    }
}

private struct BatchCapsuleWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Local to this app. Space and arrows play without table focus. Esc closes the queue first.
@MainActor
private enum KeyMonitor {
    static weak var session: AppSession?

    static func handle(_ event: NSEvent) -> NSEvent? {
        guard let session else { return event }
        if session.libraryRemovalPrompt != nil { return event }
        if textInputIsFocused || menuOrSheetIsOpen { return event }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let plain = !flags.contains(.command) && !flags.contains(.shift)
            && !flags.contains(.option) && !flags.contains(.control)
        if event.keyCode == 53 {
            if session.queueVisible {
                session.queueVisible = false
                return nil
            }
            guard session.trackTableFocused, !session.selectedTrackIds.isEmpty else { return event }
            session.clearSelection()
            return nil
        }
        let selectAll = flags.contains(.command)
            && !flags.contains(.shift)
            && !flags.contains(.option)
            && !flags.contains(.control)
            && event.charactersIgnoringModifiers?.lowercased() == "a"
        if selectAll {
            guard session.trackTableFocused else { return event }
            session.selectAllInScope()
            return nil
        }
        guard plain else { return event }
        switch event.keyCode {
        case 49:
            session.transportToggle()
            return nil
        case 123:
            session.transportPrevious()
            return nil
        case 124:
            session.transportNext()
            return nil
        default:
            return event
        }
    }

    private static var textInputIsFocused: Bool {
        let responder = NSApp.keyWindow?.firstResponder
        return responder is NSTextView || responder is NSTextField
    }

    private static var menuOrSheetIsOpen: Bool {
        if NSApp.mainWindow?.attachedSheet != nil { return true }
        if let key = NSApp.keyWindow, let main = NSApp.mainWindow, key != main { return true }
        return false
    }
}

#Preview {
    let root = PlaybackRoot()
    ContentView(store: root.session)
        .environment(root.transport)
        .environment(root.queue)
        .frame(width: 1180, height: 760)
}
