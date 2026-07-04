import Foundation
import SwiftData

/// One turn in a `ChatThread`. Assistant messages may carry a summarized
/// `reasoning` blob (when adaptive thinking with `display: "summarized"` is on)
/// and the per-message token usage for the cost meter.
@Model
final class ChatMessage {
    var id: UUID = UUID()
    var roleRaw: String = ChatRole.user.rawValue
    var text: String = ""
    /// Optional summarized reasoning (assistant only).
    var reasoning: String?
    var createdAt: Date = Date()

    /// Per-message usage (assistant turns). Feeds the thread totals + meter.
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadInputTokens: Int = 0
    var cacheCreationInputTokens: Int = 0

    /// True while a streaming assistant response is still being written.
    var isStreaming: Bool = false
    /// Set if the request failed (surface inline in the UI).
    var errorMessage: String?

    var thread: ChatThread?

    init(role: ChatRole, text: String = "", thread: ChatThread? = nil) {
        self.id = UUID()
        self.roleRaw = role.rawValue
        self.text = text
        self.thread = thread
        self.createdAt = Date()
    }

    var role: ChatRole {
        get { ChatRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }
}
