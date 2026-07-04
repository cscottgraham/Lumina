import SwiftUI
import SwiftData

/// Tag entry with autocomplete from every previously created tag.
///  • Selected tags render as filled chips (tap to remove).
///  • Typing filters the existing-tag pool; tapping a suggestion attaches it.
///  • Submitting text that matches nothing creates a new tag (via TagStore,
///    which enforces case-insensitive uniqueness).
struct TagPickerView: View {
    @Binding var selected: [Tag]
    var accent: AccentTheme = .aurora

    @Environment(\.modelContext) private var context
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @State private var input = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            // Selected tags
            if !selected.isEmpty {
                WrappingHStack(spacing: Space.xs) {
                    ForEach(selected) { tag in
                        Button { remove(tag) } label: {
                            HStack(spacing: 4) {
                                TagChip(text: tag.name, accent: accent, filled: true)
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(LuminaColors.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Input field
            HStack {
                Image(systemName: "tag").foregroundStyle(LuminaColors.textTertiary)
                TextField("Add tags…", text: $input)
                    .textFieldStyle(.plain)
                    .luminaText(LuminaFont.body())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit(commitInput)
            }
            .padding(Space.sm)
            .glass(cornerRadius: Radius.md, accent: accent, glow: false)

            // Autocomplete suggestions from previously created tags
            if !suggestions.isEmpty || canCreate {
                WrappingHStack(spacing: Space.xs) {
                    ForEach(suggestions) { tag in
                        Button { attach(tag) } label: {
                            TagChip(text: tag.name, accent: accent)
                        }
                        .buttonStyle(.plain)
                    }
                    if canCreate {
                        Button(action: commitInput) {
                            TagChip(text: "＋ Create “\(trimmedInput)”", accent: accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .animation(Motion.content, value: input)
            }
        }
    }

    // MARK: Logic

    private var trimmedInput: String { input.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var suggestions: [Tag] {
        let selectedIDs = Set(selected.map(\.id))
        let f = trimmedInput.lowercased()
        return allTags
            .filter { !selectedIDs.contains($0.id) }
            .filter { f.isEmpty || $0.normalizedName.contains(f) }
            .prefix(8)
            .map { $0 }
    }

    private var canCreate: Bool {
        let f = trimmedInput.lowercased()
        guard !f.isEmpty else { return false }
        return !allTags.contains { $0.normalizedName == f }
    }

    private func attach(_ tag: Tag) {
        guard !selected.contains(where: { $0.id == tag.id }) else { return }
        withAnimation(Motion.tap) { selected.append(tag) }
        input = ""
    }

    private func commitInput() {
        guard let tag = TagStore(context: context).findOrCreate(trimmedInput) else { return }
        attach(tag)
    }

    private func remove(_ tag: Tag) {
        withAnimation(Motion.tap) { selected.removeAll { $0.id == tag.id } }
    }
}

/// A minimal wrapping layout (iOS 16+ `Layout`) so chips flow onto new lines.
struct WrappingHStack: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
