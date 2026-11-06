import SwiftUI

enum LyriaTheme {
    static let background = Color(red: 10 / 255, green: 11 / 255, blue: 26 / 255) // #0a0b1a
    static let foreground = Color.white
    static let mutedForeground = Color(red: 160 / 255, green: 160 / 255, blue: 176 / 255) // #a0a0b0
    static let primary = Color(red: 155 / 255, green: 135 / 255, blue: 245 / 255) // #9b87f5
    static let primaryDeep = Color(red: 124 / 255, green: 58 / 255, blue: 237 / 255) // #7c3aed
    static let card = Color.white.opacity(0.05)
    static let row = Color.white.opacity(0.04)
    static let border = Color.white.opacity(0.14)
    static let searchFill = Color.white.opacity(0.07)
    static let sidebarAccent = Color(red: 155 / 255, green: 135 / 255, blue: 245 / 255).opacity(0.18)

    static let radiusSM: CGFloat = 16
    static let radiusMD: CGFloat = 20
    static let radiusLG: CGFloat = 24

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [primary, primaryDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var softAccentGradient: LinearGradient {
        LinearGradient(
            colors: [primary.opacity(0.35), primaryDeep.opacity(0.22)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var selectedPillGradient: LinearGradient {
        LinearGradient(
            colors: [primary, primaryDeep],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
