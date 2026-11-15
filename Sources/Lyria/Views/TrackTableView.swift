import AppKit
import LyriaCore
import SwiftUI

struct TrackTableRepresentable: NSViewRepresentable {
    var tracks: [Track]
    var playlistID: String?
    var fillsVertically: Bool
    var chromeTop: CGFloat
    var selectedIDs: Set<String>
    var currentID: String?
    var playing: Bool
    var store: AppSession

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeNSView(context: Context) -> TrackTableContainer {
        let view = TrackTableContainer(fillsVertically: fillsVertically)
        view.coordinator = context.coordinator
        context.coordinator.attach(view.table)
        return view
    }

    func updateNSView(_ view: TrackTableContainer, context: Context) {
        if view.fillsVertically != fillsVertically {
            view.fillsVertically = fillsVertically
            view.install()
            context.coordinator.attach(view.table)
        }
        context.coordinator.apply(
            tracks: tracks,
            playlistID: playlistID,
            selectedIDs: selectedIDs,
            currentID: currentID,
            playing: playing
        )
        view.applyChromeTop(chromeTop)
    }
}

@MainActor
final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    let store: AppSession
    private weak var table: NSTableView?
    private var tracks: [Track] = []
    private var playlistID: String?
    private var selectedIDs: Set<String> = []
    private var currentID: String?
    private var playing = false
    private var renderedIDs: [String] = []

    init(store: AppSession) {
        self.store = store
    }

    func attach(_ table: LyriaTableView) {
        self.table = table
        table.coordinator = self
        table.dataSource = self
        table.delegate = self
    }

    func apply(
        tracks: [Track],
        playlistID: String?,
        selectedIDs: Set<String>,
        currentID: String?,
        playing: Bool
    ) {
        let ids = tracks.map(\.id)
        let structureChanged = ids != renderedIDs
        let unchanged = !structureChanged
            && playlistID == self.playlistID
            && selectedIDs == self.selectedIDs
            && currentID == self.currentID
            && playing == self.playing
            && tracks == self.tracks
        if unchanged { return }
        self.tracks = tracks
        self.playlistID = playlistID
        self.selectedIDs = selectedIDs
        self.currentID = currentID
        self.playing = playing
        renderedIDs = ids
        guard let table else { return }
        if structureChanged {
            table.reloadData()
        } else {
            table.enumerateAvailableRowViews { _, row in
                self.refresh(row: row)
            }
        }
    }

    nonisolated func numberOfRows(in tableView: NSTableView) -> Int {
        MainActor.assumeIsolated { tracks.count }
    }

    nonisolated func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        MainActor.assumeIsolated { cell(for: tableView, row: row) }
    }

    func cell(for tableView: NSTableView, row: Int) -> NSView? {
        let cell = (tableView.makeView(withIdentifier: LyriaTrackCell.reuseID, owner: self) as? LyriaTrackCell)
            ?? LyriaTrackCell()
        cell.identifier = LyriaTrackCell.reuseID
        refresh(cell, row: row)
        return cell
    }

    nonisolated func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        MainActor.assumeIsolated { plainRow(in: tableView) }
    }

    nonisolated func selectionShouldChange(in tableView: NSTableView) -> Bool { false }

    func plainRow(in tableView: NSTableView) -> NSTableRowView? {
        let rowView = (tableView.makeView(withIdentifier: PlainRowView.reuseID, owner: self) as? PlainRowView)
            ?? PlainRowView()
        rowView.identifier = PlainRowView.reuseID
        return rowView
    }

    fileprivate func track(at row: Int) -> Track? {
        tracks.indices.contains(row) ? tracks[row] : nil
    }

    fileprivate func select(row: Int, command: Bool, shift: Bool) {
        guard let track = track(at: row) else { return }
        store.clickTrack(track.id, command: command, shift: shift)
    }

    fileprivate func doubleClick(row: Int) {
        guard let track = track(at: row) else { return }
        store.doubleClicked(track, in: tracks)
    }

    fileprivate func showMenu(row: Int, event: NSEvent, on view: NSView) {
        guard let track = track(at: row) else { return }
        store.prepareMenu(for: track.id)
        let menu = TrackContextMenu.make(
            track: track,
            list: tracks,
            playlistID: playlistID,
            store: store
        )
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    private func refresh(row: Int) {
        guard let table, let cell = table.view(atColumn: 0, row: row, makeIfNecessary: false) as? LyriaTrackCell else { return }
        refresh(cell, row: row)
    }

    private func refresh(_ cell: LyriaTrackCell, row: Int) {
        guard let track = track(at: row) else { return }
        let nextSelected = tracks.indices.contains(row + 1) && selectedIDs.contains(tracks[row + 1].id)
        cell.apply(
            track: track,
            list: tracks,
            playlistID: playlistID,
            selected: selectedIDs.contains(track.id),
            nextSelected: nextSelected,
            isCurrent: track.id == currentID,
            playing: playing,
            store: store
        )
    }
}

