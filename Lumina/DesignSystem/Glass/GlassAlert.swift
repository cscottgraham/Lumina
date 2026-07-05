import SwiftUI

/// A glass alert presented over a dimmed, blurred scrim — replaces the system
/// alert for in-brand confirmations. Spring-pops in; the destructive action
/// picks up the danger tint.
///
/// Usage:
/// ```swift
/// .glassAlert(isPresented: $confirmDelete,
///             title: "Delete subject?",
///             message: "Items shared with other subjects are kept.",
///             accent: subject.accent,
///             primary: .init(title: "Delete", role: .destructive) { delete() },
///             secondary: .init(title: "Cancel"))
/// ```
struct GlassAlertAction {
    enum Role { case normal, destructive, cancel }
    var title: String
    var role: Role = .normal
    var handler: () -> Void = {}

    init(title: String, role: Role = .normal, handler: @escaping () -> Void = {}) {
        self.title = title
        self.role = role
        self.handler = handler
    }
}

private struct GlassAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    var title: String
    var message: String
    var accent: AccentTheme
    var primary: GlassAlertAction
    var secondary: GlassAlertAction?

    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                ZStack {
                    // Scrim: dim + slight blur so the alert owns the screen.
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture { dismiss(then: secondary) }

                    VStack(spacing: Space.md) {
                        Text(title)
                            .luminaText(LuminaFont.title2())
                            .multilineTextAlignment(.center)
                        Text(message)
                            .luminaText(LuminaFont.callout(), color: LuminaColors.textSecondary)
                            .multilineTextAlignment(.center)

                        VStack(spacing: Space.xs) {
                            actionButton(primary)
                            if let secondary { actionButton(secondary) }
                        }
                        .padding(.top, Space.xs)
                    }
                    .padding(Space.lg)
                    .frame(maxWidth: 320)
                    .glass(cornerRadius: Radius.xl, accent: accent, depth: .regular, strong: true)
                    .transition(.scale(scale: 0.86).combined(with: .opacity))
                }
                .zIndex(10)
            }
        }
        .animation(Motion.spring, value: isPresented)
    }

    @ViewBuilder
    private func actionButton(_ action: GlassAlertAction) -> some View {
        Button { dismiss(then: action) } label: {
            Text(action.title)
                .font(LuminaFont.headline())
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.sm)
                .background {
                    switch action.role {
                    case .normal:
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(LuminaGradients.linear(accent))
                    case .destructive:
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(LuminaColors.danger.opacity(0.85))
                    case .cancel:
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(.regularMaterial)
                            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .strokeBorder(LuminaColors.glassStroke, lineWidth: 1))
                    }
                }
                .foregroundStyle(action.role == .cancel ? LuminaColors.textPrimary : .black.opacity(0.9))
        }
        .buttonStyle(.plain)
    }

    private func dismiss(then action: GlassAlertAction?) {
        withAnimation(Motion.spring) { isPresented = false }
        action?.handler()
    }
}

extension View {
    /// Presents a glass alert over this view.
    func glassAlert(isPresented: Binding<Bool>,
                    title: String,
                    message: String,
                    accent: AccentTheme = .aurora,
                    primary: GlassAlertAction,
                    secondary: GlassAlertAction? = GlassAlertAction(title: "Cancel", role: .cancel)) -> some View {
        modifier(GlassAlertModifier(isPresented: isPresented, title: title, message: message,
                                    accent: accent, primary: primary, secondary: secondary))
    }
}
