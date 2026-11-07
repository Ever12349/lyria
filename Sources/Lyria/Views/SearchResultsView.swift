import SwiftUI

struct SearchResultsView: View {
    @EnvironmentObject private var store: FakeLibraryStore

    var body: some View {
        if store.searchTracks.isEmpty {
            EmptyState(
                systemImage: "magnifyingglass",
                title: "无搜索结果",
                message: "找不到与「\(store.trimmedQuery)」匹配的音乐、艺人或专辑。"
            ) { EmptyView() }
        } else {
            TrackTable(tracks: store.searchTracks)
        }
    }
}
