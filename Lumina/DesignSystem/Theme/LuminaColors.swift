import SwiftUI

/// Core palette. Dark-mode-first: the app forces a dark interface (see
/// project.yml `UIUserInterfaceStyle: Dark`) so these are tuned for depth on a
/// near-black canvas.
enum LuminaColors {
    // Base canvas (behind the aurora + glass).
    static let canvas       = Color(hex: "#06070C")
    static let canvasRaised  = Color(hex: "#0C0E16")

    // Text.
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.68)
    static let textTertiary  = Color.white.opacity(0.42)

    // Glass surface tints (layered over blur material).
    static let glassFill      = Color.white.opacity(0.06)
    static let glassFillStrong = Color.white.opacity(0.10)
    static let glassStroke    = Color.white.opacity(0.14)
    static let glassStrokeSoft = Color.white.opacity(0.08)
    static let glassHighlight  = Color.white.opacity(0.55) // specular top edge

    static let separator = Color.white.opacity(0.08)

    // Semantic.
    static let success = Color(hex: "#34D399")
    static let warning = Color(hex: "#FBBF24")
    static let danger  = Color(hex: "#FB7185")
}

extension Color {
    /// Hex initializer supporting "#RGB", "#RRGGBB", "#AARRGGBB".
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let a, r, g, b: UInt64
        switch s.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (value >> 8 & 0xF) * 17, (value >> 4 & 0xF) * 17, (value & 0xF) * 17)
        case 6: // RRGGBB
            (a, r, g, b) = (255, value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF)
        case 8: // AARRGGBB
            (a, r, g, b) = (value >> 24 & 0xFF, value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(.sRGB,
                  red: Double(r) / 255, green: Double(g) / 255,
                  blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
