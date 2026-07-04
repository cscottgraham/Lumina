import Foundation
import SwiftData

/// App-layer tag registry. CloudKit forbids unique constraints, so this is the
/// single place that creates tags — it reuses an existing tag when the
/// normalized name matches, keeping the autocomplete pool free of duplicates.
@MainActor
struct TagStore {
    let context: ModelContext

    /// All tags, sorted for suggestion lists.
    func allTags() -> [Tag] {
        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Case-insensitive find-or-create by name. Returns nil for blank input.
    @discardableResult
    func findOrCreate(_ rawName: String) -> Tag? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let normalized = name.lowercased()
        if let existing = allTags().first(where: { $0.normalizedName == normalized }) {
            return existing
        }
        let tag = Tag(name: name, colorHex: Self.nextColor())
        context.insert(tag)
        return tag
    }

    /// Suggestions for an autocomplete field: previously created tags matching
    /// the fragment (all tags when the fragment is empty), minus already-picked.
    func suggestions(matching fragment: String, excluding: [Tag] = [], limit: Int = 8) -> [Tag] {
        let f = fragment.trimmingCharacters(in: .whitespaces).lowercased()
        let excludedIDs = Set(excluding.map(\.id))
        return allTags()
            .filter { !excludedIDs.contains($0.id) }
            .filter { f.isEmpty || $0.normalizedName.contains(f) }
            .prefix(limit)
            .map { $0 }
    }

    /// Attach a tag to an item (no duplicates).
    func attach(_ tag: Tag, to item: ContentItem) {
        var current = item.tags ?? []
        guard !current.contains(where: { $0.id == tag.id }) else { return }
        current.append(tag)
        item.tags = current
    }

    /// Cycle through pleasant defaults for new tag dots.
    private static let palette = ["#5EEAD4", "#818CF8", "#FB7185", "#FBBF24", "#4ADE80", "#38BDF8", "#F472B6"]
    private static var cursor = 0
    private static func nextColor() -> String {
        defer { cursor = (cursor + 1) % palette.count }
        return palette[cursor]
    }
}
