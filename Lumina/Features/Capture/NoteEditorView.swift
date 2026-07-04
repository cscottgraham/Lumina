import SwiftUI
import SwiftData

/// Typed-note capture with topic, tags (autocomplete), and source metadata.
/// On save, `ItemEnrichmentService` evaluates the item with Claude in the
/// background (toggle in Settings). Later phases add photo/video/audio capture
/// and web-snippet clipping producing `ContentItem`s through the same path.
struct NoteEditorView: View {
    let subject: Subject
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var text = ""
    @State private var selectedTopic: Topic?
    @State private var selectedTags: [Tag] = []

    // Provenance metadata
    @State private var capturedAt = Date()
    @State private var sourceDetail = ""
    @State private var location: LocationService.Snapshot?
    @State private var fetchingLocation = false

    // New-topic alert
    @State private var showNewTopic = false
    @State private var newTopicTitle = ""

    private var accent: AccentTheme { subject.accent }

    var body: some View {
        GlassSheet(title: "New Note", accent: accent, onClose: { dismiss() }) {
            VStack(alignment: .leading, spacing: Space.lg) {
                TextField("Title (optional)", text: $title)
                    .textFieldStyle(.plain).luminaText(LuminaFont.title2())
                    .padding(Space.md).glass(cornerRadius: Radius.md, accent: accent)

                TextField("Write your note…", text: $text, axis: .vertical)
                    .textFieldStyle(.plain).luminaText(LuminaFont.body())
                    .lineLimit(6...20)
                    .padding(Space.md).glass(cornerRadius: Radius.md, accent: accent)

                section("Topic") { topicPicker }
                section("Tags") { TagPickerView(selected: $selectedTags, accent: accent) }
                section("Source") { metadataEditor }

                GlassButton("Save note", systemImage: "checkmark", accent: accent, weight: .primary, action: save)
            }
        }
        .alert("New Topic", isPresented: $showNewTopic) {
            TextField("Topic name", text: $newTopicTitle)
            Button("Create") { createTopic() }
            Button("Cancel", role: .cancel) { newTopicTitle = "" }
        }
    }

    // MARK: Sections

    private func section<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(label).luminaText(LuminaFont.subheadline(), color: LuminaColors.textSecondary)
            content()
        }
    }

    private var topicPicker: some View {
        WrappingHStack(spacing: Space.xs) {
            Button { withAnimation(Motion.tap) { selectedTopic = nil } } label: {
                TagChip(text: "None", accent: accent, filled: selectedTopic == nil)
            }.buttonStyle(.plain)

            ForEach(subject.sortedTopics) { topic in
                Button { withAnimation(Motion.tap) { selectedTopic = topic } } label: {
                    TagChip(text: topic.displayTitle, accent: accent, filled: selectedTopic?.id == topic.id)
                }.buttonStyle(.plain)
            }

            Button { showNewTopic = true } label: {
                TagChip(text: "＋ New topic", systemImage: "folder.badge.plus", accent: accent)
            }.buttonStyle(.plain)
        }
    }

    private var metadataEditor: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            DatePicker("Captured", selection: $capturedAt)
                .luminaText(LuminaFont.callout())
                .tint(LuminaGradients.accentColor(accent))

            TextField("Where is this from? e.g. “Lecture”, “Lab whiteboard”", text: $sourceDetail)
                .textFieldStyle(.plain).luminaText(LuminaFont.callout())

            HStack {
                if let location {
                    Label(location.placeName ?? String(format: "%.3f, %.3f", location.latitude, location.longitude),
                          systemImage: "mappin.circle.fill")
                        .luminaText(LuminaFont.callout(), color: LuminaGradients.accentColor(accent))
                    Spacer()
                    Button("Remove") { self.location = nil }
                        .font(LuminaFont.caption()).foregroundStyle(LuminaColors.textTertiary)
                } else {
                    Button {
                        fetchingLocation = true
                        Task {
                            location = await LocationService.shared.snapshot()
                            fetchingLocation = false
                        }
                    } label: {
                        Label(fetchingLocation ? "Locating…" : "Add current location",
                              systemImage: "location")
                            .luminaText(LuminaFont.callout(), color: LuminaColors.textSecondary)
                    }
                    .disabled(fetchingLocation)
                }
            }
        }
        .padding(Space.md)
        .glass(cornerRadius: Radius.md, accent: accent, glow: false)
    }

    // MARK: Actions

    private func createTopic() {
        let name = newTopicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        newTopicTitle = ""
        guard !name.isEmpty else { return }
        let topic = Topic(title: name, subject: subject, order: subject.sortedTopics.count)
        context.insert(topic)
        try? context.save()
        selectedTopic = topic
    }

    private func save() {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty || !title.isEmpty else { return }

        let item = ContentItem(kind: .note, title: title, text: body, subject: subject)
        item.topic = selectedTopic
        item.capturedAt = capturedAt
        item.sourceDetail = sourceDetail.isEmpty ? nil : sourceDetail
        if let location {
            item.latitude = location.latitude
            item.longitude = location.longitude
            item.locationName = location.placeName
        }
        context.insert(item)
        let store = TagStore(context: context)
        selectedTags.forEach { store.attach($0, to: item) }
        subject.touch()
        try? context.save()

        // Background AI evaluation — never blocks capture.
        let ctx = context
        Task { @MainActor in
            await ItemEnrichmentService().enrich(item, in: ctx)
        }
        dismiss()
    }
}
