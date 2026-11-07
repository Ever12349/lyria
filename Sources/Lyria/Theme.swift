import SwiftUI

enum LyriaTheme {
    static let background = Color(red: 10 / 255, green: 11 / 255, blue: 26 / 255) // #0a0b1a
    static let panel = Color(red: 18 / 255, green: 19 / 255, blue: 31 / 255) // #12131f
    static let panel2 = Color(red: 26 / 255, green: 27 / 255, blue: 46 / 255) // #1a1b2e
    static let foreground = Color.white
    static let text2 = Color(red: 161 / 255, green: 161 / 255, blue: 181 / 255) // #a1a1b5
    static let text3 = Color(red: 107 / 255, green: 107 / 255, blue: 128 / 255) // #6b6b80
    static let mutedForeground = text2
    static let primary = Color(red: 155 / 255, green: 135 / 255, blue: 245 / 255) // #9b87f5
    static let primaryDeep = Color(red: 124 / 255, green: 58 / 255, blue: 237 / 255) // #7c3aed
    static let danger = Color(red: 255 / 255, green: 123 / 255, blue: 114 / 255) // #ff7b72
    static let card = Color.white.opacity(0.03)
    static let row = Color.white.opacity(0.03)
    static let border = Color.white.opacity(0.12)
    static let borderStrong = Color.white.opacity(0.18)
    static let searchFill = Color.white.opacity(0.06)
    static let sidebarAccent = Color(red: 155 / 255, green: 135 / 255, blue: 245 / 255).opacity(0.18)

    static let radiusSM: CGFloat = 12
    static let radiusMD: CGFloat = 16
    static let radiusLG: CGFloat = 22
    static let sidebarInset: CGFloat = 12

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [primary, primaryDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var softAccentGradient: LinearGradient {
        LinearGradient(
            colors: [primary.opacity(0.28), primaryDeep.opacity(0.16)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var selectedPillGradient: LinearGradient {
        LinearGradient(
            colors: [primary, primaryDeep],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func coverGradient(seed: String) -> LinearGradient {
        let presets: [[Color]] = [
            [primary, primaryDeep],
            [Color(red: 176 / 255, green: 140 / 255, blue: 1), primaryDeep],
            [Color(red: 125 / 255, green: 108 / 255, blue: 245 / 255), Color(red: 88 / 255, green: 48 / 255, blue: 214 / 255)],
            [Color(red: 196 / 255, green: 160 / 255, blue: 1), Color(red: 109 / 255, green: 70 / 255, blue: 224 / 255)],
            [primary.opacity(0.95), Color(red: 76 / 255, green: 42 / 255, blue: 196 / 255)],
        ]
        let index = abs(seed.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) }) % presets.count
        return LinearGradient(
            colors: presets[index],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
