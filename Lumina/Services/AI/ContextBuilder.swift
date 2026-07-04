import Foundation

/// Turns a Subject's stored content into a compact, cache-friendly prompt so the
/// chat "feels magical" — Claude references the user's *actual* material — while
/// keeping cost bounded (see docs/CLAUDE_INTEGRATION.md).
///
/// Strategy (RAG-lite, no server, no embeddings in the MVP):
///   1. A rolling `Subject.digest` (LLM-written summary) as the stable spine.
///   2. Top-K relevant item excerpts, ranked by a keyword/recency score against
///      the user's latest question — *not* raw media, just text/transcripts/
///      captions/snippet excerpts.
///   3. A hard token budget: excerpts are truncated to fit `maxContextChars`.
/// The cacheable context is byte-stable across a turn's retries so prompt
/// caching pays off; volatile per-request bits go in `volatileInstructions`.
struct ContextBuilder {
    /// Rough budget for the retrieved-context section (≈ maxContextChars/4 tokens).
    var maxContextChars: Int = 12_000
    var maxItems: Int = 12

    func buildPrompt(subject: Subject,
                     history: [ChatMessage],
                     userQuestion: String) -> LLMPrompt {

        let excerpts = rank(items: subject.sortedItems, for: userQuestion)
        let contextBody = assembleContext(subject: subject, excerpts: excerpts)

        let systemSpine = """
        You are Lumina, a research partner embedded in the user's personal \
        knowledge vault. You are helping them research the subject below. \
        Ground your answers in THEIR captured material — quote and cite items by \
        their title when relevant, and be honest when the vault doesn't cover \
        something. Be insightful, concise, and specific.

        # SUBJECT: \(subject.title)
        \(subject.subjectDescription.isEmpty ? "" : subject.subjectDescription + "\n")
        \(contextBody)
        """

        let messages = Self.toRequestMessages(history: history, newUser: userQuestion)

        return LLMPrompt(
            cacheableContext: systemSpine,
            volatileInstructions: "Current date: \(Self.today()).",
            messages: messages
        )
    }

    // MARK: Retrieval

    private func rank(items: [ContentItem], for question: String) -> [ContentItem] {
        let terms = Self.tokenize(question)
        func score(_ item: ContentItem) -> Double {
            // Rank on everything we know: title, body, topic, tags, AI summary.
            let tagText = item.sortedTags.map(\.name).joined(separator: " ")
            let topicText = item.topic?.title ?? ""
            let haystack = Self.tokenize([item.resolvedTitle, item.text, topicText,
                                          tagText, item.aiSummary].joined(separator: " "))
            let overlap = Double(terms.intersection(haystack).count)
            // Recency bonus: newer items rank slightly higher.
            let ageDays = max(0, Date().timeIntervalSince(item.updatedAt) / 86_400)
            let recency = 1.0 / (1.0 + ageDays / 30.0)
            return overlap * 2.0 + recency
        }
        return Array(items.sorted { score($0) > score($1) }.prefix(maxItems))
    }

    private func assembleContext(subject: Subject, excerpts: [ContentItem]) -> String {
        var out = ""
        if !subject.digest.isEmpty {
            out += "## Subject digest\n\(subject.digest)\n\n"
        }
        // Give the model the subject's shape (topics) before the excerpts.
        let topics = subject.sortedTopics
        if !topics.isEmpty {
            out += "## Topics in this subject\n"
            out += topics.map { "- \($0.title) (\($0.itemCount) items)" }.joined(separator: "\n")
            out += "\n\n"
        }

        out += "## Relevant items from the vault\n"
        var used = out.count
        for item in excerpts {
            var meta: [String] = []
            if let topic = item.topic { meta.append("topic: \(topic.title)") }
            let tagNames = item.sortedTags.map(\.name)
            if !tagNames.isEmpty { meta.append("tags: \(tagNames.joined(separator: ", "))") }
            if let prov = item.provenanceLine { meta.append("source: \(prov)") }
            let metaLine = meta.isEmpty ? "" : "(\(meta.joined(separator: " · ")))\n"

            let header = "\n### \(item.kind.title): \(item.resolvedTitle)\n" + metaLine
            let bodyBudget = max(0, min(1_400, maxContextChars - used - header.count))
            guard bodyBudget > 80 else { break }
            var body = String(item.text.prefix(bodyBudget))
            if !item.aiSummary.isEmpty, body.count + item.aiSummary.count + 12 < bodyBudget {
                body += "\n[AI note] \(item.aiSummary)"
            }
            let block = header + (body.isEmpty ? "(no text — \(item.kind.title))" : body) + "\n"
            out += block
            used += block.count
        }
        return out
    }

    // MARK: Messages

    static func toRequestMessages(history: [ChatMessage], newUser: String) -> [ClaudeRequestMessage] {
        var msgs: [ClaudeRequestMessage] = []
        for m in history where m.role != .system && !m.text.isEmpty {
            msgs.append(.init(role: m.role == .assistant ? "assistant" : "user", content: m.text))
        }
        msgs.append(.init(role: "user", content: newUser))
        // Messages API requires the first message to be `user`.
        if msgs.first?.role != "user" { msgs.insert(.init(role: "user", content: "(context)"), at: 0) }
        return msgs
    }

    // MARK: Helpers

    private static func tokenize(_ s: String) -> Set<String> {
        Set(s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 })
    }
    private static func today() -> String {
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: Date())
    }
}
