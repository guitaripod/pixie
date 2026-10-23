# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

**Pixie** is the client-app suite for the Pixie AI image-generation product: the **iOS app** (`iOS/Pixie`), the **Android app** (`android/`), and the **CLI** (`cli/`). All three are clients of the **mako** backend.

> **The backend is mako, `services/intelligence` in this monorepo (mirrored to `guitaripod/mako`).** Anything about the Cloudflare Worker, D1, migrations, wrangler, secrets, credits, or providers (OpenAI/Gemini/Claude) belongs there, NOT here. Deployed as `openai-image-proxy` @ `mako.midgarcorp.cc`. This repo only consumes its HTTP API.

## Common Commands

```bash
# CLI (Rust, standalone product + the reference client)
cd cli && cargo run -- [args]
cd cli && cargo build --release

# iOS
cd iOS/Pixie && xcodebuild -project Pixie.xcodeproj -scheme Pixie \
  -destination 'platform=iOS Simulator,id=69011470-D880-44F0-A527-480A03C692CA' build -quiet

# Android
cd android && ./gradlew compileDebugSources
```

## iOS Development

- Reference the CLI and the Android app when building iOS UI components so behavior stays consistent — reimplement with native iOS components and feel, don't hallucinate.
- Use modern SDK `UIButton` configuration APIs, not the old `@objc` target/action style.
- Prefer `UIStackView` for layout wherever possible.

## Important Notes

- **CLI is the source of truth**: all client code (iOS, Android) must treat the CLI's behavior as canonical.
- **Cost optimization**: when testing image generation, use `--quality low` (4-5 credits), not high (50-80 credits).
- **API compatibility**: the backend's `/v1/images/generations` matches OpenAI's format; clients should too.
- **Backend changes** (worker, credits, providers, migrations, rate limiting): make them in `guitaripod/mako`, then consume here.
- **iOS tests**: the `PixieTests` target (Swift Testing, hosted in the app) covers `PixieMidgar`, the review-prompt migration, the welcome credits and the gateway address. Run it on the iPhone 17 simulator with `xcodebuild test -project iOS/Pixie/Pixie.xcodeproj -scheme Pixie -destination 'platform=iOS Simulator,id=<udid>'`. Everything else is validated against a running backend (`~/Dev/rust/mako`, `npx wrangler dev`) via the CLI.

## Midgar platform (iOS)

- MidgarKit and AICredits come from the monorepo's `packages/` by path (local package references in `Pixie.xcodeproj`, decision D15). The app targets build in Swift 6 with complete strict concurrency and MainActor default isolation; model records, `GalleryCache`, `CacheManager`'s file helpers and the notification delegate are `nonisolated`.
- `Services/PixieMidgar.swift` is the composition root: Midgar ID (keychain group `cc.midgarcorp.shared` after the app's own group, no App Attest entitlement), the gateway client for the portal, signals and `MidgarStore` in `Mode.readOnly`, because RevenueCat still buys and finishes every credit pack (registry engine `rc-full`).
- Every mako call goes to `https://api.midgarcorp.cc/v1/intelligence` with `X-App-ID: pixiepocket` and `X-Midgar-Token` when the identity answers within 2 seconds (`NetworkService` takes the headers from `PixieMidgar.midgarTokenHeaders()`). AICredits keeps its tenant id `pixie` (`PixieMidgar.creditsAppID`) because its keychain item is `aicredits.pixie`; renaming it would strand every anonymous account. Generated image URLs still come from mako as `openai-image-proxy.guitaripod.workers.dev/r2/...`, the one direct host in the registry's `network_exceptions`.
- Logging is `MidgarLog` (file `Library/Logs/pixie.log`, categories in `Utils/LogCategories.swift`). Never log prompts, tokens or email addresses.
- `Utils/ReviewPrompt.swift` reports generations to `MidgarReviewPolicy`; the old ask history is carried over once by `LegacyReviewState`.
- Settings opens the portal with `PixieMidgar.shared.portalConfig`; the About screen (`ViewControllers/AboutSettings.swift`) is MidgarUI rows.
- Privacy: `Resources/PrivacyInfo.xcprivacy`, `store/privacy-label.md` and the policy in `web/midgarcorp/src/content/legal/pixiepocket/privacy.html` move together. mako keeps prompts and generated images for this tenant (`store_prompts` and `store_images` default to 1).
- Persistence is not SwiftData: the app keeps files, UserDefaults and the Keychain, so there is nothing to migrate to GRDB.

## Marketing screenshots

- Raw captures: `marketing/shoot.sh` (DEBUG `PX_DEMO` screens on the iPhone 17 Pro Max and iPad Pro 13" simulators; iPad with `PX_RAW_SUBDIR=ipad`). Composition: `marketing/compose_screenshots.py [--ipad]`.
- Frame every device type with the `frames` CLI (the `frames-cli` skill), never a hand-drawn bezel: `compose_screenshots.py` calls `frames --json -o <dir> -c Black <raw.png>` and only adds the gradient, captions and shadow. Run `frames doctor` first.
- Copy lives in `marketing/listing/<locale>.json` (the single source); store push with `listing_to_metadata.py` + `asc metadata push`, screenshots with `asc screenshots upload --device-type IPHONE_67|IPAD_PRO_3GEN_129 --replace --confirm`. Screenshots are locked once a version is submitted.

# No Code comments
- DO NOT ADD CODE COMMENTS. THEY ARE BLOAT!!
