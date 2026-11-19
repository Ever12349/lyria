import SwiftUI

/// Shared scrubber for the transport bar and menu-bar popover.
/// Holds local scrub state so the thumb does not flash through a pre-seek position.
struct PlaybackProgressSlider: View {
    @EnvironmentObject private var store: AppSession
    @Environment(TransportState.self) private var transport
    @State private var scrub: Double?
    @State private var pendingSeekMs: Int?

    var body: some View {
        HStack(spacing: 8) {
            Text(TimeFormat.label(ms: displayedMs))
                .frame(width: 36, alignment: .trailing)
            slider
            Text(TimeFormat.label(ms: transport.durationMs))
                .frame(width: 36, alignment: .leading)
        }
        .font(.system(size: 10, weight: .medium).monospacedDigit())
        .foregroundStyle(LyriaTheme.text3)
    }

    private var displayedFraction: Double {
        scrub ?? transport.fraction
    }

    private var displayedMs: Int {
        Int((displayedFraction * Double(max(transport.durationMs, 0))).rounded())
    }

    private var slider: some View {
        Slider(
            value: Binding(
                get: { displayedFraction },
                set: { scrub = $0 }
            ),
            in: 0...1
        ) { editing in
            if editing {
                pendingSeekMs = nil
                if scrub == nil {
                    scrub = transport.fraction
                }
            } else {
                commitScrub()
            }
        }
        .controlSize(.mini)
        .tint(LyriaTheme.primary)
        .disabled(transport.current == nil)
        .transaction { $0.animation = nil }
        .onChange(of: transport.positionMs) { _, ms in
            clearScrubIfSeekLanded(ms)
        }
        .onChange(of: transport.current?.id) { _, _ in
            pendingSeekMs = nil
            scrub = nil
        }
        .accessibilityLabel("播放进度")
    }

    private func commitScrub() {
        guard let scrub else { return }
        let ms = Int((scrub * Double(max(transport.durationMs, 0))).rounded())
        if abs(ms - transport.positionMs) <= 50 {
            pendingSeekMs = nil
            self.scrub = nil
            return
        }
        pendingSeekMs = ms
        store.transportSeek(ms: ms)
    }

    private func clearScrubIfSeekLanded(_ ms: Int) {
        guard let pending = pendingSeekMs else { return }
        guard abs(ms - pending) <= 50 else { return }
        pendingSeekMs = nil
        scrub = nil
    }
}
