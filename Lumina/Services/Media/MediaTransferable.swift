import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// Receives a movie from PhotosPicker as a FILE (never as in-memory Data) —
/// the key to handling multi-gigabyte videos gracefully. The received temp
/// file is copied to our own temp path because the system deletes its copy
/// when the closure returns.
struct MovieFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copy = URL.temporaryDirectory.appending(path: "import-\(UUID().uuidString).\(ext)")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}
