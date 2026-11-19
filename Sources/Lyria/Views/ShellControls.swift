import AppKit
import LyriaCore
import SwiftUI

struct PillButton: View {
    let title: String
    var systemImage: String? = nil
    var prominent = false
    var danger = false
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .bold))
                }
                Text(title)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(danger ? LyriaTheme.danger : Color.white)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background {
                Capsule(style: .continuous)
                    .fill(prominent ? AnyShapeStyle(LyriaTheme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.06)))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        danger ? LyriaTheme.danger : (prominent ? Color.clear : LyriaTheme.border),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

struct PageHeader: View {
    let title: String
    var subtitle: String? = nil
    var showsBack = false
    var onBack: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            if showsBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LyriaTheme.foreground)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                        .overlay(Circle().strokeBorder(LyriaTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回")
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(LyriaTheme.foreground)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LyriaTheme.text2)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct SearchField: View {
    @Binding var text: String
    /// When the batch capsule is showing, an empty field can collapse to the magnifying glass.
    var allowsCompact = false
    @Binding var expanded: Bool
    @EnvironmentObject private var store: AppSession
    @State private var didFocus = false
    /// Compact → expanded needs an explicit focus request; launch must not.
    @State private var requestFocus = false

    private var showsCompact: Bool {
        allowsCompact && text.isEmpty && !expanded
    }

    var body: some View {
        Group {
            if showsCompact {
                Button {
                    expanded = true
                    requestFocus = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(LyriaTheme.text3)
                        .frame(width: 36, height: 36)
                        .background(Capsule(style: .continuous).fill(LyriaTheme.searchFill))
                        .overlay(Capsule(style: .continuous).strokeBorder(LyriaTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("搜索")
            } else {
                field
            }
        }
        .onChange(of: allowsCompact) { _, allowed in
            if !allowed { expanded = false }
        }
    }

    private var field: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(LyriaTheme.text3)
            SearchTextField(
                text: $text,
                requestFocus: $requestFocus,
                onFocus: {
                    didFocus = true
                    store.trackTableFocused = false
                },
                onBlur: {
                    if didFocus && text.isEmpty {
                        didFocus = false
                        expanded = false
                    }
                }
            )
            .frame(maxWidth: .infinity)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(LyriaTheme.text3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
        .frame(maxWidth: .infinity)
        .background(Capsule(style: .continuous).fill(LyriaTheme.searchFill))
        .overlay(Capsule(style: .continuous).strokeBorder(LyriaTheme.border, lineWidth: 1))
    }
}

/// AppKit field that refuses window-initial first responder. Click or an explicit
/// `requestFocus` opens editing; launch Space therefore reaches KeyMonitor.
private struct SearchTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var requestFocus: Bool
    var onFocus: () -> Void
    var onBlur: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, requestFocus: $requestFocus, onFocus: onFocus, onBlur: onBlur)
    }

    func makeNSView(context: Context) -> LaunchQuietSearchField {
        let field = LaunchQuietSearchField()
        field.delegate = context.coordinator
        field.isEditable = true
        field.isSelectable = true
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 13, weight: .medium)
        field.textColor = .white
        field.placeholderAttributedString = NSAttributedString(
            string: "搜索音乐、艺人、专辑",
            attributes: [
                .foregroundColor: NSColor.white.withAlphaComponent(0.35),
                .font: NSFont.systemFont(ofSize: 13, weight: .medium)
            ]
        )
        field.stringValue = text
        return field
    }

    func updateNSView(_ field: LaunchQuietSearchField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.requestFocus = $requestFocus
        context.coordinator.onFocus = onFocus
        context.coordinator.onBlur = onBlur
        if field.currentEditor() == nil, field.stringValue != text {
            field.stringValue = text
        }
        if requestFocus, !context.coordinator.focusPending {
            context.coordinator.focusPending = true
            DispatchQueue.main.async {
                context.coordinator.focusPending = false
                context.coordinator.requestFocus.wrappedValue = false
                field.beginEditingFromUserAction()
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var requestFocus: Binding<Bool>
        var onFocus: () -> Void
        var onBlur: () -> Void
        var focusPending = false

        init(
            text: Binding<String>,
            requestFocus: Binding<Bool>,
            onFocus: @escaping () -> Void,
            onBlur: @escaping () -> Void
        ) {
            self.text = text
            self.requestFocus = requestFocus
            self.onFocus = onFocus
            self.onBlur = onBlur
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            onFocus()
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? LaunchQuietSearchField else { return }
            text.wrappedValue = field.stringValue
            field.endEditingSession()
            onBlur()
        }
    }
}

/// Skips AppKit's automatic initial first responder / key-loop claim until the user
/// clicks or compact-mode expansion asks for focus.
private final class LaunchQuietSearchField: NSTextField {
    private var allowFocus = false

    override var acceptsFirstResponder: Bool { allowFocus }

    override func becomeFirstResponder() -> Bool {
        guard allowFocus else { return false }
        return super.becomeFirstResponder()
    }

    override func mouseDown(with event: NSEvent) {
        beginEditingFromUserAction()
        super.mouseDown(with: event)
    }

    func beginEditingFromUserAction() {
        allowFocus = true
        window?.makeFirstResponder(self)
    }

    func endEditingSession() {
        allowFocus = false
    }
}

struct EmptyState<Actions: View>: View {
    let systemImage: String
    let title: String
    var message: String? = nil
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(LyriaTheme.text3)
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(LyriaTheme.foreground)
            if let message {
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(LyriaTheme.text2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            actions()
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ToastPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(LyriaTheme.foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.16))
                    .background(Capsule(style: .continuous).fill(LyriaTheme.panel2))
            }
            .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }
}

struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(LyriaTheme.text3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DetailHero<Actions: View>: View {
    let seed: String
    var artworkPath: String? = nil
    var artworkPaths: [String] = []
    var systemImage: String = "music.note"
    var circle = false
    let eyebrow: String
    let title: String
    let subtitle: String
    var renaming: Binding<String>? = nil
    var onCommitRename: () -> Void = {}
    var onCancelRename: () -> Void = {}
    @EnvironmentObject private var store: AppSession
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        HStack(alignment: .bottom, spacing: 20) {
            CoverArt(
                seed: seed,
                artworkPath: artworkPath,
                artworkPaths: artworkPaths,
                systemImage: systemImage,
                cornerRadius: 16,
                circle: circle,
                elevated: true
            )
                .frame(width: 160, height: 160)
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(LyriaTheme.text2)
                titleView
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(LyriaTheme.text2)
                HStack(spacing: 10) { actions() }
                    .padding(.top, 8)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var titleView: some View {
        if let renaming {
            RenameTitleField(
                text: renaming,
                onCommit: onCommitRename,
                onCancel: onCancelRename,
                onFocus: { store.trackTableFocused = false }
            )
        } else {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(LyriaTheme.foreground)
                .lineLimit(2)
        }
    }
}

/// Single-line title editor. Enter, Tab, and clicking away commit. Esc cancels.
/// The movement code on the same end-editing notification decides which one.
private struct RenameTitleField: NSViewRepresentable {
    @Binding var text: String
    var onCommit: () -> Void
    var onCancel: () -> Void
    var onFocus: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCommit: onCommit, onCancel: onCancel, onFocus: onFocus)
    }

    func makeNSView(context: Context) -> RenameField {
        let field = RenameField(string: text)
        field.delegate = context.coordinator
        field.isEditable = true
        field.isSelectable = true
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 28, weight: .bold)
        field.textColor = .white
        field.placeholderString = "名称"
        field.maximumNumberOfLines = 1
        field.onAttach = { [weak coordinator = context.coordinator] in
            coordinator?.onFocus()
        }
        return field
    }

    func updateNSView(_ field: RenameField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.onCommit = onCommit
        context.coordinator.onCancel = onCancel
        context.coordinator.onFocus = onFocus
        field.onAttach = { [weak coordinator = context.coordinator] in
            coordinator?.onFocus()
        }
        if field.currentEditor() == nil, field.stringValue != text {
            field.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var onCommit: () -> Void
        var onCancel: () -> Void
        var onFocus: () -> Void
        private var didEnd = false

        init(text: Binding<String>, onCommit: @escaping () -> Void, onCancel: @escaping () -> Void, onFocus: @escaping () -> Void) {
            self.text = text
            self.onCommit = onCommit
            self.onCancel = onCancel
            self.onFocus = onFocus
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard !didEnd, let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
            guard let raw = Self.movement(in: notification) else { return }
            didEnd = true
            switch NSTextMovement(rawValue: raw) {
            case .cancel:
                onCancel()
            case .return, .tab, .backtab, .other, .left, .right, .up, .down:
                onCommit()
            default:
                break
            }
        }

        private static func movement(in notification: Notification) -> Int? {
            let value = notification.userInfo?[NSText.movementUserInfoKey]
            if let raw = value as? Int { return raw }
            if let number = value as? NSNumber { return number.intValue }
            return nil
        }
    }
}

private final class RenameField: NSTextField {
    var onAttach: (() -> Void)?
    private var didFocus = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, !didFocus else { return }
        didFocus = true
        window?.makeFirstResponder(self)
        onAttach?()
    }
}

