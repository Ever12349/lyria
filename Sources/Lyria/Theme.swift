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
    static let sidebarRadius: CGFloat = 18
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

    /// Selected track row. Softer than `softAccentGradient`, which stays the now-playing wash.
    static var selectedRowFill: LinearGradient {
        LinearGradient(
            colors: [primary.opacity(0.23), primaryDeep.opacity(0.13)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Batch capsule in the title row. Quieter than the selected row wash.
    static var batchBarFill: LinearGradient {
        LinearGradient(
            colors: [primary.opacity(0.16), primaryDeep.opacity(0.10)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Enforced on the SwiftUI frame and on `NSWindow.minSize` / `contentMinSize`.
    static let windowMinimum = CGSize(width: 980, height: 640)

    static var selectedPillGradient: LinearGradient {
        LinearGradient(
            colors: [primary, primaryDeep],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Same hash as the HTML prototype `coverStyle`: hue from the album id.
    static func coverGradient(seed: String) -> LinearGradient {
        var hash: UInt32 = 0
        for scalar in seed.unicodeScalars {
            hash = hash &* 33 &+ UInt32(scalar.value)
        }
        let hue = Double(hash % 360)
        return LinearGradient(
            colors: [hsl(hue, 58, 58), hsl((hue + 32).truncatingRemainder(dividingBy: 360), 46, 34)],
            startPoint: UnitPoint(x: 0.2, y: 0),
            endPoint: UnitPoint(x: 0.8, y: 1)
        )
    }

    private static func hsl(_ h: Double, _ s: Double, _ l: Double) -> Color {
        let sat = s / 100
        let lig = l / 100
        let c = (1 - abs(2 * lig - 1)) * sat
        let hp = h / 60
        let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        let m = lig - c / 2
        let rgb: (Double, Double, Double)
        switch hp {
        case 0..<1: rgb = (c, x, 0)
        case 1..<2: rgb = (x, c, 0)
        case 2..<3: rgb = (0, c, x)
        case 3..<4: rgb = (0, x, c)
        case 4..<5: rgb = (x, 0, c)
        default: rgb = (c, 0, x)
        }
        return Color(red: rgb.0 + m, green: rgb.1 + m, blue: rgb.2 + m)
    }
}

struct TopChromeHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct TitleRowHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct TitleRowWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Height of the pinned title bar plus any scan bar and library column header.
private enum LyriaChromeTopInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 88
}

extension EnvironmentValues {
    var lyriaChromeTopInset: CGFloat {
        get { self[LyriaChromeTopInsetKey.self] }
        set { self[LyriaChromeTopInsetKey.self] = newValue }
    }
}

extension View {
    /// Top padding so page content starts clear of the overlaid title bar.
    func lyriaChromeContentPadding() -> some View {
        modifier(LyriaChromeContentPadding())
    }
}

private struct LyriaChromeContentPadding: ViewModifier {
    @Environment(\.lyriaChromeTopInset) private var inset

    func body(content: Content) -> some View {
        content.padding(.top, inset)
    }
}
