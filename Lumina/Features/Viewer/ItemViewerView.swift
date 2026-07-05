import SwiftUI
import SwiftData
import AVKit
import UIKit

/// Full-screen immersive viewer, per kind, with glass chrome:
///   photo  → pinch-zoom / pan / double-tap, memory-safe downsampled load
///   video  → AVKit player, autoplay, glass top bar
///   audio  → scrubber + waveform + transcript
///   note / webSnippet / document → glass reader (+ open-link for snippets)
@MainActor
struct ItemViewerView: View {
    let item: ContentItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.mediaStore) private var mediaStore

    private var accent: AccentTheme { item.primarySubject?.accent ?? .aurora }

    var body: some View {
        ZStack(alignment: .top) {
            LuminaColors.canvas.ignoresSafeArea()

            Group {
                switch item.kind {
                case .photo:      PhotoZoomViewer(item: item)
                case .video:      VideoViewer(item: item)
                case .audio:      AudioViewer(item: item, accent: accent)
                case .note, .webSnippet, .document: ReaderViewer(item: item, accent: accent)
                }
            }
            .ignoresSafeArea(edges: .bottom)

            chrome
        }
        .preferredColorScheme(.dark)
    }

    // Glass top bar: close + title + provenance.
    private var chrome: some View {
        HStack(spacing: Space.sm) {
            GlassIconButton(systemImage: "xmark", accent: accent) { dismiss() }
            VStack(alignment: .leading, spacing: 1) {
                Text(item.resolvedTitle).luminaText(LuminaFont.headline()).lineLimit(1)
                if let prov = item.provenanceLine {
                    Text(prov).luminaText(LuminaFont.caption(), color: LuminaColors.textSecondary).lineLimit(1)
                }
            }
            Spacer()
            if !item.aiSummary.isEmpty {
                Image(systemName: "sparkles")
                    .foregroundStyle(LuminaGradients.accentColor(accent))
            }
        }
        .padding(.horizontal, Space.sm)
        .padding(.vertical, Space.xs)
        .glass(cornerRadius: Radius.xl, accent: accent, depth: .regular, strong: true)
        .padding(.horizontal, Space.md)
    }
}

// MARK: - Photo (zoom + pan, downsampled load)

@MainActor
private struct PhotoZoomViewer: View {
    let item: ContentItem
    @Environment(\.mediaStore) private var mediaStore

    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(zoomAndPan)
                        .onTapGesture(count: 2) {
                            withAnimation(Motion.spring) {
                                scale = scale > 1.05 ? 1 : 2.4
                                offset = .zero; lastOffset = .zero; lastScale = scale
                            }
                        }
                } else {
                    ProgressView().tint(.white)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .task { await load(fit: geo.size) }
        }
    }

    private var zoomAndPan: some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in scale = max(1, min(6, lastScale * value)) }
                .onEnded { _ in lastScale = scale },
            DragGesture()
                .onChanged { value in
                    guard scale > 1.02 else { return }
                    offset = CGSize(width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height)
                }
                .onEnded { _ in lastOffset = offset }
        )
    }

    /// Load the ORIGINAL downsampled to ~3× screen — full quality for zooming
    /// without holding a 48-megapixel bitmap ("handle large files gracefully").
    private func load(fit size: CGSize) async {
        guard image == nil, let attachment = item.primaryAttachment else { return }
        let url = mediaStore.absoluteURL(for: attachment.relativePath)
        let maxPixel = max(size.width, size.height) * 3

        let loaded: UIImage? = await Task.detached(priority: .userInitiated) {
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                kCGImageSourceCreateThumbnailWithTransform: true,
            ]
            guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
            return UIImage(cgImage: cg)
        }.value
        image = loaded
    }
}

// MARK: - Video

@MainActor
private struct VideoViewer: View {
    let item: ContentItem
    @Environment(\.mediaStore) private var mediaStore
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
            } else {
                ProgressView().tint(.white)
            }
        }
        .onAppear {
            guard player == nil, let attachment = item.primaryAttachment else { return }
            let p = AVPlayer(url: mediaStore.absoluteURL(for: attachment.relativePath))
            player = p
            p.play()
        }
        .onDisappear { player?.pause() }
    }
}

