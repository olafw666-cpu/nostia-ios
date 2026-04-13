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

// Design tokens
extension Color {
    // Backgrounds — deep navy/indigo for rich glass refraction
    static let nostiaBackground  = Color(hex: "0C1120")
    static let nostiaCard        = Color(hex: "1C2537")

    // Borders & inputs
    static let nostriaBorder     = Color(hex: "374151")
    static let nostiaInput       = Color(hex: "1E2A3A")

    // Accents & semantic
    static let nostiaAccent      = Color(hex: "3B82F6")
    static let nostiaSuccess     = Color(hex: "10B981")
    static let nostiaWarning     = Color(hex: "F59E0B")
    static let nostriaDanger     = Color(hex: "EF4444")
    static let nostriaPurple     = Color(hex: "8B5CF6")

    // Text
    static let nostiaTextPrimary = Color.white
    static let nostiaTextSecond  = Color(hex: "9CA3AF")
    static let nostiaTextMuted   = Color(hex: "6B7280")
}

// Shared gradient used as the base for all liquid glass screens
extension ShapeStyle where Self == LinearGradient {
    static var nostiaGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(hex: "0C1120"), location: 0.0),
                .init(color: Color(hex: "1A0E35"), location: 0.5),
                .init(color: Color(hex: "0A1628"), location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
