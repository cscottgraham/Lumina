import Foundation

/// Calls Claude's **Messages API** directly over HTTPS (Anthropic ships no
/// Swift SDK), streaming Server-Sent Events.
///
/// Wire facts (see docs/CLAUDE_INTEGRATION.md):
///   • POST https://api.anthropic.com/v1/messages
///   • headers: x-api-key, anthropic-version: 2023-06-01, content-type json
///   • body: { model, max_tokens, system[], messages[], stream:true, thinking? }
///   • the stable subject context is a system block with cache_control:ephemeral
///   • SSE events: message_start (usage.input), content_block_delta
///     (text_delta / thinking_delta), message_delta (usage.output, stop_reason)
///
/// The account key lives in the Keychain and is read per-request.
struct ClaudeClient: LLMProvider {
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let anthropicVersion = "2023-06-01"
    private let keychain: KeychainStore

    init(keychain: KeychainStore = .shared) { self.keychain = keychain }

    func stream(_ prompt: LLMPrompt, options: LLMOptions) -> AsyncThrowingStream<ClaudeStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let apiKey = keychain.apiKey() else { throw ClaudeError.missingAPIKey }

                    var request = URLRequest(url: endpoint)
                    request.httpMethod = "POST"
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
                    request.setValue("application/json", forHTTPHeaderField: "content-type")
                    request.timeoutInterval = 120
                    request.httpBody = try encodeBody(prompt, options)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw ClaudeError.network("No HTTP response")
                    }
                    guard http.statusCode == 200 else {
                        // Read the (small) error body for a useful message.
                        var body = ""
                        for try await line in bytes.lines { body += line }
                        throw ClaudeError.http(status: http.statusCode, body: body)
                    }

                    var running = ClaudeUsage()
                    for try await line in bytes.lines {
                        // SSE payload lines look like: `data: { ... }`
                        guard line.hasPrefix("data:") else { continue }
                        let json = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if json.isEmpty || json == "[DONE]" { continue }
                        guard let data = json.data(using: .utf8) else { continue }
                        if let event = try? Self.decodeEvent(data, running: &running) {
                            switch event {
                            case .usage(let u): running = u
                            default: break
                            }
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

    // MARK: Body

    private func encodeBody(_ prompt: LLMPrompt, _ options: LLMOptions) throws -> Data {
        var system: [ClaudeSystemBlock] = []
        // Stable context first, cache-controlled → cache hit on later turns.
        if !prompt.cacheableContext.isEmpty {
            system.append(ClaudeSystemBlock(
                text: prompt.cacheableContext,
                cacheControl: options.enablePromptCaching ? .init() : nil
            ))
        }
        // Volatile instructions AFTER the cache breakpoint.
        if !prompt.volatileInstructions.isEmpty {
            system.append(ClaudeSystemBlock(text: prompt.volatileInstructions, cacheControl: nil))
        }

        let body = ClaudeRequest(
            model: options.model.rawValue,
            maxTokens: options.maxTokens,
            system: system,
            messages: prompt.messages,
            stream: true,
            thinking: options.useAdaptiveThinking ? .init(type: "adaptive", display: "summarized") : nil
        )
        let encoder = JSONEncoder()
        return try encoder.encode(body)
    }

    // MARK: SSE event decoding

    /// Decode one SSE JSON object into a distilled `ClaudeStreamEvent`.
    /// Internal (not private) so LuminaTests can exercise the wire parsing.
    static func decodeEvent(_ data: Data, running: inout ClaudeUsage) throws -> ClaudeStreamEvent? {
        struct Envelope: Decodable {
            let type: String
            let delta: Delta?
            let message: MessageStart?
            let usage: ClaudeUsage?
            struct Delta: Decodable {
                let type: String?
                let text: String?
                let thinking: String?
                let stopReason: String?
                enum CodingKeys: String, CodingKey { case type, text, thinking, stopReason = "stop_reason" }
            }
            struct MessageStart: Decodable { let usage: ClaudeUsage? }
        }

        let env = try JSONDecoder().decode(Envelope.self, from: data)
        switch env.type {
        case "message_start":
            if let u = env.message?.usage { return .usage(u) }
            return nil
        case "content_block_delta":
            if env.delta?.type == "thinking_delta", let t = env.delta?.thinking { return .reasoningDelta(t) }
            if let t = env.delta?.text { return .textDelta(t) }
            return nil
        case "message_delta":
            // Carries output-token usage + stop_reason. Merge output onto running.
            if let u = env.usage {
                var merged = running
                merged.outputTokens = u.outputTokens != 0 ? u.outputTokens : merged.outputTokens
                return .usage(merged)
            }
            if let stop = env.delta?.stopReason { return .done(stopReason: stop) }
            return nil
        case "message_stop":
            return .done(stopReason: nil)
        default:
            return nil
        }
    }
}
