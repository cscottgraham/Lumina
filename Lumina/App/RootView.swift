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

            GlassTabBar(selected: $router.selectedTab)
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

/// The custom glass tab bar.
private struct GlassTabBar: View {
    @Binding var selected: AppRouter.Tab

    private let tabs: [(AppRouter.Tab, String, String)] = [
        (.subjects, "square.stack.3d.up", "Subjects"),
        (.search, "sparkle.magnifyingglass", "Search"),
        (.settings, "gearshape", "Settings"),
    ]

    var body: some View {
        HStack {
            ForEach(tabs, id: \.0) { tab, icon, label in
                Button {
                    withAnimation(Motion.tap) { selected = tab }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: icon).font(.system(size: 20, weight: .semibold))
                        Text(label).font(LuminaFont.caption())
                    }
                    .foregroundStyle(selected == tab ? LuminaColors.textPrimary : LuminaColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.xs)
        .glass(cornerRadius: Radius.pill, accent: .aurora, strong: true)
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
