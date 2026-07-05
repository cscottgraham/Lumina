import SwiftUI

/// Live waveform for recording/dictation: accent-gradient capsules driven by a
/// rolling levels array (newest last), spring-animated so the bars breathe.
struct LiveWaveformView: View {
    var levels: [CGFloat]           // normalized 0…1
    var accent: AccentTheme = .aurora
    var maxBarHeight: CGFloat = 44

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(levels.indices, id: \.self) { i in
                Capsule()
                    .fill(LuminaGradients.linear(accent))
                    .frame(width: 3, height: max(4, levels[i] * maxBarHeight))
                    .opacity(0.5 + levels[i] * 0.5)
            }
        }
        .frame(height: maxBarHeight)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.18, dampingFraction: 0.7), value: levels)
    }
}
