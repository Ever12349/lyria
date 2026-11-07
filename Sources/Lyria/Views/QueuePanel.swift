import SwiftUI

struct QueuePanel: View {
    @EnvironmentObject private var store: FakeLibraryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("队列")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LyriaTheme.foreground)
                Spacer()
                Text("\(store.queue.count) 首")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LyriaTheme.text3)
            }
            .padding(.bottom, 4)

            if store.queue.isEmpty {
                Text("队列是空的")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(LyriaTheme.text2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(Array(store.queue.enumerated()), id: \.offset) { index, id in
                            if let track = store.track(id) {
                                queueRow(track, index: index)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LyriaTheme.panel.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(LyriaTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 24, y: 8)
    }

    private func queueRow(_ track: Track, index: Int) -> some View {
        let current = track.id == store.nowPlayingId
        return HStack(spacing: 8) {
            Button { store.play(track.id) } label: {
                HStack(spacing: 8) {
                    CoverArt(seed: track.id, cornerRadius: 6)
                        .frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LyriaTheme.foreground)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(LyriaTheme.text2)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Text(track.durationLabel)
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(LyriaTheme.text3)
                }
            }
            .buttonStyle(.plain)

            Button { store.removeFromQueue(at: index) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(LyriaTheme.text3)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("从队列移除")
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(current ? AnyShapeStyle(LyriaTheme.softAccentGradient) : AnyShapeStyle(Color.white.opacity(0.03)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(current ? LyriaTheme.primary.opacity(0.55) : LyriaTheme.border, lineWidth: 1)
        )
    }
}
