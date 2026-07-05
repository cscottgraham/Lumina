import SwiftUI
import SwiftData

/// Global search: title, body/transcript, tags, AI notes, and subject names —
/// with kind filters. Results render as full ContentItemCards; tapping jumps
/// to the item's subject.
@MainActor
struct SearchView: View {
    @Environment(AppRouter.self) private var router
    @Query(sort: \ContentItem.updatedAt, order: .reverse) private var allItems: [ContentItem]

    @State private var query = ""
    @State private var kinds: Set<ContentKind> = []

    private var results: [ContentItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let q = query.lowercased()
        return allItems.filter { item in
            (kinds.isEmpty || kinds.contains(item.kind)) && (
                item.resolvedTitle.lowercased().contains(q)
                || item.text.lowercased().contains(q)
                || item.aiSummary.lowercased().contains(q)
                || item.sortedTags.contains { $0.normalizedName.contains(q) }
                || (item.primarySubject?.title.lowercased().contains(q) ?? false)
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("Search").luminaText(LuminaFont.largeTitle())

                GlassSearchBar(text: $query, prompt: "Notes, transcripts, tags, AI notes…")

                GlassFilterChips(items: ContentKind.allCases, selection: $kinds,
                                 label: { $0.title }, icon: { $0.systemImage })

                if query.isEmpty {
                    EmptyStateView(systemImage: "sparkle.magnifyingglass",
                                   title: "Search your vault",
                                   message: "Matches titles, note text, transcripts, tags, Claude's AI notes, and subject names.")
                        .frame(maxWidth: .infinity, minHeight: 280)
                } else if results.isEmpty {
                    EmptyStateView(systemImage: "questionmark.circle",
                                   title: "No matches",
                                   message: "Nothing in the vault matches “\(query)”.")
                        .frame(maxWidth: .infinity, minHeight: 280)
                } else {
                    Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                        .luminaOverline()
                    ForEach(results) { item in
                        Button {
                            if let subject = item.primarySubject { router.openSubject(subject) }
                        } label: {
                            ContentItemCard(item: item, accent: item.primarySubject?.accent ?? .aurora)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                    }
                }

                Color.clear.frame(height: 40)
            }
            .padding(Space.md)
        }
        .scrollContentBackground(.hidden)
        .animation(Motion.spring, value: results.count)
    }
}
