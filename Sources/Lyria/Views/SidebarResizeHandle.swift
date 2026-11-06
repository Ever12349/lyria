import SwiftUI
import AppKit

/// AppKit pan handle between sidebar and detail — SwiftUI DragGesture on a clear
/// overlay was easy to miss; NSPanGestureRecognizer tracks reliably on macOS.
struct SidebarResizeHandle: NSViewRepresentable {
    @Binding var sidebarWidth: CGFloat
    var minWidth: CGFloat
    var maxWidth: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(sidebarWidth: $sidebarWidth, minWidth: minWidth, maxWidth: maxWidth)
    }

    func makeNSView(context: Context) -> ResizeHandleView {
        let view = ResizeHandleView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: ResizeHandleView, context: Context) {
        context.coordinator.sidebarWidth = $sidebarWidth
        context.coordinator.minWidth = minWidth
        context.coordinator.maxWidth = maxWidth
        nsView.coordinator = context.coordinator
    }

    final class Coordinator {
        var sidebarWidth: Binding<CGFloat>
        var minWidth: CGFloat
        var maxWidth: CGFloat
        var dragOrigin: CGFloat?

        init(sidebarWidth: Binding<CGFloat>, minWidth: CGFloat, maxWidth: CGFloat) {
            self.sidebarWidth = sidebarWidth
            self.minWidth = minWidth
            self.maxWidth = maxWidth
        }

        func beginDrag() {
            dragOrigin = sidebarWidth.wrappedValue
        }

        func drag(deltaX: CGFloat) {
            let origin = dragOrigin ?? sidebarWidth.wrappedValue
            let next = min(max(minWidth, origin + deltaX), maxWidth)
            sidebarWidth.wrappedValue = next
        }

        func endDrag() {
            dragOrigin = nil
        }
    }
}

final class ResizeHandleView: NSView {
    weak var coordinator: SidebarResizeHandle.Coordinator?
    private var tracking: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        // Visible 1px rule + wide hit target
        layer?.backgroundColor = NSColor.clear.cgColor

        let pan = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 12, height: NSView.noIntrinsicMetric)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.resizeLeftRight.push()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.pop()
    }

    override func draw(_ dirtyRect: NSRect) {
        // Center hairline
        let hair = NSRect(x: bounds.midX - 0.5, y: 0, width: 1, height: bounds.height)
        NSColor.white.withAlphaComponent(0.08).setFill()
        hair.fill()
    }

    @objc private func handlePan(_ gr: NSPanGestureRecognizer) {
        guard let coordinator else { return }
        switch gr.state {
        case .began:
            coordinator.beginDrag()
        case .changed:
            let dx = gr.translation(in: self).x
            coordinator.drag(deltaX: dx)
        case .ended, .cancelled:
            coordinator.endDrag()
            gr.setTranslation(.zero, in: self)
        default:
            break
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }
}
