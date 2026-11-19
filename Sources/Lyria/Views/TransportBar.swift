import AppKit
import SwiftUI
import LyriaCore

struct TransportBar: View {
    @EnvironmentObject private var store: AppSession
    @Environment(TransportState.self) private var transport
    @State private var volumeDrag: Double?

    var body: some View {
        GeometryReader { geo in
            let inner = max(geo.size.width - 24, 1)
            HStack(alignment: .center, spacing: 12) {
                nowPlayingColumn
                    .frame(width: inner / 3.4, alignment: .leading)
                controlsColumn
                    .frame(width: inner * 1.4 / 3.4)
                volumeColumn
                    .frame(width: inner / 3.4, alignment: .trailing)
            }
        }
        .frame(height: 72)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(LyriaTheme.border)
                .frame(height: 1)
                .allowsHitTesting(false)
        }
    }

    private var nowPlayingColumn: some View {
        HStack(spacing: 10) {
            CoverArt(
                seed: transport.current?.id ?? "idle",
                artworkPath: transport.current?.artworkPath,
                cornerRadius: 8
            )
            .frame(width: 44, height: 44)
            .opacity(transport.current == nil ? 0.35 : 1)
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

    private var controlsColumn: some View {
        VStack(spacing: 8) {
            PlaybackProgressSlider()

            HStack(spacing: 16) {
                iconButton("shuffle", label: "随机播放", action: store.transportToggleShuffle, active: transport.shuffle)
                iconButton("backward.fill", label: "上一首", action: store.transportPrevious)
                playButton
                iconButton("forward.fill", label: "下一首", action: store.transportNext)
                iconButton(
                    transport.repeatMode.systemImage,
                    label: transport.repeatMode.tooltip,
                    action: store.transportToggleRepeat,
                    active: transport.repeatMode != .off
                )
            }
        }
        .frame(maxWidth: 460)
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
        .accessibilityLabel(transport.playing ? "暂停" : "播放")
    }

    private var volumeColumn: some View {
        HStack(spacing: 8) {
            Button { store.queueVisible.toggle() } label: {
                Image(systemName: "music.note.list")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LyriaTheme.text2)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("队列")
            .opacity(store.queueVisible ? 1 : 0.85)

            Button(action: store.transportToggleSpeaker) {
                Image(systemName: transport.volume > 0 ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LyriaTheme.text2)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("音量")

            Slider(
                value: Binding(
                    get: { volumeDrag ?? transport.volume },
                    set: { value in
                        volumeDrag = value
                        store.transportSetVolume(value)
                    }
                ),
                in: 0...1
            ) { editing in
                if editing {
                    volumeDrag = volumeDrag ?? transport.volume
                } else {
                    if let volumeDrag {
                        store.transportSetVolume(volumeDrag)
                    }
                    volumeDrag = nil
                }
            }
            .controlSize(.mini)
            .tint(LyriaTheme.primary)
            .frame(width: 90)
        }
    }

    private func iconButton(
        _ systemName: String,
        label: String,
        action: @escaping () -> Void,
        enabled: Bool = true,
        active: Bool = false
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(active ? LyriaTheme.primary : LyriaTheme.text2)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}


/// Own SwiftUI graph so progress ticks cannot relayout the keep-alive pages.
struct IsolatedTransportBar: NSViewRepresentable {
    @EnvironmentObject private var store: AppSession

    func makeNSView(context: Context) -> NSHostingView<AnyView> {
        NSHostingView(rootView: AnyView(
            TransportBar()
                .environmentObject(store)
                .environment(store.transport)
        ))
    }

    func updateNSView(_ nsView: NSHostingView<AnyView>, context: Context) {
        // The inner graph observes TransportState itself. Rebuilding here would
        // dirty the window graph again on unrelated session updates.
    }
}
