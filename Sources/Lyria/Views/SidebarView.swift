import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: AppSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { store.showLibraryHome() } label: {
                Text("Lyria")
                    .font(.system(size: 28, weight: .medium, design: .serif))
                    .foregroundStyle(LyriaTheme.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.top, 40)
            .padding(.bottom, 22)

            VStack(spacing: 6) {
                ForEach(NavItem.primaryItems) { item in
                    if item == .playlists {
                        Rectangle()
                            .fill(LyriaTheme.border)
                            .frame(height: 1)
                            .padding(.vertical, 4)
                    }
                    navRow(item)
                    if item == .playlists {
                        ForEach(store.recentPlaylists) { playlist in
                            shortcutRow(playlist)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 12)

            navRow(.settings)
                .padding(.horizontal, 10)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: LyriaTheme.sidebarRadius, style: .continuous)
                .fill(LyriaTheme.panel.opacity(0.92))
        }
        .overlay {
            RoundedRectangle(cornerRadius: LyriaTheme.sidebarRadius, style: .continuous)
                .strokeBorder(LyriaTheme.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: LyriaTheme.sidebarRadius, style: .continuous))
    }

    private func navRow(_ item: NavItem) -> some View {
        sidebarButton(
            title: item.rawValue,
            systemImage: item.systemImage,
            selected: sectionHighlighted(item)
        ) {
            store.select(item)
        }
    }

    private func shortcutRow(_ playlist: Playlist) -> some View {
        sidebarButton(
            title: playlist.name,
            systemImage: nil,
            selected: shortcutHighlighted(playlist.id)
        ) {
            store.openPlaylist(playlist.id)
        }
    }

    /// On the playlists root, only 「全部播放列表」. On playlist X, only that shortcut.
    private func sectionHighlighted(_ item: NavItem) -> Bool {
        guard store.currentSection == item else { return false }
        guard item == .playlists else { return true }
        if case .playlists = store.route { return true }
        return false
    }

    private func shortcutHighlighted(_ id: String) -> Bool {
        guard case .playlist(let current) = store.route else { return false }
        return current == id
    }

    private func sidebarButton(
        title: String,
        systemImage: String?,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Group {
                    if let systemImage {
                        Image(systemName: systemImage)
                    } else {
                        Color.clear
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 20, height: 18)
                Text(title)
                    .font(.system(size: 14, weight: selected ? .semibold : .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(selected ? Color.white : LyriaTheme.text2)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LyriaTheme.selectedPillGradient)
                        .shadow(color: LyriaTheme.primaryDeep.opacity(0.35), radius: 12, y: 4)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
