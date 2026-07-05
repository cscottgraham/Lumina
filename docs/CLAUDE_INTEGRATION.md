# AI Integration (Claude + Grok)

Lumina's research layer is **provider-pluggable** behind the `LLMProvider`
protocol. Two providers ship; pick one in **Settings → AI Provider** (each has
its own Keychain key slot). Everything upstream — QueryPlanner, ContextBuilder,
the chat UI, enrichment, the cost meter — is provider-agnostic.

| | Claude (`ClaudeClient`) | Grok (`GrokClient`) |
| --- | --- | --- |
| Endpoint | `api.anthropic.com/v1/messages` | `api.x.ai/v1/chat/completions` (OpenAI-compatible) |
| System context | Cache-controlled system blocks (`cache_control`) | Single system message; xAI prefix caching is automatic |
| Reasoning | Adaptive thinking (`display: summarized`) | Reasoning models stream `reasoning_content` natively |
| Usage/cost | `usage` fields incl. cache read/write | `stream_options.include_usage` final chunk; `cached_tokens` mapped to cache reads |
| Models | Opus 4.8 / Sonnet 5 / Haiku 4.5 | Grok 4.1 Fast (Reasoning / non) / Grok 4 |
| Enrichment model | Haiku 4.5 | Grok 4.1 Fast (non-reasoning) |

`ModelCatalog` resolves names + pricing from the raw model-id string stored on
`ChatThread.modelRaw`, and `LLMProviderFactory` supplies the active client and
per-provider defaults. Grok pricing in the catalog is approximate — verify at
console.x.ai.

The rest of this document details the Claude wire format; Grok's is the
standard OpenAI chat-completions shape (see `GrokClient.swift` header).

---

Lumina calls Claude's **Messages API** directly over HTTPS (Anthropic ships no
official Swift SDK, so raw HTTP is the correct path). All of it lives in
`Lumina/Services/AI/`.

## Request

`POST https://api.anthropic.com/v1/messages`

Headers:
```
x-api-key: <key from Keychain>
anthropic-version: 2023-06-01
content-type: application/json
```

Body (`ClaudeRequest`):
```jsonc
{
  "model": "claude-opus-4-8",
  "max_tokens": 4096,
  "system": [
    { "type": "text", "text": "<stable subject context>",
      "cache_control": { "type": "ephemeral" } },   // ← cached prefix
    { "type": "text", "text": "Current date: …" }     // ← volatile, no cache
  ],
  "messages": [ { "role": "user", "content": "…" }, … ],
  "stream": true,
  "thinking": { "type": "adaptive", "display": "summarized" } // optional
}
```

## Models & pricing (USD per 1M tokens)

| Model | id | input | output |
| --- | --- | --- | --- |
| Opus 4.8 (default) | `claude-opus-4-8` | $5.00 | $25.00 |
| Sonnet 5 | `claude-sonnet-5` | $3.00 | $15.00 |
| Haiku 4.5 | `claude-haiku-4-5` | $1.00 | $5.00 |

Cached-read input ≈ **0.1×** input price; cache-write ≈ **1.25×** (5-min TTL).
Defined on `ClaudeModel`; the cost meter uses `CostEstimator`.

> Model choice is the user's call (Settings + per-thread picker). Default is
> Opus 4.8 for the deepest research; Haiku handles background enrichment.

## Streaming (SSE)

`ClaudeClient.stream` uses `URLSession.bytes(for:)` and parses `data:` lines
into distilled `ClaudeStreamEvent`s:

| SSE event | We emit |
| --- | --- |
| `message_start` | `.usage` (input tokens, cache reads/writes) |
| `content_block_delta` · `text_delta` | `.textDelta` |
| `content_block_delta` · `thinking_delta` | `.reasoningDelta` |
| `message_delta` | `.usage` (output tokens), `.done(stopReason)` |
| `message_stop` | `.done` |

`ChatViewModel` accumulates `.textDelta` into `liveText` for the live bubble,
then persists the final `ChatMessage` + usage and rolls it into the thread
totals. `LLMProvider.complete(...)` is a non-UI convenience that drains the same
stream into a final string (used by enrichment).

## Item enrichment (background AI)

`ItemEnrichmentService` evaluates **each newly captured item** and writes value
back onto it:

