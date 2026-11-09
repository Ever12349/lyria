import SwiftUI

struct TransportBar: View {
    @EnvironmentObject private var store: AppSession

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
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LyriaTheme.panel.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(LyriaTheme.border, lineWidth: 1)
        )
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .opacity(0.55)
    }

    private var nowPlayingColumn: some View {
        HStack(spacing: 10) {
            CoverArt(seed: "idle", cornerRadius: 8)
                .frame(width: 44, height: 44)
                .opacity(0.35)
            VStack(alignment: .leading, spacing: 2) {
                Text("—")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LyriaTheme.foreground)
                    .lineLimit(1)
                Text("—")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LyriaTheme.text2)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var controlsColumn: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("0:00")
                    .frame(width: 36, alignment: .trailing)
                progressBar
                Text("0:00")
                    .frame(width: 36, alignment: .leading)
            }
            .font(.system(size: 10, weight: .medium).monospacedDigit())
            .foregroundStyle(LyriaTheme.text3)

            HStack(spacing: 16) {
                // TODO(engine): shuffle, previous, play/pause, next, repeat.
                iconButton("shuffle", label: "随机播放")
                iconButton("backward.fill", label: "上一首")
                playButton
                iconButton("forward.fill", label: "下一首")
                iconButton(RepeatMode.off.systemImage, label: RepeatMode.off.tooltip)
            }
        }
        .frame(maxWidth: 460)
    }

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.12)).frame(height: 3)
            Circle()
                .fill(Color.white)
                .frame(width: 10, height: 10)
                .shadow(color: LyriaTheme.primary.opacity(0.45), radius: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .allowsHitTesting(false)
        .frame(height: 16)
        .accessibilityLabel("播放进度")
        .disabled(true)
    }

    private var playButton: some View {
        Button {} label: {
            ZStack {
                Circle()
                    .fill(LyriaTheme.accentGradient)
                    .frame(width: 40, height: 40)
                    .shadow(color: LyriaTheme.primaryDeep.opacity(0.45), radius: 10, y: 3)
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(true) // TODO(engine)
        .accessibilityLabel("播放")
    }

    private var volumeColumn: some View {
        HStack(spacing: 8) {
            Button {} label: {
                Image(systemName: "music.note.list")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LyriaTheme.text2)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(true) // TODO(engine): queue panel
            .accessibilityLabel("队列")
            .opacity(store.queueVisible ? 1 : 0.85)

            Button {} label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LyriaTheme.text2)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .disabled(true) // TODO(engine)
            .accessibilityLabel("音量")

            Slider(value: .constant(1.0), in: 0...1)
                .controlSize(.mini)
                .tint(LyriaTheme.primary)
                .frame(width: 90)
                .disabled(true) // TODO(engine): volume starts at 1.0 once the engine exists
        }
    }

    private func iconButton(_ systemName: String, label: String) -> some View {
        Button {} label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LyriaTheme.text2)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .disabled(true) // TODO(engine)
        .accessibilityLabel(label)
    }
}
