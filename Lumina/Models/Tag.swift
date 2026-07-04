import Foundation
import SwiftData

extension LuminaSchemaV1 {
    /// A lightweight label applied across subjects and items for cross-cutting
    /// organization, filtering, and the tag-autocomplete pool.
    ///
    /// CloudKit forbids unique constraints, so uniqueness of `name` is enforced
    /// in the app layer — create tags ONLY through `TagStore.findOrCreate`.
    @Model
    final class Tag {
        var id: UUID = UUID()
        var name: String = ""
        var colorHex: String = "#8E8E93"
        var createdAt: Date = Date()

        // Many-to-many; inverses are declared on Subject.tags / ContentItem.tags.
        var subjects: [Subject]? = []
        var items: [ContentItem]? = []

        init(name: String, colorHex: String = "#8E8E93") {
            self.id = UUID()
            self.name = name
            self.colorHex = colorHex
            self.createdAt = Date()
        }
    }
}

extension Tag {
    var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// How widely used this tag is — for sorting suggestion lists by relevance.
    var usageCount: Int { (items?.count ?? 0) + (subjects?.count ?? 0) }
}
