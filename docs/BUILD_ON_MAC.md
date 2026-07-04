# First Build on a Mac

This repo is authored without a Mac; nothing here has been compiled yet.
Expect the usual first-compile fixups (a stray type here, an API spelling
there) — the structure is designed so they're local and quick.

## Prerequisites
- macOS with **Xcode 15+** (iOS 17 SDK).
- An Apple ID (free is fine for device installs; paid for iCloud sync + TestFlight).
- [Homebrew](https://brew.sh).

## Steps

```bash
# 1. Clone
git clone <your-remote>/Lumina.git && cd Lumina

# 2. Generate the Xcode project from project.yml
brew install xcodegen
xcodegen generate

# 3. Open
open Lumina.xcodeproj
```

In Xcode:

1. **Signing & Capabilities** → select your Team. (Or set `DEVELOPMENT_TEAM`
   in `project.yml` and regenerate.)
2. Add capability **iCloud** → CloudKit → container `iCloud.com.lumina.app`
   (must match `PersistenceController` / entitlements). If you skip this,
   the app still runs — `PersistenceController` falls back to a local-only
   store — you just won't sync.
3. Pick a simulator or device → **Run**.

## First-run checklist

- App launches to the Subjects grid over the aurora.
- Create a subject → accent picker changes the glass tint.
- Add a topic + a note with tags & location → row shows chips + provenance.
- Settings → paste an Anthropic API key (`sk-ant-…`) → Save.
- Open a subject → **Research with Claude** → ask something about your notes:
  the reply should stream in and the cost meter should tick.
- Add a second note → within a few seconds it should sprout a ✨ (AI note),
  and its suggested tags should appear in the tag autocomplete pool.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `xcodegen: command not found` | `brew install xcodegen` |
| Signing errors | Set Team in Signing & Capabilities; unique bundle id if taken |
| CloudKit container errors | Add the iCloud capability + container, or ignore (local fallback) |
| Claude 401 | Re-paste the key in Settings (it lives in the Keychain) |
| Claude 400 mentioning `cache_control` | Cacheable prefix too small on tiny subjects — harmless; caching engages as the subject grows |
| No enrichment on new items | Settings → "Auto-enhance new items" ON + API key set; check Xcode console in DEBUG |

## Suggested dev loop

Xcode Previews are wired for the key views (`PersistenceController.preview()`
seeds sample data incl. topics/tags/AI notes) — iterate on design in Previews,
run on device for capture/location/Claude flows.
