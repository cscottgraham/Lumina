import Foundation
import SwiftData
import ImageIO
import AVFoundation
import UniformTypeIdentifiers

/// THE way media enters the vault. Centralizes what was previously scattered:
/// copy into MediaStore (file-based — large files never pass through memory as
/// a whole except still images), probe metadata (dimensions/duration), create
/// the ContentItem + Attachment pair, generate the thumbnail immediately (so
/// list cards never do expensive work), and kick best-effort enrichment.
@MainActor
struct MediaImportService {
    let context: ModelContext
    var store: MediaStore = .shared
    var thumbnails: ThumbnailService = ThumbnailService()

    // MARK: Photos

    /// Import a still image (picker/camera hand us Data; images are the one
    /// media type small enough for that).
    @discardableResult
    func importImage(data: Data, ext: String = "jpg",
                     into subject: Subject,
                     title: String = "",
                     method: CaptureMethod) async -> ContentItem? {
        guard let relPath = try? store.importData(data, ext: ext) else { return nil }

        var width = 0, height = 0
        if let src = CGImageSourceCreateWithData(data as CFData, nil),
           let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] {
            width = props[kCGImagePropertyPixelWidth] as? Int ?? 0
            height = props[kCGImagePropertyPixelHeight] as? Int ?? 0
        }

        let attachment = Attachment(relativePath: relPath,
                                    uti: UTType.jpeg.identifier,
                                    originalFilename: "photo.\(ext)",
                                    byteCount: data.count,
                                    pixelWidth: width, pixelHeight: height)
        let item = ContentItem(kind: .photo, title: title, subject: subject, captureMethod: method)
        return await finalize(item: item, attachment: attachment, subject: subject)
    }

    // MARK: Video

    /// Import a video by FILE URL (never as Data — videos can be gigabytes;
    /// PhotosPicker/camera give us temp-file URLs we copy straight to disk).
    @discardableResult
    func importVideo(from url: URL,
                     into subject: Subject,
                     title: String = "",
                     method: CaptureMethod) async -> ContentItem? {
        guard let relPath = try? store.importFile(at: url) else { return nil }
        let dest = store.absoluteURL(for: relPath)

        var duration: Double = 0
        var width = 0, height = 0
        let asset = AVURLAsset(url: dest)
        if let d = try? await asset.load(.duration) { duration = d.seconds }
        if let track = try? await asset.loadTracks(withMediaType: .video).first,
           let size = try? await track.load(.naturalSize) {
            width = Int(abs(size.width)); height = Int(abs(size.height))
        }
        let bytes = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? Int) ?? 0

        let attachment = Attachment(relativePath: relPath,
                                    uti: UTType.movie.identifier,
                                    originalFilename: url.lastPathComponent,
                                    byteCount: bytes,
                                    duration: duration,
                                    pixelWidth: width, pixelHeight: height)
        let item = ContentItem(kind: .video, title: title, subject: subject, captureMethod: method)
        return await finalize(item: item, attachment: attachment, subject: subject)
    }

    // MARK: Audio

    /// Import a recorded audio file; `transcript` (from live dictation or
    /// post-recording speech recognition) becomes the item's LLM-facing text.
    @discardableResult
    func importAudio(from url: URL,
                     into subject: Subject,
                     title: String = "",
                     transcript: String = "",
                     method: CaptureMethod) async -> ContentItem? {
        guard let relPath = try? store.importFile(at: url) else { return nil }
        let dest = store.absoluteURL(for: relPath)

        var duration: Double = 0
        if let d = try? await AVURLAsset(url: dest).load(.duration) { duration = d.seconds }
        let bytes = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? Int) ?? 0

        let attachment = Attachment(relativePath: relPath,
                                    uti: UTType.mpeg4Audio.identifier,
                                    originalFilename: url.lastPathComponent,
                                    byteCount: bytes,
                                    duration: duration)
        let item = ContentItem(kind: .audio, title: title, text: transcript,
                               subject: subject, captureMethod: method)
        return await finalize(item: item, attachment: attachment, subject: subject)
    }

    // MARK: Web snippet screenshot (og:image)

    /// Attach a fetched page image to a web snippet as its screenshot.
    func attachScreenshot(data: Data, to item: ContentItem) async {
        guard let relPath = try? store.importData(data, ext: "jpg") else { return }
        let attachment = Attachment(relativePath: relPath,
                                    uti: UTType.jpeg.identifier,
                                    originalFilename: "page.jpg",
                                    role: .screenshot,
                                    byteCount: data.count)
        attachment.item = item
        context.insert(attachment)
        if let thumb = await thumbnails.thumbnail(for: attachment) {
            attachment.thumbnailRelativePath = thumb
        }
        try? context.save()
    }

    // MARK: Shared tail

    private func finalize(item: ContentItem, attachment: Attachment, subject: Subject) async -> ContentItem {
        item.capturedAt = Date()
        context.insert(item)
        attachment.item = item
        context.insert(attachment)

        // Thumbnail NOW, not lazily — cards must never pay this cost.
        if let thumb = await thumbnails.thumbnail(for: attachment) {
            attachment.thumbnailRelativePath = thumb
        }
        subject.touch()
        try? context.save()

        // Best-effort AI evaluation (only fires when there's text, e.g. transcripts).
        let ctx = context
        Task { @MainActor in
            await ItemEnrichmentService().enrich(item, in: ctx)
        }
        return item
    }
}
