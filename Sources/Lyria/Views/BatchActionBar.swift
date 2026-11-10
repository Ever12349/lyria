import SwiftUI

/// Shown under the page title only when at least two tracks are selected.
struct BatchActionBar: View {
    var playlistID: String?
    @EnvironmentObject private var store: AppSession

    var body: some View {
        HStack(spacing: 8) {
            Text("已选 \(store.selectedTrackIds.count)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LyriaTheme.foreground)
                .lineLimit(1)
            separator
            barButton("全选", action: store.selectAllInScope)
            separator
            barButton("清除", action: store.clearSelection)
            separator
            addMenu
            if let playlistID {
                separator
                barButton("从列表移除") {
                    store.removeFromPlaylist(store.orderedSelectionIDs(), playlistID: playlistID)
                }
            }
            separator
            barButton("从曲库移除", danger: true) {
                store.requestLibraryRemoval(store.orderedSelectionIDs())
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: LyriaTheme.radiusSM, style: .continuous)
                .fill(LyriaTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LyriaTheme.radiusSM, style: .continuous)
                .strokeBorder(LyriaTheme.border, lineWidth: 1)
        )
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("已选 \(store.selectedTrackIds.count) 首")
    }

    private var separator: some View {
        Text("·")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(LyriaTheme.text3)
    }

    private func barButton(_ title: String, danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(danger ? LyriaTheme.danger : LyriaTheme.text2)
    }

    private var addMenu: some View {
        Menu {
            if store.playlists.isEmpty {
                Button("没有播放列表") {}
                    .disabled(true)
            } else {
                ForEach(store.playlists) { playlist in
                    Button(playlist.name) {
                        store.addToPlaylist(store.orderedSelectionIDs(), playlistID: playlist.id)
                    }
                }
            }
        } label: {
            Text("加入播放列表")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LyriaTheme.text2)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("加入播放列表")
    }
}
