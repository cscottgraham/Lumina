import SwiftUI
import SwiftData

/// A subject's contents + the entry point into research chat and capture.
/// The backdrop reflects the subject itself (its imagery, blurred under the
/// accent aurora — see `SubjectBackdrop`). Items can be filtered by Topic.
@MainActor
struct SubjectDetailView: View {
    @Bindable var subject: Subject
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context

    @State private var selectedTopic: Topic?      // nil → all items
    @State private var showNewTopic = false
    @State private var newTopicTitle = ""

    private var accent: AccentTheme { subject.accent }

    private var visibleItems: [ContentItem] {
        guard let topic = selectedTopic else { return subject.sortedItems }
        return subject.sortedItems.filter { $0.topic?.id == topic.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                header
                researchButton
                topicsSection
                itemsSection
            }
            .padding(Space.md)
            .padding(.bottom, Space.xxl)
        }
        .background(SubjectBackdrop(subject: subject))
        .navigationTitle(subject.title.isEmpty ? "Subject" : subject.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { router.sheet = .newNote(subject) } label: { Label("Add note", systemImage: "text.alignleft") }
                    Button { showNewTopic = true } label: { Label("Add topic", systemImage: "folder.badge.plus") }
                    Button { router.sheet = .editSubject(subject) } label: { Label("Edit subject", systemImage: "pencil") }
                    Button { subject.isPinned.toggle(); try? context.save() } label: {
                        Label(subject.isPinned ? "Unpin" : "Pin", systemImage: subject.isPinned ? "pin.slash" : "pin")
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .alert("New Topic", isPresented: $showNewTopic) {
            TextField("Topic name", text: $newTopicTitle)
            Button("Create") { createTopic() }
            Button("Cancel", role: .cancel) { newTopicTitle = "" }
        }
    }

    private var header: some View {
        GlassCard(accent: accent) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(subject.emoji).font(.system(size: 40))
                Text(subject.title).luminaText(LuminaFont.largeTitle())
                if !subject.subjectDescription.isEmpty {
                    Text(subject.subjectDescription)
                        .luminaText(LuminaFont.callout(), color: LuminaColors.textSecondary)
                }
            }
        }
    }

    private var researchButton: some View {
        GlassButton("Research with \(LLMProviderFactory.activeKind.displayName)",
                    systemImage: "sparkles", accent: accent, weight: .primary) {
            let thread = ChatThread(subject: subject)
            thread.modelRaw = LLMProviderFactory.defaultChatModelID()
            context.insert(thread)
            try? context.save()
            router.openResearch(thread)
        }
    }

    // MARK: Topics

    @ViewBuilder private var topicsSection: some View {
        if !subject.sortedTopics.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.xs) {
                    topicChip(nil, label: "All (\(subject.itemCount))")
                    ForEach(subject.sortedTopics) { topic in
                        topicChip(topic, label: "\(topic.displayTitle) (\(topic.itemCount))")
                            .contextMenu {
                                Button(role: .destructive) { deleteTopic(topic) } label: {
                                    Label("Delete topic (keeps items)", systemImage: "trash")
                                }
                            }
                    }
                    Button { showNewTopic = true } label: {
                        TagChip(text: "＋ Topic", systemImage: "folder.badge.plus", accent: accent)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func topicChip(_ topic: Topic?, label: String) -> some View {
        Button { withAnimation(Motion.tap) { selectedTopic = topic } } label: {
            TagChip(text: label, accent: accent, filled: selectedTopic?.id == topic?.id)
        }.buttonStyle(.plain)
    }

    private func createTopic() {
        let name = newTopicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        newTopicTitle = ""
        guard !name.isEmpty else { return }
        let topic = Topic(title: name, subject: subject, order: subject.sortedTopics.count)
        context.insert(topic)
        try? context.save()
    }

    private func deleteTopic(_ topic: Topic) {
        if selectedTopic?.id == topic.id { selectedTopic = nil }
        context.delete(topic)   // .nullify keeps the items
        try? context.save()
    }

    // MARK: Items

    @ViewBuilder private var itemsSection: some View {
        HStack {
            Text(selectedTopic.map { $0.title } ?? "Items").luminaText(LuminaFont.title2())
            Spacer()
            GlassButton("Capture", systemImage: "plus", accent: accent, weight: .secondary) {
                router.sheet = .capture(subject)
            }
            .fixedSize()
        }
        if visibleItems.isEmpty {
            Text(selectedTopic == nil
                 ? "No items yet. Capture a note, photo, or web snippet to build context for research."
                 : "No items in this topic yet.")
                .luminaText(LuminaFont.callout(), color: LuminaColors.textSecondary)
                .padding(.vertical, Space.md)
        } else {
            // Kind-specific layouts (photo/video/audio/text/web) — see
            // DesignSystem/Components/ContentItemCard.swift. Tap → full-screen
            // immersive viewer.
            ForEach(visibleItems) { item in
                Button { router.viewerItem = item } label: {
                    ContentItemCard(item: item, accent: accent)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
