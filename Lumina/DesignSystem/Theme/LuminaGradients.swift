import SwiftUI

/// Vibrant accent gradients, one per `AccentTheme`. Each subject picks an
/// accent that tints its glass, its aurora background, and its buttons.
enum LuminaGradients {

    /// The two-to-three stop colors that define an accent.
    static func stops(for accent: AccentTheme) -> [Color] {
        switch accent {
        case .aurora: return [Color(hex: "#5EEAD4"), Color(hex: "#818CF8"), Color(hex: "#C084FC")]
        case .sunset: return [Color(hex: "#FBBF24"), Color(hex: "#FB7185"), Color(hex: "#E879F9")]
        case .ocean:  return [Color(hex: "#38BDF8"), Color(hex: "#22D3EE"), Color(hex: "#2DD4BF")]
        case .forest: return [Color(hex: "#4ADE80"), Color(hex: "#A3E635"), Color(hex: "#22D3EE")]
        case .rose:   return [Color(hex: "#FB7185"), Color(hex: "#F472B6"), Color(hex: "#FDBA74")]
        case .mono:   return [Color(hex: "#9CA3AF"), Color(hex: "#6B7280"), Color(hex: "#D1D5DB")]
        }
    }

    /// The primary accent color (first stop) — for text, icons, meters.
    static func accentColor(_ accent: AccentTheme) -> Color { stops(for: accent).first ?? .white }

    /// A linear gradient for buttons, chips, and highlights.
    static func linear(_ accent: AccentTheme, from: UnitPoint = .topLeading, to: UnitPoint = .bottomTrailing) -> LinearGradient {
        LinearGradient(colors: stops(for: accent), startPoint: from, endPoint: to)
    }

    /// A soft radial glow used inside glass fills.
    static func glow(_ accent: AccentTheme) -> RadialGradient {
        RadialGradient(colors: [accentColor(accent).opacity(0.35), .clear],
                       center: .topLeading, startRadius: 0, endRadius: 260)
    }

    /// The specular top-edge stroke that sells the "glass" look.
    static var specularStroke: LinearGradient {
        LinearGradient(colors: [LuminaColors.glassHighlight, .white.opacity(0.05), .clear],
                       startPoint: .top, endPoint: .bottom)
    }
}
