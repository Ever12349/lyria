import SwiftUI
import AppKit
import ObjectiveC

private let deepSpace = NSColor(
    calibratedRed: 10 / 255,
    green: 11 / 255,
    blue: 26 / 255,
    alpha: 1
)

/// Music.app-style chrome. Native title bar owns drag + double-click zoom.
/// Passthrough wrapper is reinstalled whenever SwiftUI replaces contentView.
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
        private var pollTimer: Timer?

        func schedule(from view: NSView) {
            workItem?.cancel()
            let item = DispatchWorkItem { [weak self, weak view] in
                guard let self, let window = view?.window else { return }
                WindowChromeConfigurer.apply(to: window)
                self.startPolling(window)
            }
            workItem = item
            DispatchQueue.main.async(execute: item)
        }

        private func startPolling(_ window: NSWindow) {
            pollTimer?.invalidate()
            var ticks = 0
            pollTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] timer in
                ticks += 1
                WindowChromeConfigurer.apply(to: window)
                if ticks >= 15 { // ~3s after layout settles
                    timer.invalidate()
                    self?.pollTimer = nil
                }
            }
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

/// Returns nil in the top title-bar band so NSThemeFrame handles native zoom/drag.
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
        guard window != nil else { return super.hitTest(point) }

        let local = convert(point, from: superview)
        let layoutDelta = (window?.frame.height ?? 0) - (window?.contentLayoutRect.height ?? 0)
        let titleband = max(layoutDelta, 52)

        if local.y >= bounds.maxY - titleband {
            return nil // system title bar
        }

        guard let hosted else { return super.hitTest(point) }
        return hosted.hitTest(local)
    }
}
