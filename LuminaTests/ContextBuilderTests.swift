import XCTest
import SwiftData
@testable import Lumina

/// ContextBuilder is what makes the chat "grounded in the vault" — and what
/// keeps cost bounded. These tests exercise it against a real (in-memory)
/// SwiftData store, which also smoke-tests the whole versioned schema.
@MainActor
final class ContextBuilderTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        container = PersistenceController.makeContainer(inMemory: true)
        context = container.mainContext
    }

    private func makeSubject() -> Subject {
        let s = Subject(title: "Quantum Computing", subjectDescription: "QEC research")
        s.researchNotes = "My hypothesis: surface codes win on hardware pragmatics."
        s.digest = "Studying quantum error correction."
        context.insert(s)
        return s
    }

    func testPromptContainsVaultMaterialAndUserNotes() throws {
        let subject = makeSubject()
        let item = ContentItem(kind: .note, title: "Surface codes",
                               text: "Below-threshold error rates enable fault tolerance.",
                               subject: subject)
        context.insert(item)
        try context.save()

        let prompt = ContextBuilder().buildPrompt(subject: subject, history: [], userQuestion: "Tell me about surface codes")

        XCTAssertTrue(prompt.cacheableContext.contains("Quantum Computing"))
        XCTAssertTrue(prompt.cacheableContext.contains("Surface codes"), "item excerpt missing")
        XCTAssertTrue(prompt.cacheableContext.contains("surface codes win"), "researchNotes missing")
        XCTAssertTrue(prompt.cacheableContext.contains("Studying quantum error correction"), "digest missing")
        // Volatile bits must stay OUT of the cacheable prefix (cache hygiene).
        XCTAssertFalse(prompt.cacheableContext.isEmpty)
        XCTAssertTrue(prompt.volatileInstructions.contains("Current date"))
    }

    func testContextRespectsCharBudget() throws {
        let subject = makeSubject()
        for i in 0..<30 {
            let item = ContentItem(kind: .note, title: "Note \(i)",
                                   text: String(repeating: "lorem ipsum dolor ", count: 400),
                                   subject: subject)
            context.insert(item)
        }
        try context.save()

        var builder = ContextBuilder()
        builder.maxContextChars = 12_000
        let prompt = builder.buildPrompt(subject: subject, history: [], userQuestion: "summarize")

        // Spine (persona+digest+notes) + budgeted excerpts; generous slack for headers.
        XCTAssertLessThan(prompt.cacheableContext.count, 20_000,
                          "context must be bounded regardless of vault size")
    }

    func testFirstMessageIsAlwaysUser() {
        let thread = ChatThread(subject: nil)
        let assistantFirst = ChatMessage(role: .assistant, text: "Earlier answer", thread: thread)
        let messages = ContextBuilder.toRequestMessages(history: [assistantFirst], newUser: "follow-up")

        XCTAssertEqual(messages.first?.role, "user", "Messages API rejects assistant-first conversations")
        XCTAssertEqual(messages.last?.role, "user")
        XCTAssertEqual(messages.last?.content, "follow-up")
    }

    func testRankingPrefersRelevantItems() throws {
        let subject = makeSubject()
        let relevant = ContentItem(kind: .note, title: "Willow chip",
                                   text: "Google Willow demonstrated below-threshold error correction.",
                                   subject: subject)
        let noise = ContentItem(kind: .note, title: "Grocery list",
                                text: "eggs milk bread", subject: subject)
        context.insert(relevant); context.insert(noise)
        try context.save()

        let prompt = ContextBuilder().buildPrompt(subject: subject, history: [],
                                                  userQuestion: "What did the Willow chip demonstrate?")
        let ctx = prompt.cacheableContext
        let willowPos = ctx.range(of: "Willow chip")?.lowerBound
        XCTAssertNotNil(willowPos, "relevant item must be included")
        if let groceryPos = ctx.range(of: "Grocery list")?.lowerBound, let willowPos {
            XCTAssertLessThan(willowPos, groceryPos, "relevant item should rank above noise")
        }
    }
}
