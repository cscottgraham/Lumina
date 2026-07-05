import SwiftUI
import SwiftData

/// Home: everything you've captured, newest first — a two-column glass masonry
/// with a pinned (favorites) rail, glass search + kind filters, and
/// pull-to-refresh (which also nudges enrichment for any items Claude hasn't
/// evaluated yet). Tapping a card jumps to its subject.
@MainActor
struct LibraryView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context

    @Query(sort: \ContentItem.createdAt, order: .reverse)
    private var allItems: [ContentItem]

    @State private var query = ""
    @State private var kindFilter: Set<ContentKind> = []

    // MARK: Filtering

    private var filtered: [ContentItem] {
        allItems.filter { item in
            (kindFilter.isEmpty || kindFilter.contains(item.kind))
            && (query.isEmpty || matches(item))
        }
    }

    private func matches(_ item: ContentItem) -> Bool {
        let q = query.lowercased()
        return item.resolvedTitle.lowercased().contains(q)
            || item.text.lowercased().contains(q)
            || item.sortedTags.contains { $0.normalizedName.contains(q) }
            || (item.primarySubject?.title.lowercased().contains(q) ?? false)
    }

    private var pinned: [ContentItem] { filtered.filter(\.isFavorite) }
    private var recent: [ContentItem] { filtered.filter { !$0.isFavorite } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                GlassSearchBar(text: $query, prompt: "Search everything…")

                GlassFilterChips(items: ContentKind.allCases,
                                 selection: $kindFilter,
                                 label: { $0.title },
                                 icon: { $0.systemImage })

                if filtered.isEmpty {
                    EmptyStateView(systemImage: "sparkles.rectangle.stack",
                                   title: allItems.isEmpty ? "Your vault is empty" : "No matches",
                                   message: allItems.isEmpty
                                       ? "Capture your first note, photo, or web snippet — everything lands here."
                                       : "Nothing matches that search/filter combination.",
                                   actionTitle: allItems.isEmpty ? "Capture" : nil) {
                        router.sheet = .capture(nil)
                    }
                    .frame(maxWidth: .infinity, minHeight: 320)
                } else {
                    if !pinned.isEmpty { pinnedRail }
                    masonry(recent)
                }

                Color.clear.frame(height: 40)
            }
            .padding(Space.md)
        }
        .refreshable { await refresh() }
        .navigationTitle("Lumina")
        .scrollContentBackground(.hidden)
        .animation(Motion.spring, value: filtered.count)
    }

    // MARK: Pinned rail

    private var pinnedRail: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Pinned").luminaOverline()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.sm) {
                    ForEach(pinned) { item in
                        libraryCard(item)
                            .frame(width: 260)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: Masonry (two independent columns → varied heights interleave)

    private func masonry(_ items: [ContentItem]) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Recent").luminaOverline()
            HStack(alignment: .top, spacing: Space.sm) {
                column(items.enumerated().filter { $0.offset % 2 == 0 }.map(\.element))
                column(items.enumerated().filter { $0.offset % 2 == 1 }.map(\.element))
            }
        }
    }

    private func column(_ items: [ContentItem]) -> some View {
        LazyVStack(spacing: Space.sm) {
            ForEach(items) { item in
                libraryCard(item)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
        }
    }

    private func libraryCard(_ item: ContentItem) -> some View {
        Button {
            router.viewerItem = item        // full-screen immersive viewer
        } label: {
            ContentItemCard(item: item, accent: item.primarySubject?.accent ?? .aurora)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                item.isFavorite.toggle(); try? context.save()
            } label: {
                Label(item.isFavorite ? "Unpin" : "Pin", systemImage: item.isFavorite ? "pin.slash" : "pin")
            }
            if let subject = item.primarySubject {
                Button { router.openSubject(subject) } label: {
                    Label("Go to \(subject.title)", systemImage: "square.stack.3d.up")
                }
            }
        }
    }

    // MARK: Refresh — also nudges pending AI enrichment

    private func refresh() async {
        let pending = allItems.filter { $0.aiEnrichedAt == nil && !$0.text.isEmpty }.prefix(5)
        for item in pending {
            await ItemEnrichmentService().enrich(item, in: context)
        }
    }
}
