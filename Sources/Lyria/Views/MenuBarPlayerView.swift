import SwiftUI
import LyriaCore

/// Menu-bar popover: now playing, transport, and up to three upcoming queue rows.
struct MenuBarPlayerView: View {
    @EnvironmentObject private var store: AppSession
    @Environment(TransportState.self) private var transport
    @Environment(PlaybackQueueState.self) private var queue
    @Environment(\.openWindow) private var openWindow

    private var hasCurrent: Bool { transport.current != nil }

    private var upNextIndices: [Int] {
        MenuBarUpNext.indices(count: queue.rows.count, currentIndex: queue.currentIndex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            nowPlayingHeader
                .padding(14)
                .padding(.bottom, 10)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(LyriaTheme.border)
                        .frame(height: 1)
                }

            VStack(spacing: 10) {
                PlaybackProgressSlider()
                transportButtons
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            upNextSection
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
        .frame(width: 320)
        .background(LyriaTheme.background)
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: .lyriaOpenMainWindow)) { _ in
            openWindow(id: LyriaSceneID.main)
        }
    }

    private var nowPlayingHeader: some View {
        HStack(spacing: 10) {
            CoverArt(
                seed: transport.current?.id ?? "idle",
                artworkPath: transport.current?.artworkPath,
                cornerRadius: 8
            )
            .frame(width: 44, height: 44)
            .opacity(hasCurrent ? 1 : 0.35)

            VStack(alignment: .leading, spacing: 2) {
                Text(transport.current?.title ?? "—")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LyriaTheme.foreground)
                    .lineLimit(1)
                Text(transport.current?.artistLabel ?? "—")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LyriaTheme.text2)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var transportButtons: some View {
        HStack(spacing: 16) {
            iconButton("backward.fill", label: "上一首", action: store.transportPrevious)
            playButton
            iconButton("forward.fill", label: "下一首", action: store.transportNext)
        }
        .frame(maxWidth: .infinity)
    }

    private var playButton: some View {
        Button(action: store.transportToggle) {
            ZStack {
                Circle()
                    .fill(LyriaTheme.accentGradient)
                    .frame(width: 40, height: 40)
                    .shadow(color: LyriaTheme.primaryDeep.opacity(0.45), radius: 10, y: 3)
                Image(systemName: transport.playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: transport.playing ? 0 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!hasCurrent)
        .accessibilityLabel(transport.playing ? "暂停" : "播放")
    }

    private var upNextSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("接下来")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LyriaTheme.text3)

            if upNextIndices.isEmpty {
                Text("队列里没有下一首")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LyriaTheme.text3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(upNextIndices, id: \.self) { index in
                        upNextRow(index: index)
                    }
                }
            }
        }
    }

    private func upNextRow(index: Int) -> some View {
        let row = queue.rows[index]
        let artist = row.artist.isEmpty ? "未知艺人" : row.artist
        let label = row.missing ? "文件缺失" : "\(row.title) · \(artist)"
        return Button {
            store.playQueueRow(index)
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(row.missing ? LyriaTheme.danger : LyriaTheme.foreground)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(LyriaTheme.border)
                .frame(height: 1)
        }
    }

    private func iconButton(
        _ systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LyriaTheme.text2)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .disabled(!hasCurrent)
        .accessibilityLabel(label)
    }
}
