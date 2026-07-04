import SwiftUI

/// A square thumbnail for a content item. Shows the cached image for photo/video
/// attachments, or a glassy kind-icon tile for notes/audio/web.
struct MediaThumbnail: View {
    var item: ContentItem
    var accent: AccentTheme = .aurora
    var side: CGFloat = 84

    @Environment(\.mediaStore) private var mediaStore

    var body: some View {
        ZStack {
            if let path = item.primaryAttachment?.thumbnailRelativePath ?? item.primaryAttachment?.relativePath,
               item.kind == .photo || item.kind == .video,
               let image = mediaStore.thumbnailImage(relativePath: path) {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(colors: [LuminaGradients.accentColor(accent).opacity(0.35), .clear],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: item.kind.systemImage)
                    .font(.system(size: side * 0.32, weight: .semibold))
                    .foregroundStyle(LuminaColors.textPrimary.opacity(0.9))
            }

            // Video play glyph overlay.
            if item.kind == .video {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: side * 0.30))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(radius: 6)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            .strokeBorder(LuminaColors.glassStrokeSoft, lineWidth: 1))
    }
}
