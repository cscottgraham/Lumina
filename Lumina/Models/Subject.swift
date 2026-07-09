import Foundation
import SwiftData

extension LuminaSchemaV1 {
    /// A research topic/project — the top-level organizing unit. Items live in
    /// one **or more** Subjects (many-to-many); each Subject also carries the
    /// user's own research notes and the full LLM conversation history.
    ///
    /// CloudKit note: every stored property has a default value and every
    /// relationship is optional, as required for a CloudKit-backed container.
    @Model
    final class Subject {
        /// Stable identity that survives across devices/sync.
        var id: UUID = UUID()
        var title: String = ""
        var subjectDescription: String = ""
        var accentRaw: String = AccentTheme.aurora.rawValue
        var emoji: String = "✨"
        var isPinned: Bool = false
        var isArchived: Bool = false
        var createdAt: Date = Date()
        var updatedAt: Date = Date()

        /// A photo/video item the user has explicitly pinned as this subject's
        /// backdrop. `nil` → the backdrop auto-follows the newest photo/video
        /// (see `backdropMediaItem`). Stored as the item's `id` rather than a
        /// relationship: the target is always one of this subject's own items,
        /// so a soft reference keeps the ContentItem model untouched.
        var backdropItemID: UUID? = nil

        /// The user's own subject-level scratchpad (markdown): hypotheses,
        /// open questions, reading lists. Distinct from `digest` (AI-written)
        /// and from ContentItems (captured material). Fed to Claude as part of
        /// the subject spine.
        var researchNotes: String = ""

        /// A rolling, LLM-generated digest of the subject's content, cached to
        /// keep chat context compact (see ContextBuilder). Refreshed as content
        /// changes (Phase 3 background job).
        var digest: String = ""
        var digestUpdatedAt: Date?

        // MARK: Relationships (all optional for CloudKit)

        /// Items in this subject. MANY-TO-MANY: an item may belong to several
        /// subjects, so deleting a subject must NOT cascade into items — see
        /// `delete(_:from:)` for the orphan-aware removal flow.
        @Relationship(deleteRule: .nullify, inverse: \ContentItem.subjects)
        var items: [ContentItem]? = []

        /// Subcategories. Cascade: topics are meaningless without the subject
        /// (their items survive — Topic→items is `.nullify`).
        @Relationship(deleteRule: .cascade, inverse: \Topic.subject)
        var topics: [Topic]? = []

        /// LLM conversation history. Cascade: threads are scoped to the subject.
        @Relationship(deleteRule: .cascade, inverse: \ChatThread.subject)
        var threads: [ChatThread]? = []

        @Relationship(inverse: \Tag.subjects)
        var tags: [Tag]? = []

        init(
            title: String = "",
            subjectDescription: String = "",
            accent: AccentTheme = .aurora,
            emoji: String = "✨"
        ) {
            self.id = UUID()
            self.title = title
            self.subjectDescription = subjectDescription
            self.accentRaw = accent.rawValue
            self.emoji = emoji
            self.createdAt = Date()
            self.updatedAt = Date()
        }
    }
}

// MARK: - Computed properties & helpers

extension Subject {
    var accent: AccentTheme {
        get { AccentTheme(rawValue: accentRaw) ?? .aurora }
        set { accentRaw = newValue.rawValue }
    }

    var itemCount: Int { items?.count ?? 0 }

    /// Newest first — the default browsing order.
    var sortedItems: [ContentItem] {
        (items ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    var sortedTopics: [Topic] {
        (topics ?? []).sorted { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) }
    }

    /// Items grouped by kind — powers "12 photos · 3 audio · 8 notes" summaries.
    var itemCountsByKind: [ContentKind: Int] {
        Dictionary(grouping: items ?? [], by: \.kind).mapValues(\.count)
    }

    /// Items not filed under any topic (shown at the subject level).
    var untopicedItems: [ContentItem] {
        sortedItems.filter { $0.topic == nil }
    }

    // MARK: Conversation history

    /// Threads, most recently active first.
    var sortedThreads: [ChatThread] {
        (threads ?? []).sorted { $0.updatedAt > $1.updatedAt }
    }

    /// The most recently active conversation, if any — lets "Research" resume
    /// where the user left off instead of always starting fresh.
    var latestThread: ChatThread? { sortedThreads.first }

    /// Total estimated Claude spend across every thread in this subject.
    var totalResearchCostUSD: Double {
        (threads ?? []).reduce(0) { $0 + $1.estimatedCostUSD }
    }

    /// The newest photo/video item that has media.
    var heroMediaItem: ContentItem? {
        sortedItems.first { ($0.kind == .photo || $0.kind == .video) && $0.primaryAttachment != nil }
    }

    /// Whether a given item can serve as a backdrop (photo/video with media).
    static func canBeBackdrop(_ item: ContentItem) -> Bool {
        (item.kind == .photo || item.kind == .video) && item.primaryAttachment != nil
    }

    /// The item that drives `SubjectBackdrop`: the user's pinned choice if it
    /// still exists and has media, otherwise the newest photo/video.
    var backdropMediaItem: ContentItem? {
        if let id = backdropItemID,
           let pinned = (items ?? []).first(where: { $0.id == id }),
           Subject.canBeBackdrop(pinned) {
            return pinned
        }
        return heroMediaItem
    }

    /// True when `item` is the currently pinned backdrop.
    func isBackdrop(_ item: ContentItem) -> Bool { backdropItemID == item.id }

    /// Pin `item` as the backdrop (no-op for non-media items).
    func pinBackdrop(_ item: ContentItem) {
        guard Subject.canBeBackdrop(item) else { return }
        backdropItemID = item.id
        touch()
    }

    /// Clear any pinned backdrop, reverting to the auto (newest media) behavior.
    func clearBackdrop() {
        backdropItemID = nil
        touch()
    }

    func touch() { updatedAt = Date() }

    // MARK: Deletion (many-to-many aware)

    /// Deletes a subject safely. Because items are shared (many-to-many),
    /// SwiftData's `.nullify` only removes the membership — this helper also
    /// deletes items that belonged to *no other* subject (and their media
    /// files), so nothing is silently orphaned.
    @MainActor
    static func delete(_ subject: Subject, in context: ModelContext,
                       mediaStore: MediaStore = .shared,
                       deleteExclusiveItems: Bool = true) {
        if deleteExclusiveItems {
            for item in subject.items ?? [] where (item.subjects ?? []).count <= 1 {
                for attachment in item.attachments ?? [] {
                    mediaStore.deleteFile(relativePath: attachment.relativePath)
                    if let thumb = attachment.thumbnailRelativePath {
                        mediaStore.deleteFile(relativePath: thumb)
                    }
                }
                context.delete(item)
            }
        }
        context.delete(subject)   // cascades topics + threads; nullifies items
        try? context.save()
    }
}
