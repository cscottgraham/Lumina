import SwiftUI

/// Global navigation + presentation state. `@Observable` (Observation framework,
/// iOS 17+) rather than `ObservableObject`.
@Observable
final class AppRouter {
    enum Tab: Hashable { case library, subjects, search, settings }

    var selectedTab: Tab = .library
    /// Navigation path shared by the Library and Subjects stacks.
    var subjectsPath: [Route] = []

    /// Currently presented modal, if any.
    var sheet: Sheet?

    enum Route: Hashable {
        case subject(Subject)
        case research(ChatThread)
    }

    enum Sheet: Identifiable {
        case capture(Subject?)          // quick-capture; nil → pick a subject
        case newSubject
        case editSubject(Subject)
        case newNote(Subject)
        case settings

        var id: String {
            switch self {
            case .capture(let s): return "capture-\(s?.id.uuidString ?? "any")"
            case .newSubject: return "newSubject"
            case .editSubject(let s): return "editSubject-\(s.id)"
            case .newNote(let s): return "newNote-\(s.id)"
            case .settings: return "settings"
            }
        }
    }

    func openSubject(_ subject: Subject) {
        // Subject browsing lives on the Subjects tab — jump there from anywhere
        // (e.g. tapping a Library card) so back-navigation stays coherent.
        selectedTab = .subjects
        subjectsPath = [.subject(subject)]
    }

    func pushSubject(_ subject: Subject) { subjectsPath.append(.subject(subject)) }
    func openResearch(_ thread: ChatThread) { subjectsPath.append(.research(thread)) }
}
