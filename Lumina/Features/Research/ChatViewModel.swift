import Foundation
import SwiftData
import Observation

/// Drives one research conversation: builds context, streams Claude's reply,
/// persists messages + usage, and exposes streaming state to the view.
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
    /// The vault items grounding the latest question — drives the context
    /// chips in the chat UI ("Claude is reading these").
    var lastContextItems: [ContentItem] = []

    private var streamTask: Task<Void, Never>?

    init(thread: ChatThread, context: ModelContext, provider: LLMProvider = ClaudeClient()) {
        self.thread = thread
        self.context = context
        self.provider = provider
    }

    var canSend: Bool { !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming }

    func send(options: LLMOptions) {
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isStreaming else { return }
        input = ""
        errorText = nil

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

        let history = thread.sortedMessages.filter { $0.id != assistant.id && $0.id != userMsg.id }
        let prompt = contextBuilder.buildPrompt(subject: subject, history: history, userQuestion: question)
        lastContextItems = contextBuilder.relevantItems(in: subject, for: question)

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

    // MARK: Completion

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
