import SwiftUI
import AppKit

private let deepSpace = NSColor(
    calibratedRed: 10 / 255,
    green: 11 / 255,
    blue: 26 / 255,
    alpha: 1
)

/// Music.app-style chrome. Native title bar owns drag + double-click zoom.
/// The passthrough band is only the system titlebar height — not a fixed 52pt strip.
struct WindowChromeConfigurer: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.schedule(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.schedule(from: nsView)
    }

    final class Coordinator {
        private var workItem: DispatchWorkItem?
        private var delayed: [DispatchWorkItem] = []

        func schedule(from view: NSView) {
            workItem?.cancel()
            delayed.forEach { $0.cancel() }
            delayed.removeAll()
            let item = DispatchWorkItem { [weak view, weak self] in
                guard let window = view?.window else { return }
                WindowChromeConfigurer.apply(to: window)
                // SwiftUI sometimes resets contentView or button frames after the first pass.
                for delay in [0.35, 1.0] {
                    let followUp = DispatchWorkItem { [weak window] in
                        guard let window else { return }
                        WindowChromeConfigurer.apply(to: window)
                    }
                    self?.delayed.append(followUp)
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: followUp)
                }
            }
            workItem = item
            DispatchQueue.main.async(execute: item)
        }
    }

    static func apply(to window: NSWindow?) {
        guard let window else { return }

        let chrome: NSWindow.StyleMask = [
            .titled,
            .closable,
            .miniaturizable,
            .resizable,
            .fullSizeContentView
        ]
        if window.styleMask != chrome { window.styleMask = chrome }
        if window.titleVisibility != .hidden { window.titleVisibility = .hidden }
        if !window.titlebarAppearsTransparent { window.titlebarAppearsTransparent = true }
        if window.titlebarSeparatorStyle != .none { window.titlebarSeparatorStyle = .none }
        if window.toolbar != nil { window.toolbar = nil }
        if window.backgroundColor != deepSpace { window.backgroundColor = deepSpace }
        if !window.isOpaque { window.isOpaque = true }
        if window.isMovableByWindowBackground { window.isMovableByWindowBackground = false }
        enforceMinimumSize(on: window)

        for type: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            if let button = window.standardWindowButton(type) {
                button.isHidden = false
                button.alphaValue = 1
            }
        }

        TitlebarPassthroughContentView.installIfNeeded(on: window)
        positionTrafficLights(on: window)
    }

    /// SwiftUI `.frame(minWidth:minHeight:)` does not clamp `NSWindow`. Set both mins and grow a frame that is already smaller.
    private static func enforceMinimumSize(on window: NSWindow) {
        let minimum = NSSize(width: LyriaTheme.windowMinimum.width, height: LyriaTheme.windowMinimum.height)
        if window.minSize != minimum { window.minSize = minimum }
        if window.contentMinSize != minimum { window.contentMinSize = minimum }
        let frame = window.frame
        guard frame.width < minimum.width || frame.height < minimum.height else { return }
        let width = max(frame.width, minimum.width)
        let height = max(frame.height, minimum.height)
        let origin = NSPoint(x: frame.origin.x, y: frame.origin.y + frame.height - height)
        window.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
    }

    /// System buttons, shifted so they sit in the sidebar card’s top blank band
    /// (card is inset 12pt; corner radius 18). Reparented onto the content view
    /// so they stay clickable below the titlebar strip.
    private static var trafficPitch: CGFloat = 20

    static func positionTrafficLights(on window: NSWindow) {
        let types: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        let buttons = types.compactMap { window.standardWindowButton($0) }
        guard buttons.count == 3, let content = window.contentView else { return }
        guard content.bounds.width > 200, content.bounds.height > 200 else { return }

        if buttons[0].superview === buttons[1].superview {
            let pitch = buttons[1].frame.minX - buttons[0].frame.minX
            if pitch >= 14, pitch <= 32 {
                trafficPitch = pitch
            }
        }

        let margin: CGFloat = 12
        let insetX: CGFloat = 16
        let insetY: CGFloat = 8
        let topFromTop = margin + insetY

        for (index, button) in buttons.enumerated() {
            if button.superview !== content {
                button.removeFromSuperview()
                content.addSubview(button)
            }
            button.translatesAutoresizingMaskIntoConstraints = true
            button.autoresizingMask = []
            let size = button.bounds.size
            let x = margin + insetX + CGFloat(index) * trafficPitch
            let y = content.isFlipped
                ? topFromTop
                : content.bounds.height - topFromTop - size.height
            let origin = NSPoint(x: x, y: y)
            if abs(button.frame.origin.x - origin.x) > 0.5 || abs(button.frame.origin.y - origin.y) > 0.5 {
                button.setFrameOrigin(origin)
            }
        }
    }
}

/// Returns nil only inside the system titlebar drag band so NSThemeFrame can drag and zoom.
/// Interactive controls (search, sidebar rows) sit below that band and keep their clicks.
final class TitlebarPassthroughContentView: NSView {
    private weak var hosted: NSView?

    @discardableResult
    static func installIfNeeded(on window: NSWindow) -> Bool {
        guard let current = window.contentView else { return false }

        if let existing = current as? TitlebarPassthroughContentView {
            existing.hosted?.frame = existing.bounds
            return false
        }

        let wrapper = TitlebarPassthroughContentView(frame: current.frame)
        wrapper.wantsLayer = false
        wrapper.autoresizingMask = [.width, .height]
        wrapper.hosted = current

        current.removeFromSuperview()
        current.translatesAutoresizingMaskIntoConstraints = true
        current.autoresizingMask = [.width, .height]
        current.frame = wrapper.bounds
        wrapper.addSubview(current)
        window.contentView = wrapper
        return true
    }

    override func layout() {
        super.layout()
        hosted?.frame = bounds
        if let window {
            WindowChromeConfigurer.positionTrafficLights(on: window)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let window else { return super.hitTest(point) }

        let local = convert(point, from: superview)
        // System traffic lights live on this view so they can sit inside the
        // inset sidebar card and still receive clicks inside the drag band.
        for subview in subviews.reversed() where subview !== hosted {
            if let hit = subview.hitTest(local) {
                return hit
            }
        }

        let layoutDelta = window.frame.height - window.contentLayoutRect.height
        let band = layoutDelta > 1 ? layoutDelta : 28

        if local.y >= bounds.maxY - band {
            return nil
        }

        guard let hosted else { return super.hitTest(point) }
        return hosted.hitTest(local)
    }
}
