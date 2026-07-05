import SwiftUI
import SwiftData

/// Voice-memo capture: big record button, live gradient waveform, elapsed
/// time. On save the recording is imported (file-based), then transcribed in
/// the background so the memo becomes searchable and chat-visible.
@MainActor
struct AudioRecorderView: View {
    let subject: Subject
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var recorder = AudioRecorderService()
    @State private var title = ""
    @State private var isSaving = false

    private var accent: AccentTheme { subject.accent }

    var body: some View {
        GlassSheet(title: "Voice Memo", accent: accent, onClose: { cancel() }) {
            VStack(spacing: Space.lg) {
                TextField("Title (optional)", text: $title)
                    .textFieldStyle(.plain).luminaText(LuminaFont.title2())
                    .padding(Space.md).glass(cornerRadius: Radius.md, accent: accent)

                GlassCard(accent: accent, vibrant: recorder.isRecording) {
                    VStack(spacing: Space.md) {
                        LiveWaveformView(levels: recorder.levels, accent: accent)
                        Text(timeString)
                            .luminaText(LuminaFont.mono(), color: LuminaColors.textSecondary)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                }

                if let err = recorder.errorText {
                    Text(err).luminaText(LuminaFont.caption(), color: LuminaColors.danger)
                }

                // Record / stop
                Button {
                    Task {
                        if recorder.isRecording { _ = recorder.stop() }
                        else { await recorder.start() }
                    }
                } label: {
                    ZStack {
                        Circle().fill(.regularMaterial)
                            .overlay(Circle().strokeBorder(LuminaColors.glassStroke, lineWidth: 1))
                            .frame(width: 84, height: 84)
                        if recorder.isRecording {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(LuminaColors.danger)
                                .frame(width: 30, height: 30)
                        } else {
                            Circle()
                                .fill(LuminaGradients.linear(accent))
                                .frame(width: 62, height: 62)
                                .shadow(color: LuminaGradients.accentColor(accent).opacity(0.5), radius: 12)
                        }
                    }
                }
                .buttonStyle(.plain)
                .animation(Motion.tap, value: recorder.isRecording)

                if recorder.fileURL != nil && !recorder.isRecording {
                    GlassButton(isSaving ? "Saving…" : "Save voice memo",
                                systemImage: "checkmark", accent: accent, weight: .primary) {
                        save()
                    }
                    .disabled(isSaving)
                }
            }
            .padding(.top, Space.md)
        }
        .interactiveDismissDisabled(recorder.isRecording || isSaving)
    }

    private var timeString: String {
        let s = Int(recorder.duration)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func cancel() {
        recorder.discard()
        dismiss()
    }

    private func save() {
        guard let url = recorder.stop() else { return }
        isSaving = true
        let ctx = context
        let memoTitle = title
        let target = subject
        Task { @MainActor in
            let importer = MediaImportService(context: ctx)
            let item = await importer.importAudio(from: url, into: target,
                                                  title: memoTitle, method: .captured)
            dismiss()
            // Transcribe in the background; the transcript feeds search, chat
            // context, and (via finalize's enrichment hook) the AI note.
            if let item {
                let transcript = await DictationService.transcribeFile(
                    at: MediaStore.shared.absoluteURL(for: item.primaryAttachment?.relativePath ?? ""))
                if !transcript.isEmpty {
                    item.text = transcript
                    try? ctx.save()
                    await ItemEnrichmentService().enrich(item, in: ctx)
                }
            }
        }
    }
}
