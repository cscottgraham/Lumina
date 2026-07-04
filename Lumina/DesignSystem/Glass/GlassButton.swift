import SwiftUI

/// A tappable glass button with three visual weights. Uses a ButtonStyle so it
/// gets a satisfying spring press animation for free.
struct GlassButton: View {
    enum Weight { case primary, secondary, ghost }

    var title: String
    var systemImage: String?
    var accent: AccentTheme = .aurora
    var weight: Weight = .secondary
    var action: () -> Void

    init(_ title: String, systemImage: String? = nil, accent: AccentTheme = .aurora,
         weight: Weight = .secondary, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.accent = accent
        self.weight = weight
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.xs) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(LuminaFont.headline())
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .frame(maxWidth: weight == .primary ? .infinity : nil)
        }
        .buttonStyle(GlassButtonStyle(accent: accent, weight: weight))
    }
}

private struct GlassButtonStyle: ButtonStyle {
    var accent: AccentTheme
    var weight: GlassButton.Weight

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .background {
                switch weight {
                case .primary:
                    RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                        .fill(LuminaGradients.linear(accent))
                        .shadow(color: LuminaGradients.accentColor(accent).opacity(0.5), radius: 14, y: 6)
                case .secondary:
                    RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                            .strokeBorder(LuminaColors.glassStroke, lineWidth: 1))
                case .ghost:
                    Color.clear
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.pill, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(Motion.tap, value: configuration.isPressed)
    }

    private var foreground: Color {
        switch weight {
        case .primary: return .black.opacity(0.9)
        case .secondary: return LuminaColors.textPrimary
        case .ghost: return LuminaGradients.accentColor(accent)
        }
    }
}

/// A circular icon-only glass button (e.g. floating capture, close).
struct GlassIconButton: View {
    var systemImage: String
    var accent: AccentTheme = .aurora
    var filled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(filled ? Color.black.opacity(0.9) : LuminaColors.textPrimary)
                .frame(width: 46, height: 46)
                .background {
                    if filled {
                        Circle().fill(LuminaGradients.linear(accent))
                            .shadow(color: LuminaGradients.accentColor(accent).opacity(0.5), radius: 12, y: 5)
                    } else {
                        Circle().fill(.ultraThinMaterial)
                            .overlay(Circle().strokeBorder(LuminaColors.glassStroke, lineWidth: 1))
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
