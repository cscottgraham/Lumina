import SwiftUI

/// A horizontally scrolling row of selectable glass filter chips.
/// Generic over any Hashable option; supports single-select (`Binding<T?>`
/// via `GlassFilterChipsSingle`) and multi-select (`Binding<Set<T>>`).
///
/// Usage (multi):
/// ```swift
/// GlassFilterChips(items: ContentKind.allCases, selection: $kinds,
///                  accent: accent, label: \.title, icon: \.systemImage)
/// ```
struct GlassFilterChips<T: Hashable>: View {
    var items: [T]
    @Binding var selection: Set<T>
    var accent: AccentTheme = .aurora
    var label: (T) -> String
    var icon: ((T) -> String)? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.xs) {
                ForEach(items, id: \.self) { item in
                    chip(item, selected: selection.contains(item)) {
                        withAnimation(Motion.tap) {
                            if selection.contains(item) { selection.remove(item) }
                            else { selection.insert(item) }
                        }
                    }
                }
            }
            .padding(.vertical, 2) // room for shadows
        }
    }

    @ViewBuilder
    private func chip(_ item: T, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Space.xxs) {
                if let icon {
                    Image(systemName: icon(item)).font(.system(size: 11, weight: .semibold))
                }
                Text(label(item)).font(LuminaFont.caption())
                if selected {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                }
            }
            .padding(.horizontal, Space.sm)
            .padding(.vertical, 7)
            .foregroundStyle(selected ? Color.black.opacity(0.85) : LuminaColors.textSecondary)
            .background {
                if selected {
                    Capsule().fill(LuminaGradients.linear(accent))
                        .shadow(color: LuminaGradients.accentColor(accent).opacity(0.4), radius: 8, y: 3)
                } else {
                    Capsule().fill(.regularMaterial)
                        .overlay(Capsule().strokeBorder(LuminaColors.glassStrokeSoft, lineWidth: 1))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// Single-select variant — one chip active at a time; tapping it again clears.
struct GlassFilterChipsSingle<T: Hashable>: View {
    var items: [T]
    @Binding var selection: T?
    var accent: AccentTheme = .aurora
    var label: (T) -> String
    var icon: ((T) -> String)? = nil
    /// Optional leading "All" chip that maps to nil selection.
    var allLabel: String? = "All"

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.xs) {
                if let allLabel {
                    TagChipButton(text: allLabel, accent: accent, filled: selection == nil) {
                        withAnimation(Motion.tap) { selection = nil }
                    }
                }
                ForEach(items, id: \.self) { item in
                    TagChipButton(text: label(item),
                                  systemImage: icon?(item),
                                  accent: accent,
                                  filled: selection == item) {
                        withAnimation(Motion.tap) {
                            selection = (selection == item) ? nil : item
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

/// A tappable TagChip — shared by pickers and filter rows.
struct TagChipButton: View {
    var text: String
    var systemImage: String? = nil
    var accent: AccentTheme = .aurora
    var filled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            TagChip(text: text, systemImage: systemImage, accent: accent, filled: filled)
        }
        .buttonStyle(.plain)
    }
}
