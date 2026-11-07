import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: FakeLibraryStore

    var body: some View {
        ScrollView {
        VStack(spacing: 12) {
            SettingRow(title: "曲库路径", detail: "~/Music/Lyria · 添加 / 移除文件夹后自动扫描") {
                Menu {
                    Button(store.libraryEmpty ? "恢复示例曲库" : "查看空曲库") {
                        if store.libraryEmpty { store.restoreLibrary() }
                        else { store.previewEmptyLibrary() }
                    }
                } label: {
                    Text("管理…")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                        .overlay(Capsule().strokeBorder(LyriaTheme.border, lineWidth: 1))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            SettingRow(title: "重新扫描曲库", detail: "按路径指纹重建索引，不改动文件") {
                PillButton(title: "立即扫描") {
                    store.showToast("重新扫描仍是静态壳")
                }
            }
            SettingRow(title: "本地 HTTP API", detail: "可选，默认关闭 · 端口 17890") {
                OffToggle(label: "本地 HTTP API") {
                    store.showToast("本地 HTTP API 保持关闭")
                }
            }
            SettingRow(title: "登录时启动", detail: "开机后以菜单栏形态待命") {
                OffToggle(label: "登录时启动") {
                    store.showToast("登录时启动仍是静态壳")
                }
            }
            SettingRow(title: "外观 · Deep Space", detail: "左右栏同色深空底，无壁纸吸色 vibrancy") {
                PillButton(title: "当前主题") {
                    store.showToast("外观固定为 Deep Space")
                }
            }
            SettingRow(title: "清除指纹缓存", detail: "危险操作 · 下次打开将全量重建 trk_ 索引", danger: true) {
                PillButton(title: "清除", danger: true) {
                    store.showToast("清除指纹缓存仍是静态壳")
                }
            }
        }
        }
    }
}
