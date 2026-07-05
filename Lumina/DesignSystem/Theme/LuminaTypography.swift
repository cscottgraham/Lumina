import SwiftUI

/// Type scale — SF Pro (system default design) with deliberate weights.
/// The hierarchy leans on weight + size contrast rather than typeface changes:
/// heavy/bold display tiers, semibold UI labels, regular reading text.
/// Monospaced is reserved for keys, tokens, and cost meters.
enum LuminaFont {
    /// Hero numerals / splash moments.
    static func display() -> Font    { .system(size: 40, weight: .heavy) }
    /// Screen titles.
    static func largeTitle() -> Font { .system(size: 34, weight: .bold) }
    static func title() -> Font      { .system(size: 28, weight: .bold) }
    static func title2() -> Font     { .system(size: 21, weight: .semibold) }
    /// Row/button labels.
    static func headline() -> Font   { .system(size: 17, weight: .semibold) }
    /// Reading text.
    static func body() -> Font       { .system(size: 16, weight: .regular) }
    static func callout() -> Font    { .system(size: 15, weight: .regular) }
    /// Secondary labels.
    static func subheadline() -> Font { .system(size: 14, weight: .medium) }
    /// Chips, meters, timestamps.
    static func caption() -> Font    { .system(size: 12, weight: .medium) }
    static func caption2() -> Font   { .system(size: 11, weight: .semibold) }
    /// Keys, tokens, costs.
    static func mono() -> Font       { .system(size: 13, weight: .regular, design: .monospaced) }
}

extension View {
    /// Applies a Lumina text style + color in one modifier.
    func luminaText(_ font: Font, color: Color = LuminaColors.textPrimary) -> some View {
        self.font(font).foregroundStyle(color)
    }

    /// Uppercased micro-label with wide tracking — section headers on glass.
    func luminaOverline(color: Color = LuminaColors.textTertiary) -> some View {
        self.font(.system(size: 11, weight: .semibold))
            .kerning(1.2)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}
