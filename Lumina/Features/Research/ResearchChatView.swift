import SwiftUI
import SwiftData

/// The "magical" research chat: a glass conversation grounded in the subject's
/// content, with a live streaming reply, a cost meter, and a model picker.
@MainActor
struct ResearchChatView: View {
    let thread: ChatThread
    @Environment(\.modelContext) private var context
    @State private var vm: ChatViewModel?
    @State private var useThinking = false

    private var accent: AccentTheme { thread.subject?.accent ?? .aurora }

    var body: some View {
        ZStack {
            // Backdrop reflects the subject's own imagery (glass preserved).
            SubjectBackdrop(subject: thread.subject)

            VStack(spacing: 0) {
                messages
                composer
            }
        }
        .navigationTitle(thread.subject?.title ?? "Research")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { costMeter } }
        .onAppear { if vm == nil { vm = ChatViewModel(thread: thread, context: context) } }
    }

    // MARK: Messages

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Space.md) {
                    if thread.sortedMessages.isEmpty && !(vm?.isStreaming ?? false) {
                        primer
                    }
                    ForEach(thread.sortedMessages) { msg in
                        MessageBubble(message: msg, accent: accent, liveText: liveText(for: msg),
                                      liveReasoning: liveReasoning(for: msg))
                            .id(msg.id)
                    }
                }
                .padding(Space.md)
                .padding(.bottom, Space.lg)
            }
            .onChange(of: vm?.liveText) { _, _ in
                if let last = thread.sortedMessages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }

    private func liveText(for msg: ChatMessage) -> String? {
        guard msg.isStreaming, let vm else { return nil }
        return vm.liveText
    }
    private func liveReasoning(for msg: ChatMessage) -> String? {
        guard msg.isStreaming, let vm, !vm.liveReasoning.isEmpty else { return nil }
        return vm.liveReasoning
    }

    private var primer: some View {
        GlassCard(accent: accent) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Label("Grounded in your vault", systemImage: "sparkles")
                    .luminaText(LuminaFont.headline(), color: LuminaGradients.accentColor(accent))
                Text("Ask anything about **\(thread.subject?.title ?? "this subject")**. Lumina answers using your \(thread.subject?.itemCount ?? 0) captured items — notes, transcripts, and snippets.")
                    .luminaText(LuminaFont.callout(), color: LuminaColors.textSecondary)
            }
        }
    }

    // MARK: Context chips — the items grounding the current answer

    @ViewBuilder private var contextStrip: some View {
        if let vm, !vm.lastContextItems.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.xxs) {
                    Label("Reading", systemImage: "sparkles")
                        .luminaText(LuminaFont.caption2(), color: LuminaGradients.accentColor(accent))
                    ForEach(vm.lastContextItems.prefix(6)) { item in
                        TagChip(text: String(item.resolvedTitle.prefix(24)),
                                systemImage: item.kind.systemImage,
                                accent: accent)
                    }
                    if vm.lastContextItems.count > 6 {
                        TagChip(text: "+\(vm.lastContextItems.count - 6)", accent: accent)
                    }
                }
                .padding(.horizontal, Space.md)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: Composer

    private var composer: some View {
        VStack(spacing: Space.xs) {
            contextStrip
            if let err = vm?.errorText {
                Text(err).luminaText(LuminaFont.caption(), color: LuminaColors.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(alignment: .bottom, spacing: Space.xs) {
                HStack {
                    TextField("Research this subject…", text: Binding(
                        get: { vm?.input ?? "" }, set: { vm?.input = $0 }), axis: .vertical)
                        .textFieldStyle(.plain)
                        .luminaText(LuminaFont.body())
                        .lineLimit(1...5)
                    Menu {
                        Picker("Model", selection: modelBinding) {
                            ForEach(ClaudeModel.allCases) { m in Text(m.displayName).tag(m) }
                        }
                        Toggle("Deep thinking", isOn: $useThinking)
                    } label: {
                        Image(systemName: "slider.horizontal.3").foregroundStyle(LuminaColors.textSecondary)
                    }
                }
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm)
                .glass(cornerRadius: Radius.lg, accent: accent)

                if vm?.isStreaming == true {
                    GlassIconButton(systemImage: "stop.fill", accent: accent, filled: true) { vm?.cancel() }
                } else {
                    GlassIconButton(systemImage: "arrow.up", accent: accent, filled: vm?.canSend ?? false) {
                        vm?.send(options: LLMOptions(model: thread.model, useAdaptiveThinking: useThinking))
                    }
                    .disabled(!(vm?.canSend ?? false))
                }
            }
        }
        .padding(Space.md)
        .background(.ultraThinMaterial.opacity(0.0))
    }

    private var modelBinding: Binding<ClaudeModel> {
        Binding(get: { thread.model }, set: { thread.model = $0; try? context.save() })
    }

    private var costMeter: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill").font(.system(size: 10))
            Text(CostEstimator.format(thread.estimatedCostUSD)).font(LuminaFont.caption())
        }
        .foregroundStyle(LuminaColors.textSecondary)
        .padding(.horizontal, Space.sm).padding(.vertical, 5)
        .background(Capsule().fill(.ultraThinMaterial))
    }
}

// MARK: - Bubble

private struct MessageBubble: View {
    let message: ChatMessage
    let accent: AccentTheme
    var liveText: String?
    var liveReasoning: String?

    private var displayText: String { liveText ?? message.text }
    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: Space.xs) {
                if let reasoning = liveReasoning ?? message.reasoning, !reasoning.isEmpty {
                    ReasoningDisclosure(text: reasoning, accent: accent)
                }
                Text(displayText.isEmpty && message.isStreaming ? "…" : displayText)
                    .luminaText(LuminaFont.body(), color: LuminaColors.textPrimary)
                    .textSelection(.enabled)
                    .padding(Space.md)
                    .background {
                        if isUser {
                            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                                .fill(LuminaGradients.linear(accent).opacity(0.9))
                        } else {
                            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                                    .strokeBorder(LuminaColors.glassStrokeSoft, lineWidth: 1))
                        }
                    }
                    .foregroundStyle(isUser ? Color.black.opacity(0.9) : LuminaColors.textPrimary)
                if let err = message.errorMessage {
                    Text(err).luminaText(LuminaFont.caption(), color: LuminaColors.danger)
                }
            }
            if !isUser { Spacer(minLength: 40) }
        }
    }
}

private struct ReasoningDisclosure: View {
    let text: String
    let accent: AccentTheme
    @State private var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { withAnimation(Motion.content) { expanded.toggle() } } label: {
                Label(expanded ? "Hide thinking" : "Show thinking",
                      systemImage: expanded ? "chevron.down" : "chevron.right")
                    .font(LuminaFont.caption())
                    .foregroundStyle(LuminaGradients.accentColor(accent))
            }
            .buttonStyle(.plain)
            if expanded {
                Text(text).luminaText(LuminaFont.caption(), color: LuminaColors.textTertiary)
            }
        }
    }
}
