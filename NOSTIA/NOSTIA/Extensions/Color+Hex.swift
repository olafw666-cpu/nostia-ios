import SwiftUI

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
}

// MARK: - Atlas (Light) design tokens
//
// The app uses a light, card-based system: a soft off-white canvas, solid white
// surfaces with gentle drop shadows, a green primary, an orange star/accent and a
// blue secondary. Token *names* are kept stable so the hundreds of existing call
// sites flip to the light palette automatically; only the values changed.
extension Color {
    // Canvas & surfaces
    static let nostiaBackground  = Color(hex: "F4F6F9")   // app canvas
    static let nostiaCard        = Color(hex: "FFFFFF")   // cards / sheets surfaces

    // Borders, dividers & inputs
    static let nostriaBorder     = Color(hex: "E7ECF1")   // control / card hairline
    static let nostiaDivider     = Color(hex: "EEF1F5")   // in-card separators
    static let nostiaInput       = Color(hex: "FFFFFF")   // input fields are white cards

    // Accents & semantic
    static let nostiaAccent      = Color(hex: "0E9F6E")   // primary green
    static let nostiaAccentSoft  = Color(hex: "E7F6EF")   // green tint background
    static let nostiaSuccess     = Color(hex: "0E9F6E")
    static let nostiaWarning     = Color(hex: "E8843C")   // orange — stars / warnings
    static let nostiaStar        = Color(hex: "E8843C")
    static let nostriaDanger     = Color(hex: "E5484D")
    static let nostiaBlue        = Color(hex: "3B82C4")   // secondary blue
    static let nostriaPurple     = Color(hex: "3B82C4")   // legacy alias → secondary blue

    // Text
    static let nostiaTextPrimary = Color(hex: "14181F")   // near-black ink
    static let nostiaTextSecond  = Color(hex: "8A93A0")
    static let nostiaTextMuted   = Color(hex: "A6AEB9")

    // Soft shadow colour used by cards (rgba(30,50,70,…))
    static let nostiaShadow      = Color(hex: "1E3246")
}

// Shared gradient used as the base canvas for all screens. Kept as a (now nearly
// flat) light gradient so any view still referencing `.nostiaGradient` stays light.
extension ShapeStyle where Self == LinearGradient {
    static var nostiaGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "F6F8FB"), Color(hex: "F4F6F9"), Color(hex: "EEF1F5")],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