- **What it produces** (strict JSON asked of the model): a ≤60-word `summary`,
  up to 4 suggested `tags` (auto-attached via `TagStore.findOrCreate`), and a
  short `related` note — relevant context/connections the researcher would want.
- **Where it lands**: `ContentItem.aiSummary` + `aiEnrichedAt`; suggested tags
  join the item's tag set (and therefore the global autocomplete pool).
- **Cost posture**: runs on **Haiku 4.5** with `max_tokens: 512`, no caching
  (one-shot, per-item), so enrichment costs a fraction of a cent per item.
- **Control**: Settings → "Auto-enhance new items" toggle
  (`UserDefaults` key `enrichNewItems`); silently skipped when no API key is set
  or the item has no text. Failures are best-effort and never block capture.
- **Feedback loop**: `ContextBuilder` includes `aiSummary` in ranking and
  context, so enrichment makes future research chats smarter.

## The research layer (QueryPlanner + tiered context)

Every question flows through three stages before a single token is spent:

1. **Plan (on-device, free)** — `QueryPlanner` classifies the question:
   *general Q&A*, *"summarize all photos/audio/…"* (per-kind sweep),
   *subject overview*, *compare X and Y* (fuzzy title match → focus items),
   or *deep read* ("quote…", "full text…"). The plan sets the retrieval
   filter, the item budget, the depth tier, and a steering instruction that
   rides in the **uncached** volatile block (so it never invalidates the
   prompt cache).
2. **Select** — `ContextBuilder.select` scores items with field-weighted term
   overlap (title ×3 > tags/topic ×2 > AI summary ×1.5 > body ×1) plus a
   recency bonus. The AI summaries double as cheap semantic matching: because
   enrichment normalizes vocabulary, meaning-level matches surface even when
   the user's words differ from the item's.
3. **Assemble, tiered** — by default each item contributes its **summary**
   (enrichment note or head excerpt, ≤~420 chars). Only the plan's **focus
   items** get **full text** (≤~2.6k chars, marked `[FULL]`). Media without
   transcripts contribute a structured description line
   (`[Photo — no description yet, 4032×3024]`) so Claude knows it exists.
   Whole section is hard-capped (~12k chars ≈ 3k tokens).

The chat UI mirrors the plan: the "Reading" strip shows exactly which items
ground the answer (filled chips = sent at full depth), suggestion chips
exercise each intent, and any answer can be **saved back into the vault** as a
note (tagged `research-output`) — including the one-tap **research brief**
(wand menu), a structured markdown output with findings / open questions /
contradictions / next captures.

## Cost control

1. **Prompt caching.** The stable subject context (digest + retrieved excerpts)
   is one `system` block with `cache_control: ephemeral`. Repeat turns in a
   thread re-read it at ~0.1× instead of full price. Volatile per-request text
   (date, one-off instructions) goes in a *second, uncached* system block so it
   never invalidates the cached prefix.
   - Opus 4.8's minimum cacheable prefix is ~4096 tokens — small subjects won't
     cache; that's fine, they're cheap.
   - Verify caching works by watching `cache_read_input_tokens` climb across
     turns (surfaced in the thread totals).
2. **Bounded context.** `ContextBuilder` sends a compact digest + top-K ranked
   *text* excerpts (never raw media), truncated to a char budget (~12k chars ≈
   3k tokens). Cost scales with the question, not the whole vault.
3. **Model + thinking are user-controlled.** Deep adaptive thinking is off by
   default (faster/cheaper); toggle per message. Enrichment defaults to Haiku.
4. **Live meter.** `ChatThread.estimatedCostUSD` shows spend in the nav bar.

## Security

The API key lives in the iOS **Keychain** (`KeychainStore`) — never in
SwiftData, UserDefaults, iCloud, or the repo. For an App Store release you'd
proxy calls through your own backend so the key never ships in the client; for a
personal vault, a Keychain-stored key called directly is appropriate.

## Future (Phase 4+)

- Vision: attach images as `image` content blocks so Claude can *see* photos
  (enrichment then works for photos without captions).
- On-device embeddings (`NaturalLanguage`) for semantic retrieval in
  `ContextBuilder` instead of keyword ranking.
- A background job that (re)writes `Subject.digest` with a cheap Haiku call when
  content changes, so the cached spine stays fresh and small.
- `count_tokens` endpoint for an exact pre-send cost estimate.
