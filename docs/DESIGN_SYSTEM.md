# Lumina Design System — Glassmorphism

Dark-mode-first. Everything lives in `Lumina/DesignSystem/`.
**Living style guide:** open the `DesignSystemShowcase` preview
(`Components/DesignSystemShowcase.swift`) — every component, composed the way
feature code should compose it.

## The glass recipe

Real-feeling glass is five layers, composed by the `.glass(...)` modifier
(`Glass/GlassModifiers.swift`):

1. **Frost** — a material blur, at one of two weights (`GlassDepth`):
   `.ultraThinMaterial` for content cards (the backdrop stays alive behind
   them) and `.regularMaterial` for chrome that must dominate what's under it
   (nav/tab bars, buttons, inputs, alerts).
2. **Fill** — `white @ 6–10%` for readability; or `vibrant: true` for an
   accent-gradient wash (~18%) on hero surfaces.
3. **Accent glow** — a radial accent gradient bleeding from one corner,
   `plusLighter` blended.
4. **Specular stroke** — a 1pt top-edge gradient stroke (bright → clear) plus a
   0.5pt low-opacity white hairline. This is the tell of glass; skip it and
   surfaces read as flat panels.
5. **Depth shadows** — one tight contact shadow + one soft ambient shadow.

```swift
VStack { … }.glass(cornerRadius: Radius.lg, accent: subject.accent)            // content
HStack { … }.glass(cornerRadius: Radius.pill, depth: .regular, strong: true)   // chrome
GlassCard(accent: accent, vibrant: true) { … }                                  // hero tint
```

## Backdrops

- **`AuroraBackground`** — blurred accent-tinted blobs drifting over the canvas
  (`transparentCanvas: true` lets it layer over imagery). iOS 17-safe (no
  `MeshGradient`); pass `animated: false` in scroll-heavy screens.
- **`SubjectBackdrop`** — the subject's own most recent photo/video, blurred
  48pt, saturated, dimmed under a scrim, with the accent aurora on top. Opening
  a different subject visibly shifts the whole mood while the glass language
  stays identical.

## Tokens

| Token set | File | Notes |
| --- | --- | --- |
| Colors | `Theme/LuminaColors.swift` | canvas, text tiers (100/68/42%), glass fills/strokes, semantic |
| Gradients | `Theme/LuminaGradients.swift` | 6 accents; house palette `aurora` = teal `#2DD4BF` → deep indigo `#4F46E5` → purple `#A855F7` |
| Type | `Theme/LuminaTypography.swift` | **SF Pro**, weight-driven hierarchy (heavy display → semibold labels → regular body), `.luminaText(...)`, `.luminaOverline()` micro-headers, mono for keys/costs |
| Spacing/Radius | `Theme/LuminaSpacing.swift` | primary surfaces in the **22–28pt** band (`md` 22 / `lg` 26 / `xl` 28); `sm` 14 for nested elements so inner < outer |
| Motion | `Theme/LuminaMotion.swift` | `Motion.spring/tap/drift/content` — springs for interaction, long ease for ambience |

Accents are **per-subject** (`Subject.accent`) — the subject's gradient tints
its cards, buttons, aurora, and backdrop.

## Components

| Component | File | Use |
| --- | --- | --- |
| `GlassCard` | `Glass/GlassCard.swift` | padded glass container; `vibrant:` for accent-tinted hero cards |
| `GlassButton` / `GlassIconButton` | `Glass/GlassButton.swift` | primary (gradient pill), secondary (regular-material pill), ghost |
| `GlassNavigationBar` | `Glass/GlassNavigationBar.swift` | custom glass header (back + title/subtitle + trailing actions) for screens that hide the system bar |
| `GlassTabBar` | `Glass/GlassTabBar.swift` | floating pill tab bar, generic over any Hashable selection, matched-geometry sliding accent lens |
| `GlassSheet` | `Glass/GlassSheet.swift` | modal editor chrome (grabber + title + aurora) |
| `GlassAlert` (`.glassAlert(...)`) | `Glass/GlassAlert.swift` | in-brand confirmations over a dimmed scrim; destructive role tinting |
| `AuroraBackground` / `SubjectBackdrop` | `Glass/` | backdrops (above) |
| `ContentItemCard` | `Components/ContentItemCard.swift` | **the** item card — kind-specific layouts: photo (full-bleed + caption strip), video (+play/duration), audio (waveform motif + transcript), note/document (text-first), webSnippet (domain + quoted excerpt + screenshot) |
| `GlassSearchBar` | `Components/GlassSearchBar.swift` | search field with accent focus ring, clear + animated Cancel |
| `GlassFilterChips` / `GlassFilterChipsSingle` | `Components/GlassFilterChips.swift` | multi/single-select glass chip rows, generic over options |
| `TagChip` / `TagChipButton` | `Components/TagChip.swift`, `GlassFilterChips.swift` | tag/kind/topic pills |
| `TagPickerView` | `Components/TagPickerView.swift` | tag entry with autocomplete from all existing tags |
| `WrappingHStack` | in `TagPickerView.swift` | `Layout` that wraps chips onto new lines |
| `MediaThumbnail` | `Components/MediaThumbnail.swift` | square media/kind tile (compact rows) |
| `EmptyStateView` | `Components/EmptyStateView.swift` | friendly empty states |

## Rules of thumb

- Glass never sits on glass more than two layers deep — legibility dies.
- Material weight by purpose: content `ultraThin`, chrome `regular`.
- Text on glass: primary `white`, secondary `68%`, tertiary `42%`.
- One accent per screen (the subject's); semantic colors only for status.
- Filled (gradient) elements are reserved for the single primary action.
- Radii: outer surfaces 22–28pt; nested elements always smaller than their
  container.
- Motion: springs for interaction (`Motion.tap`/`Motion.spring`), long ease for
  ambience (`Motion.drift`). Nothing animates without a reason.
