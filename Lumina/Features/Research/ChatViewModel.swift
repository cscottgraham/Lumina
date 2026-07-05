import Foundation
import SwiftData
import Observation

/// Drives one research conversation: plans each question (QueryPlanner),
/// builds tiered context (ContextBuilder), streams Claude's reply, persists
/// messages + usage, and can turn any answer back into a vault note.
@MainActor
@Observable
final class ChatViewModel {
    let thread: ChatThread
    private let context: ModelContext
    private let provider: LLMProvider
    private let contextBuilder = ContextBuilder()

    var input: String = ""
    var isStreaming = false
    var liveText = ""          // assistant text as it streams
    var liveReasoning = ""     // summarized thinking as it streams
    var errorText: String?
    /// Transient confirmation ("Saved to vault ✓") shown above the composer.
    var toast: String?

    /// The vault items grounding the latest question — drives the context
    /// chips in the chat UI ("Claude is reading these").
    var lastContextItems: [ContentItem] = []
    /// IDs of items sent at FULL depth (deep-read/compare).
    var lastFullDepthIDs: Set<UUID> = []
    /// Human label for the strip, e.g. "All photos · 8 items".
    var lastPlanLabel: String?

    private var streamTask: Task<Void, Never>?

    init(thread: ChatThread, context: ModelContext,
         provider: LLMProvider = LLMProviderFactory.current()) {
        self.thread = thread
        self.context = context
        self.provider = provider
    }

    var canSend: Bool { !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming }

    /// Starter prompts for the empty state — each exercises a planner intent.
    static let suggestedPrompts: [String] = [
        "Give me an overview of this subject",
        "Summarize all photos",
        "What connections am I missing?",
        "What should I capture next?",
    ]

    // MARK: Send

    func send(_ overrideQuestion: String? = nil, options: LLMOptions) {
        let question = (overrideQuestion ?? input).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isStreaming else { return }
        input = ""
        errorText = nil
        toast = nil

        // Persist the user's turn.
        let userMsg = ChatMessage(role: .user, text: question, thread: thread)
        context.insert(userMsg)

        // Create the streaming assistant placeholder.
        let assistant = ChatMessage(role: .assistant, thread: thread)
        assistant.isStreaming = true
        context.insert(assistant)
        try? context.save()

        guard let subject = thread.subject else {
            fail(assistant, "This research thread isn't attached to a subject.")
            return
        }

        // Plan on-device (free), then build tiered context.
        let plan = QueryPlanner.plan(question: question, subject: subject)
        let selection = contextBuilder.select(subject: subject, question: question, plan: plan)
        lastContextItems = selection.items
        lastFullDepthIDs = selection.fullDepthIDs
        lastPlanLabel = Self.label(for: plan, itemCount: selection.items.count)

        let history = thread.sortedMessages.filter { $0.id != assistant.id && $0.id != userMsg.id }
        let prompt = contextBuilder.buildPrompt(subject: subject, history: history,
                                                userQuestion: question, plan: plan)

        isStreaming = true
        liveText = ""
        liveReasoning = ""

        streamTask = Task { [weak self] in
            guard let self else { return }
            var finalUsage = ClaudeUsage()
            do {
                for try await event in provider.stream(prompt, options: options) {
                    switch event {
                    case .reasoningDelta(let r): liveReasoning += r
                    case .textDelta(let t): liveText += t
                    case .usage(let u): finalUsage = u
                    case .done: break
                    }
                }
                finish(assistant, usage: finalUsage)
            } catch {
                fail(assistant, (error as? LocalizedError)?.errorDescription ?? "\(error)")
            }
        }
    }

    func cancel() {
        streamTask?.cancel()
        isStreaming = false
    }

    // MARK: Research outputs → vault

    /// Turn an assistant answer into a real note in the subject — research
    /// outputs become first-class vault content (and future chat context).
    func saveAsNote(_ message: ChatMessage) {
        guard message.role == .assistant, !message.text.isEmpty,
              let subject = thread.subject else { return }

        let firstLine = message.text
            .split(separator: "\n", maxSplits: 1)[0]
            .trimmingCharacters(in: CharacterSet(charactersIn: "# *"))
        let note = ContentItem(kind: .note,
                               title: String(firstLine.prefix(60)),
                               text: message.text,
                               subject: subject,
                               captureMethod: .imported)
        note.sourceDetail = "Research chat · \(ModelCatalog.displayName(for: thread.modelRaw))"
        context.insert(note)
        let store = TagStore(context: context)
        if let tag = store.findOrCreate("research-output") { store.attach(tag, to: note) }
        subject.touch()
        try? context.save()

        toast = "Saved to \(subject.title) ✓"
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            self?.toast = nil
        }
    }

    /// Ask Claude for a structured research brief; the reply lands as a normal
    /// assistant message the user can then save as a note.
    func generateBrief(options: LLMOptions) {
        send("""
        Create a structured research brief for this subject in markdown with these \
        sections: **Key findings** (grounded in my items, cite titles), \
        **Open questions**, **Contradictions or tensions**, and **Suggested next \
        captures**. Keep it tight enough to save as a reference note.
        """, options: options)
    }

    // MARK: Completion

    private static func label(for plan: ResearchPlan, itemCount: Int) -> String {
        switch plan.intent {
        case .general:              return "\(itemCount) items"
        case .summarizeKind(let k): return "All \(k.title.lowercased())s · \(itemCount)"
        case .subjectOverview:      return "Overview · \(itemCount) items"
        case .compare:              return "Comparing · full depth"
        case .deepRead:             return "Deep read · full depth"
        }
    }

    private func finish(_ assistant: ChatMessage, usage: ClaudeUsage) {
        assistant.text = liveText
        assistant.reasoning = liveReasoning.isEmpty ? nil : liveReasoning
        assistant.isStreaming = false
        assistant.inputTokens = usage.inputTokens
        assistant.outputTokens = usage.outputTokens
        assistant.cacheReadInputTokens = usage.cacheReadInputTokens
        assistant.cacheCreationInputTokens = usage.cacheCreationInputTokens
        thread.addUsage(usage)
        if thread.title == "New research", let first = thread.sortedMessages.first(where: { $0.role == .user }) {
            thread.title = String(first.text.prefix(48))
        }
        try? context.save()
        isStreaming = false
    }

    private func fail(_ assistant: ChatMessage, _ message: String) {
        assistant.isStreaming = false
        assistant.errorMessage = message
        assistant.text = liveText
        errorText = message
        try? context.save()
        isStreaming = false
    }
}
