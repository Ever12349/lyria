import SwiftUI

struct TransportBar: View {
    let track: Track?

    @Binding var isPlaying: Bool
    @Binding var progress: Double
    @Binding var volume: Double
    @Binding var shuffleOn: Bool
    @Binding var repeatOn: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Progress above controls (mock)
            HStack(spacing: 10) {
                Text(format(progress * Double(track?.durationMs ?? 1) / 1000.0))
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(LyriaTheme.mutedForeground)
                    .frame(width: 36, alignment: .trailing)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 4)
                        Capsule()
                            .fill(LyriaTheme.accentGradient)
                            .frame(width: max(8, geo.size.width * progress), height: 4)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                            .shadow(color: LyriaTheme.primary.opacity(0.4), radius: 4, y: 1)
                            .offset(x: max(0, geo.size.width * progress - 5))
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0).onChanged { value in
                            progress = min(max(value.location.x / max(geo.size.width, 1), 0), 1)
                        }
                    )
                }
                .frame(height: 16)

                Text(track?.durationLabel ?? "0:00")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(LyriaTheme.mutedForeground)
                    .frame(width: 36, alignment: .leading)
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)

            HStack(spacing: 16) {
                nowPlayingInfo
                    .frame(minWidth: 180, maxWidth: 240, alignment: .leading)

                Spacer(minLength: 4)

                HStack(spacing: 18) {
                    transportButton("shuffle", active: shuffleOn, size: 13) { shuffleOn.toggle() }
                    transportButton("backward.fill", size: 15) {}
                    Button { isPlaying.toggle() } label: {
                        ZStack {
                            Circle()
                                .fill(LyriaTheme.accentGradient)
                                .frame(width: 40, height: 40)
                                .shadow(color: LyriaTheme.primary.opacity(0.45), radius: 10, y: 3)
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .offset(x: isPlaying ? 0 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                    transportButton("forward.fill", size: 15) {}
                    transportButton("repeat", active: repeatOn, size: 13) { repeatOn.toggle() }
                }

                Spacer(minLength: 4)

                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LyriaTheme.mutedForeground)
                    Slider(value: $volume, in: 0...1)
                        .controlSize(.mini)
                        .tint(LyriaTheme.primary)
                        .frame(width: 96)
                }
                .frame(minWidth: 140, alignment: .trailing)
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
        .background(
            ZStack {
                VisualEffectView(material: .headerView, blendingMode: .withinWindow)
                LinearGradient(
                    colors: [Color.white.opacity(0.05), LyriaTheme.background.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var nowPlayingInfo: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LyriaTheme.accentGradient)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                )
                .shadow(color: LyriaTheme.primaryDeep.opacity(0.4), radius: 12, y: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(track?.title ?? "未在播放")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LyriaTheme.foreground)
                    .lineLimit(1)
                Text(track?.artist ?? "选择一首歌曲")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LyriaTheme.mutedForeground)
                    .lineLimit(1)
            }
        }
    }

    private func transportButton(
        _ systemName: String,
        active: Bool = false,
        size: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(active ? LyriaTheme.primary : Color.white.opacity(0.85))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func format(_ seconds: Double) -> String {
        let total = max(Int(seconds.rounded()), 0)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
