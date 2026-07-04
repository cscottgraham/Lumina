import Foundation
import SwiftData

/// Seed content for SwiftUI previews and first-run onboarding demos.
/// Exercises the full schema: topics, tags, provenance metadata, AI enrichment.
enum SampleData {
    @MainActor
    static func seed(into context: ModelContext) {
        let quantum = Subject(title: "Quantum Computing",
                              subjectDescription: "Notes, papers, and ideas on qubits and error correction.",
                              accent: .aurora, emoji: "⚛️")
        quantum.isPinned = true
        quantum.digest = "The user is studying quantum error correction, focusing on surface codes and the threshold theorem."

        let longevity = Subject(title: "Longevity",
                                subjectDescription: "Healthspan research, protocols, and reading.",
                                accent: .forest, emoji: "🧬")
        let design = Subject(title: "Interface Design",
                             subjectDescription: "Glassmorphism, motion, and spatial UI references.",
                             accent: .sunset, emoji: "🎨")

        context.insert(quantum); context.insert(longevity); context.insert(design)

        // Topics (subcategories of the Subject)
        let errorCorrection = Topic(title: "Error correction", emoji: "🛠", subject: quantum, order: 0)
        let hardware = Topic(title: "Hardware", emoji: "🔬", subject: quantum, order: 1)
        context.insert(errorCorrection); context.insert(hardware)

        // Tags (global autocomplete pool)
        let store = TagStore(context: context)
        let paperTag = store.findOrCreate("paper")
        let ideaTag = store.findOrCreate("idea")
        let keyTag = store.findOrCreate("key-concept")

        let n1 = ContentItem(kind: .note, title: "Surface codes",
                             text: "Surface codes tolerate ~1% physical error rates. The threshold theorem says arbitrarily long computation is possible below threshold.",
                             subject: quantum)
        n1.topic = errorCorrection
        n1.sourceDetail = "Nielsen & Chuang ch.10"
        n1.aiSummary = "Core claim: below-threshold physical error rates make fault-tolerant computation scalable. Surface codes are the leading practical code family.\n\nRelated: Google's Willow result is the first clear below-threshold demonstration."
        n1.aiEnrichedAt = Date()
        if let paperTag { store.attach(paperTag, to: n1) }
        if let keyTag { store.attach(keyTag, to: n1) }

        let n2 = ContentItem(kind: .webSnippet, title: "Google Willow",
                             text: "Google's Willow chip demonstrated below-threshold error correction at scale.",
                             subject: quantum)
        n2.topic = hardware
        n2.sourceURL = URL(string: "https://example.com/willow")
        n2.locationName = "Home office"
        if let paperTag { store.attach(paperTag, to: n2) }

        let n3 = ContentItem(kind: .voiceNote, title: "Idea while walking",
                             text: "What if we used the vault's own notes as few-shot examples for the research chat?",
                             subject: quantum)
        n3.sourceDetail = "Voice memo"
        n3.locationName = "Brockville, ON"
        if let ideaTag { store.attach(ideaTag, to: n3) }

        [n1, n2, n3].forEach(context.insert)

        try? context.save()
    }
}
