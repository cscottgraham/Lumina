# Building Lumina Entirely From Windows

**The honest constraint:** SwiftUI/SwiftData compile only in Xcode on macOS —
no tool changes that. **The workaround that actually works:** you never need to
*own or touch* a Mac. GitHub Actions provides macOS build machines; TestFlight
delivers builds to your iPhone. Everything is driven from this Windows PC.

```
┌────────────── Windows PC ──────────────┐      ┌───── GitHub Actions (macOS) ─────┐
│ edit Swift files (VS Code / Claude)    │ push │ ios-ci.yml:                       │
│ git commit / git push ─────────────────┼─────▶│  XcodeGen → build → unit tests    │
│ read results in Actions tab            │◀─────┤  ❌ compile errors / ✅ green      │
└────────────────────────────────────────┘      │ testflight.yml (manual):          │
                 ▲                              │  signed archive → App Store       │
                 │ install via TestFlight app   │  Connect upload                   │
            ┌────┴────┐                         └──────────────┬────────────────────┘
            │ iPhone  │◀───────────── TestFlight ──────────────┘
            └─────────┘
```

## The everyday loop (no cost, no account beyond GitHub)

1. Edit code on Windows.
2. `git push` → **iOS CI** runs automatically: generates the Xcode project,
   compiles for the iPhone 15 simulator, runs the unit-test suite
   (`LuminaTests/` — SSE parsing, cost math, enrichment JSON, ContextBuilder
   against a real in-memory SwiftData store).
3. Read the results: `https://github.com/<you>/Lumina/actions`. A red ❌ shows
   the exact Swift compile error with file/line — fix on Windows, push again.
   Failed test runs upload a `TestResults.xcresult` artifact.

This replaces the local compiler. Expect the first runs to shake out errors —
that's the loop working, not failing.

> **CI minutes:** public repos get unlimited free Actions minutes. Private
> repos get 2,000 free min/month, and macOS burns them at **10×** (≈200 real
> minutes ≈ 12–18 CI runs/month). If CI quota pinches, flip the repo to
> public (Settings → General → Danger Zone) — the code contains no secrets
> (the Claude key lives only in the iOS Keychain).

## Getting it onto your iPhone (TestFlight — still no Mac)

One-time setup, all from Windows (~1 evening):

1. **Apple Developer Program** — enroll at developer.apple.com ($99/yr).
2. **Distribution certificate — generated with OpenSSL on Windows** (Git for
   Windows ships `openssl`; no Keychain Access needed):
   ```bash
   openssl genrsa -out lumina.key 2048
   openssl req -new -key lumina.key -out lumina.csr -subj "/CN=Lumina/O=You/C=CA"
   # upload lumina.csr: developer.apple.com → Certificates → Apple Distribution
   # download distribution.cer, then:
   openssl x509 -inform DER -in distribution.cer -out distribution.pem
   openssl pkcs12 -export -inkey lumina.key -in distribution.pem -out lumina.p12
   ```
3. **App ID + provisioning profile** — portal: register `com.cscottgraham.lumina`
   (capabilities: iCloud/CloudKit, Push), create an **App Store** provisioning
   profile named `lumina` for it.
4. **App record** — App Store Connect → New App (TestFlight needs it; the app
   never has to go to review for your own devices via internal testing).
5. **App Store Connect API key** — Users & Access → Integrations → Team key
   (App Manager). Download the `.p8`.
6. **Repo secrets** — add the seven secrets listed at the top of
   `.github/workflows/testflight.yml` (base64 the .p12/.mobileprovision with
   the PowerShell one-liner in that file). Also set your Team ID in
   `project.yml` → `DEVELOPMENT_TEAM`.

Then, whenever you want the app on your phone: **Actions → TestFlight → Run
workflow** (bump the build number) → ~15 min later it appears in the TestFlight
app on your iPhone. Sign into the same Apple ID, tap Install.

## What genuinely can't be done from Windows (and the mitigations)

| Gap | Reality | Mitigation |
| --- | --- | --- |
| Xcode Previews / visual iteration | No live canvas on Windows | Design-system changes are centralized (`DesignSystemShowcase`); judge visuals on-device via TestFlight builds. Later: CI UI-test **screenshot artifacts** for per-PR visuals. |
| Interactive debugging (breakpoints, Instruments) | Needs Xcode | Unit tests + on-device testing catch most issues; rent a cloud Mac by the hour only if a bug truly demands a debugger. |
| iOS Simulator interaction | macOS-only | TestFlight on the real phone is the better test surface anyway. |
| CloudKit dashboard schema promote | Browser-based ✅ works on Windows | icloud.developer.apple.com |

**Cloud Mac escape hatch** (optional, hourly): MacinCloud / Scaleway / AWS EC2
Mac give you a full remote Xcode via RDP/VNC for the rare debugger session —
still no Mac purchase.

## Optional: local Swift syntax checking

The Swift toolchain runs on Windows (`winget install --id Swift.Toolchain`) but
**cannot compile SwiftUI/SwiftData** — only pure-logic code. It becomes worth
installing if/when we extract a platform-neutral `LuminaCore` package (wire
types, SSE parsing, cost math) for instant local `swift test`. Until then, CI
is the compiler; don't bother.

## Reference

- CI workflow: `.github/workflows/ios-ci.yml`
- TestFlight workflow + secret list: `.github/workflows/testflight.yml`
- If a *future* Mac session happens: `docs/BUILD_ON_MAC.md` still applies.
