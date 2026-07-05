import CoreGraphics

/// Spacing + radius scale for consistent rhythm.
enum Space {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

/// Corner radii. Primary glass surfaces live in the 22–28pt band; `sm` is for
/// nested elements (thumbnails, inner fields) so inner < outer always holds.
enum Radius {
    static let sm: CGFloat = 14      // nested: thumbnails, inner fields
    static let md: CGFloat = 22      // compact cards, inputs
    static let lg: CGFloat = 26      // standard cards, sheets
    static let xl: CGFloat = 28      // hero surfaces, alerts
    static let pill: CGFloat = 999
}
