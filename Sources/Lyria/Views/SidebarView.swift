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
            selected: sectionHighlighted(item)
        ) {
            Image(systemName: item.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 20, height: 18)
        } action: {
            store.select(item)
        }
    }

    private func shortcutRow(_ playlist: Playlist) -> some View {
        sidebarButton(
            title: playlist.name,
            selected: shortcutHighlighted(playlist.id),
            leadingWidth: 24,
            leadingHeight: 24
        ) {
            CoverArt(
                seed: playlist.id,
                artworkPaths: store.artworkPaths(for: playlist),
                systemImage: "music.note.list",
                cornerRadius: 4
            )
            .frame(width: 24, height: 24)
            .opacity(playlist.trackIDs.isEmpty ? 0.45 : 1)
        } action: {
            store.showPlaylist(playlist.id)
        }
    }

    /// 「全部播放列表」 stays selected while a playlist was opened from the grid.
    /// A sidebar shortcut selects only that shortcut.
    private func sectionHighlighted(_ item: NavItem) -> Bool {
        guard store.currentSection == item else { return false }
        guard item == .playlists else { return true }
        if case .playlists = store.playlistsSidebarPage { return true }
        return false
    }

    private func shortcutHighlighted(_ id: String) -> Bool {
        guard store.currentSection == .playlists else { return false }
        if case .playlist(let current) = store.playlistsSidebarPage { return current == id }
        return false
    }

    private func sidebarButton<Leading: View>(
        title: String,
        selected: Bool,
        leadingWidth: CGFloat = 20,
        leadingHeight: CGFloat = 18,
        @ViewBuilder leading: () -> Leading,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                leading()
                    .frame(width: leadingWidth, height: leadingHeight)
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
