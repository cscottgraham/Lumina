# Lumina Design System — Glassmorphism

Dark-mode-first. Everything lives in `Lumina/DesignSystem/`.

## The glass recipe

Real-feeling glass is five layers, composed by the `.glass(...)` modifier
(`Glass/GlassModifiers.swift`):

1. **Frost** — `.ultraThinMaterial` blur.
2. **Tint fill** — `white @ 6–10%` so content stays readable on near-black.
3. **Accent glow** — a radial accent gradient bleeding from one corner,
   `plusLighter` blended.
4. **Specular stroke** — a 1pt top-edge gradient stroke (bright → clear). This
   is the tell of glass; skip it and surfaces read as flat panels.
5. **Depth shadows** — one tight contact shadow + one soft ambient shadow.

```swift
VStack { … }.glass(cornerRadius: Radius.lg, accent: subject.accent)
```

## Backdrops

- **`AuroraBackground`** — blurred accent-tinted blobs drifting over the canvas
  (`transparentCanvas: true` lets it layer over imagery). Runs on iOS 17
  (no `MeshGradient`); pass `animated: false` in scroll-heavy screens.
- **`SubjectBackdrop`** — *the background reflects the subject*: the subject's
  own most recent photo/video, blurred (48pt), saturated, dimmed under a scrim,
  with the accent aurora layered on top. Subjects without imagery fall back to
  the pure aurora. Used by `SubjectDetailView` and `ResearchChatView`, so
  opening a different subject visibly shifts the whole mood while the glass
  language stays identical. (Future: generated subject artwork slots into the
  same layering.)

## Tokens

| Token set | File | Notes |
| --- | --- | --- |
| Colors | `Theme/LuminaColors.swift` | canvas, text tiers, glass fills/strokes, semantic |
| Gradients | `Theme/LuminaGradients.swift` | 6 accent themes (`AccentTheme`) → stops, linear, glow, specular |
| Type | `Theme/LuminaTypography.swift` | rounded system scale + `.luminaText(...)` |
| Spacing/Radius | `Theme/LuminaSpacing.swift` | `Space.*`, `Radius.*` |
| Motion | `Theme/LuminaMotion.swift` | `Motion.spring/tap/drift/content` |

Accents are **per-subject** (`Subject.accent`) — the subject's gradient tints
its cards, buttons, aurora, and backdrop.

## Components

| Component | File | Use |
| --- | --- | --- |
| `GlassCard` | `Glass/GlassCard.swift` | padded glass container (lists, tiles, sections) |
| `GlassButton` / `GlassIconButton` | `Glass/GlassButton.swift` | primary (gradient pill), secondary (glass pill), ghost |
| `GlassSheet` | `Glass/GlassSheet.swift` | modal editor chrome (grabber + title + aurora) |
| `AuroraBackground` / `SubjectBackdrop` | `Glass/` | backdrops (above) |
| `TagChip` | `Components/TagChip.swift` | tag/kind/topic pills, filled or outline |
| `TagPickerView` | `Components/TagPickerView.swift` | tag entry with autocomplete from all existing tags; creates via `TagStore` |
| `WrappingHStack` | in `TagPickerView.swift` | `Layout` that wraps chips onto new lines |
| `MediaThumbnail` | `Components/MediaThumbnail.swift` | square media/kind tile |
| `EmptyStateView` | `Components/EmptyStateView.swift` | friendly empty states |
| Glass tab bar | `App/RootView.swift` | floating pill tab bar |

## Rules of thumb

- Glass never sits on glass more than two layers deep — legibility dies.
- Text on glass: primary `white`, secondary `68%`, tertiary `42%`. Never pure
  gray-on-gray.
- One accent per screen (the subject's); semantic colors only for status.
- Motion: springs for interaction (`Motion.tap`), long ease for ambience
  (`Motion.drift`). Nothing animates without a reason.
- Filled (gradient) elements are reserved for the single primary action.
