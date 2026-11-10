import AppKit
import SwiftUI

struct CoverArt: View {
    var seed: String
    var artworkPath: String? = nil
    var systemImage: String = "music.note"
    var cornerRadius: CGFloat = 8
    var circle = false
    var elevated = false
    @State private var artwork: NSImage?

    var body: some View {
        let shape = circle
            ? AnyShape(Circle())
            : AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        shape
            .fill(LyriaTheme.coverGradient(seed: seed))
            .overlay {
                if let artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .scaledToFill()
                } else {
                    GeometryReader { geo in
                        Image(systemName: systemImage)
                            .font(.system(size: max(11, geo.size.width * 0.28), weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
            }
            .clipShape(shape)
            .shadow(color: elevated ? LyriaTheme.primaryDeep.opacity(0.35) : .clear, radius: elevated ? 18 : 0, y: elevated ? 8 : 0)
            .task(id: artworkPath) {
                guard let artworkPath else {
                    artwork = nil
                    return
                }
                artwork = NSImage(contentsOfFile: artworkPath)
            }
    }
}

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
    @FocusState private var fieldFocused: Bool
    @State private var didFocus = false

    private var showsCompact: Bool {
        allowsCompact && text.isEmpty && !expanded
    }

    var body: some View {
        Group {
            if showsCompact {
                Button {
                    expanded = true
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
                    .onAppear {
                        if expanded { fieldFocused = true }
                    }
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
            TextField("搜索音乐、艺人、专辑", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(LyriaTheme.foreground)
                .focused($fieldFocused)
                .onChange(of: fieldFocused) { _, focused in
                    if focused {
                        didFocus = true
                        store.trackTableFocused = false
                    } else if didFocus && text.isEmpty {
                        didFocus = false
                        expanded = false
                    }
                }
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
    var systemImage: String = "music.note"
    var circle = false
    let eyebrow: String
    let title: String
    let subtitle: String
    var renaming: Binding<String>? = nil
    var onCommitRename: () -> Void = {}
    var onCancelRename: () -> Void = {}
    @EnvironmentObject private var store: AppSession
    @FocusState private var nameFieldFocused: Bool
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        HStack(alignment: .bottom, spacing: 20) {
            CoverArt(seed: seed, artworkPath: artworkPath, systemImage: systemImage, cornerRadius: 16, circle: circle, elevated: true)
                .frame(width: 160, height: 160)
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(LyriaTheme.text2)
                titleView
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(LyriaTheme.foreground)
                    .lineLimit(2)
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
            TextField("名称", text: renaming)
                .textFieldStyle(.plain)
                .focused($nameFieldFocused)
                .onSubmit(onCommitRename)
                .onExitCommand(perform: onCancelRename)
                .onAppear { nameFieldFocused = true }
                .onChange(of: nameFieldFocused) { _, focused in
                    if focused { store.trackTableFocused = false }
                    if !focused { onCommitRename() }
                }
        } else {
            Text(title)
        }
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