final class TrackTableContainer: NSView {
    var fillsVertically: Bool
    let table = LyriaTableView()
    private let scroll = NSScrollView()
    weak var coordinator: Coordinator?

    init(fillsVertically: Bool) {
        self.fillsVertically = fillsVertically
        super.init(frame: .zero)
        install()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func install() {
        scroll.removeFromSuperview()
        table.removeFromSuperview()
        table.configureChrome()
        if fillsVertically {
            scroll.drawsBackground = false
            scroll.backgroundColor = .clear
            scroll.focusRingType = .none
            scroll.hasVerticalScroller = true
            scroll.hasHorizontalScroller = false
            scroll.autohidesScrollers = true
            scroll.autoresizingMask = [.width, .height]
            scroll.documentView = table
            scroll.contentView.drawsBackground = false
            scroll.automaticallyAdjustsContentInsets = false
            table.autoresizingMask = [.width]
            addSubview(scroll)
            scroll.frame = bounds
        } else {
            table.headerView = nil
            table.autoresizingMask = [.width, .height]
            addSubview(table)
            table.frame = bounds
        }
    }

    var chromeTop: CGFloat = 0

    func applyChromeTop(_ top: CGFloat) {
        let top = max(0, top)
        guard abs(chromeTop - top) > 0.5 else { return }
        chromeTop = top
        needsLayout = true
    }

    private var layingOut = false

    override func layout() {
        guard !layingOut else { return }
        layingOut = true
        defer { layingOut = false }
        // Size the table before it tiles. The old order laid it out first, then
        // wrote a column width that never reached the cells.
        if fillsVertically {
            scroll.frame = bounds
            let insets = NSEdgeInsets(top: max(0, chromeTop), left: 0, bottom: 0, right: 0)
            if !edgeInsetsEqual(scroll.contentInsets, insets) {
                scroll.contentInsets = insets
            }
            // Keep the scroller flush with the top of the window; only the
            // document is inset under the pinned title, search, and header.
            let scrollerInsets = NSEdgeInsets()
            if !edgeInsetsEqual(scroll.scrollerInsets, scrollerInsets) {
                scroll.scrollerInsets = scrollerInsets
            }
            // The clip view is often still its previous width here. Widen the
            // document view to the container, which is the width the header used.
            if bounds.width > 1, table.bounds.width + 0.5 < bounds.width {
                var frame = table.frame
                frame.size.width = bounds.width
                table.frame = frame
            }
        } else {
            table.frame = bounds
        }
        super.layout()
        table.fitColumnToTableWidth()
    }
}

final class LyriaTableView: NSTableView {
    weak var coordinator: Coordinator?

