import Foundation
import AVFoundation
import UIKit

/// Generates and caches thumbnails for photos and videos. Runs off the main
/// thread; writes a JPEG into the store's `thumbnails/` folder and returns its
/// relative path to persist on the `Attachment`.
struct ThumbnailService {
    var store: MediaStore = .shared
    var maxPixel: CGFloat = 400

    /// Returns a thumbnail relative path for an attachment, generating it if
    /// needed. Photos downscale; videos snapshot the first frame.
    func thumbnail(for attachment: Attachment) async -> String? {
        if let cached = attachment.thumbnailRelativePath,
           FileManager.default.fileExists(atPath: store.absoluteURL(for: cached).path) {
            return cached
        }
        let src = store.absoluteURL(for: attachment.relativePath)
        let image: UIImage?
        if attachment.uti.contains("movie") || attachment.uti.contains("mpeg") || attachment.duration > 0 {
            image = await videoFrame(url: src)
        } else {
            image = downscaledImage(url: src)
        }
        guard let image, let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let name = "thumbnails/\(UUID().uuidString).jpg"
        try? data.write(to: store.absoluteURL(for: name))
        return name
    }

    private func downscaledImage(url: URL) -> UIImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    private func videoFrame(url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: maxPixel, height: maxPixel)
        return await withCheckedContinuation { cont in
            gen.generateCGImagesAsynchronously(forTimes: [NSValue(time: CMTime(seconds: 0.1, preferredTimescale: 600))]) { _, cg, _, _, _ in
                cont.resume(returning: cg.map(UIImage.init))
            }
        }
    }
}
