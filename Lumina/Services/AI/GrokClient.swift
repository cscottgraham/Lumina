import Foundation

/// Calls xAI's **Grok** API (OpenAI-compatible chat/completions) over HTTPS
/// with SSE streaming, and distills the wire events into the same
/// `ClaudeStreamEvent` stream the chat UI already consumes — so switching
/// providers changes nothing upstream.
///
/// Wire shape:
///   • POST https://api.x.ai/v1/chat/completions
///   • headers: Authorization: Bearer <key>, content-type json
///   • body: { model, messages[{role,content}], stream:true,
///             stream_options:{include_usage:true}, max_tokens }
///   • SSE `data:` chunks: choices[0].delta.content → text,
///     delta.reasoning_content → reasoning (reasoning models),
///     final usage chunk when include_usage, `data: [DONE]` terminator.
///   • Prompt caching is automatic on xAI (no cache_control) —
///     usage.prompt_tokens_details.cached_tokens reports hits.
struct GrokClient: LLMProvider {
    private let endpoint = URL(string: "https://api.x.ai/v1/chat/completions")!
    private let keychain: KeychainStore

    init(keychain: KeychainStore = .shared) { self.keychain = keychain }

    func stream(_ prompt: LLMPrompt, options: LLMOptions) -> AsyncThrowingStream<ClaudeStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let apiKey = keychain.apiKey(account: .grok) else {
                        throw ClaudeError.missingAPIKey(provider: "Grok")
                    }

                    var request = URLRequest(url: endpoint)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "content-type")
                    request.timeoutInterval = 120
                    request.httpBody = try Self.encodeBody(prompt, options)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw ClaudeError.network("No HTTP response")
                    }
                    guard http.statusCode == 200 else {
                        var body = ""
                        for try await line in bytes.lines { body += line }
                        throw ClaudeError.http(status: http.statusCode, body: body)
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let json = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if json.isEmpty { continue }
                        if json == "[DONE]" {
                            continuation.yield(.done(stopReason: nil))
                            continue
                        }
                        guard let data = json.data(using: .utf8) else { continue }
                        for event in Self.decodeChunk(data) {
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Body (OpenAI-compatible)

    /// Grok has no cache_control blocks — the whole system context (stable +
    /// volatile) becomes one system message; xAI's automatic prefix caching
    /// still benefits because the stable part comes first, byte-identical
    /// across turns.
    static func encodeBody(_ prompt: LLMPrompt, _ options: LLMOptions) throws -> Data {
        struct Message: Encodable { let role: String; let content: String }
        struct StreamOptions: Encodable {
            let includeUsage: Bool
            enum CodingKeys: String, CodingKey { case includeUsage = "include_usage" }
        }
        struct Body: Encodable {
            let model: String
            let messages: [Message]
            let stream: Bool
            let streamOptions: StreamOptions
            let maxTokens: Int
            enum CodingKeys: String, CodingKey {
                case model, messages, stream
                case streamOptions = "stream_options"
                case maxTokens = "max_tokens"
            }
        }

        var messages: [Message] = []
        let system = [prompt.cacheableContext, prompt.volatileInstructions]
            .filter { !$0.isEmpty }.joined(separator: "\n\n")
        if !system.isEmpty { messages.append(Message(role: "system", content: system)) }
        messages += prompt.messages.map { Message(role: $0.role, content: $0.content) }

        return try JSONEncoder().encode(Body(
            model: options.modelID,
            messages: messages,
            stream: true,
            streamOptions: StreamOptions(includeUsage: true),
            maxTokens: options.maxTokens
        ))
    }

    // MARK: Chunk decoding

    /// Decode one SSE JSON chunk into distilled events (0, 1, or 2 of them).
    /// Internal (not private) so LuminaTests can exercise the wire parsing.
    static func decodeChunk(_ data: Data) -> [ClaudeStreamEvent] {
        struct Chunk: Decodable {
            struct Choice: Decodable {
                struct Delta: Decodable {
                    let content: String?
                    let reasoningContent: String?
                    enum CodingKeys: String, CodingKey {
                        case content
                        case reasoningContent = "reasoning_content"
                    }
                }
                let delta: Delta?
                let finishReason: String?
                enum CodingKeys: String, CodingKey {
                    case delta
                    case finishReason = "finish_reason"
                }
            }
            struct Usage: Decodable {
                struct PromptDetails: Decodable {
                    let cachedTokens: Int?
                    enum CodingKeys: String, CodingKey { case cachedTokens = "cached_tokens" }
                }
                let promptTokens: Int?
                let completionTokens: Int?
                let promptTokensDetails: PromptDetails?
                enum CodingKeys: String, CodingKey {
                    case promptTokens = "prompt_tokens"
                    case completionTokens = "completion_tokens"
                    case promptTokensDetails = "prompt_tokens_details"
                }
            }
            let choices: [Choice]?
            let usage: Usage?
        }

        guard let chunk = try? JSONDecoder().decode(Chunk.self, from: data) else { return [] }
        var events: [ClaudeStreamEvent] = []

        if let delta = chunk.choices?.first?.delta {
            if let reasoning = delta.reasoningContent, !reasoning.isEmpty {
                events.append(.reasoningDelta(reasoning))
            }
            if let text = delta.content, !text.isEmpty {
                events.append(.textDelta(text))
            }
        }
        if let usage = chunk.usage {
            var u = ClaudeUsage()
            let cached = usage.promptTokensDetails?.cachedTokens ?? 0
            // ClaudeUsage semantics: inputTokens EXCLUDES cached reads.
            u.inputTokens = max(0, (usage.promptTokens ?? 0) - cached)
            u.cacheReadInputTokens = cached
            u.outputTokens = usage.completionTokens ?? 0
            events.append(.usage(u))
        }
        if let finish = chunk.choices?.first?.finishReason, !finish.isEmpty {
            events.append(.done(stopReason: finish))
        }
        return events
    }
}
