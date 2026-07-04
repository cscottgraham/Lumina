import Foundation
import SwiftData

/// A research topic/project — the top-level organizing unit. Everything the
/// user captures lives inside a Subject, and the Claude chat for a Subject is
/// grounded in that Subject's content.
///
/// CloudKit note: every stored property has a default value and every
/// relationship is optional, as required for a CloudKit-backed ModelContainer.
@Model
final class Subject {
    /// Stable identity that survives across devices/sync.
    var id: UUID = UUID()
    var title: String = ""
    var subjectDescription: String = ""
    var accentRaw: String = AccentTheme.aurora.rawValue
    var emoji: String = "✨"
    var isPinned: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// A rolling, LLM-generated digest of the subject's content, cached to keep
    /// chat context compact (see ContextBuilder). Refreshed as content changes.
    var digest: String = ""
    var digestUpdatedAt: Date?

    // MARK: Relationships (all optional for CloudKit; cascade delete children)

    @Relationship(deleteRule: .cascade, inverse: \ContentItem.subject)
    var items: [ContentItem]? = []

    /// Subcategories. Deleting a subject cascades; deleting a topic keeps items.
    @Relationship(deleteRule: .cascade, inverse: \Topic.subject)
    var topics: [Topic]? = []

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

    // MARK: Convenience

    var accent: AccentTheme {
        get { AccentTheme(rawValue: accentRaw) ?? .aurora }
        set { accentRaw = newValue.rawValue }
    }

    var itemCount: Int { items?.count ?? 0 }

    var sortedItems: [ContentItem] {
        (items ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    var sortedTopics: [Topic] {
        (topics ?? []).sorted { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) }
    }

    func touch() { updatedAt = Date() }
}