    func configureChrome() {
        if tableColumns.isEmpty {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("tracks"))
            column.isEditable = false
            addTableColumn(column)
        }
        if let column = tableColumns.first {
            // Dragging stays off (`allowsColumnResizing`). Autoresizing is what
            // lets tile stretch this column when the table resizes. An empty mask
            // leaves it at NSTableColumn's 100pt default.
            column.resizingMask = .autoresizingMask
            column.minWidth = 1
        }
        headerView = nil
        cornerView = nil
        backgroundColor = .clear
        usesAlternatingRowBackgroundColors = false
        selectionHighlightStyle = .none
        allowsEmptySelection = true
        allowsMultipleSelection = false
        allowsColumnReordering = false
        allowsColumnResizing = false
        allowsColumnSelection = false
        allowsTypeSelect = false
        style = .plain
        rowHeight = TrackTableMetrics.rowHeight
        intercellSpacing = .zero
        gridStyleMask = []
        focusRingType = .none
        columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        if #available(macOS 11.0, *) {
            style = .plain
        }
    }

    private var fittingColumn = false
    private var tiledForWidth: CGFloat = 0

    /// Cell bounds are the column width, and the header uses the same
    /// `frames(width:)`. A width assigned during the container's layout does
    /// not retile existing cells, and pinning min/max to a clip-view width
    /// freezes whatever size that view had before it was laid out.
    func fitColumnToTableWidth() {
        guard !fittingColumn, let column = tableColumns.first else { return }
        let fitted = bounds.width
        guard fitted > 1 else { return }
        let widthChanged = abs(column.width - fitted) > 0.5
        let cellsStale = cellsAreNarrower(than: fitted)
        guard widthChanged || cellsStale else { return }
        if !widthChanged, abs(tiledForWidth - fitted) <= 0.5 { return }

        fittingColumn = true
        defer { fittingColumn = false }
        if column.minWidth > fitted { column.minWidth = 1 }
        if column.maxWidth < fitted { column.maxWidth = fitted }
        if abs(column.width - fitted) > 0.5 {
            column.width = fitted
        }
        guard abs(column.width - fitted) <= 0.5 else { return }
        tiledForWidth = fitted
        tile()
    }

    private func cellsAreNarrower(than fitted: CGFloat) -> Bool {
        guard numberOfRows > 0,
              let cell = view(atColumn: 0, row: 0, makeIfNecessary: false) else { return false }
        return abs(cell.bounds.width - fitted) > 0.5
    }

    override func layout() {
        super.layout()
        fitColumnToTableWidth()
    }

    override var acceptsFirstResponder: Bool { false }

    override func becomeFirstResponder() -> Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Labels and row fill are not controls. Returning `self` makes the table own the click
    /// so a cell cannot swallow it. Cover and ⋯ stay the hit view, so they do not select or play.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hit = super.hitTest(point) else { return nil }
        if Self.owningControl(hit, stoppingAt: self) != nil { return hit }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        let row = row(at: local)
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.control) {
            if row >= 0 { coordinator?.showMenu(row: row, event: event, on: self) }
            return
        }
        guard row >= 0, let coordinator else { return }
        resignTextInput()
        if event.clickCount >= 2 {
            coordinator.doubleClick(row: row)
            return
        }
        coordinator.select(
            row: row,
            command: flags.contains(.command),
            shift: flags.contains(.shift)
        )
    }

    override func rightMouseDown(with event: NSEvent) {
        let row = row(at: convert(event.locationInWindow, from: nil))
        guard row >= 0 else { return }
        coordinator?.showMenu(row: row, event: event, on: self)
    }

    override func canDragRows(with rowIndexes: IndexSet, at mouseDownPoint: NSPoint) -> Bool { false }

    override func menu(for event: NSEvent) -> NSMenu? {
        nil
    }

    private func resignTextInput() {
        guard let window else { return }
        let responder = window.firstResponder
        if responder is NSTextView || responder is NSTextField {
            window.makeFirstResponder(nil)
        }
    }

    private static func owningControl(_ view: NSView?, stoppingAt root: NSView) -> NSView? {
        var current = view
        while let view = current, view !== root {
            if view is PassThroughLabel { current = view.superview; continue }
            if view is NSControl || view is NSHostingView<AnyView> { return view }
            current = view.superview
        }
        return nil
    }
}

final class PlainRowView: NSTableRowView {
    static let reuseID = NSUserInterfaceItemIdentifier("plain-row")

    override func drawSelection(in dirtyRect: NSRect) {}
    override func drawBackground(in dirtyRect: NSRect) {}
    override var isEmphasized: Bool {
        get { false }
        set {}
    }
}

final class LyriaTrackCell: NSView {
    static let reuseID = NSUserInterfaceItemIdentifier("track-cell")

