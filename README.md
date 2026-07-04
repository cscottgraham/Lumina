# Lumina ✨

A personal research & knowledge vault for iPhone. Capture mixed media (photos,
video, audio, voice-dictated + typed notes, web snippets), organize it into
**Subjects** with **Topic** subcategories and autocompleting **tags**, keep
**provenance metadata** (when/where/what source) on every item, and *research*
any subject by chatting with Claude — which draws rich context from your own
stored content. New captures are **auto-enhanced by Claude** (summary, related
context, suggested tags). Built SwiftUI-first with a bespoke **glassmorphism**
design system, dark-mode-first — each subject's backdrop reflects its own
imagery under the aurora.

> **Status:** foundation scaffold. Authored on Windows; **builds on macOS +
> Xcode 15+**. See [`docs/BUILD_ON_MAC.md`](docs/BUILD_ON_MAC.md) for the
> one-command first build.

## What's here

| Area | Where | Doc |
| --- | --- | --- |
| Architecture & project structure | `Lumina/` | [ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| SwiftData schema | `Lumina/Models/` | [ARCHITECTURE.md](docs/ARCHITECTURE.md#data-model) |
| Glassmorphism design system | `Lumina/DesignSystem/` | [DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md) |
| Claude integration (context + cost) | `Lumina/Services/AI/` | [CLAUDE_INTEGRATION.md](docs/CLAUDE_INTEGRATION.md) |
| Phased build plan | — | [ROADMAP.md](docs/ROADMAP.md) |

## Tech

- **SwiftUI + SwiftData** (iOS 17+), `@Observable` view models.
- **CloudKit-backed `ModelContainer`** → local-first with iCloud sync.
- **Media as files** in the app container (iCloud-synced); SwiftData stores
  only metadata + relative file paths. Never blobs in the DB.
- **Claude via raw HTTPS** to `POST /v1/messages` (no official Swift SDK),
  streaming SSE, prompt caching, live token/cost metering. Key in the Keychain.

## Quick start (on a Mac)

```bash
brew install xcodegen
cd Lumina
xcodegen generate      # creates Lumina.xcodeproj
open Lumina.xcodeproj
# In Xcode: set your Team ID (Signing & Capabilities), add the iCloud/CloudKit
# capability with container iCloud.com.lumina.app, then Run on a device/simulator.
```

Add your Claude API key in-app: **Settings → Claude → API Key** (stored in the
iOS Keychain — never in the repo). Get one at <https://console.anthropic.com>.

## License

MIT — see `LICENSE` (add before publishing).
