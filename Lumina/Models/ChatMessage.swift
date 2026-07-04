import Foundation
import SwiftData

extension LuminaSchemaV1 {
    /// One turn in a `ChatThread`. Assistant messages may carry a summarized
    /// `reasoning` blob (adaptive thinking with `display: "summarized"`) and
    /// the per-message token usage that feeds the cost meter.
    @Model
    final class ChatMessage {
        var id: UUID = UUID()
        var roleRaw: String = ChatRole.user.rawValue
        var text: String = ""
        /// Optional summarized reasoning (assistant only).
        var reasoning: String?
        var createdAt: Date = Date()

        /// Per-message usage (assistant turns). Feeds the thread totals.
        var inputTokens: Int = 0
        var outputTokens: Int = 0
        var cacheReadInputTokens: Int = 0
        var cacheCreationInputTokens: Int = 0

        /// True while a streaming assistant response is still being written.
        var isStreaming: Bool = false
        /// Set if the request failed (surfaced inline in the UI).
        var errorMessage: String?

        var thread: ChatThread?

        init(role: ChatRole, text: String = "", thread: ChatThread? = nil) {
            self.id = UUID()
            self.roleRaw = role.rawValue
            self.text = text
            self.thread = thread
            self.createdAt = Date()
        }
    }
}

extension ChatMessage {
    var role: ChatRole {
        get { ChatRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }
}
