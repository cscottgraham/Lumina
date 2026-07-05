import Foundation

// MARK: - Usage & cost

/// Token usage returned by the Messages API (`message_start` + `message_delta`).
struct ClaudeUsage: Codable, Sendable {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheCreationInputTokens: Int = 0
    var cacheReadInputTokens: Int = 0

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }

    // Some events omit fields; decode defensively.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        inputTokens = (try? c.decode(Int.self, forKey: .inputTokens)) ?? 0
        outputTokens = (try? c.decode(Int.self, forKey: .outputTokens)) ?? 0
        cacheCreationInputTokens = (try? c.decode(Int.self, forKey: .cacheCreationInputTokens)) ?? 0
        cacheReadInputTokens = (try? c.decode(Int.self, forKey: .cacheReadInputTokens)) ?? 0
    }
    init() {}

    static func + (l: ClaudeUsage, r: ClaudeUsage) -> ClaudeUsage {
        var out = ClaudeUsage()
        out.inputTokens = l.inputTokens + r.inputTokens
        out.outputTokens = l.outputTokens + r.outputTokens
        out.cacheCreationInputTokens = l.cacheCreationInputTokens + r.cacheCreationInputTokens
        out.cacheReadInputTokens = l.cacheReadInputTokens + r.cacheReadInputTokens
        return out
    }
}

// MARK: - Request payload (raw HTTPS; no official Swift SDK)

/// One message in the request. `content` is plain text here; extend to the
/// block form for images/documents in a later phase.
struct ClaudeRequestMessage: Codable, Sendable {
    let role: String        // "user" | "assistant"
    let content: String
}

/// A cache-controllable system text block. The stable subject context goes here
/// with `cacheControl` set so repeat turns hit the prompt cache (~0.1× reads).
struct ClaudeSystemBlock: Codable, Sendable {
    let type = "text"
    let text: String
    var cacheControl: CacheControl?

    struct CacheControl: Codable, Sendable { let type = "ephemeral" }

    enum CodingKeys: String, CodingKey { case type, text, cacheControl = "cache_control" }
}

struct ClaudeThinking: Codable, Sendable {
    let type: String        // "adaptive"
    var display: String?    // "summarized"
}

struct ClaudeRequest: Codable, Sendable {
    let model: String
    let maxTokens: Int
    let system: [ClaudeSystemBlock]
    let messages: [ClaudeRequestMessage]
    let stream: Bool
    var thinking: ClaudeThinking?

    enum CodingKeys: String, CodingKey {
        case model, system, messages, stream, thinking
        case maxTokens = "max_tokens"
    }
}

// MARK: - Streaming events (SSE)

/// The distilled events our UI cares about, produced from the raw SSE stream.
enum ClaudeStreamEvent: Sendable {
    case reasoningDelta(String)   // summarized thinking text
    case textDelta(String)        // assistant answer text
    case usage(ClaudeUsage)       // running usage (merged from message_start/_delta)
    case done(stopReason: String?)
}

/// Shared error type for all LLM providers (Claude, Grok, …).
enum ClaudeError: LocalizedError {
    case missingAPIKey(provider: String)
    case http(status: Int, body: String)
    case decoding(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "No \(provider) API key set. Add one in Settings → AI Provider."
        case .http(let status, let body):
            return "API error \(status): \(body.prefix(300))"
        case .decoding(let m): return "Couldn't read the model's response: \(m)"
        case .network(let m): return "Network error: \(m)"
        }
    }
}
