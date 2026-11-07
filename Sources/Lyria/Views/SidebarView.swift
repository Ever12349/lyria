import SwiftUI

/// Flush with the window top so the traffic lights sit in the sidebar band.
/// Bottom corners stay rounded above the 12pt margin.
private func sidebarCard() -> UnevenRoundedRectangle {
    UnevenRoundedRectangle(
        topLeadingRadius: 0,
        bottomLeadingRadius: LyriaTheme.sidebarRadius,
        bottomTrailingRadius: LyriaTheme.sidebarRadius,
        topTrailingRadius: 0,
        style: .continuous
    )
}

struct SidebarView: View {
    @EnvironmentObject private var store: FakeLibraryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { store.select(.library) } label: {
                Text("Lyria")
                    .font(.system(size: 28, weight: .medium, design: .serif))
                    .foregroundStyle(LyriaTheme.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.top, 40)
            .padding(.bottom, 22)

            VStack(spacing: 6) {
                ForEach(NavItem.primaryItems) { item in
                    navRow(item)
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 12)

            navRow(.settings)
                .padding(.horizontal, 10)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            sidebarCard()
                .fill(LyriaTheme.panel.opacity(0.92))
                .ignoresSafeArea(edges: .top)
        }
        .overlay {
            sidebarCard()
                .strokeBorder(LyriaTheme.border, lineWidth: 1)
                .ignoresSafeArea(edges: .top)
        }
        .clipShape(sidebarCard())
    }

    private func navRow(_ item: NavItem) -> some View {
        let selected = store.currentNav == item
        return Button {
            store.select(item)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 20)
                Text(item.rawValue)
                    .font(.system(size: 14, weight: selected ? .semibold : .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(selected ? Color.white : LyriaTheme.text2)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LyriaTheme.selectedPillGradient)
                        .shadow(color: LyriaTheme.primaryDeep.opacity(0.35), radius: 12, y: 4)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
