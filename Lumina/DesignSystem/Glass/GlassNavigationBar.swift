import SwiftUI

/// A custom glass navigation header for hero screens that hide the system bar
/// (`.toolbar(.hidden, for: .navigationBar)`): a regular-material strip with a
/// back/leading button, a two-line title block, and trailing actions.
///
/// Usage:
/// ```swift
/// VStack(spacing: 0) {
///     GlassNavigationBar(title: subject.title, subtitle: "12 items",
///                        accent: subject.accent,
///                        onBack: { dismiss() }) {
///         GlassIconButton(systemImage: "ellipsis", accent: subject.accent) { … }
///     }
///     ScrollView { … }
/// }
/// ```
struct GlassNavigationBar<Trailing: View>: View {
    var title: String
    var subtitle: String?
    var accent: AccentTheme = .aurora
    var onBack: (() -> Void)?
    @ViewBuilder var trailing: () -> Trailing

    init(title: String,
         subtitle: String? = nil,
         accent: AccentTheme = .aurora,
         onBack: (() -> Void)? = nil,
         @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.onBack = onBack
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: Space.sm) {
            if let onBack {
                GlassIconButton(systemImage: "chevron.left", accent: accent, action: onBack)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .luminaText(LuminaFont.headline())
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .luminaText(LuminaFont.caption(), color: LuminaColors.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing()
        }
        .padding(.horizontal, Space.sm)
        .padding(.vertical, Space.xs)
        // Chrome weight: regular material so scrolling content dims beneath it.
        .glass(cornerRadius: Radius.xl, accent: accent, depth: .regular, strong: true)
        .padding(.horizontal, Space.md)
    }
}
