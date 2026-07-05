import SwiftUI
import SwiftData

/// Create or edit a Subject. Presented as a glass sheet.
@MainActor
struct SubjectEditorView: View {
    var subject: Subject?          // nil → create
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var desc = ""
    @State private var emoji = "✨"
    @State private var accent: AccentTheme = .aurora

    private var isEditing: Bool { subject != nil }

    var body: some View {
        GlassSheet(title: isEditing ? "Edit Subject" : "New Subject", accent: accent, onClose: { dismiss() }) {
            VStack(alignment: .leading, spacing: Space.lg) {
                field("Emoji") {
                    TextField("✨", text: $emoji).textFieldStyle(.plain).luminaText(LuminaFont.title())
                }
                field("Title") {
                    TextField("e.g. Quantum Computing", text: $title).textFieldStyle(.plain).luminaText(LuminaFont.body())
                }
                field("Description") {
                    TextField("What is this research about?", text: $desc, axis: .vertical)
                        .textFieldStyle(.plain).luminaText(LuminaFont.body()).lineLimit(2...5)
                }

                Text("Accent").luminaText(LuminaFont.subheadline(), color: LuminaColors.textSecondary)
                accentPicker

                GlassButton(isEditing ? "Save" : "Create", systemImage: "checkmark", accent: accent, weight: .primary, action: save)
                    .padding(.top, Space.sm)
            }
        }
        .onAppear(perform: load)
    }

    private var accentPicker: some View {
        HStack(spacing: Space.sm) {
            ForEach(AccentTheme.allCases) { theme in
                Circle()
                    .fill(LuminaGradients.linear(theme))
                    .frame(width: 38, height: 38)
                    .overlay(Circle().strokeBorder(.white, lineWidth: accent == theme ? 2.5 : 0))
                    .onTapGesture { withAnimation(Motion.tap) { accent = theme } }
            }
        }
    }

    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(label).luminaText(LuminaFont.subheadline(), color: LuminaColors.textSecondary)
            content()
                .padding(Space.md)
                .glass(cornerRadius: Radius.md, accent: accent)
        }
    }

    private func load() {
        guard let s = subject else { return }
        title = s.title; desc = s.subjectDescription; emoji = s.emoji; accent = s.accent
    }

    private func save() {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if let s = subject {
            s.title = clean; s.subjectDescription = desc; s.emoji = emoji.isEmpty ? "✨" : emoji
            s.accent = accent; s.touch()
        } else {
            let s = Subject(title: clean, subjectDescription: desc, accent: accent, emoji: emoji.isEmpty ? "✨" : emoji)
            context.insert(s)
        }
        try? context.save()
        dismiss()
    }
}
