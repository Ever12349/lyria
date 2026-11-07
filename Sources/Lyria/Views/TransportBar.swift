import SwiftUI

struct TransportBar: View {
    @EnvironmentObject private var store: FakeLibraryStore
    @State private var volumeBeforeMute = 0.6

    private var track: Track? { store.nowPlaying }
    private var durationMs: Int { track?.durationMs ?? 0 }
    private var progress: Double {
        guard durationMs > 0 else { return 0 }
        return min(max(Double(store.positionMs) / Double(durationMs), 0), 1)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            nowPlayingColumn
                .frame(maxWidth: .infinity, alignment: .leading)
            controlsColumn
                .frame(maxWidth: .infinity)
            volumeColumn
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: LyriaTheme.radiusMD, style: .continuous)
                .fill(LyriaTheme.panel.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LyriaTheme.radiusMD, style: .continuous)
                .strokeBorder(LyriaTheme.border, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        .opacity(track == nil ? 0.45 : 1)
    }

    private var nowPlayingColumn: some View {
        HStack(spacing: 10) {
            Button {
                guard let album = track?.album else { return }
                store.openAlbum(named: album)
            } label: {
                CoverArt(seed: track?.id ?? "idle", cornerRadius: 8)
                    .frame(width: 44, height: 44)
                    .opacity(track == nil ? 0.4 : 1)
            }
            .buttonStyle(.plain)
            .disabled(track == nil)
            .accessibilityLabel(track == nil ? "没有正在播放" : "打开专辑")

            VStack(alignment: .leading, spacing: 2) {
                Text(track?.title ?? "未在播放")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LyriaTheme.foreground)
                    .lineLimit(1)
                Text(track?.artist ?? "—")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LyriaTheme.text2)
                    .lineLimit(1)
            }

            if let track {
                Menu {
                    TrackMenu.items(track: track, playlistID: nil, store: store)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LyriaTheme.text2)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 28, height: 28)
                .accessibilityLabel("更多")
            }
            Spacer(minLength: 0)
        }
    }

    private var controlsColumn: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(TimeFormat.label(ms: store.positionMs))
                    .frame(width: 36, alignment: .trailing)
                progressBar
                Text(track?.durationLabel ?? "0:00")
                    .frame(width: 36, alignment: .leading)
            }
            .font(.system(size: 10, weight: .medium).monospacedDigit())
            .foregroundStyle(LyriaTheme.text3)

            HStack(spacing: 16) {
                iconButton("shuffle", active: store.shuffleOn, label: store.shuffleOn ? "关闭随机" : "随机播放") {
                    store.toggleShuffle()
                }
                iconButton("backward.fill", label: "上一首") { store.skip(-1) }
                playButton
                iconButton("forward.fill", label: "下一首") { store.skip(1) }
                iconButton(
                    store.repeatMode.systemImage,
                    active: store.repeatMode != .off,
                    label: "重复：\(store.repeatMode.label)"
                ) {
                    store.cycleRepeat()
                }
            }
        }
        .frame(maxWidth: 460)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12)).frame(height: 3)
                Capsule()
                    .fill(LyriaTheme.accentGradient)
                    .frame(width: max(0, width * progress), height: 3)
                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .shadow(color: LyriaTheme.primary.opacity(0.45), radius: 4)
                    .offset(x: max(0, width * progress - 5))
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                    guard durationMs > 0 else { return }
                    store.seek(toProgress: value.location.x / width, durationMs: durationMs)
                }
            )
        }
        .frame(height: 16)
        .accessibilityLabel("播放进度")
    }

    private var playButton: some View {
        Button { store.togglePlay() } label: {
            ZStack {
                Circle()
                    .fill(LyriaTheme.accentGradient)
                    .frame(width: 40, height: 40)
                    .shadow(color: LyriaTheme.primaryDeep.opacity(0.45), radius: 10, y: 3)
                Image(systemName: store.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: store.isPlaying ? 0 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(track == nil)
        .accessibilityLabel(store.isPlaying ? "暂停" : "播放")
    }

    private var volumeColumn: some View {
        HStack(spacing: 8) {
            Button {
                if store.volume > 0.001 {
                    volumeBeforeMute = store.volume
                    store.volume = 0
                } else {
                    store.volume = volumeBeforeMute > 0 ? volumeBeforeMute : 0.6
                }
            } label: {
                Image(systemName: volumeSymbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LyriaTheme.text2)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("音量")

            Slider(value: $store.volume, in: 0...1)
                .controlSize(.mini)
                .tint(LyriaTheme.primary)
                .frame(width: 90)

            Button { store.toggleQueue() } label: {
                Image(systemName: "music.note.list")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(store.queueVisible ? LyriaTheme.primary : LyriaTheme.text2)
                    .frame(width: 28, height: 28)
                    .background {
                        if store.queueVisible {
                            Circle().fill(LyriaTheme.primary.opacity(0.16))
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.queueVisible ? "关闭队列" : "打开队列")
        }
    }

    private var volumeSymbol: String {
        if store.volume <= 0.001 { return "speaker.slash.fill" }
        if store.volume < 0.34 { return "speaker.fill" }
        if store.volume < 0.67 { return "speaker.wave.1.fill" }
        return "speaker.wave.2.fill"
    }

    private func iconButton(
        _ systemName: String,
        active: Bool = false,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(active ? LyriaTheme.primary : LyriaTheme.text2)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(track == nil)
        .accessibilityLabel(label)
    }
}
