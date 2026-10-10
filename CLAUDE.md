# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

**Pixie** is the client-app suite for the Pixie AI image-generation product: the **iOS app** (`iOS/Pixie`), the **Android app** (`android/`), and the **CLI** (`cli/`). All three are clients of the **mako** backend.

> **The backend lives in a separate repo: `guitaripod/mako` (`~/Dev/rust/mako`).** Anything about the Cloudflare Worker, D1, migrations, wrangler, secrets, credits, or providers (OpenAI/Gemini/Claude) belongs there, NOT here. Deployed as `openai-image-proxy` @ `mako.midgarcorp.cc`. This repo only consumes its HTTP API.

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
- **No automated tests** — validate clients against a running backend (`~/Dev/rust/mako`, `npx wrangler dev`) via the CLI.

## Marketing screenshots

- Raw captures: `marketing/shoot.sh` (DEBUG `PX_DEMO` screens on the iPhone 17 Pro Max and iPad Pro 13" simulators; iPad with `PX_RAW_SUBDIR=ipad`). Composition: `marketing/compose_screenshots.py [--ipad]`.
- Frame every device type with the `frames` CLI (the `frames-cli` skill), never a hand-drawn bezel: `compose_screenshots.py` calls `frames --json -o <dir> -c Black <raw.png>` and only adds the gradient, captions and shadow. Run `frames doctor` first.
- Copy lives in `marketing/listing/<locale>.json` (the single source); store push with `listing_to_metadata.py` + `asc metadata push`, screenshots with `asc screenshots upload --device-type IPHONE_67|IPAD_PRO_3GEN_129 --replace --confirm`. Screenshots are locked once a version is submitted.

# No Code comments
- DO NOT ADD CODE COMMENTS. THEY ARE BLOAT!!
