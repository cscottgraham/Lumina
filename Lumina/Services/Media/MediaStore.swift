import SwiftUI
import UIKit

/// Owns the on-disk media files. Binaries live under the app container (mirrored
/// to iCloud via the app's ubiquity container in a later phase); SwiftData only
/// stores relative paths, which this store resolves to absolute URLs.
///
/// MVP uses the local Application Support directory; Phase 5 swaps `rootURL` for
/// the iCloud ubiquity container so media syncs alongside the SwiftData store.
final class MediaStore {
    static let shared = MediaStore()

    let rootURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        rootURL = base.appendingPathComponent("LuminaMedia", isDirectory: true)
        try? FileManager.default.createDirectory(at: rootURL.appendingPathComponent("media"), withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: rootURL.appendingPathComponent("thumbnails"), withIntermediateDirectories: true)
    }

    func absoluteURL(for relativePath: String) -> URL {
        rootURL.appendingPathComponent(relativePath)
    }

    /// Imports raw data under a fresh relative path and returns it.
    @discardableResult
    func importData(_ data: Data, ext: String) throws -> String {
        let name = "media/\(UUID().uuidString).\(ext)"
        try data.write(to: absoluteURL(for: name))
        return name
    }

    /// Copies an external file (e.g. from the photo picker) into the store.
    @discardableResult
    func importFile(at url: URL) throws -> String {
        let ext = url.pathExtension.isEmpty ? "dat" : url.pathExtension
        let name = "media/\(UUID().uuidString).\(ext)"
        let dest = absoluteURL(for: name)
        if url.startAccessingSecurityScopedResource() { defer { url.stopAccessingSecurityScopedResource() } }
        try FileManager.default.copyItem(at: url, to: dest)
        return name
    }

    func deleteFile(relativePath: String) {
        try? FileManager.default.removeItem(at: absoluteURL(for: relativePath))
    }

    /// Loads an image at a relative path as a SwiftUI `Image` (thumbnails/photos).
    func thumbnailImage(relativePath: String) -> Image? {
        guard let ui = UIImage(contentsOfFile: absoluteURL(for: relativePath).path) else { return nil }
        return Image(uiImage: ui)
    }
}

// MARK: - Environment plumbing so views can reach the store without singletons everywhere.

private struct MediaStoreKey: EnvironmentKey {
    static let defaultValue = MediaStore.shared
}
extension EnvironmentValues {
    var mediaStore: MediaStore {
        get { self[MediaStoreKey.self] }
        set { self[MediaStoreKey.self] = newValue }
    }
}
