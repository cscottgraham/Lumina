import SwiftUI

/// Type scale. Rounded-design system font gives Lumina a soft, premium feel
/// without shipping a custom font. Swap `.rounded` for a bundled font later.
enum LuminaFont {
    static func largeTitle() -> Font { .system(size: 34, weight: .bold, design: .rounded) }
    static func title() -> Font      { .system(size: 26, weight: .bold, design: .rounded) }
    static func title2() -> Font     { .system(size: 21, weight: .semibold, design: .rounded) }
    static func headline() -> Font   { .system(size: 17, weight: .semibold, design: .rounded) }
    static func body() -> Font       { .system(size: 16, weight: .regular, design: .rounded) }
    static func callout() -> Font    { .system(size: 15, weight: .regular, design: .rounded) }
    static func subheadline() -> Font { .system(size: 14, weight: .medium, design: .rounded) }
    static func caption() -> Font    { .system(size: 12, weight: .medium, design: .rounded) }
    static func mono() -> Font       { .system(size: 13, weight: .regular, design: .monospaced) }
}

extension View {
    /// Applies a Lumina text style + primary color in one modifier.
    func luminaText(_ font: Font, color: Color = LuminaColors.textPrimary) -> some View {
        self.font(font).foregroundStyle(color)
    }
}
