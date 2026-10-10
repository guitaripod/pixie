# Pixie iOS: design remaster

Source of truth for the 1.6.1 redesign. Written after looking at every screen (iPhone, light and dark; iPad and Duo through the split view) and before touching code.

## 1. What is wrong today (audit)

The app looks like system defaults plus one dull purple. Findings, by screen:

- **Everything:** white or grey system backgrounds, grey cards, one Material-style purple (#6750A4). No identity, no typographic voice (default SF bold), no hierarchy between hero content and chrome. Every screen is a different shape of the same flat card.
- **Splash:** pastel gradient with black "Pixie" text, no mark. Looks like a placeholder.
- **Onboarding:** better than before (real before/after) but the card is a boxed image on white; the consent card is a wall of grey text, clipped at its bottom edge.
- **Login (shown after logging out):** a lavender placeholder box that literally says "Anime Art", four dots, "Get free credits to start creating" (stale: the app starts anonymously with 3 free images), a "Why do I need to sign in?" link, and 40% empty screen below. Nothing on it is designed. Logging out of an anonymous account also silently discards the account.
- **Start (home):** a 2-column wall of text cards with tiny pastel icons; no pictures of what an edit does; the strongest asset (the results) is nowhere. "Create from text" chips are in a different style than the cards above them.
- **Composer (bottom bar):** a flat white strip; the drag handle sits on top of the text (regression), "Describe your edits… / Tap to customize" is two lines of grey; the send action does not exist visually; options are hidden behind an unexplained pan gesture.
- **Chat / results:** iMessage clone: heavy purple bubbles, the result as a small rounded rectangle, 40% dead space, three tiny pastel circles for actions, no generation state worth looking at.
- **Gallery:** every thumbnail carries a caption over the picture (illegible on bright images), star + number in the corner; the grid is the least picture-forward thing it could be.
- **Detail:** image inside a translucent glass card on a blurred grid, pastel buttons on glass (low contrast), details below the fold.
- **Credits:** two tiles ("Buy Credits", "Estimate") that duplicate two rows of the "Features" list underneath; content squeezed into a 530-pt column on a 920-pt screen; recent transactions an unstyled text list.
- **Store:** structurally fine; badges straddle card borders, "Enterprise"/"Business" names carry no meaning to a photo-app user, value (how many images) is a footnote.
- **History:** cleanest screen; just needs the shared row style.
- **Settings:** a form: eight segmented controls in a row, no account section, no sense of what matters; anonymous users see "Logout".
- **Help:** wrong. It says Pixie is "powered by gpt-image-1", that GitHub sign-in is recommended, that the account syncs "with the CLI tool", and to "tap the bottom toolbar". None of that is the product.
- **Launch failure, banner, loading dots, consent sheet:** correct but unstyled.

## 2. Direction

**Photo-first, calm, one bold gesture.** The product is a transformation; the UI should get out of its way and make the picture the loudest thing on every screen. Chrome is quiet (ink and paper, hairlines, no heavy fills); colour is reserved for the one thing to do next, which wears the brand gradient.

Three registers:
1. **Brand moments** (splash, onboarding, login, launch failure): always dark "ink" with a soft violet glow and the gradient. White rounded-heavy type.
2. **Work screens** (home, chat, gallery, credits, settings): follow system appearance. Light = warm "paper" canvas with white surfaces; dark = ink canvas with raised surfaces.
3. **Content** (results, thumbnails): square-cornered or 20-pt rounded, edge-to-edge where possible, never overlaid with text.

Voice: short, concrete, friendly. No "AI-powered", no "stunning", no model names, no prices in marketing copy.

## 3. Tokens (code: `Pixie/DesignSystem/Theme.swift`)

### Colour (all dynamic)
| token | light | dark | use |
|---|---|---|---|
| `canvas` | #F6F4FA | #0B0A12 | screen background |
| `surface` | #FFFFFF | #15131F | cards, rows |
| `surfaceRaised` | #FFFFFF | #1E1B2B | sheets, popovers, selected cards |
| `fill` | #15121F @6% | #FFFFFF @8% | tonal fills, inputs |
| `line` | #15121F @10% | #FFFFFF @10% | hairlines (0.5–1 pt) |
| `ink` (text) | #15121F | #F4F2FA | primary text |
| `inkSecondary` | #5E5A6E | #A7A2B8 | secondary text |
| `inkTertiary` | #8C879C | #75708A | hints, placeholders |
| `accent` | #6C47FF | #7F62FF | fills with white text (contrast ≥ 5:1) |
| `accentText` | #5B38F0 | #A99BFF | accent as text / icons on canvas |
| `accentSoft` | accent @12% | accent @24% | tonal buttons, selected tint |
| `success` / `warning` / `danger` | #12A06B / #D98E00 / #E5484D | #3DD9A0 / #FFC247 / #FF7A80 | states (always with text/symbol) |

Brand gradient `Theme.gradient`: #6C47FF → #B04BFF → #FF6FA3 (top-left to bottom-right). Uses: primary button fill, selection ring, hero balance card, splash orb, progress. Never on body text, never on more than one element per screen region.

Ink backdrop for brand moments: `#0B0A12` base + radial glow `#6C47FF @35%` top and `#FF6FA3 @18%` bottom.

### Type (SF Pro; numerals and display in SF Rounded; all scale with Dynamic Type)
| style | spec |
|---|---|
| `display` | rounded heavy 34, tracking −0.4, line ≈ 1.05 |
| `title` | rounded bold 28 |
| `title2` | semibold 22 |
| `headline` | semibold 17 |
| `body` | regular 17 |
| `callout` | regular 16 |
| `subhead` | medium 15 |
| `footnote` | regular 13 |
| `caption` | semibold 12, uppercase, tracking +0.6 (section labels, badges) |
| `numeral` | rounded heavy, any size (credits, prices, counts) |

### Space (4-pt grid)
`xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24 · xxxl 32 · huge 48`. Screen margin 20 (compact width), 32 (regular). Max readable content width 640 for forms and lists, 1100 for grids; content is centred, never a narrow column on a wide screen with dead gutters unless it is a form.

### Shape
Radii: `sm 10 · md 14 · lg 20 · xl 28 · sheet 32 · pill = height/2`. Cards 20, tiles 20, thumbnails 14, images in chat 24, buttons and chips pills, sheets 32. Continuous corner curve everywhere.

### Elevation
Light: surface cards get a 1-pt `line` border and shadow `#1B0F4A @8%`, radius 24, y 8. Dark: no shadow, `line` border only. Glass (iOS 26 `UIGlassEffect`, fallback `.systemThinMaterial`) only for floating chrome: top bar buttons, composer, action bars.

### Motion
Spring 0.4 s, damping 0.82 for presentation and selection; 0.2 s ease-out for state fades; all through `Motion` (instant under Reduce Motion). Press state: scale 0.97 + haptic selection. Hero moments (result arriving) may use a 0.6 s fade-scale; never loop motion except the generation shimmer (static under Reduce Motion).

## 4. Components (code: `Pixie/DesignSystem/`)

- `PixieButton` — `.primary` (gradient capsule, white label, 56 pt), `.secondary` (accentSoft capsule, accentText label), `.plain` (text), `.destructive` (danger tonal); sizes large 56 / medium 46 / small 36; optional leading SF Symbol; `isLoading`; haptic + press scale; Dynamic Type grows the height.
- `SurfaceView` — card background: radius, hairline, adaptive shadow; styles `.card`, `.sunken` (fill), `.glass`.
- `GradientView` — brand gradient layer; `InkBackdropView` — ink + glow for brand moments.
- `SectionLabelView` — caption-style title (+ optional trailing action).
- `CreditPill` — sparkle + balance (rounded numerals), "N free" variant, tappable.
- `IconBadge` — rounded-square gradient tile with a white SF Symbol (presets, settings rows).
- `ChipView` — selectable pill (text and optional symbol): off = fill, on = accent.
- `ListRowView` — icon badge, title, subtitle, trailing value/chevron; used by settings, credits, help.
- `StateView` — gradient glyph, title, message, optional button: empty, error, offline, loading.
- `ShimmerView` — skeleton fill with a moving highlight (static under Reduce Motion).

Existing helpers kept: `UIFont.scaled`, `Motion`, `Announce`, `describe`, `GlassMaterial`.

## 5. Screens

Rules for every screen: dark and light both designed; iPad and Duo through size classes (centred max widths, grids reflow); Dynamic Type to the largest accessibility size without clipping; VoiceOver labels kept from the accessibility pass; every state (loading, empty, error, offline) uses `StateView`/`ShimmerView`; copy follows the voice rules in §2; reuse existing string keys wherever the meaning is unchanged.

### 5.1 Splash (brand moment)
Ink backdrop; a 120-pt orb (gradient disc, soft outer glow) with the sparkle glyph in white at its centre; "Pixie" below in rounded heavy 40 white, tracking −0.5. In: orb scales 0.86→1 and fades 0.5 s, wordmark fades 0.2 s later; out: whole view fades and scales 1.04. After 6 s the "Taking longer than usual…" line fades in under the wordmark in `white @60%`. The launch screen storyboard background is the same ink so there is no flash.

### 5.2 Onboarding (brand moment)
Ink backdrop with glow. Top: page counter as three pill dots (active pill is 24-pt wide gradient) and "Skip" (plain white @70%). Hero: the before/after card at 4:5, 20-pt inner radius on a `white @8%` glass tray with a hairline, the divider handle white; it sits in the upper 55% of the screen and scales with height. Title in `display` white, body in `white @70%` callout, max 3 lines. Bottom: primary gradient button 56 pt (full width, max 420) and a text link. Page 3 replaces the grey consent wall with a compact glass row: cloud glyph in an `IconBadge`, one-line summary "Your photos are sent to Google Gemini and OpenAI to make your images." and a "Details" link that opens the full disclosure in a sheet; the button still says "Agree & Start Creating" and the full `CloudAIConsent.disclosure` is always reachable and shown in the sheet and Settings. The page-3 title is "3 free images to start".

### 5.3 Login (brand moment; shown after logout and from "Sign in")
Ink backdrop. Hero: a fan of three real photo cards from the onboarding before/after assets (rotated −8°, 0°, +8°, 3:4, 20 radius, white hairline) occupying the upper 45%, with a slow 12-s drift (static under Reduce Motion). Title "Keep your creations safe" (display); body "Sign in to back up your images and credits and use them on every device. You can keep using Pixie without an account." Buttons stacked 12 pt apart, all 56 pt full width (max 420): Sign in with Apple (system button, white style on ink), Continue with Google (white fill, ink text, Google mark), Continue with GitHub (`white @12%` fill, white text, mark). Below: plain "Not now" only when an account exists to return to; the "Why sign in?" link opens a sheet (benefits list: sync, recover, use the CLI). Error banner at the top of the content as a danger-tinted `SurfaceView` with text and symbol. Loading: the tapped button shows a spinner, others dim.

### 5.4 Launch failure (brand moment)
Ink backdrop. Gradient glyph tile (cloud with slash) 88 pt, title "Couldn't get set up", message (existing strings), primary "Try Again" (Retrying… with spinner), plain "Sign in instead". Same copy rules and states as before.

### 5.5 Home / Create (work screen)
Top bar (glass, floating over content, 12 pt margin): left, the `Pixie` wordmark (rounded heavy 22) or, when a conversation exists, a "New" capsule with sparkle; right, `CreditPill`, then gallery and settings as 44-pt glass circles. Content scrolls under it with a top fade.
Sections, 20-pt margins, 28 pt between sections:
1. **Your photo** (when a photo is selected): the photo as a 3:4 hero card (radius 24, 160×213) with a "Change" capsule and × to remove, next to a short line "Tap an edit below, or describe your own". When no photo: **Start with a photo** — a 16:9 hero drop-zone card (radius 24, `accentSoft` fill, dashed gradient hairline) with a large plus glyph tile, "Choose a photo" headline, "or try the sample" secondary; first-run users also see the sample tile as a second card. Recent photos follow as 72-pt rounded thumbnails in a horizontal strip.
2. **Popular edits** — horizontal carousel of image cards (150×200, radius 20, snap): Pro headshot, Restore old photo, 3D figurine, Royal pet portrait, Headshot pack, with their real result images (`preset_*` imagesets, ≤ 80 KB each), a bottom scrim, the title in white headline and a one-line subtitle in white @75% footnote; the pack card has a "×4" capsule.
3. **More edits** — 2-column grid of compact tiles (72 pt high): `IconBadge` (preset colour gradient) + title + subtitle (2 lines max). Halloween is first in October with a "Seasonal" caption badge.
4. **Create from text** — "Start from a template" `SectionLabelView` with `ChipView`s in one wrapping row (no per-chip colours; the style symbol only).
Bottom inset leaves room for the composer. Empty/first-run: a short welcome line under the wordmark, never a paragraph.

### 5.6 Composer
Floating capsule 56 pt (grows to 4 lines at 24 radius), glass material with hairline and shadow, 12 pt from the sides and bottom safe area / keyboard. Leading slot 44×44: if a photo is selected a 40-pt rounded thumbnail with a small × badge, otherwise a tonal "+" circle that opens the picker. Centre: text field (body 17) with placeholder "What do you want to create?" (generate) or "Describe your edit…" (edit); no handle, no second line. Trailing: an options button (`slider.horizontal.3`, with a 6-pt accent dot when any option is non-default) and the send button (40-pt gradient circle, `arrow.up`; disabled = `fill` with `inkTertiary` glyph). When text is present a footnote under the capsule shows "≈ 21 credits · 3 free left" (secondary), "Not enough credits" in danger with a "Get credits" link when short.
**Options panel** opens above the composer as a card (radius 28, `surfaceRaised`, its own centred 36×5 grabber at the top, max height 60%): Model — three selectable cards (name, one line of what it is best at, relative cost) in a horizontal row; Quality — pill selector with the credit cost per option; Size — four shape tiles (auto, square, landscape, portrait) drawn as aspect-ratio outlines; **Advanced** disclosure: format, compression, background, moderation as `ChipView` groups. Pan down on the grabber or tapping outside collapses. All existing properties/callbacks of `ChatInputBar` keep their names.

### 5.7 Conversation / results
Content on `canvas`, 20-pt margins, 24 between turns.
- **Request**: right-aligned `SurfaceView` (radius 20, `fill` background, no heavy colour), body text, with the source photo as a 56-pt rounded thumbnail on its left; timestamp only on long press.
- **Result**: full-width image card (radius 24, border + shadow, aspect preserved, max height 70% of the screen; multi-image results as a 2×2 grid with 6-pt gaps inside one card). Under it a single action row of three equal capsules with icon and label — Save, Share, Compare — in `fill` with `ink` text, 44 pt tall; success state turns the tapped capsule `success` tinted for 1.5 s with a check. Tap the image for the full-screen viewer.
- **Generating**: a shimmer placeholder card with the expected aspect, a centred gradient sparkle that pulses (static under Reduce Motion), "Creating your image…" and an elapsed timer in `inkSecondary`; the composer shows the stop control in place of send.
- **Assistant notice** (declined, error, low balance): a tinted `SurfaceView` with symbol, title and an action ("Get credits", "Try again"); never raw model text.
- **Before / After**: Compare opens the existing composite viewer restyled with the shared handle and pills.

### 5.8 Gallery
Large title "Gallery" with "N images" subtitle; Select as a plain button. Grid: 3 columns on compact, 4–6 by width on regular, 1-pt gaps, square crops, edge-to-edge. No text on thumbnails. Press and hold = existing context menu; selection mode shows a dimmed thumbnail with a gradient check badge bottom-right and the toolbar from the previous pass restyled with `PixieButton`s. Empty: `StateView` "No images yet" + "Create an image". Loading: shimmer squares.

### 5.9 Image detail
Ink backdrop at the top 58% (image aspect-fit, pinch/double-tap zoom, status bar light), a grabbable sheet below (`surface`, radius 32). Action row: four 72×64 tonal tiles (Edit, Copy, Save, Share) with icon over label, "More" as a trailing circle. Then **Prompt** (body, "Copy" plain button, "Use again" secondary), then a two-column grid of facts (Model, Size, Quality, Format, Credits, Created) in `caption` + `subhead`. Save/copy confirmations are toasts, not alerts.

### 5.10 Credits
One scroll column, max width 640, centred.
1. **Balance hero** — card with the brand gradient background, radius 28: "Balance" caption in white @75%, the number in `numeral` 56 white, "credits" beside it, "≈ 65 images at standard quality" below, freshness line ("Updated just now"/"Offline, showing last balance"), and inside the card a white `.primary`-inverted button "Get credits". A banner variant appears for low balance (warning tint) and for errors (with Retry).
2. **Recent activity** — `SectionLabelView` + 5 `ListRowView`s (icon badge by kind, description, time, signed amount in rounded numerals: spend `ink`, purchase/bonus `success`) + "See all" → history.
3. **Tools** — one `ListRowView` "Cost estimator".
The duplicate quick-action tiles and the Features list are removed.

### 5.11 Credit store (sheet)
Sheet radius 32 with grabber. Header: gradient `IconBadge` 64, title "Credits" (title), line "Pay for what you create. No subscription, ever." Current balance as a `CreditPill`. Packs: five selectable cards (radius 20): left, **images** as the headline ("≈ 71 images", rounded heavy 22) with "1,500 credits · +32% bonus" below; right, the localized price in a capsule. A "Most popular" / "Best value" label sits *inside* the card top-left as a small gradient capsule (caption style). Selected: gradient border 2 pt, `accentSoft` fill, check. Sticky bottom bar (blur) with the primary button "Get 1,500 credits · $24.99" and the small "Privacy · Terms" row. Names stay as the product defines them. Loading: shimmer cards; failed: `StateView` with Retry. No Restore Purchases button.

### 5.12 Transaction history
Large title; sections by day (caption headers, sticky); rows are `ListRowView`s as in credits; footer spinner while paging; empty/error via `StateView`.

### 5.13 Settings
Large title. Sections (insetGrouped on `canvas`, rows on `surface`):
1. **Account card** (not a row): anonymous → gradient `IconBadge` + "Not signed in" + "Your images and credits are only on this device" + `.primary` "Sign in to back up"; signed in → provider glyph, "Signed in with Apple/Google/GitHub", user id in `footnote` copyable. Anonymous accounts get no Logout row anywhere (logging out would discard the account); signed-in accounts get it in the Account section.
2. **Appearance** — three preview tiles (System / Light / Dark) instead of a segmented control.
3. **Defaults** — Model (three selectable cards like the composer), Quality and Size as pill selectors with cost hints.
4. **Advanced** — a disclosure row; inside, format, compression, background, moderation as chip groups (compression slider when relevant, with the PNG footer).
5. **Privacy & data** — Cloud AI consent switch with the disclosure; Clear cache with size; Connection status.
6. **Support** — Help, Contact (opens the support URL), Version.
7. **Danger zone** — Delete Account (destructive tonal row with the existing confirmation); Logout only for signed-in accounts.
Admin rows only for admins, same style.

### 5.14 Help
Rewrite the content: it must describe the real product. Three sections as `ListRowView` accordion cards (icon badge, title, expand to body): **Get started** (pick a photo → tap an edit → refine by chat; the sample photo; 3 free images; no sign-up), **Credits** (what a credit is, packs never expire, no subscription, how cost shows before you generate, history), **Your data** (images are private, no public feed, sent to Google Gemini and OpenAI with consent, delete the account in Settings), plus an FAQ list (offline, declined requests cost nothing, sign in to sync, contact). No mention of gpt-image-1, GitHub-first sign-in, the CLI, or a bottom toolbar. Contact row at the end.

### 5.15 Consent sheet
Same content, new style: gradient `IconBadge` cloud, title, disclosure in `body` secondary, primary "Continue", plain "Not now" with the footnote; detents medium and large.

### 5.16 Cost estimator
Sheet with a result card on top (credits in `numeral` 44, USD secondary), controls below as pill selectors and a stepper restyled as a capsule with − / +; balance comparison as a progress bar with text.

### 5.17 Chrome and system pieces
Offline banner: top pill (danger-tinted surface, wifi.slash, "No Internet Connection"), slides in. Loading dots: three accent dots. Toasts: capsule `surfaceRaised` with symbol, bottom 24 pt above the safe area, undo button as plain accent text. Sidebar (iPad/Duo): rows with `IconBadge` mini (28 pt), selection = `accentSoft` pill, credits badge dot when balance is low. Admin screens: `SurfaceView` cards and `ListRowView`s, no new layout.

### 5.18 Widget / Live Activity
Keep structure; progress bar and accents use the new gradient and ink; thumbnails keep radius 12.

## 6. Assets
`preset_headshot`, `preset_restore`, `preset_figurine`, `preset_pet`, `preset_pack`: result images downscaled from DemoArt to 600 px on the long side, JPEG 0.8, ≤ 80 KB each, as imagesets. DemoArt (12 MB) must not ship in Release: move it to a DEBUG-only catalog or exclude it from Release builds.

## 7. Implementation order
1. Theme, components, palette swap (`UIColor.brand*` map to the new accent so every screen shifts at once).
2. Parallel screen packages (see work packages in the agent briefs).
3. Integration build, screenshot audit in light, dark, iPad, largest Dynamic Type; fix pass.
4. Strings in ten languages; store screenshots through `frames`; release.
