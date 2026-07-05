import Foundation

/// Fetches lightweight page metadata for web snippets: <title>, description,
/// author, and the og:image (which becomes the snippet's screenshot
/// attachment). Plain URLSession + regex over the first chunk of HTML — no
/// WebKit dependency, graceful on failure.
struct WebMetadataService {
    struct Metadata {
        var title: String?
        var descriptionText: String?
        var author: String?
        var imageURL: URL?
    }

    func fetchMetadata(for url: URL) async -> Metadata {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Mozilla/5.0 (iPhone) Lumina/1.0", forHTTPHeaderField: "User-Agent")

        guard let (data, _) = try? await URLSession.shared.data(for: request) else {
            return Metadata()
        }
        // Only the head matters; cap work on huge pages.
        let html = String(decoding: data.prefix(300_000), as: UTF8.self)

        var meta = Metadata()
        meta.title = firstMatch(#"<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)"#, in: html)
            ?? firstMatch(#"<title[^>]*>([^<]+)</title>"#, in: html).map(decodeEntities)
        meta.descriptionText = firstMatch(#"<meta[^>]+property=["']og:description["'][^>]+content=["']([^"']+)"#, in: html)
            ?? firstMatch(#"<meta[^>]+name=["']description["'][^>]+content=["']([^"']+)"#, in: html)
        meta.author = firstMatch(#"<meta[^>]+name=["']author["'][^>]+content=["']([^"']+)"#, in: html)
        if let img = firstMatch(#"<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)"#, in: html) {
            meta.imageURL = URL(string: img, relativeTo: url)?.absoluteURL
        }
        meta.title = meta.title.map(decodeEntities)
        meta.descriptionText = meta.descriptionText.map(decodeEntities)
        return meta
    }

    /// Downloads the og:image (bounded) for the screenshot attachment.
    func fetchImage(at url: URL, maxBytes: Int = 6_000_000) async -> Data? {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              data.count <= maxBytes,
              (response.mimeType ?? "").hasPrefix("image") else { return nil }
        return data
    }

    // MARK: Helpers

    private func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodeEntities(_ s: String) -> String {
        s.replacingOccurrences(of: "&amp;", with: "&")
         .replacingOccurrences(of: "&lt;", with: "<")
         .replacingOccurrences(of: "&gt;", with: ">")
         .replacingOccurrences(of: "&quot;", with: "\"")
         .replacingOccurrences(of: "&#39;", with: "'")
         .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}
