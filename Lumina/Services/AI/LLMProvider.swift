import Foundation

/// A prompt assembled by `ContextBuilder`: a cache-friendly system context plus
/// the running message history.
struct LLMPrompt: Sendable {
    /// Stable, cacheable context (subject digest + retrieved excerpts).
    var cacheableContext: String
    /// Small, per-request instructions that change often (kept AFTER the cache
    /// breakpoint so they don't invalidate the cache).
    var volatileInstructions: String
    /// Prior turns + the new user message.
    var messages: [ClaudeRequestMessage]
}

struct LLMOptions: Sendable {
    var model: ClaudeModel = .opus48
    var maxTokens: Int = 4096
    var useAdaptiveThinking: Bool = false
    var enablePromptCaching: Bool = true
}

/// Provider abstraction so other backends (local models, OpenAI, …) can slot in
/// later. Lumina ships with `ClaudeClient`.
protocol LLMProvider: Sendable {
    /// Streams distilled events for a prompt. Throws `ClaudeError` on failure.
    func stream(_ prompt: LLMPrompt, options: LLMOptions) -> AsyncThrowingStream<ClaudeStreamEvent, Error>
}

extension LLMProvider {
    /// Drains the stream into a final (text, usage) pair — for non-UI callers
    /// like `ItemEnrichmentService` that don't render token-by-token.
    func complete(_ prompt: LLMPrompt, options: LLMOptions) async throws -> (text: String, usage: ClaudeUsage) {
        var text = ""
        var usage = ClaudeUsage()
        for try await event in stream(prompt, options: options) {
            switch event {
            case .textDelta(let t): text += t
            case .usage(let u): usage = u
            case .reasoningDelta, .done: break
            }
        }
        return (text, usage)
    }
}
