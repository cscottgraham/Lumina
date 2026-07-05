import SwiftUI
import SwiftData
import UIKit

/// Web clip capture: paste a URL (one tap from the clipboard), fetch the
/// page's title/description/author + og:image, add the passage you care
/// about, and save. The og:image becomes the snippet's screenshot attachment.
/// (A share extension can feed this same path later — see ROADMAP.)
@MainActor
struct WebSnippetEditor: View {
    let subject: Subject
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var urlText = ""
    @State private var pageTitle = ""
    @State private var selectedText = ""
    @State private var author = ""
    @State private var fetching = false
    @State private var fetchedImage: Data?
    @State private var fetchNote: String?
    @State private var isSaving = false

    private var accent: AccentTheme { subject.accent }
    private var url: URL? {
        var s = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if !s.lowercased().hasPrefix("http") { s = "https://" + s }
        return URL(string: s)
    }

    var body: some View {
        GlassSheet(title: "Web Clip", accent: accent, onClose: { dismiss() }) {
            VStack(alignment: .leading, spacing: Space.lg) {
                // URL row + paste + fetch
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Page URL").luminaOverline()
                    HStack(spacing: Space.xs) {
                        TextField("https://…", text: $urlText)
                            .textFieldStyle(.plain).luminaText(LuminaFont.mono())
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(Space.md)
                            .glass(cornerRadius: Radius.md, accent: accent, glow: false)
                        GlassIconButton(systemImage: "doc.on.clipboard", accent: accent) {
                            if let pasted = UIPasteboard.general.string { urlText = pasted }
                            else if let pastedURL = UIPasteboard.general.url { urlText = pastedURL.absoluteString }
                        }
                    }
                    GlassButton(fetching ? "Fetching…" : "Fetch page info",
                                systemImage: "arrow.down.circle", accent: accent) {
                        fetchMetadata()
                    }
                    .disabled(url == nil || fetching)
                    if let fetchNote {
                        Text(fetchNote).luminaText(LuminaFont.caption(), color: LuminaColors.textTertiary)
                    }
                }

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Title").luminaOverline()
                    TextField("Page title", text: $pageTitle)
                        .textFieldStyle(.plain).luminaText(LuminaFont.headline())
                        .padding(Space.md).glass(cornerRadius: Radius.md, accent: accent, glow: false)
                }

                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Selected text / why it matters").luminaOverline()
                    TextField("Paste the passage that matters, or your own note about it…",
                              text: $selectedText, axis: .vertical)
                        .textFieldStyle(.plain).luminaText(LuminaFont.body())
                        .lineLimit(4...12)
                        .padding(Space.md).glass(cornerRadius: Radius.md, accent: accent, glow: false)
                }

                if let fetchedImage, let ui = UIImage(data: fetchedImage) {
                    HStack(spacing: Space.sm) {
                        Image(uiImage: ui).resizable().scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                        Text("Page image will be attached as the snippet's screenshot.")
                            .luminaText(LuminaFont.caption(), color: LuminaColors.textSecondary)
                    }
                }

                GlassButton(isSaving ? "Saving…" : "Save web clip",
                            systemImage: "checkmark", accent: accent, weight: .primary, action: save)
                    .disabled(url == nil || isSaving)
            }
        }
    }

    private func fetchMetadata() {
        guard let url else { return }
        fetching = true
        fetchNote = nil
        Task { @MainActor in
            let service = WebMetadataService()
            let meta = await service.fetchMetadata(for: url)
            if let t = meta.title, pageTitle.isEmpty { pageTitle = t }
            if let a = meta.author { author = a }
            if selectedText.isEmpty, let d = meta.descriptionText { selectedText = d }
            if let imageURL = meta.imageURL {
                fetchedImage = await service.fetchImage(at: imageURL)
            }
            fetchNote = meta.title == nil
                ? "Couldn't read the page — fill the fields manually."
                : "Fetched. Edit anything before saving."
            fetching = false
        }
    }

    private func save() {
        guard let url else { return }
        isSaving = true
        let item = ContentItem(kind: .webSnippet,
                               title: pageTitle,
                               text: selectedText,
                               subject: subject,
                               captureMethod: .imported)
        item.sourceURL = url
        item.sourceTitle = pageTitle.isEmpty ? nil : pageTitle
        item.author = author.isEmpty ? nil : author
        item.capturedAt = Date()
        context.insert(item)
        subject.touch()
        try? context.save()

        let ctx = context
        let image = fetchedImage
        Task { @MainActor in
            if let image {
                await MediaImportService(context: ctx).attachScreenshot(data: image, to: item)
            }
            await ItemEnrichmentService().enrich(item, in: ctx)
            dismiss()
        }
    }
}