// MARK: - Audio

@MainActor
private struct AudioViewer: View {
    let item: ContentItem
    let accent: AccentTheme
    @Environment(\.mediaStore) private var mediaStore
    @State private var audio = AudioPlayerService()

    var body: some View {
        VStack(spacing: Space.lg) {
            Spacer().frame(height: 90) // clear the chrome

            GlassCard(accent: accent, vibrant: true) {
                VStack(spacing: Space.md) {
                    WaveformMotif(seed: item.id, accent: accent, barCount: 40)
                        .frame(height: 44)

                    // Scrubber
                    Slider(value: Binding(
                        get: { audio.currentTime },
                        set: { audio.seek(to: $0) }
                    ), in: 0...max(audio.duration, 0.01))
                    .tint(LuminaGradients.accentColor(accent))

                    HStack {
                        Text(format(audio.currentTime))
                        Spacer()
                        Text(format(audio.duration))
                    }
                    .luminaText(LuminaFont.caption(), color: LuminaColors.textSecondary)
                    .monospacedDigit()

                    GlassIconButton(systemImage: audio.isPlaying ? "pause.fill" : "play.fill",
                                    accent: accent, filled: true) {
                        audio.togglePlay()
                    }
                    .scaleEffect(1.2)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Space.md)

            if item.hasTranscript {
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("Transcript").luminaOverline()
                        Text(item.text)
                            .luminaText(LuminaFont.body(), color: LuminaColors.textSecondary)
                            .textSelection(.enabled)
                    }
                    .padding(Space.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glass(cornerRadius: Radius.lg, accent: accent)
                    .padding(.horizontal, Space.md)
                    .padding(.bottom, Space.xl)
                }
            } else {
                Spacer()
            }
        }
        .onAppear {
            guard let attachment = item.primaryAttachment else { return }
            audio.load(url: mediaStore.absoluteURL(for: attachment.relativePath))
        }
        .onDisappear { audio.stop() }
    }

    private func format(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Reader (note / web snippet / document)

@MainActor
private struct ReaderViewer: View {
    let item: ContentItem
    let accent: AccentTheme
    @Environment(\.mediaStore) private var mediaStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Spacer().frame(height: 76) // clear the chrome

                if item.kind == .webSnippet, let url = item.sourceURL {
                    GlassCard(accent: accent, padding: Space.sm) {
                        Link(destination: url) {
                            Label(url.host() ?? url.absoluteString, systemImage: "safari")
                                .luminaText(LuminaFont.subheadline(), color: LuminaGradients.accentColor(accent))
                                .lineLimit(1)
                        }
                    }
                }

                if let shot = item.snippetScreenshot,
                   let image = mediaStore.thumbnailImage(relativePath: shot.thumbnailRelativePath ?? shot.relativePath) {
                    image.resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                }

                if !item.text.isEmpty {
                    GlassCard(accent: accent) {
                        Text(item.text)
                            .luminaText(LuminaFont.body())
                            .textSelection(.enabled)
                    }
                }

                if !item.aiSummary.isEmpty {
                    GlassCard(accent: accent, vibrant: true) {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Label("Claude's note", systemImage: "sparkles")
                                .luminaText(LuminaFont.subheadline(), color: LuminaGradients.accentColor(accent))
                            Text(item.aiSummary)
                                .luminaText(LuminaFont.callout(), color: LuminaColors.textSecondary)
                        }
                    }
                }

                if !(item.tags ?? []).isEmpty || item.topic != nil {
                    WrappingHStack(spacing: Space.xxs) {
                        if let topic = item.topic {
                            TagChip(text: topic.displayTitle, systemImage: "folder", accent: accent)
                        }
                        ForEach(item.sortedTags) { tag in
                            TagChip(text: tag.name, accent: accent)
                        }
                    }
                }
            }
            .padding(Space.md)
            .padding(.bottom, Space.xxl)
        }
        .background(SubjectBackdrop(subject: item.primarySubject))
    }
}
