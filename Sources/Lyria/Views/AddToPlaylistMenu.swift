import SwiftUI

struct PlaylistAddAction: Identifiable {
    var id: String
    var title: String
    var run: () -> Void
}

/// One 「加入播放列表」 list for the row menu, the batch bar, and the AppKit context menu.
enum PlaylistAddMenu {
    @MainActor
    static func actions(trackIDs: [String], store: AppSession) -> [PlaylistAddAction] {
        var rows = [
            PlaylistAddAction(id: "new", title: "新建播放列表") {
                store.promptNewPlaylist(adding: trackIDs)
            }
        ]
        rows += store.playlists.map { playlist in
            PlaylistAddAction(id: playlist.id, title: playlist.name) {
                store.addToPlaylist(trackIDs, playlistID: playlist.id)
            }
        }
        return rows
    }
}

struct AddToPlaylistMenuItems: View {
    var trackIDs: [String]
    @EnvironmentObject private var store: AppSession

    var body: some View {
        let actions = PlaylistAddMenu.actions(trackIDs: trackIDs, store: store)
        if let create = actions.first {
            Button(create.title, action: create.run)
        }
        if actions.count > 1 {
            Divider()
        }
        ForEach(Array(actions.dropFirst())) { action in
            Button(action.title, action: action.run)
        }
    }
}