struct SettingRow<Trailing: View>: View {
    let title: String
    let detail: String
    var danger = false
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(danger ? LyriaTheme.danger : LyriaTheme.foreground)
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LyriaTheme.text2)
            }
            Spacer(minLength: 12)
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(LyriaTheme.border, lineWidth: 1)
        )
    }
}

struct OffToggle: View {
    var label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 40, height: 22)
                Circle()
                    .fill(Color.white)
                    .frame(width: 18, height: 18)
                    .padding(.leading, 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue("关闭")
    }
}

/// Within-window frost plus a Deep Space wash. Does not use behind-window vibrancy.
/// The wash is a vertical gradient: nearly solid at the top so the title reads
/// against a calm surface, thinning toward the bottom edge so the frost and the
/// page scrolling underneath glow through instead of hitting a hard slab.
struct LyriaFrostBar: View {
    /// Deep Space opacity at the top edge of the bar.
    var topWash: CGFloat = 0.92
    /// Deep Space opacity at the bottom edge. Low enough to let frost light through.
    var bottomWash: CGFloat = 0.38

    var body: some View {
        ZStack {
            WithinWindowFrost()
            LinearGradient(
                stops: [
                    .init(color: LyriaTheme.background.opacity(topWash), location: 0),
                    // Hold near-solid a little past the traffic-light band, then fall away.
                    .init(color: LyriaTheme.background.opacity(midWash), location: 0.55),
                    .init(color: LyriaTheme.background.opacity(bottomWash), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
    }

    /// Weighted toward the top so the fade eases in rather than ramping linearly.
    private var midWash: CGFloat {
        topWash - (topWash - bottomWash) * 0.45
    }
}

private final class PassthroughVisualEffectView: NSVisualEffectView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private struct WithinWindowFrost: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = PassthroughVisualEffectView()
        view.material = .headerView
        view.blendingMode = .withinWindow
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
