import SwiftUI
import SwiftData

/// Quick capture: pick the target Subject, then one of five capture actions.
/// Text Note is fully wired (swaps this sheet for the note editor); Camera /
/// Photos / Voice Dictation / Web Clip are Phase-2 surfaces — present, styled,
/// and honest about it, so the muscle memory forms now.
struct CaptureSheet: View {
    /// Preselected subject (e.g. launched from a Subject screen); nil → pick.
    var initialSubject: Subject?

    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subject.updatedAt, order: .reverse) private var subjects: [Subject]

    @State private var target: Subject?
    @State private var phaseTwoNudge: String?

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
                    if let nudge = phaseTwoNudge {
                        Label(nudge, systemImage: "hammer")
                            .luminaText(LuminaFont.caption(), color: LuminaColors.textTertiary)
                            .transition(.opacity)
                    }
                }
            }
        }
        .onAppear { target = initialSubject ?? subjects.first }
        .animation(Motion.content, value: phaseTwoNudge)
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
            action("text.alignleft", "Text Note", ready: true)
            action("camera.fill", "Camera", ready: false)
            action("photo.on.rectangle.angled", "Photos", ready: false)
            action("waveform.badge.mic", "Voice Dictation", ready: false)
            action("safari.fill", "Web Clip", ready: false)
        }
    }

    @ViewBuilder
    private func action(_ icon: String, _ label: String, ready: Bool) -> some View {
        Button {
            guard let target else { return }
            if ready {
                // Swap this sheet for the note editor, keeping the subject.
                router.sheet = .newNote(target)
            } else {
                phaseTwoNudge = "\(label) lands in Phase 2 — the capture path is already plumbed (MediaStore + Attachment)."
            }
        } label: {
            VStack(spacing: Space.xs) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(ready ? AnyShapeStyle(LuminaGradients.linear(accent))
                                           : AnyShapeStyle(LuminaColors.textSecondary))
                Text(label).luminaText(LuminaFont.subheadline(),
                                       color: ready ? LuminaColors.textPrimary : LuminaColors.textSecondary)
                if !ready {
                    TagChip(text: "Phase 2", accent: accent)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.md)
            .glass(cornerRadius: Radius.md, accent: accent, vibrant: ready)
            .opacity(ready ? 1 : 0.75)
        }
        .buttonStyle(.plain)
    }
}
