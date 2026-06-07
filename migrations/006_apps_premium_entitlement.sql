-- 006: add an optional premium-entitlement marker per app. When set, the worker
-- treats users holding that RevenueCat entitlement as "unlimited" and skips the
-- per-call credit charge (verified server-side against the RevenueCat REST API,
-- non-spoofable). NULL = the app has no premium tier (no RC check, no latency).
ALTER TABLE apps ADD COLUMN premium_entitlement TEXT;

UPDATE apps SET premium_entitlement = 'premium' WHERE app_id = 'dreameater';
