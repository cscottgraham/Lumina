import SwiftUI

/// A padded glass container for arbitrary content — the workhorse surface for
/// lists, tiles, and detail sections. Set `vibrant: true` for an accent-tinted
/// wash (hero cards, primary sections); leave it off for neutral content glass.
struct GlassCard<Content: View>: View {
    var accent: AccentTheme = .aurora
    var cornerRadius: CGFloat = Radius.lg
    var padding: CGFloat = Space.md
    var depth: GlassDepth = .ultraThin
    var strong: Bool = false
    var vibrant: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glass(cornerRadius: cornerRadius, accent: accent, depth: depth,
                   strong: strong, vibrant: vibrant)
            // Guarantees the full card is one hit-testable region — without
            // this, a bare .onTapGesture/Button wrapping a card whose content
            // includes Spacers or padding can silently miss taps in those areas.
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

#Preview("GlassCard variants") {
    ZStack {
        AuroraBackground(accent: .aurora).ignoresSafeArea()
        VStack(spacing: Space.md) {
            GlassCard(accent: .aurora) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Neutral glass").luminaText(LuminaFont.title2())
                    Text("ultraThinMaterial · content card")
                        .luminaText(LuminaFont.subheadline(), color: LuminaColors.textSecondary)
                }
            }
            GlassCard(accent: .aurora, vibrant: true) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Vibrant tint").luminaText(LuminaFont.title2())
                    Text("accent-gradient wash · hero card")
                        .luminaText(LuminaFont.subheadline(), color: LuminaColors.textSecondary)
                }
            }
            GlassCard(accent: .sunset, depth: .regular, strong: true) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Regular material").luminaText(LuminaFont.title2())
                    Text("regularMaterial · chrome-weight surface")
                        .luminaText(LuminaFont.subheadline(), color: LuminaColors.textSecondary)
                }
            }
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
