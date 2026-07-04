import SwiftUI

/// A small pill for a tag or a content-kind label.
struct TagChip: View {
    var text: String
    var systemImage: String?
    var accent: AccentTheme = .aurora
    var filled: Bool = false

    var body: some View {
        HStack(spacing: Space.xxs) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 11, weight: .semibold)) }
            Text(text).font(LuminaFont.caption())
        }
        .padding(.horizontal, Space.sm)
        .padding(.vertical, 6)
        .foregroundStyle(filled ? Color.black.opacity(0.85) : LuminaColors.textSecondary)
        .background {
            if filled {
                Capsule().fill(LuminaGradients.linear(accent))
            } else {
                Capsule().fill(.ultraThinMaterial)
                    .overlay(Capsule().strokeBorder(LuminaColors.glassStrokeSoft, lineWidth: 1))
            }
        }
    }
}
