import SwiftUI

/// Title-row capsule. Shown only when at least two tracks are selected.
struct BatchActionBar: View {
    var playlistID: String?
    @EnvironmentObject private var store: AppSession

    var body: some View {
        HStack(spacing: 2) {
            Text("已选 \(store.selectedTrackIds.count)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LyriaTheme.foreground)
                .lineLimit(1)
                .padding(.trailing, 4)
            textButton("全选", action: store.selectAllInScope)
            addMenu
            if let playlistID {
                textButton("从列表移除") {
                    store.removeFromPlaylist(store.orderedSelectionIDs(), playlistID: playlistID)
                }
            }
            iconButton("trash", label: "从曲库移除", danger: true) {
                store.requestLibraryRemoval(store.orderedSelectionIDs())
            }
            iconButton("xmark", label: "清除") {
                store.clearSelection()
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .frame(height: 36)
        .fixedSize(horizontal: true, vertical: true)
        .background(Capsule(style: .continuous).fill(LyriaTheme.batchBarFill))
        .overlay(Capsule(style: .continuous).strokeBorder(LyriaTheme.border, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }

    private func textButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(LyriaTheme.text2)
            .padding(.horizontal, 6)
            .frame(height: 28)
            .accessibilityLabel(title)
            .help(title)
    }

    private func iconButton(
        _ systemName: String,
        label: String,
        danger: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(danger ? LyriaTheme.danger : LyriaTheme.text2)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
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
                .padding(.horizontal, 6)
                .frame(height: 28)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("加入播放列表")
        .help("加入播放列表")
    }
}
