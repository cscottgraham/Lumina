import Foundation

/// What a research question is actually asking for — decided ON-DEVICE with
/// cheap heuristics, so no tokens are ever spent planning. The plan steers
/// retrieval (which items), depth (summary vs full text), and adds a steering
/// instruction for Claude.
struct ResearchPlan {
    enum Intent: Equatable {
        case general                      // ordinary grounded Q&A
        case summarizeKind(ContentKind)   // "summarize all photos…"
        case subjectOverview              // "give me an overview / digest"
        case compare                      // "compare X and Y"
        case deepRead                     // "quote / full text / details of X"
    }

    var intent: Intent = .general
    /// Restrict retrieval to one kind (e.g. photos only).
    var kindFilter: ContentKind?
    /// Items that must be sent at FULL depth (their whole text, budget-capped).
    var focus: [ContentItem] = []
    /// Extra steering appended to the volatile (uncached) instructions.
    var instruction: String = ""
    /// How many items to include (overview sweeps wider than Q&A).
    var maxItems: Int = 12

    static let general = ResearchPlan()
}

enum QueryPlanner {

    /// Build a plan for `question` against `subject`'s items.
    static func plan(question: String, subject: Subject) -> ResearchPlan {
        let q = question.lowercased()
        var plan = ResearchPlan()

        // ── "Summarize all photos / recordings / notes / snippets…" ──────
        let kindWords: [(ContentKind, [String])] = [
            (.photo,      ["photo", "photos", "picture", "pictures", "image", "images"]),
            (.video,      ["video", "videos", "clip", "clips"]),
            (.audio,      ["audio", "recording", "recordings", "voice memo", "voice note"]),
            (.note,       ["notes", "my notes"]),
            (.webSnippet, ["snippet", "snippets", "article", "articles", "link", "links", "web clip"]),
            (.document,   ["document", "documents", "pdf", "pdfs"]),
        ]
        if let (kind, _) = kindWords.first(where: { _, words in words.contains(where: q.contains) }) {
            plan.kindFilter = kind
            if q.contains("summar") || q.contains("all ") || q.contains("overview") || q.contains("list") {
                plan.intent = .summarizeKind(kind)
                plan.maxItems = 30   // sweep the whole kind, summaries only
                plan.instruction = """
                The user is asking about the subject's \(kind.title.lowercased())s as a set. \
                Every \(kind.title.lowercased()) currently in the vault is listed in context \
                (summaries/descriptions). Synthesize across ALL of them; note any that lack \
                descriptions so the user knows what's uncovered.
                """
            }
        }

        // ── "Compare X and Y" ─────────────────────────────────────────────
        if q.contains("compare") || q.contains(" versus ") || q.contains(" vs ") || q.contains("difference between") {
            let named = itemsNamed(in: q, subject: subject)
            if named.count >= 2 {
                plan.intent = .compare
                plan.focus = Array(named.prefix(3))
                plan.instruction = """
                The user wants a comparison. The items being compared are included at FULL \
                depth. Compare them directly: agreements, contradictions, and what each \
                adds that the other lacks. Cite each by title.
                """
            }
        }

        // ── Subject overview ──────────────────────────────────────────────
        if plan.intent == .general,
           q.contains("overview") || q.contains("summarize this subject") || q.contains("summarise this subject")
            || q.contains("what do i have") || q.contains("state of my research") || q.contains("digest") {
            plan.intent = .subjectOverview
            plan.maxItems = 25
            plan.instruction = """
            Produce a structured overview of this subject: key themes, strongest \
            findings, open questions, and gaps worth capturing next. Ground every \
            point in the listed items (cite titles).
            """
        }

        // ── Deep read: "quote / verbatim / full text / exactly what…" ────
        if plan.intent == .general,
           q.contains("quote") || q.contains("verbatim") || q.contains("full text")
            || q.contains("exact") || q.contains("word for word") || q.contains("in detail") {
            let named = itemsNamed(in: q, subject: subject)
            if let best = named.first {
                plan.intent = .deepRead
                plan.focus = [best]
                plan.instruction = "The item in question is included at FULL depth — quote it precisely."
            }
        }

        return plan
    }

    /// Items whose titles are (fuzzily) mentioned in the question, best first.
    static func itemsNamed(in question: String, subject: Subject) -> [ContentItem] {
        let q = Set(tokenize(question))
        return subject.sortedItems
            .map { item -> (ContentItem, Double) in
                let titleTokens = Set(tokenize(item.resolvedTitle))
                guard !titleTokens.isEmpty else { return (item, 0) }
                let overlap = Double(q.intersection(titleTokens).count) / Double(titleTokens.count)
                return (item, overlap)
            }
            .filter { $0.1 >= 0.5 }          // at least half the title mentioned
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    static func tokenize(_ s: String) -> [String] {
        s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }
    }
}
