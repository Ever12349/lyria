import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: AppSession

    var body: some View {
        TrackTable(tracks: store.visibleTracks)
    }
}

struct LibraryEmptyView: View {
    @EnvironmentObject private var store: AppSession

    var body: some View {
        EmptyState(systemImage: "opticaldisc", title: "还没有音乐") {
            HStack(spacing: 10) {
                PillButton(title: "扫描曲目", systemImage: "folder", prominent: true) {
                    store.scanTracks()
                }
                .disabled(store.scanSession.isRunning)
                PillButton(title: "打开设置", systemImage: "gearshape") {
                    store.select(.settings)
                }
            }
        }
        .lyriaChromeContentPadding()
    }
}
