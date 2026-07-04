import Foundation
import SwiftData
import CoreLocation

extension LuminaSchemaV1 {
    /// A single captured item: photo, video, audio recording, text note
    /// (typed or dictated), web snippet, or document.
    ///
    /// • Belongs to **one or more Subjects** (many-to-many) and optionally one
    ///   Topic within them.
    /// • Text lives here; binary media lives on disk as `Attachment`s
    ///   (relative paths — never blobs in the DB).
    /// • `text` is the single LLM-facing surface: note body, audio transcript,
    ///   snippet's selected text, or an OCR/caption for media. ContextBuilder
    ///   feeds it (plus `aiSummary`, tags, topic) to Claude.
    @Model
    final class ContentItem {
        var id: UUID = UUID()
        var kindRaw: String = ContentKind.note.rawValue
        /// How it entered the vault (typed/dictated/imported/shared/captured).
        var captureMethodRaw: String = CaptureMethod.typed.rawValue

        /// Short user-facing title (auto-derived if empty).
        var title: String = ""
        /// Primary text payload (see type doc above).
        var text: String = ""

        // MARK: Web-snippet source (URL, page title, author)
        var sourceURL: URL?
        var sourceTitle: String?
        var author: String?

        // MARK: Provenance (when/where this came from)

        /// When the source was captured/observed (may differ from `createdAt`,
        /// e.g. importing an old photo). Nil → treat `createdAt` as capture time.
        var capturedAt: Date?
        /// Free-form origin note, e.g. "Voice memo while driving", "Lecture".
        var sourceDetail: String?
        /// Optional geotag.
        var latitude: Double?
        var longitude: Double?
        var locationName: String?

        // MARK: AI enrichment (written by ItemEnrichmentService)

        /// Claude's evaluation: short summary + relevant related context.
        var aiSummary: String = ""
        var aiEnrichedAt: Date?

        var isFavorite: Bool = false
        var createdAt: Date = Date()
        var updatedAt: Date = Date()

        // MARK: Relationships (all optional for CloudKit)

        /// MANY-TO-MANY: the subjects this item belongs to (≥1, app-enforced —
        /// CloudKit forbids required relationships). Inverse on Subject.items.
        var subjects: [Subject]? = []

        /// Optional subcategory. App-level invariant: `topic.subject` should be
        /// one of `subjects` (see `topicIsConsistent`).
        var topic: Topic?

        @Relationship(deleteRule: .cascade, inverse: \Attachment.item)
        var attachments: [Attachment]? = []

        @Relationship(inverse: \Tag.items)
        var tags: [Tag]? = []

        init(
            kind: ContentKind,
            title: String = "",
            text: String = "",
            subjects: [Subject] = [],
            captureMethod: CaptureMethod = .typed
        ) {
            self.id = UUID()
            self.kindRaw = kind.rawValue
            self.captureMethodRaw = captureMethod.rawValue
            self.title = title
            self.text = text
            self.subjects = subjects
            self.createdAt = Date()
            self.updatedAt = Date()
        }
    }
}

// MARK: - Computed properties & helpers

extension ContentItem {
    /// Back-compat convenience: single-subject creation.
    convenience init(kind: ContentKind, title: String = "", text: String = "",
                     subject: Subject?, captureMethod: CaptureMethod = .typed) {
        self.init(kind: kind, title: title, text: text,
                  subjects: subject.map { [$0] } ?? [], captureMethod: captureMethod)
    }

    var kind: ContentKind {
        get { ContentKind(rawValue: kindRaw) ?? .note }
        set { kindRaw = newValue.rawValue }
    }

    var captureMethod: CaptureMethod {
        get { CaptureMethod(rawValue: captureMethodRaw) ?? .typed }
        set { captureMethodRaw = newValue.rawValue }
    }

    var sortedTags: [Tag] {
        (tags ?? []).sorted { $0.normalizedName < $1.normalizedName }
    }

    /// First subject — for single-subject contexts (enrichment, display).
    var primarySubject: Subject? { subjects?.first }

    /// App-level invariant check: a topic must belong to one of the item's
    /// subjects. Call before assigning `topic` from pickers.
    var topicIsConsistent: Bool {
        guard let topic, let topicSubject = topic.subject else { return true }
        return (subjects ?? []).contains { $0.id == topicSubject.id }
    }

    // MARK: Media conveniences

    /// The primary media attachment (`role == .original`, lowest order).
    var primaryAttachment: Attachment? {
        (attachments ?? [])
            .filter { $0.role == .original }
            .sorted { $0.order < $1.order }
            .first
            ?? (attachments ?? []).sorted { $0.order < $1.order }.first
    }

    /// A web snippet's page screenshot, if one was captured.
    var snippetScreenshot: Attachment? {
        guard kind == .webSnippet else { return nil }
        return (attachments ?? []).first { $0.role == .screenshot }
    }

    /// Absolute URL of the original media file (resolved via MediaStore).
    var originalMediaURL: URL? {
        primaryAttachment.map { MediaStore.shared.absoluteURL(for: $0.relativePath) }
    }

    /// Absolute URL of the cached thumbnail, if generated.
    var thumbnailMediaURL: URL? {
        guard let path = primaryAttachment?.thumbnailRelativePath
                ?? snippetScreenshot?.thumbnailRelativePath else { return nil }
        return MediaStore.shared.absoluteURL(for: path)
    }

    /// Playback duration for audio/video (0 otherwise).
    var mediaDuration: Double { primaryAttachment?.duration ?? 0 }

    /// True when an audio/video item has a usable transcript in `text`.
    var hasTranscript: Bool {
        (kind == .audio || kind == .video) && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Display conveniences

    /// A display title even when the user didn't set one.
    var resolvedTitle: String {
        if !title.isEmpty { return title }
        if kind == .webSnippet, let sourceTitle, !sourceTitle.isEmpty { return sourceTitle }
        if !text.isEmpty { return String(text.prefix(60)) }
        return kind.title
    }

    /// Geotag as a CoreLocation coordinate, when present.
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// "Jul 4, 2026 · Brockville · Voice memo" — one-line provenance summary.
    var provenanceLine: String? {
        var parts: [String] = []
        let f = DateFormatter(); f.dateStyle = .medium
        parts.append(f.string(from: capturedAt ?? createdAt))
        if let locationName, !locationName.isEmpty { parts.append(locationName) }
        if let sourceDetail, !sourceDetail.isEmpty { parts.append(sourceDetail) }
        else if captureMethod == .dictated { parts.append(CaptureMethod.dictated.title) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    func touch() {
        updatedAt = Date()
        subjects?.forEach { $0.touch() }
    }
}
