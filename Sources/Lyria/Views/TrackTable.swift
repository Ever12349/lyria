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
        let targets = TrackSelection.menuTrackIDs(
            trackID: track.id,
            selected: store.selectedTrackIds,
            orderedIDs: store.selectionScopeIDs
        )
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
        .onAppear { store.prepareMenu(for: track.id) }
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
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    let nextIsSelected = tracks.indices.contains(index + 1)
                        && store.selectedTrackIds.contains(tracks[index + 1].id)
                    TrackRow(
                        track: track,
                        playlistID: playlistID,
                        nextIsSelected: nextIsSelected
                    )
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
                    .lineLimit(1)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            Text("艺人")
                .lineLimit(1)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            Text("专辑")
                .lineLimit(1)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
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
            Rectangle()
                .fill(Color.white.opacity(headerHairlineOpacity))
                .frame(height: 1)
        }
    }

    /// The header rule is the first row's top edge, so a selected first track uses the selected weight.
    private var headerHairlineOpacity: Double {
        guard let first = tracks.first, store.selectedTrackIds.contains(first.id) else { return 0.12 }
        return 0.2
    }
}

private struct TrackRow: View {
    let track: Track
    var playlistID: String? = nil
    /// The next row is selected, so this bottom rule is that row's top edge.
    var nextIsSelected = false
    @EnvironmentObject private var store: AppSession
    @State private var hovering = false

    private var isCurrent: Bool { false }
    private var isSelected: Bool { store.selectedTrackIds.contains(track.id) }
    /// One 1px rule. Bright when this row or the next is selected, so a block's top and bottom match.
    private var hairlineOpacity: Double { (isSelected || nextIsSelected) ? 0.2 : 0.08 }

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
                    LyriaTheme.selectedRowFill
                } else if hovering {
                    Color.white.opacity(0.04)
                }
            }
            .overlay(alignment: .bottom) {
                if !isCurrent {
                    Rectangle()
                        .fill(Color.white.opacity(hairlineOpacity))
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
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    .allowsHitTesting(false)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            metaLabel(track.artistLabel)
            metaLabel(track.albumLabel)
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

    private func metaLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(LyriaTheme.text2)
            .lineLimit(1)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)
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

    /// Control-click and right-click belong to the row context menu. Handling them here
    /// swallowed mouseUp and left later clicks unable to select.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard bounds.contains(local), !isHiddenOrHasHiddenAncestor else { return nil }
        if Self.isContextClick(NSApp.currentEvent) { return nil }
        return self
    }

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
        if flags.contains(.control) { return }
        onClick?(flags)
    }

    /// Hosting views drop ⌘/⇧ clicks before `mouseDown`, or deliver them as a plain click.
    /// This sees the original event and consumes it so that plain path cannot replace the range.
    private static func isContextClick(_ event: NSEvent?) -> Bool {
        guard let event else { return false }
        switch event.type {
        case .rightMouseDown, .rightMouseUp, .rightMouseDragged:
            return true
        case .leftMouseDown, .leftMouseUp, .leftMouseDragged:
            return event.modifierFlags.contains(.control)
        default:
            return false
        }
    }

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