    private let fill = NSView()
    private let accent = NSView()
    private let hairline = NSView()
    private let title = LyriaTrackCell.passThroughLabel(font: .systemFont(ofSize: 13, weight: .semibold), color: .white)
    private let artist = LyriaTrackCell.passThroughLabel(font: .systemFont(ofSize: 12, weight: .medium), color: TrackChrome.meta)
    private let album = LyriaTrackCell.passThroughLabel(font: .systemFont(ofSize: 12, weight: .medium), color: TrackChrome.meta)
    private let duration = LyriaTrackCell.passThroughLabel(font: .monospacedDigitSystemFont(ofSize: 12, weight: .medium), color: TrackChrome.duration)
    private let cover = NSHostingView(rootView: AnyView(EmptyView()))
    private let menuHost = NSHostingView(rootView: AnyView(EmptyView()))
    private var hovering = false
    private var snapshot: Snapshot?
    private var lastHostChrome: HostChrome?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        fill.wantsLayer = true
        accent.wantsLayer = true
        accent.layer?.backgroundColor = TrackChrome.primary.cgColor
        hairline.wantsLayer = true
        duration.alignment = .right
        cover.translatesAutoresizingMaskIntoConstraints = true
        menuHost.translatesAutoresizingMaskIntoConstraints = true
        if #available(macOS 13.0, *) {
            cover.sizingOptions = []
            menuHost.sizingOptions = []
        }
        for view in [fill, accent, title, artist, album, duration, cover, menuHost, hairline] {
            addSubview(view)
        }
        let area = NSTrackingArea(rect: .zero, options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited], owner: self)
        addTrackingArea(area)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        refreshChrome()
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        refreshChrome()
    }

    func apply(
        track: Track,
        list: [Track],
        playlistID: String?,
        selected: Bool,
        nextSelected: Bool,
        isCurrent: Bool,
        playing: Bool,
        store: AppSession
    ) {
        snapshot = Snapshot(
            track: track,
            list: list,
            playlistID: playlistID,
            selected: selected,
            nextSelected: nextSelected,
            isCurrent: isCurrent,
            playing: playing,
            store: store
        )
        title.stringValue = track.title
        artist.stringValue = track.artistLabel
        album.stringValue = track.albumLabel
        duration.stringValue = track.missing ? "文件缺失" : track.durationLabel
        duration.textColor = track.missing ? TrackChrome.danger : TrackChrome.duration
        refreshChrome()
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let missing = snapshot?.track.missing ?? false
        let frames = TrackTableMetrics.frames(width: bounds.width, missing: missing)
        fill.frame = bounds
        accent.frame = CGRect(x: 0, y: 0, width: 3, height: bounds.height)
        cover.frame = frames.cover
        title.frame = frames.title
        artist.frame = frames.artist
        album.frame = frames.album
        duration.frame = frames.duration
        menuHost.frame = frames.menu
        hairline.frame = CGRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1)
        if let gradient = fill.layer as? CAGradientLayer {
            gradient.frame = fill.bounds
        }
    }

    private func refreshChrome() {
        guard let snapshot else { return }
        let showCurrent = snapshot.isCurrent
        accent.isHidden = !showCurrent
        title.textColor = showCurrent ? TrackChrome.primary : .white
        if snapshot.selected {
            TrackChrome.apply(fill, colors: TrackChrome.selectedColors)
        } else if hovering && !showCurrent {
            TrackChrome.apply(fill, colors: [NSColor.white.withAlphaComponent(0.04)])
        } else {
            fill.isHidden = true
        }
        hairline.isHidden = false
        let bright = snapshot.selected || snapshot.nextSelected
        hairline.layer?.backgroundColor = NSColor.white.withAlphaComponent(bright ? 0.2 : 0.08).cgColor
        let host = HostChrome(
            trackID: snapshot.track.id,
            artworkPath: snapshot.track.artworkPath,
            albumId: snapshot.track.albumId,
            playlistID: snapshot.playlistID,
            isCurrent: snapshot.isCurrent,
            playing: snapshot.playing,
            hovering: hovering
        )
        guard host != lastHostChrome else { return }
        lastHostChrome = host
        cover.rootView = AnyView(CoverChrome(
            track: snapshot.track,
            list: snapshot.list,
            isCurrent: snapshot.isCurrent,
            playing: snapshot.playing,
            hovering: hovering,
            store: snapshot.store
        ))
        menuHost.rootView = AnyView(RowMenuChrome(
            track: snapshot.track,
            list: snapshot.list,
            playlistID: snapshot.playlistID,
            hovering: hovering,
            store: snapshot.store
        ))
    }

    private static func passThroughLabel(font: NSFont, color: NSColor) -> NSTextField {
        let label = PassThroughLabel(labelWithString: "")
        label.font = font
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.cell?.truncatesLastVisibleLine = true
        return label
    }
}

private struct Snapshot {
    var track: Track
    var list: [Track]
    var playlistID: String?
    var selected: Bool
    var nextSelected: Bool
    var isCurrent: Bool
    var playing: Bool
    var store: AppSession
}

private struct HostChrome: Equatable {
    var trackID: String
    var artworkPath: String?
    var albumId: String?
    var playlistID: String?
    var isCurrent: Bool
    var playing: Bool
    var hovering: Bool
}

