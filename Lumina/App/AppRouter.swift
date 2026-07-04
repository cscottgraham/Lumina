import SwiftUI

/// Global navigation + presentation state. `@Observable` (Observation framework,
/// iOS 17+) rather than `ObservableObject`.
@Observable
final class AppRouter {
    enum Tab: Hashable { case subjects, search, settings }

    var selectedTab: Tab = .subjects
    /// Navigation path for the Subjects tab.
    var subjectsPath: [Route] = []

    /// Currently presented modal editor, if any.
    var sheet: Sheet?

    enum Route: Hashable {
        case subject(Subject)
        case research(ChatThread)
    }

    enum Sheet: Identifiable {
        case newSubject
        case editSubject(Subject)
        case newNote(Subject)
        case settings

        var id: String {
            switch self {
            case .newSubject: return "newSubject"
            case .editSubject(let s): return "editSubject-\(s.id)"
            case .newNote(let s): return "newNote-\(s.id)"
            case .settings: return "settings"
            }
        }
    }

    func openSubject(_ subject: Subject) { subjectsPath.append(.subject(subject)) }
    func openResearch(_ thread: ChatThread) { subjectsPath.append(.research(thread)) }
}
