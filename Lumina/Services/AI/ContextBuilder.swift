import Foundation

/// Turns a Subject's stored content into a compact, cache-friendly prompt so
/// the chat is grounded in the user's *actual* material while cost stays
/// bounded (docs/CLAUDE_INTEGRATION.md).
///
/// COST-CONSCIOUS DESIGN — three levers:
///   1. RETRIEVAL: items are scored (term overlap weighted by field — title >
///      tags/topic > body/AI-summary — plus a recency bonus) and only the
///      top-K are sent. "Semantic-ish" matching comes free from the AI
///      summaries: enrichment normalizes vocabulary, so summary overlap
///      catches items that share meaning but not the user's exact words.
///   2. TIERED DEPTH: by default an item contributes its SUMMARY (Claude's
///      enrichment note, or a short head excerpt). Only the plan's focus
///      items — comparisons, deep-reads — get FULL text, budget-capped.
///      Media without transcripts contribute a structured description line
///      instead of silence.
///   3. CACHE HYGIENE: the assembled context is byte-stable per turn and goes
///      in the cache-controlled system block; volatile per-request text
///      (date, plan steering) rides in a second, uncached block.
struct ContextBuilder {
    /// Rough budget for the whole context section (≈ chars/4 tokens).
    var maxContextChars: Int = 12_000
    /// Per-item caps by tier.
    var summaryCap: Int = 420
    var fullCap: Int = 2_600
    var maxItems: Int = 12

    // MARK: Selection result (drives UI chips too)

    struct Selection {
        var items: [ContentItem] = []
        var fullDepthIDs: Set<UUID> = []
    }

    /// Which items (and at what depth) would ground an answer to `question`.
    func select(subject: Subject, question: String, plan: ResearchPlan = .general) -> Selection {
        var pool = subject.sortedItems
        if let kind = plan.kindFilter { pool = pool.filter { $0.kind == kind } }

        let limit = max(plan.maxItems, maxItems)
        var ranked = rank(items: pool, for: question)
        if ranked.count > limit { ranked = Array(ranked.prefix(limit)) }

        // Plan focus items are always included, ahead of the ranking.
        var items = plan.focus
        for item in ranked where !items.contains(where: { $0.id == item.id }) {
            items.append(item)
        }
        return Selection(items: items, fullDepthIDs: Set(plan.focus.map(\.id)))
    }

    /// The items that would ground an answer — kept for the UI context chips.
    func relevantItems(in subject: Subject, for question: String) -> [ContentItem] {
        rank(items: subject.sortedItems, for: question)
    }

    // MARK: Prompt assembly

    func buildPrompt(subject: Subject,
                     history: [ChatMessage],
                     userQuestion: String,
                     plan: ResearchPlan = .general) -> LLMPrompt {

        let selection = select(subject: subject, question: userQuestion, plan: plan)
        let contextBody = assembleContext(subject: subject, selection: selection)

        let systemSpine = """
        You are Lumina, a research partner embedded in the user's personal \
        knowledge vault. You are helping them research the subject below. \
        Ground your answers in THEIR captured material — quote and cite items by \
        their title when relevant, and be honest when the vault doesn't cover \
        something. Be insightful, concise, and specific.

        # SUBJECT: \(subject.title)
        \(subject.subjectDescription.isEmpty ? "" : subject.subjectDescription + "\n")
        \(subject.researchNotes.isEmpty ? "" : "## The user's own research notes\n\(String(subject.researchNotes.prefix(2_000)))\n")
        \(contextBody)
        """

        var volatile = "Current date: \(Self.today())."
        if !plan.instruction.isEmpty { volatile += "\n" + plan.instruction }

        return LLMPrompt(
            cacheableContext: systemSpine,
            volatileInstructions: volatile,
            messages: Self.toRequestMessages(history: history, newUser: userQuestion)
        )
    }

    // MARK: Retrieval scoring

