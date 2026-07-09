import SwiftUI

/// A backdrop that *reflects the subject*: the subject's pinned image (or, if
/// none is pinned, its most recent photo/video thumbnail), heavily blurred and
/// dimmed, with the accent aurora layered on top — so the glassmorphism reads
/// the same but the mood shifts per subject. Subjects with no imagery fall back
/// to the pure accent aurora. The chosen item is resolved by
/// `Subject.backdropMediaItem`.
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

    /// The subject's backdrop image: the pinned photo/video if the user chose
    /// one, otherwise the most recent photo/video (see `backdropMediaItem`).
    private var heroImage: Image? {
        guard let item = subject?.backdropMediaItem,
              let attachment = item.primaryAttachment else { return nil }
        let path = attachment.thumbnailRelativePath ?? attachment.relativePath
        return mediaStore.thumbnailImage(relativePath: path)
    }
}
