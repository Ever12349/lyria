import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppSession

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                SettingRow(title: "允许经 MCP 控制", detail: "关闭后 Cursor 无法连接本机播放") {
                    SettingToggle(
                        isOn: Binding(
                            get: { store.mcpEnabled },
                            set: { store.setMCPEnabled($0) }
                        ),
                        label: "允许经 MCP 控制"
                    )
                }
                SettingRow(title: "本地 HTTP API", detail: "可选，默认关闭 · 端口 17890") {
                    OffToggle(label: "本地 HTTP API") {
                        store.showToast("本地 HTTP API 保持关闭")
                    }
                }
                SettingRow(title: "登录时启动", detail: "开机后以菜单栏形态待命") {
                    OffToggle(label: "登录时启动") {
                        store.showToast("登录时启动仍未开放")
                    }
                }
                SettingRow(title: "外观 · Deep Space", detail: "左右栏同色深空底，无壁纸吸色 vibrancy") {
                    PillButton(title: "当前主题") {
                        store.showToast("外观固定为 Deep Space")
                    }
                }
                SettingRow(title: "清除指纹缓存", detail: "危险操作 · 旧 id 全部失效，歌单里的旧 id 会变成缺失", danger: true) {
                    PillButton(title: "清除", danger: true) {
                        confirmClearFingerprints()
                    }
                    .disabled(store.scanSession.isRunning)
                }
            }
            .lyriaChromeContentPadding()
        }
    }

    private func confirmClearFingerprints() {
        let alert = NSAlert()
        alert.messageText = "清除指纹缓存？"
        alert.informativeText = "旧 id 将全部失效。曲目索引会被清空，播放列表里的旧 id 会显示为文件缺失。磁盘上的音频文件不会删除。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "清除")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        store.clearFingerprints()
    }
}
