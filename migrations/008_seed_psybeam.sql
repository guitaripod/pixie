-- 008: seed the Psybeam tenant + the realtime-translation session ledger.
--
-- Psybeam's capability is a STREAMING WebRTC translation metered by the minute,
-- not a request->response call. 1 credit = 1 translated minute. A session
-- reserves a block of minutes up-front (deducted on /start), then settles the
-- actual minutes used (refunding the unused remainder on /settle). rc_project_id
-- is filled in once the RevenueCat project + IAP products exist.

INSERT OR REPLACE INTO apps
    (app_id, name, enabled, rc_project_id, rc_product_prefix, apple_team_id, apple_app_bundle_id, enabled_capabilities, new_user_free_credits, premium_entitlement)
VALUES
    ('psybeam', 'Psybeam', 1, NULL, 'com.guitaripod.psybeam.credits.', 'P4DQK6SRKR', 'com.guitaripod.psybeam', 'realtime.translate', 15, NULL);

-- Minute bundles (1 credit = 1 minute).
INSERT OR REPLACE INTO credit_packs (app_id, pack_id, name, credits, bonus_credits, price_usd_cents, description, sort_order) VALUES
    ('psybeam', 'small',  'Small',   30, 0, 199, '30 minutes',  0),
    ('psybeam', 'medium', 'Medium', 120, 0, 499, '120 minutes', 1),
    ('psybeam', 'large',  'Large',  300, 0, 999, '300 minutes', 2);

-- flat_credits is the PER-MINUTE rate for this streaming capability (the realtime
-- handler multiplies it by the reserved/used minutes).
INSERT OR REPLACE INTO capability_costs (app_id, capability, flat_credits) VALUES
    ('psybeam', 'realtime.translate', 1);

-- Reservation ledger for streaming sessions: reserve on /start, settle on /settle.
CREATE TABLE IF NOT EXISTS realtime_sessions (
    id               TEXT PRIMARY KEY,
    app_id           TEXT NOT NULL,
    user_id          TEXT NOT NULL,
    capability       TEXT NOT NULL,
    rate_credits     INTEGER NOT NULL,
    reserved_minutes INTEGER NOT NULL,
    reserved_credits INTEGER NOT NULL,
    actual_minutes   INTEGER,
    refunded_credits INTEGER,
    settled          INTEGER NOT NULL DEFAULT 0,
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    settled_at       TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_realtime_sessions_user ON realtime_sessions(app_id, user_id, settled);
