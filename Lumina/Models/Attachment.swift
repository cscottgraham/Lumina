import Foundation
import SwiftData

/// Metadata for one on-disk media file belonging to a `ContentItem`.
///
/// The binary lives in the app's iCloud-synced container; we persist only the
/// **relative path** (resolved against the container at runtime) plus a cached
/// thumbnail path and lightweight metadata. This keeps the SwiftData store
/// small and CloudKit sync fast. See `MediaStore` for path resolution.
@Model
final class Attachment {
    var id: UUID = UUID()

    /// Path relative to the media container root, e.g. "media/<uuid>.mov".
    var relativePath: String = ""
    /// Cached thumbnail path (relative), generated lazily by `ThumbnailService`.
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
        byteCount: Int = 0,
        duration: Double = 0,
        pixelWidth: Int = 0,
        pixelHeight: Int = 0,
        order: Int = 0
    ) {
        self.id = UUID()
        self.relativePath = relativePath
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
