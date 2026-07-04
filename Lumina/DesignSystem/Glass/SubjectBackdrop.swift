import SwiftUI

/// A backdrop that *reflects the subject*: the subject's own most recent
/// imagery (photo/video thumbnail), heavily blurred and dimmed, with the
/// accent aurora layered on top — so the glassmorphism reads the same but the
/// mood shifts per subject. Subjects with no imagery fall back to the pure
/// accent aurora.
///
/// Future: swap `heroImage` for generated/subject-representative artwork; the
/// layering stays identical.
struct SubjectBackdrop: View {
    var subject: Subject?
    var animated: Bool = false

    @Environment(\.mediaStore) private var mediaStore

    var body: some View {
        let accent = subject?.accent ?? .aurora
        ZStack {
            LuminaColors.canvas

            if let hero = heroImage {
                // Fill the screen without affecting layout, then frost it.
                Color.clear
                    .overlay(hero.resizable().scaledToFill())
                    .clipped()
                    .blur(radius: 48)
                    .saturation(1.25)
                    .opacity(0.55)
                // Scrim keeps glass surfaces + text legible over any image.
                LuminaColors.canvas.opacity(0.5)
            }

            AuroraBackground(accent: accent, animated: animated, transparentCanvas: true)
                .opacity(heroImage == nil ? 1.0 : 0.8)
        }
        .ignoresSafeArea()
    }

    /// The most recent photo/video thumbnail in the subject.
    private var heroImage: Image? {
        guard let subject else { return nil }
        for item in subject.sortedItems where item.kind == .photo || item.kind == .video {
            if let attachment = item.primaryAttachment {
                let path = attachment.thumbnailRelativePath ?? attachment.relativePath
                if let img = mediaStore.thumbnailImage(relativePath: path) { return img }
            }
        }
        return nil
    }
}
