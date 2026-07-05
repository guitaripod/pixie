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

# No Code comments
- DO NOT ADD CODE COMMENTS. THEY ARE BLOAT!!
