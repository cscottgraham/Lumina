import SwiftUI

/// The reusable "frosted glass" surface treatment: a blur material, a subtle
/// tinted fill + accent glow, a specular top-edge stroke, and layered depth
/// shadows. Everything glassy in Lumina composes `.glass(...)`.
struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = Radius.lg
    var accent: AccentTheme = .aurora
    var strong: Bool = false          // brighter fill for prominent surfaces
    var glow: Bool = true

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    // 1. Blur material (the frost).
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    // 2. Tinted fill for readable contrast on dark canvas.
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(strong ? LuminaColors.glassFillStrong : LuminaColors.glassFill)

                    // 3. Accent glow bleeding from a corner.
                    if glow {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(LuminaGradients.glow(accent))
                            .blendMode(.plusLighter)
                            .opacity(0.9)
                    }
                }
            }
            .overlay {
                // 4. Specular top-edge stroke — the tell of real glass.
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(LuminaGradients.specularStroke, lineWidth: 1)
                    .opacity(0.6)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(LuminaColors.glassStrokeSoft, lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            // 5. Depth: a tight contact shadow + a soft ambient one.
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 12)
            .shadow(color: .black.opacity(0.20), radius: 3, x: 0, y: 1)
    }
}

extension View {
    /// Wrap any view in a Lumina glass surface.
    func glass(cornerRadius: CGFloat = Radius.lg,
               accent: AccentTheme = .aurora,
               strong: Bool = false,
               glow: Bool = true) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius, accent: accent, strong: strong, glow: glow))
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
