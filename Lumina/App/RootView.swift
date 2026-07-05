import SwiftUI
import SwiftData

/// The glass navigation shell. A custom floating glass tab bar over the aurora,
/// hosting the three primary areas.
struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        ZStack(alignment: .bottom) {
            AuroraBackground(accent: .aurora).ignoresSafeArea()

            Group {
                switch router.selectedTab {
                case .subjects:
                    NavigationStack(path: $router.subjectsPath) {
                        SubjectsListView()
                            .navigationDestination(for: AppRouter.Route.self) { route in
                                switch route {
                                case .subject(let s): SubjectDetailView(subject: s)
                                case .research(let t): ResearchChatView(thread: t)
                                }
                            }
                    }
                case .search:
                    SearchPlaceholderView()
                case .settings:
                    SettingsView()
                }
            }
            .safeAreaPadding(.bottom, 84) // clear the floating tab bar

            GlassTabBar(
                items: [
                    .init(tag: .subjects, systemImage: "square.stack.3d.up", label: "Subjects"),
                    .init(tag: .search, systemImage: "sparkle.magnifyingglass", label: "Search"),
                    .init(tag: .settings, systemImage: "gearshape", label: "Settings"),
                ],
                selection: $router.selectedTab
            )
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.xs)
        }
        .sheet(item: $router.sheet) { sheet in
            switch sheet {
            case .newSubject:       SubjectEditorView(subject: nil)
            case .editSubject(let s): SubjectEditorView(subject: s)
            case .newNote(let s):   NoteEditorView(subject: s)
            case .settings:         SettingsView()
            }
        }
    }
}

private struct SearchPlaceholderView: View {
    var body: some View {
        ZStack {
            EmptyStateView(systemImage: "sparkle.magnifyingglass",
                           title: "Search",
                           message: "Smart search across every subject, item, and transcript. Coming in Phase 4.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
