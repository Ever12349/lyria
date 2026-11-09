import SwiftUI

struct QueuePanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("队列")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LyriaTheme.foreground)
                Spacer()
                Text("0 首")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LyriaTheme.text3)
            }
            .padding(.bottom, 4)

            // TODO(engine): list Queue items and start playback from a row.
            Text("队列是空的")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(LyriaTheme.text2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
