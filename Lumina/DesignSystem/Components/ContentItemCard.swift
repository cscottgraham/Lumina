import SwiftUI

/// THE card for a captured item — one component, kind-specific layouts:
///   • photo      → full-bleed image, glass caption strip overlaid at bottom
///   • video      → same + play badge + duration pill
///   • audio      → glass card with a waveform motif, duration, transcript excerpt
///   • note/document → text-first glass card
///   • webSnippet → source row (domain), title, quoted excerpt, screenshot thumb
/// All variants share a footer: provenance line + topic/tag chips + AI sparkle.
struct ContentItemCard: View {
    let item: ContentItem
    var accent: AccentTheme = .aurora

    @Environment(\.mediaStore) private var mediaStore

    var body: some View {
        switch item.kind {
        case .photo, .video: mediaLayout
        case .audio:         audioLayout
        case .webSnippet:    webLayout
        case .note, .document: textLayout
        }
    }

    // MARK: Photo / Video — image-forward

    private var mediaLayout: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let image = loadedImage {
                    Color.clear
                        .overlay(image.resizable().scaledToFill())
                } else {
                    LuminaGradients.linear(accent).opacity(0.25)
                        .overlay(
                            Image(systemName: item.kind.systemImage)
                                .font(.system(size: 40, weight: .light))
                                .foregroundStyle(LuminaColors.textSecondary)
                        )
                }
            }
            .frame(height: 200)
            .clipped()

            // Video affordances
            if item.kind == .video {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(radius: 10)
                    .frame(maxHeight: .infinity, alignment: .center)
                if item.mediaDuration > 0 {
                    durationPill
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(Space.sm)
                }
            }

            // Bottom caption strip — glass-on-image.
            VStack(alignment: .leading, spacing: Space.xxs) {
                titleRow
                footer
            }
            .padding(Space.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .overlay(Rectangle().fill(LuminaColors.canvas.opacity(0.25)))
            .overlay(alignment: .top) {
                Rectangle().fill(LuminaColors.glassStrokeSoft).frame(height: 0.5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
            .strokeBorder(LuminaGradients.specularStroke, lineWidth: 1).opacity(0.5))
        .shadow(color: .black.opacity(0.35), radius: 18, y: 12)
    }

    // MARK: Audio — waveform motif

    private var audioLayout: some View {
        GlassCard(accent: accent, padding: Space.md) {
            VStack(alignment: .leading, spacing: Space.sm) {
                titleRow
                HStack(spacing: Space.sm) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(LuminaGradients.linear(accent))
                    WaveformMotif(seed: item.id, accent: accent)
                        .frame(height: 30)
                    if item.mediaDuration > 0 { durationPill }
                }
                if item.hasTranscript {
                    Text(item.text)
                        .luminaText(LuminaFont.caption(), color: LuminaColors.textSecondary)
                        .lineLimit(2)
                }
                footer
            }
        }
    }

    // MARK: Web snippet — source + quote + screenshot

    private var webLayout: some View {
        GlassCard(accent: accent, padding: Space.md) {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(spacing: Space.xxs) {
                    Image(systemName: "globe").font(.system(size: 11, weight: .semibold))
                    Text(item.sourceURL?.host() ?? "web")
                        .lineLimit(1)
                }
                .luminaOverline(color: LuminaGradients.accentColor(accent))

                HStack(alignment: .top, spacing: Space.sm) {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        titleRow
                        if !item.text.isEmpty {
                            // Quoted selected text.
                            HStack(alignment: .top, spacing: Space.xs) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(LuminaGradients.linear(accent))
                                    .frame(width: 3)
                                Text(item.text)
                                    .luminaText(LuminaFont.callout(), color: LuminaColors.textSecondary)
                                    .lineLimit(4)
                            }
                        }
                    }
                    if let shot = item.snippetScreenshot,
                       let img = mediaStore.thumbnailImage(relativePath: shot.thumbnailRelativePath ?? shot.relativePath) {
                        img.resizable().scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .strokeBorder(LuminaColors.glassStrokeSoft, lineWidth: 1))
                    }
                }
                footer
            }
        }
    }

    // MARK: Note / Document — text-first

    private var textLayout: some View {
        GlassCard(accent: accent, padding: Space.md) {
            VStack(alignment: .leading, spacing: Space.xs) {
                titleRow
                if !item.text.isEmpty {
                    Text(item.text)
                        .luminaText(LuminaFont.callout(), color: LuminaColors.textSecondary)
                        .lineLimit(4)
                }
                if item.kind == .document, let info = item.primaryAttachment?.infoLine, !info.isEmpty {
                    Text(info).luminaText(LuminaFont.caption(), color: LuminaColors.textTertiary)
                }
                footer
            }
        }
    }

    // MARK: Shared pieces

    private var titleRow: some View {
        HStack(spacing: Space.xxs) {
            Text(item.resolvedTitle)
                .luminaText(LuminaFont.headline())
                .lineLimit(1)
            if !item.aiSummary.isEmpty {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(LuminaGradients.accentColor(accent))
            }
            Spacer(minLength: 0)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            if let provenance = item.provenanceLine {
                Text(provenance)
                    .luminaText(LuminaFont.caption(), color: LuminaColors.textTertiary)
                    .lineLimit(1)
            }
            WrappingHStack(spacing: Space.xxs) {
                TagChip(text: item.kind.title, systemImage: item.kind.systemImage, accent: accent)
                if let topic = item.topic {
                    TagChip(text: topic.displayTitle, systemImage: "folder", accent: accent)
                }
                ForEach(item.sortedTags.prefix(3)) { tag in
                    TagChip(text: tag.name, accent: accent)
                }
            }
        }
    }

    private var durationPill: some View {
        let d = Int(item.mediaDuration)
        return Text(String(format: "%d:%02d", d / 60, d % 60))
            .luminaText(LuminaFont.caption2())
            .padding(.horizontal, Space.xs)
            .padding(.vertical, 4)
            .background(Capsule().fill(.regularMaterial))
    }

    private var loadedImage: Image? {
        guard let attachment = item.primaryAttachment else { return nil }
        let path = attachment.thumbnailRelativePath ?? attachment.relativePath
        return mediaStore.thumbnailImage(relativePath: path)
    }
}

/// A deterministic decorative waveform (seeded by the item id) — reads as
/// audio without decoding the file. Replace with real amplitude data later.
struct WaveformMotif: View {
    let seed: UUID
    var accent: AccentTheme = .aurora
    var barCount: Int = 28

    var body: some View {
        let values = Self.bars(seed: seed, count: barCount)
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(values.indices, id: \.self) { i in
                Capsule()
                    .fill(LuminaGradients.linear(accent))
                    .frame(width: 2.5, height: 6 + values[i] * 22)
                    .opacity(0.55 + values[i] * 0.45)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func bars(seed: UUID, count: Int) -> [CGFloat] {
        var state = UInt64(abs(seed.hashValue == Int.min ? 1 : seed.hashValue))
        return (0..<count).map { _ in
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((state >> 33) % 1000) / 1000
        }
    }
}
