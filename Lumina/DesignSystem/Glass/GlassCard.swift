import SwiftUI

/// A padded glass container for arbitrary content. The workhorse surface for
/// lists, tiles, and detail sections.
struct GlassCard<Content: View>: View {
    var accent: AccentTheme = .aurora
    var cornerRadius: CGFloat = Radius.lg
    var padding: CGFloat = Space.md
    var strong: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glass(cornerRadius: cornerRadius, accent: accent, strong: strong)
    }
}

#Preview {
    ZStack {
        AuroraBackground(accent: .aurora).ignoresSafeArea()
        GlassCard(accent: .aurora) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Quantum Computing")
                    .luminaText(LuminaFont.title2())
                Text("12 items · updated today")
                    .luminaText(LuminaFont.subheadline(), color: LuminaColors.textSecondary)
            }
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
