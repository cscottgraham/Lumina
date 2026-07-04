# Roadmap

Phases are cumulative; each ships something usable. ✅ = scaffolded in this repo.

## Phase 1 — Foundation (this scaffold) ✅
- Project structure, XcodeGen spec, iOS 17 target, dark-first.
- SwiftData schema: Subject, **Topic**, ContentItem, Attachment, Tag,
  ChatThread, ChatMessage — CloudKit-safe, media as files.
- Design system: glass recipe, aurora + **subject-reflective backdrops**,
  cards/buttons/sheets/chips, custom tab bar.
- Subjects: grid, create/edit, pin, accents; **topics** (create, filter,
  delete-keeps-items).
- Capture (typed notes): topic assignment, **tag picker with autocomplete**,
  **provenance metadata** (captured date/time, source note, one-tap location).
- Research chat: streaming Claude (SSE), prompt caching, context from the
  vault (digest + ranked excerpts incl. topics/tags/AI notes), model picker,
  thinking toggle, live cost meter.
- **AI item enrichment**: every new item evaluated by Claude (Haiku) → summary,
  related context, suggested tags. Settings toggle; feeds back into retrieval.
- Settings: Keychain API key, default model, enrichment toggle.

## Phase 2 — Full capture
- Photo/video via `PhotosPicker` + camera; import through `MediaStore`,
  thumbnails via `ThumbnailService` (both scaffolded).
- Audio recording (AVAudioEngine) + on-device transcription (`SFSpeechRecognizer`)
  → `ContentItem.text`, so voice notes are searchable and chat-visible.
- Voice-dictated notes (live transcription into the note editor).
- Web snippets: Share Extension → excerpt + metadata (URL, title, author, date).
- Item detail screen: full-screen viewers (photo zoom, video player, audio
  scrubber with transcript), edit metadata/tags/topic, view AI note.
- Enrichment for media: run on transcripts/captions; later vision.

## Phase 3 — Sync & resilience
- Flip media storage to the iCloud ubiquity container (SwiftData already syncs).
- Conflict-tolerant MediaStore (download-on-demand, placeholders).
- Background thumbnailing + enrichment queues; retry on failure.
- Subject digest auto-refresh (cheap Haiku call when content changes).

## Phase 4 — Intelligence
- Smart search tab: full-text across items/transcripts + filters (kind, tag,
  topic, date, location).
- On-device embeddings (NaturalLanguage) → semantic retrieval in ContextBuilder.
- Vision in chat: send item images as content blocks; visual Q&A.
- Enrichment upgrades: entity extraction, cross-item connection suggestions
  ("this contradicts your note from March").
- Multi-provider: add providers behind `LLMProvider` + provider picker.

## Phase 5 — Delight & scale
- Generated subject artwork for `SubjectBackdrop` (Image Playground / API).
- Rich animations: matched-geometry subject→detail, streaming shimmer.
- Widgets (recent subjects, quick capture), App Intents / Shortcuts, Spotlight.
- Export (Markdown/PDF per subject), share sheets.
- iPad layout; App Store hardening (backend proxy for the API key).
