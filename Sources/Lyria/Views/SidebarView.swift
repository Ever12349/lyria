import SwiftUI

struct SidebarView: View {
    @Binding var selection: NavItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Lyria")
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(LyriaTheme.foreground)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 22)

            VStack(spacing: 6) {
                ForEach(NavItem.primaryItems) { item in
                    navRow(item)
                }
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 12)

            navRow(.settings)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(LyriaTheme.mutedForeground.opacity(0.35))
                        .frame(width: 3, height: 3)
                }
            }
            .padding(.leading, 22)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Same Deep Space base as the detail column. Avoid .hudWindow/.behindWindow —
        // that samples desktop wallpaper and casts gray/green vs the solid right pane.
        .background {
            ZStack {
                LyriaTheme.background
                // Soft purple sheen so the column still reads slightly glassier
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.045),
                        LyriaTheme.primary.opacity(0.05),
                        LyriaTheme.background.opacity(0.15)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    private func navRow(_ item: NavItem) -> some View {
        let selected = selection == item
        return Button {
            selection = item
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 22)
                Text(item.rawValue)
                    .font(.system(size: 14, weight: selected ? .semibold : .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(selected ? Color.white : LyriaTheme.mutedForeground)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: LyriaTheme.radiusSM, style: .continuous)
                        .fill(LyriaTheme.selectedPillGradient)
                        .shadow(color: LyriaTheme.primary.opacity(0.35), radius: 12, y: 4)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: LyriaTheme.radiusSM, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
