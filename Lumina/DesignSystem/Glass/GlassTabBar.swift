import SwiftUI

/// One entry in a `GlassTabBar`.
struct GlassTabItem<Selection: Hashable>: Identifiable {
    let tag: Selection
    let systemImage: String
    let label: String
    var id: Selection { tag }
}

/// The floating glass tab bar: a regular-material pill with an accent
/// "lens" that slides behind the selected tab (matched-geometry), spring
/// animated. Generic over any Hashable selection so features define their own
/// tab enums.
struct GlassTabBar<Selection: Hashable>: View {
    var items: [GlassTabItem<Selection>]
    @Binding var selection: Selection
    var accent: AccentTheme = .aurora

    @Namespace private var lens

    var body: some View {
        HStack {
            ForEach(items) { item in
                Button {
                    withAnimation(Motion.spring) { selection = item.tag }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 20, weight: .semibold))
                        Text(item.label).font(LuminaFont.caption())
                    }
                    .foregroundStyle(selection == item.tag
                                     ? LuminaColors.textPrimary
                                     : LuminaColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if selection == item.tag {
                            // The sliding "lens": a soft accent glass highlight.
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .fill(LuminaGradients.linear(accent).opacity(0.22))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                        .strokeBorder(LuminaColors.glassStroke, lineWidth: 1)
                                )
                                .matchedGeometryEffect(id: "lens", in: lens)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Space.xxs)
        .glass(cornerRadius: Radius.pill, accent: accent, depth: .regular, strong: true)
    }
}

#Preview("GlassTabBar") {
    struct Demo: View {
        @State private var tab = 0
        var body: some View {
            ZStack(alignment: .bottom) {
                AuroraBackground().ignoresSafeArea()
                GlassTabBar(
                    items: [
                        .init(tag: 0, systemImage: "square.stack.3d.up", label: "Subjects"),
                        .init(tag: 1, systemImage: "sparkle.magnifyingglass", label: "Search"),
                        .init(tag: 2, systemImage: "gearshape", label: "Settings"),
                    ],
                    selection: $tab
                )
                .padding(Space.xl)
            }
        }
    }
    return Demo().preferredColorScheme(.dark)
}
