import SwiftUI
import UIKit

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }

    /// Dynamic token: resolves to `light` or `dark` (hex strings) based on the active
    /// interface style. Lets a single token name serve both themes — `.preferredColorScheme`
    /// (driven by `ThemeManager`) flips the trait collection these resolve against.
    init(light: String, dark: String) {
        self = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hexString: dark)
                : UIColor(hexString: light)
        })
    }
}

extension UIColor {
    /// UIKit hex parser used inside dynamic-colour providers (kept off the SwiftUI bridge
    /// so trait resolution stays in UIKit).
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255,
                  blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

// MARK: - Atlas design tokens (Light + Dark)
//
// Dual-theme, card-based system. Each token carries a Light and a Dark value and resolves
// against the active interface style (driven by `ThemeManager` via `.preferredColorScheme`):
//   • Light — soft off-white canvas, solid white cards, a GREEN primary (original Atlas).
//   • Dark  — WARM charcoal canvas, raised warm-grey cards, an ORANGE primary (mockups).
// Orange stays the star/warning accent in both. Token *names* are stable, so the hundreds
// of existing call sites adapt to either theme automatically.
//
// Dark-palette philosophy: every grey is a *warm* grey (red channel highest, never blue) so
// the UI reads warm next to the orange accent — the previous palette was blue-tinted ("cool"
// grey) and 2-3 shades too dark. Surfaces step up in luminance (bg → card → raised) so cards
// genuinely lift off the canvas instead of melting into it.
extension Color {
    // Canvas & surfaces (dark = neutral greys, NOT warm).
    // `nostiaCard` is now the DEFAULT NEUTRAL surface: generic cards AND buttons/controls all use it.
    // Only experience/trip/vault cards and search bars stay warm — those use `nostiaWarm` instead.
    static let nostiaBackground  = Color(light: "F4F6F9", dark: "3A3A3C")   // app canvas (neutral grey, darkened)
    static let nostiaCard        = Color(light: "FFFFFF", dark: "2C2C2E")   // DEFAULT neutral surface (cards + controls)
    static let nostiaWarm        = Color(light: "FFFFFF", dark: "2E2922")   // WARM surface: experiences / trips / vault / search bars

    // Buttons — same neutral grey as generic cards (darker than the background).
    // Light keeps the original neutral surface so light mode is unchanged.
    static let nostiaButton      = Color(light: "F4F6F9", dark: "2C2C2E")   // button / chip / control fill

    // Borders, dividers & inputs — neutral hairlines (no warmth).
    static let nostriaBorder     = Color(light: "E7ECF1", dark: "454547")   // control / card hairline
    static let nostiaDivider     = Color(light: "EEF1F5", dark: "38383A")   // in-card separators (sits above the lightened card)
    static let nostiaInput       = Color(light: "FFFFFF", dark: "2C2C2E")   // input fields (non-search)

    // Accents & semantic — GREEN primary in Light, ORANGE primary in Dark by default.
    // Computed (not `let`) so unlockable accent themes from the Adventure store can
    // swap the primary pair at render time: `AccentTheme.current` is UserDefaults-
    // backed and `RootView` rebuilds the tree (`.id(accentTheme)`) when it changes.
    // Stock values match the original constants exactly.
    static var nostiaAccent: Color {
        let t = AccentTheme.current
        return Color(light: t.accentLight, dark: t.accentDark)                // primary
    }
    static var nostiaAccentSoft: Color {
        let t = AccentTheme.current
        return Color(light: t.accentSoftLight, dark: t.accentSoftDark)        // primary tint bg
    }
    static let nostiaSuccess     = Color(light: "0E9F6E", dark: "2FBE7E")   // settled / positive
    static let nostiaWarning     = Color(hex: "E8843C")                     // orange in both
    static let nostiaWarningSoft = Color(light: "FEF3E2", dark: "45321E")   // warm star/warning tint
    static let nostiaStar        = Color(hex: "E8843C")                     // orange in both
    static let nostriaDanger     = Color(light: "E5484D", dark: "F0565B")
    static let nostiaBlue        = Color(light: "3B82C4", dark: "4A9BE0")   // secondary blue
    static let nostriaPurple     = Color(light: "3B82C4", dark: "4A9BE0")   // legacy alias → blue
    static let nostiaDisabled    = Color(light: "C2CAD3", dark: "3A3A3A")   // disabled control bg (neutral)

    // Text — warm off-white ink on dark so it harmonises with the warm surfaces.
    static let nostiaTextPrimary = Color(light: "14181F", dark: "F6F1E9")   // ink
    static let nostiaTextSecond  = Color(light: "8A93A0", dark: "ADA59A")
    static let nostiaTextMuted   = Color(light: "A6AEB9", dark: "7E756A")

    // Dev-account gold — usernames of dev accounts render in this gradient pair so
    // they're recognizable anywhere a name appears. Darker on light, brighter on dark.
    static let nostiaGold        = Color(light: "C9930A", dark: "F2C14E")
    static let nostiaGoldDeep    = Color(light: "9A6E06", dark: "D99C1B")

    // Soft shadow — tinted blue-grey on light, pure black for depth on dark.
    static let nostiaShadow      = Color(light: "1E3246", dark: "000000")

    // Card rim — a hairline that *defines* the card edge. On light it's a faint dark hairline;
    // on dark it's a soft top-light "highlight" rim so cards read as raised, not flat. Alpha is
    // baked into the hex (ARGB) so call sites don't need an extra `.opacity()`.
    static let nostiaCardStroke  = Color(light: "0F1E3246", dark: "22FFFFFF")
}

// Shared gradient used as the base canvas for all screens. Resolves light or dark to match
// the active theme so any view referencing `.nostiaGradient` adapts automatically. The dark
// stops are neutral greys centered on the darkened canvas.
extension ShapeStyle where Self == LinearGradient {
    static var nostiaGradient: LinearGradient {
        LinearGradient(
            colors: [Color(light: "F6F8FB", dark: "444446"),
                     Color(light: "F4F6F9", dark: "3A3A3C"),
                     Color(light: "EEF1F5", dark: "2E2E30")],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
