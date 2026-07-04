import Foundation
import SwiftData

extension LuminaSchemaV1 {
    /// A subcategory within a Subject — e.g. Subject "Quantum Computing" with
    /// Topics "Error correction", "Hardware", "History". Items may optionally
    /// belong to one Topic; untopiced items sit directly under the Subject.
    ///
    /// Invariant (app-enforced, see `ContentItem.topicIsConsistent`): an item's
    /// topic must belong to one of the item's subjects.
    @Model
    final class Topic {
        var id: UUID = UUID()
        var title: String = ""
        var emoji: String = ""
        /// Manual ordering within the subject (0-based).
        var order: Int = 0
        var createdAt: Date = Date()

        var subject: Subject?

        /// Items filed under this topic. Deleting a topic keeps the items
        /// (they fall back to the subject level), hence `.nullify`.
        @Relationship(deleteRule: .nullify, inverse: \ContentItem.topic)
        var items: [ContentItem]? = []

        init(title: String, emoji: String = "", subject: Subject? = nil, order: Int = 0) {
            self.id = UUID()
            self.title = title
            self.emoji = emoji
            self.subject = subject
            self.order = order
            self.createdAt = Date()
        }
    }
}

extension Topic {
    var itemCount: Int { items?.count ?? 0 }
    var displayTitle: String { emoji.isEmpty ? title : "\(emoji) \(title)" }

    var sortedItems: [ContentItem] {
        (items ?? []).sorted { $0.createdAt > $1.createdAt }
    }
}
