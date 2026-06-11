# PixiePocket — Store & Revenue Playbook (1.3.0)

App ID `6751730339` · bundle `com.guitaripod.Pixie` · RC project `proj44fd2c32` · mako tenant `pixie` (this repo, D1 `openai-image-proxy`). Sibling playbooks: psywave (`~/Dev/ios/psywave/docs/store-playbook.md`), DreamEater (`~/Dev/ios/DreamEater/docs/store-playbook.md` §2c for generic ASC sequencing).

Written 2026-06-11 from primary research (RevenueCat *State of Subscription Apps 2026*, Adapty 2026 paywall dataset, Superwall case studies, June-2026 competitor teardowns of Remini/Photoroom/Picsart, Apple guideline state as of June 2026). Every decision cites its evidence.

## 0. Baseline (2026-06-11)

There is no revenue to protect. Released 2025-09-19; v1.2.0 live since 2026-06-09; 0 ratings, 0 reviews, 0 recorded purchases in the D1 ledger. Five consumable credit-pack IAPs APPROVED ($2.99–$99.99), zero subscriptions, free app. The CFO report's standing objection — "image generation burns API credits; audit cost before anything else" — is answered in §1.

## 1. Unit economics (the margin audit)

- 1 credit = provider cost × 3 × 100 (`CREDIT_MULTIPLIER=3.0`, src/credits.rs): provider cost ≈ $0.0033/credit.
- Packs sell credits at 2.0¢ (starter) down to 1.43¢ (enterprise) → provider cost is 17–23% of list price.
- After Apple's 15% Small Business Program cut: **net margin ≈ 62–68% on every pack**. A 21-credit Nano Banana image sells for $0.30–0.42 and costs $0.07 to serve.
- Welcome credits (25) cost $0.083 per new user — the entire "free tier" liability.

## 2. The 1.3.0 monetization design (decision → evidence)

