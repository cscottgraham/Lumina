import SwiftUI

/// Shared animation curves so motion feels like one system.
enum Motion {
    /// Springy, for interactive elements (buttons, cards appearing).
    static var spring: Animation { .spring(response: 0.42, dampingFraction: 0.82) }
    /// Snappier spring for taps.
    static var tap: Animation { .spring(response: 0.28, dampingFraction: 0.7) }
    /// Smooth ease for background/aurora drift.
    static var drift: Animation { .easeInOut(duration: 14).repeatForever(autoreverses: true) }
    /// Gentle content transitions.
    static var content: Animation { .easeInOut(duration: 0.28) }
}
