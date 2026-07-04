import SwiftUI

/// The animated "aurora" backdrop: several large, blurred, accent-tinted blobs
/// drifting over the near-black canvas. Built with layered radial gradients +
/// `.blur()` so it runs on **iOS 17** (no `MeshGradient`, which is iOS 18).
///
/// It's cheap: a handful of shapes, animated with a single repeating phase.
struct AuroraBackground: View {
    var accent: AccentTheme = .aurora
    /// Set false inside scrolling lists if you want a static backdrop for perf.
    var animated: Bool = true
    /// When true, skips the opaque canvas base so the aurora can layer over
    /// other imagery (see `SubjectBackdrop`).
    var transparentCanvas: Bool = false

    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let colors = LuminaGradients.stops(for: accent)
            ZStack {
                if !transparentCanvas { LuminaColors.canvas }

                blob(colors[safe: 0] ?? .teal, at: CGPoint(x: 0.18, y: 0.16), size: 0.95, geo: geo, drift: 0)
                blob(colors[safe: 1] ?? .indigo, at: CGPoint(x: 0.86, y: 0.30), size: 1.05, geo: geo, drift: 0.5)
                blob(colors[safe: 2] ?? .purple, at: CGPoint(x: 0.32, y: 0.86), size: 0.9, geo: geo, drift: 1.0)
                blob(colors[safe: 0] ?? .teal, at: CGPoint(x: 0.78, y: 0.82), size: 0.7, geo: geo, drift: 1.5)
            }
            .compositingGroup()
            .blur(radius: 60)
            .overlay(
                // A faint dark vignette to keep foreground glass legible.
                RadialGradient(colors: [.clear, LuminaColors.canvas.opacity(0.55)],
                               center: .center, startRadius: geo.size.height * 0.25,
                               endRadius: geo.size.height * 0.9)
            )
        }
        .ignoresSafeArea()
        .onAppear {
            guard animated else { return }
            withAnimation(Motion.drift) { phase = 1 }
        }
    }

    private func blob(_ color: Color, at unit: CGPoint, size: CGFloat, geo: GeometryProxy, drift: CGFloat) -> some View {
        let dim = min(geo.size.width, geo.size.height) * size
        let wobbleX = sin((phase + drift) * .pi * 2) * 26
        let wobbleY = cos((phase + drift) * .pi * 2) * 22
        return Circle()
            .fill(RadialGradient(colors: [color.opacity(0.9), color.opacity(0.0)],
                                 center: .center, startRadius: 0, endRadius: dim / 2))
            .frame(width: dim, height: dim)
            .position(x: geo.size.width * unit.x + wobbleX,
                      y: geo.size.height * unit.y + wobbleY)
            .blendMode(.plusLighter)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

#Preview {
    AuroraBackground(accent: .sunset).preferredColorScheme(.dark)
}
