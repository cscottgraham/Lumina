import Foundation
import SwiftData

/// A lightweight label that can be applied across subjects and items for
/// cross-cutting organization and search.
///
/// CloudKit forbids unique constraints, so uniqueness of `name` is enforced in
/// the app layer (see `TagStore.findOrCreate`) rather than with `@Attribute(.unique)`.
@Model
final class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#8E8E93"
    var createdAt: Date = Date()

    // Many-to-many; inverses are declared on Subject/ContentItem.
    var subjects: [Subject]? = []
    var items: [ContentItem]? = []

    init(name: String, colorHex: String = "#8E8E93") {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
    }

    var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
