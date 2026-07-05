import SwiftUI

/// A glass search field: regular-material pill, accent focus ring, clear
/// button, and an animated Cancel that appears while editing.
struct GlassSearchBar: View {
    @Binding var text: String
    var prompt: String = "Search your vault…"
    var accent: AccentTheme = .aurora
    var onSubmit: (() -> Void)?

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(focused
                                     ? LuminaGradients.accentColor(accent)
                                     : LuminaColors.textTertiary)

                TextField(prompt, text: $text)
                    .textFieldStyle(.plain)
                    .luminaText(LuminaFont.body())
                    .focused($focused)
                    .submitLabel(.search)
                    .onSubmit { onSubmit?() }
                    .autocorrectionDisabled()

                if !text.isEmpty {
                    Button {
                        withAnimation(Motion.tap) { text = "" }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(LuminaColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .glass(cornerRadius: Radius.pill, accent: accent, depth: .regular, glow: false)
            .overlay {
                if focused {
                    // Accent focus ring.
                    Capsule().strokeBorder(LuminaGradients.linear(accent), lineWidth: 1.5)
                        .opacity(0.8)
                        .transition(.opacity)
                }
            }

            if focused {
                Button("Cancel") {
                    withAnimation(Motion.spring) {
                        text = ""
                        focused = false
                    }
                }
                .font(LuminaFont.subheadline())
                .foregroundStyle(LuminaColors.textSecondary)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(Motion.spring, value: focused)
        .animation(Motion.content, value: text.isEmpty)
    }
}

#Preview("GlassSearchBar") {
    ZStack {
        AuroraBackground().ignoresSafeArea()
        VStack {
            GlassSearchBar(text: .constant(""))
            GlassSearchBar(text: .constant("surface codes"), accent: .sunset)
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
