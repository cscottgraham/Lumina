import SwiftUI
import SwiftData

/// The glass navigation shell: aurora backdrop, four tabs in the floating
/// glass tab bar, and a gradient capture button docked above it. Tab content
/// cross-fades; pushes use the system stack.
struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        ZStack(alignment: .bottom) {
            AuroraBackground(accent: .aurora).ignoresSafeArea()

            Group {
                switch router.selectedTab {
                case .library:
                    NavigationStack { LibraryView() }
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
                    SearchView()
                case .settings:
                    SettingsView()
                }
            }
            .id(router.selectedTab)                       // fresh identity per tab…
            .transition(.opacity)                          // …so this cross-fades
            .animation(Motion.content, value: router.selectedTab)
            .safeAreaPadding(.bottom, 84)                  // clear the floating bar

            // Floating chrome: capture button docked above the tab bar.
            VStack(alignment: .trailing, spacing: Space.sm) {
                HStack {
                    Spacer()
                    GlassIconButton(systemImage: "plus", accent: .aurora, filled: true) {
                        router.sheet = .capture(nil)
                    }
                    .scaleEffect(1.15)
                    .padding(.trailing, Space.lg)
                }

                GlassTabBar(
                    items: [
                        .init(tag: .library, systemImage: "sparkles.rectangle.stack", label: "Library"),
                        .init(tag: .subjects, systemImage: "square.stack.3d.up", label: "Subjects"),
                        .init(tag: .search, systemImage: "sparkle.magnifyingglass", label: "Search"),
                        .init(tag: .settings, systemImage: "gearshape", label: "Settings"),
                    ],
                    selection: $router.selectedTab
                )
                .padding(.horizontal, Space.lg)
            }
            .padding(.bottom, Space.xs)
        }
        .sheet(item: $router.sheet) { sheet in
            switch sheet {
            case .capture(let s):     CaptureSheet(initialSubject: s)
            case .newSubject:         SubjectEditorView(subject: nil)
            case .editSubject(let s): SubjectEditorView(subject: s)
            case .newNote(let s):     NoteEditorView(subject: s)
            case .settings:           SettingsView()
            }
        }
    }
}
