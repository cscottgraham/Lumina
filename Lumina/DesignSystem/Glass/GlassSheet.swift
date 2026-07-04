import SwiftUI

/// A reusable bottom-sheet chrome with a grabber, title, and a glass panel over
/// the aurora. Use it to present editors (new note, subject editor, settings).
struct GlassSheet<Content: View>: View {
    var title: String
    var accent: AccentTheme = .aurora
    var onClose: (() -> Void)?
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            AuroraBackground(accent: accent).ignoresSafeArea()

            VStack(spacing: Space.md) {
                // Grabber
                Capsule()
                    .fill(LuminaColors.glassStroke)
                    .frame(width: 40, height: 5)
                    .padding(.top, Space.sm)

                HStack {
                    Text(title).luminaText(LuminaFont.title2())
                    Spacer()
                    if let onClose {
                        GlassIconButton(systemImage: "xmark", accent: accent, action: onClose)
                    }
                }
                .padding(.horizontal, Space.lg)

                ScrollView {
                    content()
                        .padding(.horizontal, Space.lg)
                        .padding(.bottom, Space.xxl)
                }
            }
        }
        .presentationDragIndicator(.hidden)
        .presentationBackground(.clear)
    }
}
