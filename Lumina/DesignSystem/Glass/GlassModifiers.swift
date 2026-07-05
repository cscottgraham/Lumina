import SwiftUI

/// The frost weight of a glass surface.
/// `ultraThin` for content cards (backdrop stays alive behind them);
/// `regular` for chrome that must dominate what's under it (nav/tab bars,
/// alerts, inputs).
enum GlassDepth {
    case ultraThin
    case regular

    var material: Material {
        switch self {
        case .ultraThin: return .ultraThinMaterial
        case .regular:   return .regularMaterial
        }
    }
}

/// The reusable "frosted glass" surface treatment: a blur material, a subtle
/// tinted fill (optionally a vibrant accent tint), an accent glow, a specular
/// top-edge stroke, and layered depth shadows. Everything glassy in Lumina
/// composes `.glass(...)`.
struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = Radius.lg
    var accent: AccentTheme = .aurora
    var depth: GlassDepth = .ultraThin
    var strong: Bool = false          // brighter fill for prominent surfaces
    var glow: Bool = true             // accent corner glow
    var vibrant: Bool = false         // accent-gradient tinted fill

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    // 1. Blur material (the frost).
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(depth.material)

                    // 2. Fill: neutral tint for contrast, or a vibrant accent wash.
                    if vibrant {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(LuminaGradients.linear(accent).opacity(0.18))
                    }
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(strong ? LuminaColors.glassFillStrong : LuminaColors.glassFill)

                    // 3. Accent glow bleeding from a corner.
                    if glow {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(LuminaGradients.glow(accent))
                            .blendMode(.plusLighter)
                            .opacity(vibrant ? 1.0 : 0.9)
                    }
                }
            }
            .overlay {
                // 4. Specular top-edge stroke — the tell of real glass —
                //    plus a faint uniform hairline for edge definition.
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(LuminaGradients.specularStroke, lineWidth: 1)
                    .opacity(0.6)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(LuminaColors.glassStrokeSoft, lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            // 5. Depth: a soft ambient shadow + a tight contact shadow.
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 12)
            .shadow(color: .black.opacity(0.20), radius: 3, x: 0, y: 1)
    }
}

extension View {
    /// Wrap any view in a Lumina glass surface.
    func glass(cornerRadius: CGFloat = Radius.lg,
               accent: AccentTheme = .aurora,
               depth: GlassDepth = .ultraThin,
               strong: Bool = false,
               glow: Bool = true,
               vibrant: Bool = false) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius, accent: accent,
                                 depth: depth, strong: strong, glow: glow, vibrant: vibrant))
    }

    /// A thin accent stroke used to emphasize selection/focus.
    func glassStroke(_ accent: AccentTheme, cornerRadius: CGFloat = Radius.lg, lineWidth: CGFloat = 1.5) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(LuminaGradients.linear(accent), lineWidth: lineWidth)
                .opacity(0.9)
        }
    }
}