    private func rank(items: [ContentItem], for question: String) -> [ContentItem] {
        let terms = Set(QueryPlanner.tokenize(question))
        guard !items.isEmpty else { return [] }

        func score(_ item: ContentItem) -> Double {
            // Field-weighted term overlap: title mentions matter most, then
            // tags/topic, then body + AI summary (the "semantic-ish" layer —
            // enrichment normalizes wording, so meaning matches surface here).
            let title = Set(QueryPlanner.tokenize(item.resolvedTitle))
            let organizational = Set(QueryPlanner.tokenize(
                (item.topic?.title ?? "") + " " + item.sortedTags.map(\.name).joined(separator: " ")))
            let body = Set(QueryPlanner.tokenize(item.text))
            let summary = Set(QueryPlanner.tokenize(item.aiSummary))

            var s = 0.0
            s += 3.0 * Double(terms.intersection(title).count)
            s += 2.0 * Double(terms.intersection(organizational).count)
            s += 1.0 * Double(terms.intersection(body).count)
            s += 1.5 * Double(terms.intersection(summary).count)

            // Recency bonus (half-life ~1 month) keeps fresh material surfaced
            // even for vague questions.
            let ageDays = max(0, Date().timeIntervalSince(item.updatedAt) / 86_400)
            s += 1.0 / (1.0 + ageDays / 30.0)
            return s
        }
        return Array(items.sorted { score($0) > score($1) }.prefix(maxItems * 3))
    }

    // MARK: Context text

    private func assembleContext(subject: Subject, selection: Selection) -> String {
        var out = ""
        if !subject.digest.isEmpty {
            out += "## Subject digest\n\(subject.digest)\n\n"
        }
        let topics = subject.sortedTopics
        if !topics.isEmpty {
            out += "## Topics in this subject\n"
            out += topics.map { "- \($0.title) (\($0.itemCount) items)" }.joined(separator: "\n")
            out += "\n\n"
        }

        out += "## Relevant items from the vault\n"
        out += "(Summaries by default; items marked FULL include their complete text.)\n"
        var used = out.count

        for item in selection.items {
            let full = selection.fullDepthIDs.contains(item.id)
            var meta: [String] = []
            if let topic = item.topic { meta.append("topic: \(topic.title)") }
            let tagNames = item.sortedTags.map(\.name)
            if !tagNames.isEmpty { meta.append("tags: \(tagNames.joined(separator: ", "))") }
            if let prov = item.provenanceLine { meta.append("source: \(prov)") }
            let metaLine = meta.isEmpty ? "" : "(\(meta.joined(separator: " · ")))\n"

            let header = "\n### \(item.kind.title)\(full ? " [FULL]" : ""): \(item.resolvedTitle)\n" + metaLine
            let remaining = maxContextChars - used - header.count
            guard remaining > 120 else { break }

            let body = tierBody(for: item, full: full, budget: min(full ? fullCap : summaryCap, remaining))
            let block = header + body + "\n"
            out += block
            used += block.count
        }
        return out
    }

    /// The item's contribution at its tier: full text, AI summary, head
    /// excerpt — or a structured media description when there's no text.
    private func tierBody(for item: ContentItem, full: Bool, budget: Int) -> String {
        let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)

        if full, !text.isEmpty {
            var body = String(text.prefix(budget))
            if text.count > budget { body += "\n[…truncated]" }
            return body
        }

        // Summary tier: prefer Claude's enrichment note (dense + normalized).
        if !item.aiSummary.isEmpty {
            return String(item.aiSummary.prefix(budget))
        }
        if !text.isEmpty {
            return String(text.prefix(budget))
        }

        // Media with no transcript/caption yet → structured description line.
        var desc = "[\(item.kind.title) — no description yet"
        if let a = item.primaryAttachment {
            if a.duration > 0 { desc += String(format: ", %d:%02d", Int(a.duration) / 60, Int(a.duration) % 60) }
            if a.pixelWidth > 0 { desc += ", \(a.pixelWidth)×\(a.pixelHeight)" }
        }
        desc += "]"
        return desc
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

    private static func today() -> String {
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: Date())
    }
}
