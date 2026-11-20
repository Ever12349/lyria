import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var store: AppSession

    init(store: AppSession) {
        _store = StateObject(wrappedValue: store)
    }
    @State private var keyMonitor: Any?
    @State private var searchFieldExpanded = false
    @State private var batchCapsuleWidth: CGFloat = 0
    @State private var chromeTop: CGFloat = 88
    @State private var titleRowHeight: CGFloat = 56
    @State private var pageHeadWidth: CGFloat = 640

    private let sidebarMin: CGFloat = 168
    private let sidebarMax: CGFloat = 320

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            SidebarView()
                .frame(width: store.sidebarWidth)
                .padding(.leading, LyriaTheme.sidebarInset)
                .padding(.top, LyriaTheme.sidebarInset)
                .padding(.bottom, LyriaTheme.sidebarInset)
                .ignoresSafeArea(edges: .top)

            SidebarResizeHandle(
                sidebarWidth: $store.sidebarWidth,
                minWidth: sidebarMin,
                maxWidth: sidebarMax,
                onDragEnded: { store.commitSidebarWidth() }
            )
            .frame(width: 12)
            .frame(maxHeight: .infinity)
            .ignoresSafeArea(edges: .top)

            detailColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environmentObject(store)
        .background(windowBackground)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbarColorScheme(.dark, for: .windowToolbar)
        .preferredColorScheme(.dark)
        .background(
            WindowChromeConfigurer(
                detailMinX: store.sidebarWidth + LyriaTheme.sidebarInset + 12,
                titleRowHeight: titleRowHeight
            )
        )
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
        .sheet(item: $store.playlistComposer) { composer in
            PlaylistNameDialog(suggestedName: composer.suggestedName)
                .environmentObject(store)
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

    /// Right column: stacked chrome over page (not a true VStack of title-then-page).
    /// Overlay geometry keeps TrackTable rows scrolling under the title bar via `chromeTop`.
    private var detailColumn: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                ZStack(alignment: .topTrailing) {
                    page
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.leading, 4)
                        .padding(.trailing, 20)
                        .animation(nil, value: store.queueVisible)
                    if store.queueVisible {
                        QueuePanel()
                            .frame(width: 280)
                            .padding(.trailing, 16)
                            .padding(.top, chromeTop + 8)
                            .padding(.bottom, 8)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeOut(duration: 0.18), value: store.queueVisible)

                pinnedChrome
            }
            .overlay(alignment: .bottom) {
                if let toast = store.toast {
                    ToastPill(text: toast)
                        .padding(.bottom, 12)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeOut(duration: 0.18), value: store.toast)
            .ignoresSafeArea(edges: .top)
            IsolatedTransportBar()
                .frame(height: 98)
        }
        .environment(\.lyriaChromeTopInset, chromeTop)
        .onPreferenceChange(TopChromeHeightKey.self) { height in
            guard height > 1, abs(height - chromeTop) > 0.5 else { return }
            chromeTop = height
        }
        .onPreferenceChange(TitleRowHeightKey.self) { height in
            guard height > 1, abs(height - titleRowHeight) > 0.5 else { return }
            titleRowHeight = height
        }
    }

    private var pinnedChrome: some View {
        VStack(spacing: 0) {
            titleBar
            if showsScanProgress {
                ScanProgressBar(
                    title: store.progressTitle,
                    percent: store.scanSession.percent,
                    onCancel: store.cancelScan
                )
                .padding(.trailing, 16)
                .background(LyriaTheme.background)
            }
            if showsPinnedColumnHeader {
                TrackTableColumnHeader(
                    firstIsSelected: pinnedHeaderFirstSelected,
                    showsHairline: false
                )
                .padding(.leading, 4)
                .padding(.trailing, 20)
                .background(LyriaTheme.background)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(pinnedHeaderFirstSelected && showsPinnedColumnHeader ? 0.2 : 0.12))
                .frame(height: 1)
                .allowsHitTesting(false)
        }
        .background {
            GeometryReader { geo in
                Color.clear.preference(key: TopChromeHeightKey.self, value: geo.size.height)
            }
        }
    }

    private var titleBar: some View {
        pageHead
            .padding(.top, 8)
            .padding(.trailing, 16)
            .background(LyriaFrostBar().allowsHitTesting(false))
            .background {
                GeometryReader { geo in
                    Color.clear
                        .preference(key: TitleRowHeightKey.self, value: geo.size.height)
                        .allowsHitTesting(false)
                }
            }
    }

    private var pageHead: some View {
        let restingSearchWidth = min(360, pageHeadWidth * 0.46)
        return HStack(alignment: .center, spacing: 16) {
                HStack(alignment: .center, spacing: 8) {
                    if showsBack {
                        Button { store.goBack() } label: {
                            ChromeCapsuleIcon(systemName: "chevron.left")
                        }
                        .buttonStyle(.plain)
                        .contentShape(Capsule())
                        .accessibilityLabel("返回")
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(headerTitle)
                            .font(.system(size: 20, weight: .semibold))
                            .tracking(-0.4)
                            .foregroundStyle(LyriaTheme.foreground)
                            .lineLimit(1)
                            .layoutPriority(0)
                            .allowsHitTesting(false)
                        if let headerMeta {
                            Text(headerMeta)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(LyriaTheme.text3)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .layoutPriority(1)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
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
                .frame(width: searchLayoutWidth(rowWidth: pageHeadWidth, resting: restingSearchWidth))
                .layoutPriority(1)

                addOrScanMenu
                    .layoutPriority(2)
        }
        .onPreferenceChange(BatchCapsuleWidthKey.self) { width in
            guard width > 1, abs(width - batchCapsuleWidth) > 0.5 else { return }
            batchCapsuleWidth = width
        }
        .animation(.easeOut(duration: 0.18), value: store.showsBatchBar)
        .animation(.easeOut(duration: 0.18), value: searchFieldExpanded)
        .background {
            GeometryReader { geo in
                Color.clear
                    .preference(key: TitleRowWidthKey.self, value: geo.size.width)
                    .allowsHitTesting(false)
            }
        }
        .onPreferenceChange(TitleRowWidthKey.self) { width in
            guard width > 1, abs(width - pageHeadWidth) > 0.5 else { return }
            pageHeadWidth = width
        }
        .frame(height: 44)
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }

    /// Resting search keeps the 46% / 360 cap, minus the plus button and the gap before it.
    /// With the batch capsule, an empty field is 36pt; otherwise it uses leftover space up to 360.
    private func searchLayoutWidth(rowWidth: CGFloat, resting: CGFloat) -> CGFloat {
        let plusReserve = ChromeCapsuleIcon.side + 16
        if !store.showsBatchBar { return min(360, max(36, resting - plusReserve)) }
        if store.searchText.isEmpty && !searchFieldExpanded { return 36 }
        let gaps: CGFloat = 16 * 2
        let titleFloor: CGFloat = 88
        let leftover = rowWidth - batchCapsuleWidth - titleFloor - gaps - plusReserve
        return min(360, max(36, leftover))
    }

    private var addOrScanMenu: some View {
        AddOrScanButton(
            running: store.scanSession.isRunning,
            scan: { store.scanTracks() },
            add: { store.addAudioFiles() }
        )
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
                    .environment(\.trackTableIsVisible, true)
            }
        }
    }

    private func mountedSection(_ item: NavItem) -> some View {
        let routes = store.routes(in: item)
        let active = store.currentSection == item && !store.isSearching
        return ZStack {
            ForEach(routes, id: \.stackKey) { route in
                routePage(route)
                    .environment(\.trackTableIsVisible, active && route == routes.last)
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

    private var showsPinnedColumnHeader: Bool {
        if store.isSearching { return !store.searchTracks.isEmpty }
        if case .library = store.route { return !store.visibleTracks.isEmpty }
        return false
    }

    private var pinnedHeaderFirstSelected: Bool {
        let tracks = store.isSearching ? store.searchTracks : store.visibleTracks
        return tracks.first.map { store.selectedTrackIds.contains($0.id) } ?? false
    }

    private var showsScanProgress: Bool {
        store.scanSession.isRunning
    }

    /// Playlist removal is only offered on that playlist's own table, not in search.
    private var batchPlaylistID: String? {
        guard !store.isSearching, case .playlist(let id) = store.route else { return nil }
        return id
    }

    private var showsBack: Bool {
        store.canGoBack
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

    private var headerMeta: String? {
        if store.isSearching {
            return store.hasSearchHits ? "\(store.searchTracks.count) 首" : "无结果"
        }
        if case .library = store.route, !store.visibleTracks.isEmpty {
            return "\(store.visibleTracks.count) 首"
        }
        return nil
    }
}

/// A plain 36pt capsule button, same as Back, that pops an AppKit menu.
/// SwiftUI `Menu` + `borderlessButton` draws its own bezel and does not match the search/back capsules.
private struct AddOrScanButton: View {
    var running: Bool
    var scan: () -> Void
    var add: () -> Void
    @State private var anchor = MenuAnchor()

    var body: some View {
        Button(action: present) {
            ChromeCapsuleIcon(systemName: "plus")
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .background(MenuAnchorProbe(anchor: anchor).allowsHitTesting(false))
        .accessibilityLabel("添加或扫描曲目")
        .help("添加或扫描曲目")
    }

    private func present() {
        guard let view = anchor.view else { return }
        let menu = TitleBarCallbackMenu()
        menu.add(title: "扫描文件夹", enabled: !running, run: scan)
        menu.add(title: "添加曲目", enabled: !running, run: add)
        let point = NSPoint(x: 0, y: view.isFlipped ? view.bounds.maxY : view.bounds.minY)
        menu.popUp(positioning: nil, at: point, in: view)
    }
}

@MainActor
private final class MenuAnchor {
    weak var view: NSView?
}

private struct MenuAnchorProbe: NSViewRepresentable {
    var anchor: MenuAnchor

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        anchor.view = view
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        anchor.view = view
    }
}

private final class TitleBarCallbackMenu: NSMenu {
    private var actions: [TitleBarMenuAction] = []

    func add(title: String, enabled: Bool = true, run: @escaping () -> Void) {
        let action = TitleBarMenuAction(run)
        actions.append(action)
        let item = NSMenuItem(title: title, action: #selector(TitleBarMenuAction.fire), keyEquivalent: "")
        item.target = action
        item.isEnabled = enabled
        addItem(item)
    }
}

private final class TitleBarMenuAction: NSObject {
    let run: () -> Void
    init(_ run: @escaping () -> Void) { self.run = run }
    @objc func fire() { run() }
}

/// 36pt capsule shared by the back button and the add-or-scan menu.
private struct ChromeCapsuleIcon: View {
    static let side: CGFloat = 36
    var systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(LyriaTheme.text3)
            .frame(width: Self.side, height: Self.side)
            .background(Capsule(style: .continuous).fill(LyriaTheme.searchFill))
            .overlay(Capsule(style: .continuous).strokeBorder(LyriaTheme.border, lineWidth: 1))
            .contentShape(Capsule())
    }
}

private struct BatchCapsuleWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Local to this app. Space plays and arrows seek ±5s without table focus. Esc closes the queue first.
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
            session.transportSeek(by: -5_000)
            return nil
        case 124:
            session.transportSeek(by: 5_000)
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
