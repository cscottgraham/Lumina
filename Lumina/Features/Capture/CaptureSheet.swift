import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

/// Quick capture hub — every action is live:
///   Text Note / Dictate → note editor (dictation autostarts)
///   Camera → system camera (photo + video)
///   Photos → PhotosPicker multi-select (images + videos, file-based import)
///   Voice Memo → AudioRecorderView (waveform + auto-transcription)
///   Web Clip → WebSnippetEditor (paste URL, fetch metadata + og:image)
@MainActor
struct CaptureSheet: View {
    /// Preselected subject (e.g. launched from a Subject screen); nil → pick.
    var initialSubject: Subject?

    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subject.updatedAt, order: .reverse) private var subjects: [Subject]

    @State private var target: Subject?

    // Presentation state per capture flow.
    @State private var showCamera = false
    @State private var showPhotosPicker = false
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var showRecorder = false
    @State private var showWebClip = false

    // Import feedback.
    @State private var importing = false
    @State private var importStatus: String?
    @State private var nudge: String?

    private var accent: AccentTheme { target?.accent ?? .aurora }

    var body: some View {
        GlassSheet(title: "Capture", accent: accent, onClose: { dismiss() }) {
            VStack(alignment: .leading, spacing: Space.lg) {
                if subjects.isEmpty {
                    EmptyStateView(systemImage: "square.stack.3d.up.badge.a",
                                   title: "Create a Subject first",
                                   message: "Every capture lives inside a research subject.",
                                   actionTitle: "New Subject") { router.sheet = .newSubject }
                } else {
                    subjectPicker
                    actionsGrid

                    if importing || importStatus != nil {
                        HStack(spacing: Space.xs) {
                            if importing { ProgressView().tint(LuminaGradients.accentColor(accent)) }
                            Text(importStatus ?? "Importing…")
                                .luminaText(LuminaFont.caption(), color: LuminaColors.textSecondary)
                        }
                        .transition(.opacity)
                    }
                    if let nudge {
                        Label(nudge, systemImage: "info.circle")
                            .luminaText(LuminaFont.caption(), color: LuminaColors.textTertiary)
                            .transition(.opacity)
                    }
                }
            }
        }
        .onAppear { target = initialSubject ?? subjects.first }
        .animation(Motion.content, value: importing)
        .animation(Motion.content, value: nudge)
        .interactiveDismissDisabled(importing)
        // Capture flows
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { capture in handleCamera(capture) }
                .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $pickedItems,
                      maxSelectionCount: 8, matching: .any(of: [.images, .videos]))
        .onChange(of: pickedItems) { _, items in
            guard !items.isEmpty else { return }
            importPicked(items)
        }
        .sheet(isPresented: $showRecorder) {
            if let target { AudioRecorderView(subject: target) }
        }
        .sheet(isPresented: $showWebClip) {
            if let target { WebSnippetEditor(subject: target) }
        }
    }

    // MARK: Target subject

    private var subjectPicker: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Into subject").luminaOverline()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.xs) {
                    ForEach(subjects) { subject in
                        TagChipButton(text: "\(subject.emoji) \(subject.title)",
                                      accent: subject.accent,
                                      filled: target?.id == subject.id) {
                            withAnimation(Motion.tap) { target = subject }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: Actions

    private var actionsGrid: some View {
        let columns = [GridItem(.flexible(), spacing: Space.sm),
                       GridItem(.flexible(), spacing: Space.sm)]
        return LazyVGrid(columns: columns, spacing: Space.sm) {
            action("text.alignleft", "Text Note") {
                guard let target else { return }
                router.sheet = .newNote(target)
            }
            action("waveform.badge.mic", "Dictate Note") {
                guard let target else { return }
                router.sheet = .dictateNote(target)
            }
            action("camera.fill", "Camera") {
                if CameraPicker.isAvailable { showCamera = true }
                else { nudge = "No camera on this device (simulator?) — use Photos instead." }
            }
            action("photo.on.rectangle.angled", "Photos") { showPhotosPicker = true }
            action("mic.fill", "Voice Memo") { showRecorder = true }
            action("safari.fill", "Web Clip") { showWebClip = true }
        }
    }

    @ViewBuilder
    private func action(_ icon: String, _ label: String, perform: @escaping () -> Void) -> some View {
        Button {
            nudge = nil
            perform()
        } label: {
            VStack(spacing: Space.xs) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(LuminaGradients.linear(accent))
                Text(label).luminaText(LuminaFont.subheadline())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.md)
            .glass(cornerRadius: Radius.md, accent: accent, vibrant: true)
        }
        .buttonStyle(.plain)
        .disabled(importing)
    }

    // MARK: Camera result

    private func handleCamera(_ capture: CameraPicker.Capture) {
        guard let target else { return }
        importing = true
        importStatus = "Saving capture…"
        let ctx = context
        Task { @MainActor in
            let importer = MediaImportService(context: ctx)
            switch capture {
            case .photo(let data):
                _ = await importer.importImage(data: data, into: target, method: .captured)
            case .video(let url):
                _ = await importer.importVideo(from: url, into: target, method: .captured)
            }
            importStatus = "Saved to \(target.title) ✓"
            importing = false
            try? await Task.sleep(for: .seconds(1))
            dismiss()
        }
    }

    // MARK: Photo library import (file-based for videos — large-file safe)

    private func importPicked(_ items: [PhotosPickerItem]) {
        guard let target else { return }
        pickedItems = []
        importing = true
        let total = items.count
        let ctx = context
        Task { @MainActor in
            let importer = MediaImportService(context: ctx)
            var done = 0
            for pickerItem in items {
                importStatus = "Importing \(done + 1) of \(total)…"
                let isVideo = pickerItem.supportedContentTypes.contains { $0.conforms(to: .movie) }
                if isVideo {
                    if let movie = try? await pickerItem.loadTransferable(type: MovieFile.self) {
                        _ = await importer.importVideo(from: movie.url, into: target, method: .imported)
                        try? FileManager.default.removeItem(at: movie.url)
                        done += 1
                    }
                } else if let data = try? await pickerItem.loadTransferable(type: Data.self) {
                    _ = await importer.importImage(data: data, into: target, method: .imported)
                    done += 1
                }
            }
            importStatus = done == total
                ? "Imported \(done) item\(done == 1 ? "" : "s") ✓"
                : "Imported \(done) of \(total) (some items couldn't be read)"
            importing = false
            try? await Task.sleep(for: .seconds(1.2))
            dismiss()
        }
    }
}
