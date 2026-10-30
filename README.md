# Pixie

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/us/app/pixiepocket/id6751730339)

AI image generation and editing in three clients: PixiePocket for iPhone and iPad, an Android app and a command-line tool. Describe an image in a chat, or upload a photo and say what to change; results land in your gallery. Generations are paid with credits.

All three talk to [mako](https://github.com/guitaripod/mako), Midgar's shared Cloudflare Worker (`services/intelligence` in the Midgar monorepo), which holds the provider keys, the credits and the image storage. Nothing in this repository runs a server.

## Clients

| Client | Stack | Where |
|---|---|---|
| **PixiePocket** (iOS 16.6 or later) | Swift, programmatic UIKit, MVVM; Live Activity and widget; credits on the Midgar ID wallet through MidgarKit, sold with StoreKit 2 | `App/`, `Features/`, `Core/`, `Platforms/widgets/`, project in `iOS/Pixie/` |
| **Android** | Kotlin, Jetpack Compose | `android/` |
| **CLI** (`pixie`) | Rust | `cli/` |

Sign-in is with Apple, GitHub or Google.

## Build

```
cd iOS/Pixie && open Pixie.xcodeproj          # MidgarKit comes from the monorepo's packages/ by path
cd android && ./gradlew assembleDebug
cd cli && cargo install --path .              # installs `pixie`
```

## CLI

```
pixie auth github                              # or google, apple
pixie generate "a lighthouse at dusk" -q medium -s landscape -n 2 -o ./out
pixie edit photo.png "make it watercolor"
pixie edit gallery:<id> "brighter colors"
pixie credits                                  # balance; also history, packs, estimate
pixie gallery mine                             # your images
```

Quality is `low`, `medium`, `high` or `auto`; size is `square`, `landscape`, `portrait`, `auto` or pixel dimensions; `-b` sets the background and `-f` the format. `pixie --help` lists the rest.

## License

GPL-3.0
