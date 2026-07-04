import Foundation
import SwiftData

/// Evaluates a newly captured item with Claude and writes value back onto it:
///   • `aiSummary` — a short "what this is + why it matters" note, plus any
///     relevant related context the researcher would want alongside the item.
///   • suggested tags — attached via `TagStore` (so they also join the global
///     autocomplete pool).
///
/// Cost posture: one-shot Haiku call, `max_tokens` 512, no caching — a fraction
/// of a cent per item. Best-effort: failures never block or corrupt capture.
/// Users control it with the "Auto-enhance new items" toggle in Settings.
@MainActor
struct ItemEnrichmentService {
    static let enabledDefaultsKey = "enrichNewItems"

    var provider: LLMProvider = ClaudeClient()
    var model: ClaudeModel = .haiku45

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledDefaultsKey) == nil
            ? true // default ON
            : UserDefaults.standard.bool(forKey: enabledDefaultsKey)
    }

    /// Enrich one item in place. Safe to fire-and-forget from capture flows.
    func enrich(_ item: ContentItem, in context: ModelContext) async {
        guard Self.isEnabled, KeychainStore.shared.hasAPIKey else { return }
        let body = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        guard item.aiEnrichedAt == nil else { return } // don't re-enrich

        // Items can belong to several subjects; enrich against the primary one.
        let subjectTitle = item.primarySubject?.title ?? "General research"
        let digest = item.primarySubject?.digest ?? ""
        let topicLine = item.topic.map { "Topic: \($0.title)\n" } ?? ""

        let question = """
        A researcher just captured a new item into their knowledge vault. \
        Evaluate it and reply with STRICT JSON ONLY (no prose, no code fence):
        {"summary": "<≤60 words: what this is and why it matters for the subject>",
         "tags": ["<up to 4 short lowercase tags>"],
         "related": "<≤50 words of genuinely relevant related context, connections, or a fact the researcher would value; \"\" if none>"}

        Subject: \(subjectTitle)
        \(digest.isEmpty ? "" : "Subject digest: \(digest)\n")\(topicLine)Item kind: \(item.kind.title)
        Item title: \(item.resolvedTitle)
        Item content:
        \(String(body.prefix(6_000)))
        """

        let prompt = LLMPrompt(cacheableContext: "", volatileInstructions: "",
                               messages: [.init(role: "user", content: question)])
        let options = LLMOptions(model: model, maxTokens: 512,
                                 useAdaptiveThinking: false, enablePromptCaching: false)

        do {
            let (text, _) = try await provider.complete(prompt, options: options)
            guard let json = Self.firstJSONObject(in: text) else { return }

            var summary = (json["summary"] as? String) ?? ""
            if let related = json["related"] as? String,
               !related.trimmingCharacters(in: .whitespaces).isEmpty {
                summary += summary.isEmpty ? related : "\n\nRelated: \(related)"
            }
            if !summary.isEmpty {
                item.aiSummary = summary
            }

            if let tagNames = json["tags"] as? [String] {
                let store = TagStore(context: context)
                for name in tagNames.prefix(4) {
                    if let tag = store.findOrCreate(name) { store.attach(tag, to: item) }
                }
            }

            item.aiEnrichedAt = Date()
            try? context.save()
        } catch {
            // Best-effort: log-and-move-on keeps capture instant and reliable.
            #if DEBUG
            print("Enrichment failed: \(error)")
            #endif
        }
    }

    /// Extracts the first {...} object from a possibly-chatty response.
    static func firstJSONObject(in text: String) -> [String: Any]? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"), start < end else { return nil }
        let slice = String(text[start...end])
        return (try? JSONSerialization.jsonObject(with: Data(slice.utf8))) as? [String: Any]
    }
}
