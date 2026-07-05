import SwiftUI
import SwiftData

/// A living style guide: every design-system component, composed the way
/// feature code should compose them. Open the #Preview to browse; it's also a
/// convenient place to eyeball changes to the glass recipe on one screen.
struct DesignSystemShowcase: View {
    @State private var tab = 0
    @State private var query = ""
    @State private var kinds: Set<ContentKind> = [.note]
    @State private var accentPick: AccentTheme? = .aurora
    @State private var showAlert = false

    @Query(sort: \ContentItem.createdAt) private var items: [ContentItem]

    var body: some View {
        ZStack(alignment: .bottom) {
            AuroraBackground(accent: .aurora).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {

                    // ── Navigation bar ────────────────────────────────
                    Text("GlassNavigationBar").luminaOverline()
                    GlassNavigationBar(title: "Quantum Computing",
                                       subtitle: "12 items · updated today",
                                       accent: .aurora,
                                       onBack: {}) {
                        GlassIconButton(systemImage: "ellipsis", accent: .aurora) {}
                    }
                    .padding(.horizontal, -Space.md) // bar manages its own insets

                    // ── Typography ────────────────────────────────────
                    Text("Typography — SF Pro").luminaOverline()
                    GlassCard {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text("Display 40 Heavy").luminaText(LuminaFont.display())
                            Text("Large Title 34 Bold").luminaText(LuminaFont.largeTitle())
                            Text("Title2 21 Semibold").luminaText(LuminaFont.title2())
                            Text("Headline 17 Semibold").luminaText(LuminaFont.headline())
                            Text("Body 16 Regular — reading text sits at comfortable contrast.")
                                .luminaText(LuminaFont.body(), color: LuminaColors.textSecondary)
                            Text("caption 12 medium · $0.0042").luminaText(LuminaFont.caption(), color: LuminaColors.textTertiary)
                            Text("overline · section header").luminaOverline()
                        }
                    }

                    // ── Buttons ───────────────────────────────────────
                    Text("Buttons").luminaOverline()
                    GlassCard {
                        VStack(spacing: Space.sm) {
                            GlassButton("Primary — Research with Claude", systemImage: "sparkles",
                                        accent: .aurora, weight: .primary) {}
                            HStack(spacing: Space.sm) {
                                GlassButton("Secondary", systemImage: "plus", accent: .aurora) {}
                                GlassButton("Ghost", accent: .aurora, weight: .ghost) {}
                                Spacer()
                                GlassIconButton(systemImage: "mic.fill", accent: .aurora, filled: true) {}
                                GlassIconButton(systemImage: "xmark", accent: .aurora) {}
                            }
                        }
                    }

                    // ── Cards ─────────────────────────────────────────
                    Text("GlassCard — neutral / vibrant").luminaOverline()
                    HStack(spacing: Space.md) {
                        GlassCard(accent: .ocean) {
                            Text("Neutral").luminaText(LuminaFont.headline())
                        }
                        GlassCard(accent: .ocean, vibrant: true) {
                            Text("Vibrant tint").luminaText(LuminaFont.headline())
                        }
                    }

                    // ── Search + filters ──────────────────────────────
                    Text("Search & filter chips").luminaOverline()
                    GlassSearchBar(text: $query, accent: .aurora)
                    GlassFilterChips(items: ContentKind.allCases,
                                     selection: $kinds,
                                     accent: .aurora,
                                     label: { $0.title },
                                     icon: { $0.systemImage })
                    GlassFilterChipsSingle(items: AccentTheme.allCases,
                                           selection: $accentPick,
                                           accent: .aurora,
                                           label: { $0.title })

                    // ── Content item cards (per-kind layouts) ─────────
                    Text("ContentItemCard").luminaOverline()
                    ForEach(items.prefix(4)) { item in
                        ContentItemCard(item: item, accent: .aurora)
                    }

                    // ── Alert ─────────────────────────────────────────
                    Text("GlassAlert").luminaOverline()
                    GlassButton("Show alert", systemImage: "exclamationmark.bubble", accent: .rose) {
                        showAlert = true
                    }

                    Color.clear.frame(height: 90)
                }
                .padding(Space.md)
            }

            // ── Tab bar ───────────────────────────────────────────────
            GlassTabBar(
                items: [
                    .init(tag: 0, systemImage: "square.stack.3d.up", label: "Subjects"),
                    .init(tag: 1, systemImage: "sparkle.magnifyingglass", label: "Search"),
                    .init(tag: 2, systemImage: "gearshape", label: "Settings"),
                ],
                selection: $tab
            )
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.xs)
        }
        .glassAlert(isPresented: $showAlert,
                    title: "Delete subject?",
                    message: "Items shared with other subjects will be kept.",
                    accent: .rose,
                    primary: .init(title: "Delete", role: .destructive))
        .preferredColorScheme(.dark)
    }
}

#Preview("Design System") {
    DesignSystemShowcase()
        .modelContainer(PersistenceController.preview())
        .environment(\.mediaStore, MediaStore.shared)
}
