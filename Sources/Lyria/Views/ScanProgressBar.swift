import SwiftUI

struct ScanProgressBar: View {
    let percent: Int
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("正在扫描曲库 · \(percent)%")
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
                .accessibilityLabel("扫描进度")
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
        .padding(.top, 4)
        .padding(.bottom, 10)
    }
}
