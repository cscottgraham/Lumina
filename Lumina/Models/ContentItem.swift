import Foundation
import SwiftData

/// A single captured item inside a Subject: a note, photo, video, audio/voice
/// note, web snippet, or document. Text lives here; binary media lives on disk
/// (see `Attachment`), referenced by relative path — never stored in the DB.
@Model
final class ContentItem {
    var id: UUID = UUID()
    var kindRaw: String = ContentKind.note.rawValue

    /// Short user-facing title (auto-derived if empty).
    var title: String = ""
    /// Primary text payload: the note body, the voice-note transcript, the web
    /// snippet excerpt, or an OCR/caption for media. This is what the
    /// ContextBuilder feeds to Claude.
    var text: String = ""

    /// Optional source metadata for web snippets.
    var sourceURL: URL?
    var sourceTitle: String?
    var author: String?

    // MARK: Source provenance (where/when this came from)

    /// When the source was captured/observed (may differ from `createdAt`,
    /// e.g. importing an old photo). Nil → treat `createdAt` as capture time.
    var capturedAt: Date?
    /// Free-form origin note, e.g. "Voice memo while driving", "Lab whiteboard".
    var sourceDetail: String?
    /// Optional geotag for where the item was captured.
    var latitude: Double?
    var longitude: Double?
    var locationName: String?

    // MARK: AI enrichment (written by ItemEnrichmentService)

    /// Claude's evaluation of the item: a short summary plus relevant related
    /// context. Fed back into research chat via ContextBuilder.
    var aiSummary: String = ""
    var aiEnrichedAt: Date?

    var isFavorite: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: Relationships

    var subject: Subject?
    /// Optional subcategory within the subject.
    var topic: Topic?

    @Relationship(deleteRule: .cascade, inverse: \Attachment.item)
    var attachments: [Attachment]? = []

    @Relationship(inverse: \Tag.items)
    var tags: [Tag]? = []

    init(
        kind: ContentKind,
        title: String = "",
        text: String = "",
        subject: Subject? = nil
    ) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.title = title
        self.text = text
        self.subject = subject
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: Convenience

    var kind: ContentKind {
        get { ContentKind(rawValue: kindRaw) ?? .note }
        set { kindRaw = newValue.rawValue }
    }

    /// The main media attachment (first one), if any.
    var primaryAttachment: Attachment? {
        (attachments ?? []).sorted { $0.order < $1.order }.first
    }

    /// A display title even when the user didn't set one.
    var resolvedTitle: String {
        if !title.isEmpty { return title }
        if !text.isEmpty { return String(text.prefix(60)) }
        return kind.title
    }

    /// "Jul 4, 2026 · Brockville · Voice memo" — a one-line provenance summary.
    var provenanceLine: String? {
        var parts: [String] = []
        let f = DateFormatter(); f.dateStyle = .medium
        parts.append(f.string(from: capturedAt ?? createdAt))
        if let locationName, !locationName.isEmpty { parts.append(locationName) }
        if let sourceDetail, !sourceDetail.isEmpty { parts.append(sourceDetail) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var sortedTags: [Tag] {
        (tags ?? []).sorted { $0.normalizedName < $1.normalizedName }
    }

    func touch() { updatedAt = Date(); subject?.touch() }
}
