# Architecture

## Overview

Lumina is a SwiftUI, SwiftData, iOS-17 app. It's **local-first with iCloud
sync**, media-heavy, and centered on an LLM research chat grounded in the user's
own content.

```
┌──────────────────────────────────────────────────────────────┐
│  SwiftUI Views (Features/*)                                    │
│   Subjects · Research chat · Capture · Search · Settings       │
│      │ @Observable view models (ChatViewModel, …)              │
│      ▼                                                          │
│  Services                                                      │
│   AI: LLMProvider ← ClaudeClient · ContextBuilder · Cost       │
│   Media: MediaStore (files) · ThumbnailService                 │
│   Security: KeychainStore                                      │
│   Persistence: PersistenceController → ModelContainer          │
│      ▼                                                          │
│  SwiftData Models (Models/*)  ──CloudKit──▶  iCloud            │
│   Subject · ContentItem · Attachment · Tag · ChatThread · …    │
│                                                                │
│  Media binaries: app container / iCloud (NOT in the DB)        │
└──────────────────────────────────────────────────────────────┘
```

## Key decisions

- **`@Observable`, not `ObservableObject`.** iOS 17 Observation framework →
  less boilerplate, precise view updates. View models are `@MainActor`.
- **Media as files, metadata in DB.** `Attachment` stores a *relative path*;
  `MediaStore` resolves it. Keeps the SwiftData/CloudKit store tiny and fast.
  Never store photo/video/audio blobs in SwiftData.
- **CloudKit-safe schema.** Every attribute has a default or is optional; every
  relationship is optional; no `@Attribute(.unique)` (CloudKit forbids it —
  uniqueness like Tag names is enforced in-app). See `PersistenceController`.
- **Provider-abstracted AI.** `LLMProvider` protocol; `ClaudeClient` is the
  Claude implementation. Swap/add providers without touching the UI.
- **Raw HTTPS for Claude.** No official Swift SDK, so `ClaudeClient` calls
  `POST /v1/messages` directly and parses SSE. See CLAUDE_INTEGRATION.md.

## Data model

| Model | Role | Notable relationships |
| --- | --- | --- |
| `Subject` | Research topic; the organizing unit + chat scope | → topics, items, threads, tags; cached `digest` |
| `Topic` | Subcategory within a Subject | → subject; ← items (`.nullify`: deleting a topic keeps its items) |
| `ContentItem` | One captured thing (note/photo/video/audio/web/doc) | → subject, topic?, attachments, tags; `text` is the LLM-facing payload |
| `Attachment` | Metadata for one on-disk media file | → item; `relativePath`, `thumbnailRelativePath` |
| `Tag` | Cross-cutting label (global autocomplete pool) | ↔ subjects, ↔ items; created only via `TagStore` (app-layer uniqueness) |
| `ChatThread` | A research conversation, scoped to a Subject | → subject, messages; running token/cost totals |
| `ChatMessage` | One turn; assistant carries usage + optional reasoning | → thread |

`ContentItem` also carries **provenance metadata** — `capturedAt`,
`sourceDetail`, optional geotag (`latitude`/`longitude`/`locationName`, one-shot
via `LocationService`) — surfaced as `provenanceLine` in the UI and included in
chat context; and **AI enrichment** — `aiSummary`/`aiEnrichedAt`, written in the
background by `ItemEnrichmentService` (Haiku evaluates each new capture: short
summary, related context, suggested tags via `TagStore`).

`ContentItem.text` is deliberately the single text surface the `ContextBuilder`
feeds to Claude — for a note it's the body, for a voice note the transcript, for
a web snippet the excerpt, for media an OCR/caption. This keeps retrieval simple
and uniform; `aiSummary`, topic, and tags ride along in ranking and context.

## Navigation

`AppRouter` (`@Observable`) owns the selected tab, the Subjects `NavigationStack`
path, and the presented sheet. `RootView` renders a custom **glass tab bar** over
the aurora and maps routes to screens. Modal editors (new subject/note/settings)
are `GlassSheet`s.

## Threading & performance

- Streaming runs in a `Task`; the view model mutates `@MainActor` state.
- Thumbnails generate off-main in `ThumbnailService`.
- The aurora is a handful of blurred shapes with one repeating phase — cheap;
  pass `animated: false` inside scroll-heavy screens.