private final class PassThroughLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private struct CoverChrome: View {
    var track: Track
    var list: [Track]
    var isCurrent: Bool
    var playing: Bool
    var hovering: Bool
    var store: AppSession

    var body: some View {
        Button {
            store.coverPressed(track, in: list)
        } label: {
            CoverArt(seed: track.albumId ?? track.id, artworkPath: track.artworkPath, cornerRadius: 8)
                .overlay {
                    if isCurrent {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.black.opacity(0.55))
                            if hovering {
                                Image(systemName: playing ? "pause.fill" : "play.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            } else {
                                EqualizerBars(animated: playing)
                                    .frame(width: 22, height: 16)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else if hovering {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.black.opacity(0.45))
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

private struct RowMenuChrome: View {
    var track: Track
    var list: [Track]
    var playlistID: String?
    var hovering: Bool
    var store: AppSession

    var body: some View {
        Menu {
            TrackMenu.items(track: track, playlistID: playlistID, list: list)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(hovering ? Color.white : LyriaTheme.text3)
                .frame(width: TrackTableMetrics.menuSize, height: TrackTableMetrics.menuSize)
                .opacity(hovering ? 1 : 0.45)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .environmentObject(store)
    }
}

private struct EqualizerBars: NSViewRepresentable {
    var animated: Bool

    func makeNSView(context: Context) -> EqualizerBarsView {
        let view = EqualizerBarsView()
        view.setAnimated(animated)
        return view
    }

    func updateNSView(_ view: EqualizerBarsView, context: Context) {
        view.setAnimated(animated)
    }
}

/// Core Animation bars; avoids a 16 fps SwiftUI TimelineView in the cover host.
private final class EqualizerBarsView: NSView {
    private static let barCount = 4
    private static let barWidth: CGFloat = 3.5
    private static let spacing: CGFloat = 2.5
    private static let maxHeight: CGFloat = 16
    private static let staticHeights: [CGFloat] = [7, 14, 9, 11]
    private static let durations: [CFTimeInterval] = [0.38, 0.52, 0.44, 0.60]

    private let barLayers: [CALayer] = (0..<4).map { _ in
        let layer = CALayer()
        layer.backgroundColor = NSColor.white.cgColor
        layer.cornerRadius = 1.75
        layer.anchorPoint = CGPoint(x: 0.5, y: 0)
        return layer
    }

    private var isAnimated = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        barLayers.forEach { layer?.addSublayer($0) }
        layoutBars(scale: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize { NSSize(width: 22, height: 16) }

    override func layout() {
        super.layout()
        layoutBars(scale: isAnimated ? nil : Self.staticHeights.map { $0 / Self.maxHeight })
    }

    func setAnimated(_ animated: Bool) {
        guard isAnimated != animated else { return }
        isAnimated = animated
        if animated {
            startAnimations()
        } else {
            barLayers.forEach { $0.removeAllAnimations() }
            layoutBars(scale: Self.staticHeights.map { $0 / Self.maxHeight })
        }
    }

    private func layoutBars(scale: [CGFloat]?) {
        let total = CGFloat(Self.barCount) * Self.barWidth + CGFloat(Self.barCount - 1) * Self.spacing
        let originX = (bounds.width - total) / 2
        let originY = (bounds.height - Self.maxHeight) / 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, layer) in barLayers.enumerated() {
            let x = originX + CGFloat(index) * (Self.barWidth + Self.spacing)
            layer.position = CGPoint(x: x + Self.barWidth / 2, y: originY)
            layer.bounds = CGRect(x: 0, y: 0, width: Self.barWidth, height: Self.maxHeight)
            if let scale {
                layer.transform = CATransform3DMakeScale(1, scale[index], 1)
            }
        }
        CATransaction.commit()
    }

    private func startAnimations() {
        layoutBars(scale: Self.staticHeights.map { $0 / Self.maxHeight })
        for (index, layer) in barLayers.enumerated() {
            let animation = CABasicAnimation(keyPath: "transform.scale.y")
            animation.fromValue = 4.0 / Self.maxHeight
            animation.toValue = 1
            animation.duration = Self.durations[index]
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(animation, forKey: "bounce")
        }
    }
}

private enum TrackChrome {
    static let background = NSColor(srgbRed: 10 / 255, green: 11 / 255, blue: 26 / 255, alpha: 1)
    static let header = NSColor(srgbRed: 107 / 255, green: 107 / 255, blue: 128 / 255, alpha: 1)
    static let meta = NSColor(srgbRed: 161 / 255, green: 161 / 255, blue: 181 / 255, alpha: 1)
    static let duration = NSColor(srgbRed: 107 / 255, green: 107 / 255, blue: 128 / 255, alpha: 1)
    static let danger = NSColor(srgbRed: 1, green: 123 / 255, blue: 114 / 255, alpha: 1)
    static let primary = NSColor(srgbRed: 155 / 255, green: 135 / 255, blue: 245 / 255, alpha: 1)
    static let primaryDeep = NSColor(srgbRed: 124 / 255, green: 58 / 255, blue: 237 / 255, alpha: 1)

    static var selectedColors: [NSColor] {
        [primary.withAlphaComponent(0.23), primaryDeep.withAlphaComponent(0.13)]
    }

    static func apply(_ view: NSView, colors: [NSColor]) {
        view.isHidden = false
        let gradient = (view.layer as? CAGradientLayer) ?? CAGradientLayer()
        gradient.colors = colors.map(\.cgColor)
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.frame = view.bounds
        view.layer = gradient
    }
}

enum TrackContextMenu {
    @MainActor
    static func make(track: Track, list: [Track], playlistID: String?, store: AppSession) -> NSMenu {
        let menu = CallbackMenu()
        menu.autoenablesItems = false
        let targets = TrackSelection.menuTrackIDs(
            trackID: track.id,
            selected: store.selectedTrackIds,
            orderedIDs: store.selectionScopeIDs
        )
        menu.add(title: "播放") { store.menuPlay(track, in: list) }
        menu.add(title: "下一首播放") { store.playNext(targets) }
        menu.add(title: "加入队列") { store.enqueue(targets) }
        let playlists = NSMenuItem(title: "加入播放列表", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for entry in PlaylistAddMenu.actions(trackIDs: targets, store: store) {
            let item = NSMenuItem(title: entry.title, action: nil, keyEquivalent: "")
            let action = MenuAction(entry.run)
            menu.actions.append(action)
            item.target = action
            item.action = #selector(MenuAction.fire)
            item.isEnabled = true
            submenu.addItem(item)
        }
        playlists.submenu = submenu
        menu.addItem(playlists)
        menu.addItem(.separator())
        let artistID = sharedID(in: targets, keyPath: \.artistId, track: track, store: store)
        let albumID = sharedID(in: targets, keyPath: \.albumId, track: track, store: store)
        menu.add(title: "前往艺人", enabled: artistID != nil) {
            if let artistID { store.openArtist(artistID) }
        }
        menu.add(title: "前往专辑", enabled: albumID != nil) {
            if let albumID { store.openAlbum(albumID) }
        }
        let revealRows: [RevealTarget]? = {
            var rows: [RevealTarget] = []
            for id in targets {
                guard let row = store.track(id) ?? (id == track.id ? track : nil) else { return nil }
                rows.append(RevealTarget(missing: row.missing, path: row.path))
            }
            return rows
        }()
        if let revealRows, RevealInFinder.canShow(revealRows) {
            menu.add(title: "在访达中显示") { store.revealInFinder(targets) }
        }
        if let playlistID {
            menu.addItem(.separator())
            menu.add(title: "从播放列表移除") { store.removeFromPlaylist(targets, playlistID: playlistID) }
        }
        menu.add(title: "从曲库移除") { store.requestLibraryRemoval(targets) }
        return menu
    }

    @MainActor
    private static func sharedID(
        in ids: [String],
        keyPath: KeyPath<Track, String?>,
        track: Track,
        store: AppSession
    ) -> String? {
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

private final class CallbackMenu: NSMenu {
    var actions: [MenuAction] = []

    func add(title: String, enabled: Bool = true, run: @escaping () -> Void) {
        let action = MenuAction(run)
        actions.append(action)
        let item = NSMenuItem(title: title, action: #selector(MenuAction.fire), keyEquivalent: "")
        item.target = action
        item.isEnabled = enabled
        addItem(item)
    }
}

private final class MenuAction: NSObject {
    let run: () -> Void
    init(_ run: @escaping () -> Void) { self.run = run }
    @objc func fire() { run() }
}

private func edgeInsetsEqual(_ a: NSEdgeInsets, _ b: NSEdgeInsets) -> Bool {
    abs(a.top - b.top) < 0.5
        && abs(a.left - b.left) < 0.5
        && abs(a.bottom - b.bottom) < 0.5
        && abs(a.right - b.right) < 0.5
}
