import AppKit
import LyriaCore
import SwiftUI

enum TrackMenu {
    @MainActor
    @ViewBuilder
    static func items(track: Track, playlistID: String?) -> some View {
        TrackMenuItems(track: track, playlistID: playlistID)
    }
}

private struct TrackMenuItems: View {
    let track: Track
    var playlistID: String?
    @EnvironmentObject private var store: AppSession

    var body: some View {
        let targets = beginMenu()
        let artistID = sharedID(in: targets, keyPath: \.artistId)
        let albumID = sharedID(in: targets, keyPath: \.albumId)

        // TODO(engine): play, queue, and play-next.
        Button("播放") {}
            .disabled(true)
        Button("下一首播放") {}
            .disabled(true)
        Button("加入队列") {}
            .disabled(true)
        Menu("加入播放列表") {
            if store.playlists.isEmpty {
                Button("没有播放列表") {}
                    .disabled(true)
            } else {
                ForEach(store.playlists) { playlist in
                    Button(playlist.name) {
                        store.addToPlaylist(targets, playlistID: playlist.id)
                    }
                }
            }
        }
        Divider()
        Button("前往艺人") {
            if let artistID { store.openArtist(artistID) }
        }
        .disabled(artistID == nil)
        Button("前往专辑") {
            if let albumID { store.openAlbum(albumID) }
        }
        .disabled(albumID == nil)
        if let playlistID {
            Divider()
            Button("从播放列表移除") {
                store.removeFromPlaylist(targets, playlistID: playlistID)
            }
        }
        Button("从曲库移除", role: .destructive) {
            store.requestLibraryRemoval(targets)
        }
    }

    /// Menu contents follow the selection rule immediately. Highlight catches up on the next turn
    /// so opening the menu does not publish state during the menu's view update.
    private func beginMenu() -> [String] {
        let targets = TrackSelection.menuTrackIDs(
            trackID: track.id,
            selected: store.selectedTrackIds,
            orderedIDs: store.selectionScopeIDs
        )
        store.scheduleMenuSelection(for: track.id)
        return targets
    }

    private func sharedID(in ids: [String], keyPath: KeyPath<Track, String?>) -> String? {
        var shared: String?
        for id in ids {
            let row = store.track(id) ?? (id == track.id ? track : nil)
            guard let row, let value = row[keyPath: keyPath] else { return nil }
            if let shared, shared != value { return nil }
            shared = value
        }
        return shared
    }
}

struct TrackTable: View {
    let tracks: [Track]
    var playlistID: String? = nil
    var scrolls = true
    @EnvironmentObject private var store: AppSession
    @State private var scopeActive = false

    var body: some View {
        Group {
            if scrolls {
                ScrollView { rows }
            } else {
                rows
            }
        }
        .onAppear {
            scopeActive = true
            store.noteSelectionScope(trackIDs)
        }
        .onChange(of: trackIDs) { _, ids in
            guard scopeActive else { return }
            store.noteSelectionScope(ids)
        }
        .onDisappear {
            scopeActive = false
            store.trackTableFocused = false
        }
    }

    private var trackIDs: [String] { tracks.map(\.id) }

    private var rows: some View {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            Section {
                ForEach(tracks) { track in
                    TrackRow(track: track, playlistID: playlistID)
                }
            } header: {
                header
                    .background(LyriaTheme.background)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 10) {
                Color.clear.frame(width: 36, height: 1)
                Text("标题")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("艺人")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("专辑")
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 2) {
                Text("时长")
                    .frame(width: 44, alignment: .trailing)
                Color.clear.frame(width: 28, height: 1)
            }
            .frame(width: 96, alignment: .trailing)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(LyriaTheme.text3)
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
        }
    }
}

private struct TrackRow: View {
    let track: Track
    var playlistID: String? = nil
    @EnvironmentObject private var store: AppSession
    @State private var hovering = false

    private var isCurrent: Bool { false }
    private var isSelected: Bool { store.selectedTrackIds.contains(track.id) }

