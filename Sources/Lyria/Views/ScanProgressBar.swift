import SwiftUI

struct ScanProgressBar: View {
    let title: String
    let percent: Int
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LyriaTheme.foreground)
                    .lineLimit(1)
                GeometryReader { geo in
                    let width = max(0, geo.size.width * CGFloat(min(max(percent, 0), 100)) / 100)
                    ZStack(alignment: .leading) {
                        Capsule().fill(LyriaTheme.border)
                        Capsule()
                            .fill(LyriaTheme.accentGradient)
                            .frame(width: width)
                    }
                }
                .frame(height: 4)
                .accessibilityLabel(title)
                .accessibilityValue("\(percent)%")
            }
            Button("取消", action: onCancel)
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LyriaTheme.text2)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(Capsule().fill(LyriaTheme.searchFill))
                .overlay(Capsule().strokeBorder(LyriaTheme.border, lineWidth: 1))
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 6)
    }
}
