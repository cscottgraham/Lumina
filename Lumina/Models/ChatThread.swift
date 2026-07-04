import Foundation
import SwiftData

extension LuminaSchemaV1 {
    /// A research conversation with Claude, scoped to a Subject. Persisting
    /// threads gives each Subject a durable conversation history and lets us
    /// resend prior turns to the stateless Messages API.
    @Model
    final class ChatThread {
        var id: UUID = UUID()
        var title: String = "New research"
        var modelRaw: String = ClaudeModel.opus48.rawValue
        var isArchived: Bool = false
        var createdAt: Date = Date()
        var updatedAt: Date = Date()

        /// Running totals for the cost meter (summed across messages).
        var totalInputTokens: Int = 0
        var totalOutputTokens: Int = 0
        var totalCachedReadTokens: Int = 0
        var totalCacheWriteTokens: Int = 0

        var subject: Subject?

        @Relationship(deleteRule: .cascade, inverse: \ChatMessage.thread)
        var messages: [ChatMessage]? = []

        init(subject: Subject?, model: ClaudeModel = .opus48, title: String = "New research") {
            self.id = UUID()
            self.subject = subject
            self.modelRaw = model.rawValue
            self.title = title
            self.createdAt = Date()
            self.updatedAt = Date()
        }
    }
}

extension ChatThread {
    var model: ClaudeModel {
        get { ClaudeModel(rawValue: modelRaw) ?? .opus48 }
        set { modelRaw = newValue.rawValue }
    }

    var sortedMessages: [ChatMessage] {
        (messages ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var messageCount: Int { messages?.count ?? 0 }

    /// One-line preview for thread lists — the last exchange's text.
    var preview: String {
        sortedMessages.last.map { String($0.text.prefix(90)) } ?? ""
    }

    /// Estimated USD spent on this thread so far.
    var estimatedCostUSD: Double {
        let m = model
        return (Double(totalInputTokens) / 1_000_000) * m.inputPricePerMTok
             + (Double(totalOutputTokens) / 1_000_000) * m.outputPricePerMTok
             + (Double(totalCachedReadTokens) / 1_000_000) * m.cachedInputPricePerMTok
             + (Double(totalCacheWriteTokens) / 1_000_000) * m.cacheWritePricePerMTok
    }

    func addUsage(_ usage: ClaudeUsage) {
        totalInputTokens += usage.inputTokens
        totalOutputTokens += usage.outputTokens
        totalCachedReadTokens += usage.cacheReadInputTokens
        totalCacheWriteTokens += usage.cacheCreationInputTokens
        updatedAt = Date()
    }
}
