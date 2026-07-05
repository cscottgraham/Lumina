import SwiftUI
import SwiftData

/// Home screen: a glass grid of research subjects over the aurora.
@MainActor
struct SubjectsListView: View {
    @Environment(AppRouter.self) private var router
    // Bool isn't Comparable, so isPinned can't be a SortDescriptor —
    // fetch by recency and float pinned subjects in memory.
    @Query(sort: \Subject.updatedAt, order: .reverse)
    private var subjects: [Subject]

    private var displaySubjects: [Subject] {
        subjects.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private let columns = [GridItem(.flexible(), spacing: Space.md),
                           GridItem(.flexible(), spacing: Space.md)]

    var body: some View {
        ScrollView {
            if subjects.isEmpty {
                EmptyStateView(systemImage: "square.stack.3d.up.badge.a",
                               title: "Start a Subject",
                               message: "Create your first research topic, then capture notes, photos, audio, and web snippets into it.",
                               actionTitle: "New Subject") { router.sheet = .newSubject }
                    .frame(maxWidth: .infinity, minHeight: 420)
            } else {
                LazyVGrid(columns: columns, spacing: Space.md) {
                    ForEach(displaySubjects) { subject in
                        SubjectCard(subject: subject)
                            .onTapGesture { router.openSubject(subject) }
                    }
                }
                .padding(Space.md)
            }
        }
        .navigationTitle("Lumina")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                GlassIconButton(systemImage: "plus", accent: .aurora, filled: true) {
                    router.sheet = .newSubject
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

private struct SubjectCard: View {
    let subject: Subject
    var body: some View {
        GlassCard(accent: subject.accent, padding: Space.md) {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack {
                    Text(subject.emoji).font(.system(size: 30))
                    Spacer()
                    if subject.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(LuminaGradients.accentColor(subject.accent))
                    }
                }
                Text(subject.title.isEmpty ? "Untitled" : subject.title)
                    .luminaText(LuminaFont.title2())
                    .lineLimit(2)

                Spacer(minLength: 0)

                // Preview of contained items: up to three tiny thumbnails/kind
                // tiles + the count.
                HStack(spacing: Space.xxs) {
                    ForEach(subject.sortedItems.prefix(3)) { item in
                        MediaThumbnail(item: item, accent: subject.accent, side: 30)
                    }
                    Spacer(minLength: 0)
                    Text("\(subject.itemCount)")
                        .luminaText(LuminaFont.caption(), color: LuminaColors.textSecondary)
                }
            }
        }
        .frame(height: 168)
    }
}

#Preview {
    NavigationStack { SubjectsListView() }
        .environment(AppRouter())
        .modelContainer(PersistenceController.preview())
        .preferredColorScheme(.dark)
}
