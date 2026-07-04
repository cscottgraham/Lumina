import Foundation
import SwiftData

extension LuminaSchemaV1 {
    /// Metadata for one on-disk media file belonging to a `ContentItem`.
    ///
    /// The binary lives in the app's media container; we persist only the
    /// **relative path** (resolved via `MediaStore`) plus a cached thumbnail
    /// path and lightweight metadata. This keeps the SwiftData store small and
    /// CloudKit sync fast — never store media blobs in the database.
    ///
    /// The original/thumbnail pairing the schema promises for photos & videos:
    ///   • `relativePath`          → the ORIGINAL file (full quality)
    ///   • `thumbnailRelativePath` → the cached thumbnail JPEG (generated
    ///     lazily by `ThumbnailService`; regenerable, safe to purge)
    /// `role` distinguishes the primary media from e.g. a web snippet's page
    /// screenshot or supplementary files.
    @Model
    final class Attachment {
        var id: UUID = UUID()

        /// What this file is, relative to its item (original/screenshot/supplement).
        var roleRaw: String = AttachmentRole.original.rawValue

        /// Path of the ORIGINAL file relative to the media container root,
        /// e.g. "media/8F3A….mov".
        var relativePath: String = ""
        /// Cached thumbnail path (relative), nil until generated.
        var thumbnailRelativePath: String?

        var uti: String = ""            // e.g. "public.jpeg", "public.mpeg-4"
        var originalFilename: String = ""
        var byteCount: Int = 0

        /// For audio/video: duration in seconds. For images: 0.
        var duration: Double = 0
        /// Natural pixel size for images/video (0 when N/A).
        var pixelWidth: Int = 0
        var pixelHeight: Int = 0

        /// Ordering within an item that has multiple attachments.
        var order: Int = 0
        var createdAt: Date = Date()

        var item: ContentItem?

        init(
            relativePath: String,
            uti: String,
            originalFilename: String,
            role: AttachmentRole = .original,
            byteCount: Int = 0,
            duration: Double = 0,
            pixelWidth: Int = 0,
            pixelHeight: Int = 0,
            order: Int = 0
        ) {
            self.id = UUID()
            self.relativePath = relativePath
            self.roleRaw = role.rawValue
            self.uti = uti
            self.originalFilename = originalFilename
            self.byteCount = byteCount
            self.duration = duration
            self.pixelWidth = pixelWidth
            self.pixelHeight = pixelHeight
            self.order = order
            self.createdAt = Date()
        }
    }
}

extension Attachment {
    var role: AttachmentRole {
        get { AttachmentRole(rawValue: roleRaw) ?? .original }
        set { roleRaw = newValue.rawValue }
    }

    /// Absolute URL of the original file.
    var fileURL: URL { MediaStore.shared.absoluteURL(for: relativePath) }

    /// Absolute URL of the thumbnail, when generated.
    var thumbnailURL: URL? {
        thumbnailRelativePath.map { MediaStore.shared.absoluteURL(for: $0) }
    }

    /// "12.4 MB · 1920×1080 · 0:42" style summary for detail screens.
    var infoLine: String {
        var parts: [String] = []
        if byteCount > 0 {
            parts.append(ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file))
        }
        if pixelWidth > 0 { parts.append("\(pixelWidth)×\(pixelHeight)") }
        if duration > 0 {
            let m = Int(duration) / 60, s = Int(duration) % 60
            parts.append(String(format: "%d:%02d", m, s))
        }
        return parts.joined(separator: " · ")
    }
}
