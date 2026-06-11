---
name: revenue-ops
description: Weekly PixiePocket revenue ritual — pull metrics, append docs/metrics.csv, evaluate the 30/60/90 gates from docs/store-playbook.md, and output one decision. Use when asked to "run revenue ops", "check the numbers", or on a weekly cadence.
---

# Revenue ops ritual (PixiePocket)

App Store id `6751730339`, mako tenant `pixie` (this repo IS the backend — the D1 ledger is first-party truth). Run the whole ritual; end with a gate verdict, not raw numbers.

## 1. Pull metrics

Ratings + listing state (keyless, per storefront — at minimum us, gb, de):

```bash
curl -s "https://itunes.apple.com/lookup?id=6751730339&country=us" | python3 -c "import json,sys; r=json.load(sys.stdin)['results'][0]; print(r['averageUserRating'], r['userRatingCount'], r['version'], r['price'])"
```

ASC sales/downloads (API key `DSS2FFU68G`, issuer `a5ebdab5-0ceb-463c-8151-195b902f117b`, p8 in `~/.appstoreconnect/private_keys/`). Mint an ES256 JWT (pyjwt) and call:

- `GET /v1/salesReports?filter[frequency]=WEEKLY&filter[reportType]=SALES&filter[reportSubType]=SUMMARY&filter[vendorNumber]=93803823&filter[reportDate]=<YYYY-MM-DD of week>` — gzip TSV; SKU `pixie` rows separate app downloads from credit-pack IAP units/proceeds.

D1 ledger truth (run from the repo root — no cd needed):

```bash
npx wrangler d1 execute openai-image-proxy --remote --command "SELECT COUNT(*) n FROM users WHERE app_id='pixie' AND created_at >= datetime('now','-7 days')"
npx wrangler d1 execute openai-image-proxy --remote --command "SELECT cp.pack_id, COUNT(*) n, SUM(cp.amount_usd_cents) cents FROM credit_purchases cp WHERE cp.app_id='pixie' AND cp.status='completed' AND cp.created_at >= datetime('now','-7 days') GROUP BY cp.pack_id"
npx wrangler d1 execute openai-image-proxy --remote --command "SELECT COUNT(*) gens, SUM(credits_charged) credits FROM stored_images si JOIN users u ON u.id=si.user_id WHERE u.app_id='pixie' AND si.created_at >= datetime('now','-7 days')"
npx wrangler d1 execute openai-image-proxy --remote --command "SELECT COUNT(*) reports FROM image_reports WHERE app_id='pixie' AND created_at >= datetime('now','-7 days')"
```

Provider cost sanity (margin guard, §1 of the playbook): weekly credits spent × $0.0033 must stay under 25% of weekly proceeds. Flag if not.

Review texts (for the reply-within-48h duty):

```bash
curl -s "https://itunes.apple.com/us/rss/customerreviews/page=1/id=6751730339/sortby=mostrecent/json"
```

Image reports (UGC duty — Guideline 1.2 requires timely action):

```bash
npx wrangler d1 execute openai-image-proxy --remote --command "SELECT image_id, reason, created_at FROM image_reports WHERE app_id='pixie' ORDER BY created_at DESC LIMIT 20"
```

Any reported image: review the prompt via stored_images, propose keep/remove. Removal is `DELETE FROM stored_images WHERE id=?` plus the R2 object — propose, never auto-act.

## 2. Record

Append one row to `docs/metrics.csv` (create with header if absent):

```
date,us_ratings,us_avg,downloads_wk,new_users_wk,buyers_wk,credit_units_wk,proceeds_wk_cents,gens_wk,credits_spent_wk,reports_open,notes
```

Commit it.

## 3. Evaluate gates (full table in docs/store-playbook.md §4)

- Day 30 post-1.3.0 (2026-07-11): ≥150 downloads AND ≥3 paying users → hold; else re-cut screenshots 1–3 / test subtitle. <50 downloads = ASO iteration before any product work.
- Day 60 (2026-08-10): download→paid ≥1.4% → press (web checkout for large packs, PPP pricing). <0.5% → paywall structure experiments before price moves.
- Day 90 (2026-09-09): proceeds ≥$100/mo → experiment cadence; ≈0 with healthy funnel top → positioning vs free ChatGPT/Gemini image gen, not pricing. Subscription revisit gate: proceeds ≥$200/mo AND ≥30% repeat-purchase rate. **Never ship features to fix a funnel.**

## 4. Output

One short report: the new row, week-over-week deltas, which gate window is active, the single recommended action, any unanswered reviews (draft replies, ask before posting), and any open image reports with a keep/remove proposal.