    var body: some View {
        rowContent
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                RowClickCatcher { flags in
                    select(flags: flags)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background {
                if isCurrent {
                    LyriaTheme.softAccentGradient
                } else if isSelected {
                    Color.white.opacity(0.07)
                } else if hovering {
                    Color.white.opacity(0.04)
                }
            }
            .overlay(alignment: .bottom) {
                if !isCurrent {
                    Rectangle()
                        .fill(Color.white.opacity(isSelected ? 0.2 : 0.08))
                        .frame(height: 1)
                }
            }
            .onHover { hovering = $0 }
            .contextMenu {
                TrackMenu.items(track: track, playlistID: playlistID)
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            HStack(spacing: 10) {
                coverButton
                Text(track.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LyriaTheme.foreground)
                    .lineLimit(1)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            metaButton(track.artistLabel, enabled: track.canOpenArtist) {
                if let id = track.artistId { store.openArtist(id) }
            }
            metaButton(track.albumLabel, enabled: track.canOpenAlbum) {
                if let id = track.albumId { store.openAlbum(id) }
            }

            HStack(spacing: 2) {
                Text(track.missing ? "文件缺失" : track.durationLabel)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(track.missing ? LyriaTheme.danger : LyriaTheme.text3)
                    .frame(width: track.missing ? 56 : 44, alignment: .trailing)
                    .allowsHitTesting(false)
                moreMenu
            }
            .frame(width: 96, alignment: .trailing)
        }
    }

    private var coverButton: some View {
        // TODO(engine): cover button plays or pauses.
        Button {} label: {
            CoverArt(seed: track.albumId ?? track.id, artworkPath: track.artworkPath, cornerRadius: 8)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .disabled(true)
        .accessibilityLabel(track.title)
    }

    private var moreMenu: some View {
        Menu {
            TrackMenu.items(track: track, playlistID: playlistID)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(hovering ? Color.white : LyriaTheme.text3)
                .frame(width: 28, height: 28)
                .opacity(hovering ? 1 : 0.45)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 28, height: 28)
        .accessibilityLabel("更多操作")
    }

    private func metaButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(enabled ? LyriaTheme.text2 : LyriaTheme.text3)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func select(flags: NSEvent.ModifierFlags) {
        let modifiers = flags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.control) { return }
        resignTextInput()
        store.clickTrack(
            track.id,
            command: modifiers.contains(.command),
            shift: modifiers.contains(.shift)
        )
    }

    private func resignTextInput() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        let responder = window.firstResponder
        if responder is NSTextView || responder is NSTextField {
            window.makeFirstResponder(nil)
        }
    }
}

/// Left clicks report modifier flags. Right-clicks pass upward so the row context menu can open.
private struct RowClickCatcher: NSViewRepresentable {
    var onClick: (NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> RowClickCatcherView {
        let view = RowClickCatcherView()
        view.onClick = onClick
        return view
    }

    func updateNSView(_ nsView: RowClickCatcherView, context: Context) {
        nsView.onClick = onClick
    }
}

private final class RowClickCatcherView: NSView {
    var onClick: ((NSEvent.ModifierFlags) -> Void)?

    private static let liveViews = NSHashTable<RowClickCatcherView>.weakObjects()
    private static var modifierMonitor: Any?
    private static var suppressPlainUntil: TimeInterval = 0
    private static var suppressPlainRow: ObjectIdentifier?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            Self.liveViews.remove(self)
        } else {
            Self.liveViews.add(self)
            Self.installModifierMonitorIfNeeded()
        }
    }

    override func mouseDown(with event: NSEvent) {
        // A ⌘/⇧ click is handled from the original event. Ignore the plain rewrite that follows it.
        if Self.suppressPlainRow == ObjectIdentifier(self),
           ProcessInfo.processInfo.systemUptime < Self.suppressPlainUntil {
            return
        }
        // Keyboard state covers a click SwiftUI rewrote without modifier bits.
        let flags = event.modifierFlags.union(NSEvent.modifierFlags)
        if flags.contains(.control) {
            rightMouseDown(with: event)
            return
        }
        onClick?(flags)
    }

    override func rightMouseDown(with event: NSEvent) {
        superview?.rightMouseDown(with: event)
    }

    /// Hosting views drop ⌘/⇧ clicks before `mouseDown`, or deliver them as a plain click.
    /// This sees the original event and consumes it so that plain path cannot replace the range.
    private static func installModifierMonitorIfNeeded() {
        guard modifierMonitor == nil else { return }
        modifierMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            deliverModifierClick(event)
        }
    }

    private static func deliverModifierClick(_ event: NSEvent) -> NSEvent? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command) || flags.contains(.shift), !flags.contains(.control) else {
            return event
        }
        guard let catcher = catcher(containing: event), let onClick = catcher.onClick else {
            return event
        }
        if controlOwns(event) {
            return event
        }
        let callback = onClick
        suppressPlainRow = ObjectIdentifier(catcher)
        suppressPlainUntil = ProcessInfo.processInfo.systemUptime + 0.05
        // Same synchronous hop as the key monitor: the closure updates AppSession.
        MainActor.assumeIsolated {
            callback(event.modifierFlags)
        }
        return nil
    }

    private static func controlOwns(_ event: NSEvent) -> Bool {
        guard let hit = event.window?.contentView?.hitTest(event.locationInWindow) else { return false }
        var view: NSView? = hit
        while let current = view {
            if current is RowClickCatcherView { return false }
            if current is NSControl { return true }
            view = current.superview
        }
        return false
    }

    private static func catcher(containing event: NSEvent) -> RowClickCatcherView? {
        guard let window = event.window else { return nil }
        let point = event.locationInWindow
        var best: RowClickCatcherView?
        var bestArea = CGFloat.greatestFiniteMagnitude
        for view in liveViews.allObjects {
            guard view.window === window, view.containsWindowPoint(point) else { continue }
            let area = view.bounds.width * view.bounds.height
            if area > 0, area < bestArea {
                best = view
                bestArea = area
            }
        }
        return best
    }

    private func containsWindowPoint(_ point: NSPoint) -> Bool {
        guard window != nil, !isHiddenOrHasHiddenAncestor, bounds.width > 0, bounds.height > 0 else {
            return false
        }
        return bounds.contains(convert(point, from: nil))
    }
}
