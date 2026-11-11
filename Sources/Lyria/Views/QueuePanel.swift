import SwiftUI

struct QueuePanel: View {
    @EnvironmentObject private var store: AppSession
    @Environment(PlaybackQueueState.self) private var queue
    @Environment(TransportState.self) private var transport

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("队列")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LyriaTheme.foreground)
                Spacer()
                Text("\(queue.rows.count) 首")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LyriaTheme.text3)
            }
            .padding(.bottom, 4)

            if queue.rows.isEmpty {
                Text("队列是空的")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(LyriaTheme.text2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(queue.rows.enumerated()), id: \.element.id) { index, row in
                            Button {
                                store.playQueueRow(index)
                            } label: {
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(row.missing ? "文件缺失" : row.title)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(row.missing ? LyriaTheme.danger : LyriaTheme.foreground)
                                            .lineLimit(1)
                                        Text(row.artist.isEmpty ? "未知艺人" : row.artist)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(LyriaTheme.text2)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background {
                                    if transport.current?.id == row.id {
                                        LyriaTheme.softAccentGradient
                                    }
                                }
                            }
                            .buttonStyle(.plain)
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
}
