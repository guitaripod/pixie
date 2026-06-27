-- 013: reconcile the Psybeam tenant's live economics into migration history.
--
-- After 008 seeded Psybeam (15 free credits; packs small/medium/large at
-- 30/120/300 min for $1.99/$4.99/$9.99), the welcome grant and the minute packs
-- were re-tuned directly in prod D1 and never captured in a migration — so the
-- seed history no longer reproduced live. This brings 008's values in line with
-- prod (queried 2026-06-27), the same way 009 recorded Pixie's relaunch.
-- 1 credit = 1 translated minute throughout.

-- Welcome bonus: 15 -> 5 minutes.
UPDATE apps SET new_user_free_credits = 5 WHERE app_id = 'psybeam';

-- Minute packs re-priced:
--   small  30 min/$1.99  -> 45 min/$4.99
--   medium 120 min/$4.99 -> 120 min/$9.99
--   large  300 min/$9.99 -> 300 min/$19.99
UPDATE credit_packs SET credits = 45,  price_usd_cents = 499,  description = '45 minutes'  WHERE app_id = 'psybeam' AND pack_id = 'small';
UPDATE credit_packs SET credits = 120, price_usd_cents = 999,  description = '120 minutes' WHERE app_id = 'psybeam' AND pack_id = 'medium';
UPDATE credit_packs SET credits = 300, price_usd_cents = 1999, description = '300 minutes' WHERE app_id = 'psybeam' AND pack_id = 'large';
