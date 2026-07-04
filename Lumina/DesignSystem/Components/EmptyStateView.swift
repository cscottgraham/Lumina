import SwiftUI

/// A friendly empty state used across screens.
struct EmptyStateView: View {
    var systemImage: String
    var title: String
    var message: String
    var accent: AccentTheme = .aurora
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Space.md) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(LuminaGradients.linear(accent))
            Text(title).luminaText(LuminaFont.title2())
            Text(message)
                .luminaText(LuminaFont.callout(), color: LuminaColors.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                GlassButton(actionTitle, systemImage: "plus", accent: accent, weight: .primary, action: action)
                    .fixedSize()
                    .padding(.top, Space.xs)
            }
        }
        .padding(Space.xl)
        .frame(maxWidth: 360)
    }
}
