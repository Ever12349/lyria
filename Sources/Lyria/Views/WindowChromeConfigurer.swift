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

        func schedule(from view: NSView) {
            workItem?.cancel()
            let item = DispatchWorkItem { [weak view] in
                guard let window = view?.window else { return }
                WindowChromeConfigurer.apply(to: window)
                // SwiftUI sometimes swaps contentView again after the first layout pass.
                for delay in [0.35, 1.0] {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak window] in
                        guard let window, !(window.contentView is TitlebarPassthroughContentView) else { return }
                        WindowChromeConfigurer.apply(to: window)
                    }
                }
            }
            workItem = item
            DispatchQueue.main.async(execute: item)
        }
    }

    static func apply(to window: NSWindow?) {
        guard let window else { return }

        window.styleMask = [
            .titled,
            .closable,
            .miniaturizable,
            .resizable,
            .fullSizeContentView
        ]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.toolbar = nil
        window.backgroundColor = deepSpace
        window.isOpaque = true
        window.isMovableByWindowBackground = false

        for type: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            if let button = window.standardWindowButton(type) {
                button.isHidden = false
                button.alphaValue = 1
            }
        }

        TitlebarPassthroughContentView.installIfNeeded(on: window)
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
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let window else { return super.hitTest(point) }

        let local = convert(point, from: superview)
        let layoutDelta = window.frame.height - window.contentLayoutRect.height
        let band = layoutDelta > 1 ? layoutDelta : 28

        if local.y >= bounds.maxY - band {
            return nil
        }

        guard let hosted else { return super.hitTest(point) }
        return hosted.hitTest(local)
    }
}