| # | Decision | Evidence |
|---|---|---|
| 1 | **Stay credits-only; no subscription this release** | Photo & Video has the *worst* subscription renewals of any category across every duration (23% annual / 48% monthly / 45% weekly — the "one-off project curse", RevenueCat SOSA 2026). Remini's $6.99/wk model is the category's 1-star magnet. "No subscription, ever" is the live listing's core promise and the only differentiation a zero-brand app has against Picsart/Photoroom. Revisit at the Day-90 gate only. |
| 2 | Welcome credits 6 → **25** (migration 009) | 6 credits could not buy one Nano Banana image (21 cr) — the flagship feature was untryable, while the release notes promised "free credits to try image generation instantly". Freemium taste-then-buy needs the taste. Cost: $0.083/user (§1). |
| 3 | **Real volume ladder** via bonus credits: basic +16%, popular +32%, business +49%, enterprise +68% (was: every pack ≈ 2.0¢/credit — the printed "bonus" was a no-op) | Bigger packs must be genuinely cheaper per credit or the ladder sells nothing above the anchor. Hybrid buyers are 7% of buyers but 25% of revenue (SOSA 2026) — the ladder serves exactly that whale segment. IAP list prices unchanged → no ASC pricing approvals triggered, existing users only gain. |
| 4 | **Paywall** (`CreditStoreViewController`): packs framed as "≈ N Nano Banana images", price as the dominant text, Popular pre-selected, single CTA | Users buy outcomes, not credits. 82% of paywall purchasers buy the defaulted plan; pre-selecting the high-value option beats the cheapest-first default most apps ship (Superwall). Price-dominant cards per the 3.1.2 enforcement wave (Jan–Feb 2026). |
| 5 | **Proactive paywall placement**: persistent balance chip in the nav bar; pre-flight shortfall check presents the store *before* a doomed request; 402 presents the store, not an alert | 44.5% of purchases happen Day 0 and users who never see the offer never convert (Adapty 2026). The old flow only offered packs *after* a failed generation, behind a text button two screens deep. |
| 6 | Gemini cost display fixed 15 → **21 credits** | Server charges flat 21 (src/credits.rs); client claiming 15 was a trust bug — undisclosed price inflation is how category leaders earn 1-star "scam" reviews (Picsart trial complaints, Remini teardowns). |
| 7 | **No price changes** to the five APPROVED IAPs | Price tests rarely improve conversion (28.3% win rate, Adapty) and elasticity is unobservable at ~0 volume. The ladder restructure (#3) raises effective value instead. |
| 8 | Cloud-AI **consent sheet** before first generation + Settings withdrawal | Guideline 5.1.2(i) (Nov 2025 text): explicit permission required before sharing data with third-party AI. Psybeam shipped the same pattern (`ConsentViewController`) and passed review. |
| 9 | Gallery **Report Image** action (+ `POST /v1/images/:id/report`, migration 009) | Guideline 1.2 UGC: public gallery needs report/flag mechanics; AI-generation apps are reviewed under the UGC framework (Feb 2026 clarification). |
| 10 | Liquid Glass adoption (iOS 26 SDK build, `UIGlassEffect` cards, `prominentGlass` CTA, no `UIDesignRequiresCompatibility`) | iOS 26 SDK mandatory for uploads since 2026-04-28; Apple's Liquid Glass design gallery (April 2026) is a live featuring channel and the opt-out flag is scheduled for removal. |

Explicitly rejected: a "Pixie Pro" monthly-credits subscription (RevenueCat Virtual Currency pattern). It is the right *eventual* hybrid shape for AI apps (SOSA 2026: AI apps monetize at 2× pre-AI ARPU; hybrid is the 2026 default), but: first-subscription submission requires one-time manual ASC web-UI product selection (psywave trap `FIRST_SUBSCRIPTION_MUST_BE_SUBMITTED_ON_VERSION`), renewals in this category are the worst in the market, and it would torch the listing's "no subscription, ever" promise for ~0 current users. Gate: revisit only if Day-90 proceeds ≥ $200/mo with ≥30% repeat-purchase rate.

## 3. Release facts

- **Never archive App Store builds on this Mac** (beta macOS `26A5353q` → ITMS-90111). Use `.github/workflows/release.yml` (stable runner, beta-host guard, manual signing, altool).
- Signing: manual signing lives ONLY on the app + widget targets' Release configs (global overrides break RevenueCat SPM targets). Two profiles needed: app + `PixieWidgetExtension`.
- RevenueCat ≥5.78.0 + `appStoreReceiptURL` main-thread pre-warm in AppDelegate (purchases-ios#6886; DreamEater was rejected for this exact crash).
- Screenshot rig: DEBUG env `PX_DEMO` = `create` | `edit` | `gallery` | `store` (store added in 1.3.0). Devices: iPhone 17 Pro Max sim (1320×2868, required 6.9" slot — API name `APP_IPHONE_67`) + iPad Pro 13" M5 (2064×2752). `xcrun simctl status_bar <udid> override --time "9:41"` before capture.
- The five consumables are already APPROVED → IAP display-name updates ride their own `inAppPurchaseSubmissions` track; version submissions work fully via the API (no first-product web-UI trap).
- Credits catalog is served from D1 `credit_packs` (60s edge cache); the hardcoded catalog in `src/credits.rs` is the fallback and must be kept in sync.

## 4. Gates (evaluated by /revenue-ops weekly)

- **Day 30 post-1.3.0 (2026-07-11):** ≥150 downloads AND ≥3 paying users → hold course; else the page is the problem: re-cut screenshots 1–3, test the subtitle. <50 downloads = visibility problem: ASO iteration before any product work.
- **Day 60 (2026-08-10):** download→paid ≥1.4% (low-price median, SOSA 2026; top quartile 3.7%) → press: web checkout for large packs (US external-link window is commission-free until the remand rate lands) + PPP pricing for top non-US storefronts. <0.5% → paywall structure experiments (pack order, framing) before any price move.
- **Day 90 (2026-09-09):** proceeds ≥$100/mo → start the experiment cadence (Adapty win-rate ladder: localization 62% > trial/offer structure 60% > plan duration 59% > price 46% > cosmetics 35%). Proceeds ≈ 0 with healthy top-of-funnel → positioning problem (vs free ChatGPT/Gemini image gen), not pricing. **Never ship features to fix a funnel.**
- Standing duties: reply to every review within 48h; append `docs/metrics.csv` weekly; one decision per episode.

## 5. Benchmarks to beat (SOSA 2026, Photo & Video / low-price tier)

D35 download→paid median 1.4% (top quartile 3.7%) · NA D35 median 2.6% · hybrid buyers = 7% of buyers, 25% of revenue.
