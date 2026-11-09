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
                PillButton(title: "选择文件夹", systemImage: "folder", prominent: true) {
                    store.chooseRootAndScan()
                }
                .disabled(store.isScanning)
                PillButton(title: "打开设置", systemImage: "gearshape") {
                    store.select(.settings)
                }
            }
        }
    }
}
