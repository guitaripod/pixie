-- 002: multi-tenant generalization. Additive + backfill to app_id='pixie' so the
-- live single-tenant app keeps working unchanged. SQLite/D1 caveats handled:
-- ADD COLUMN needs a constant default (the default IS the backfill); a PK change
-- requires a table rebuild (create-copy-drop-rename).

-- USERS: tenant scope. provider_id uniqueness becomes per-app via a new index.
ALTER TABLE users ADD COLUMN app_id TEXT NOT NULL DEFAULT 'pixie';
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_app_provider ON users(app_id, provider, provider_id);
CREATE INDEX IF NOT EXISTS idx_users_app_api_key ON users(app_id, api_key);

-- USER_CREDITS: wallet keyed (app_id, user_id) -> rebuild for composite PK.
CREATE TABLE user_credits_new (
    app_id TEXT NOT NULL DEFAULT 'pixie',
    user_id TEXT NOT NULL,
    balance INTEGER NOT NULL DEFAULT 0,
    lifetime_purchased INTEGER NOT NULL DEFAULT 0,
    lifetime_spent INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (app_id, user_id)
);
INSERT INTO user_credits_new (app_id, user_id, balance, lifetime_purchased, lifetime_spent, created_at, updated_at)
    SELECT 'pixie', user_id, balance, lifetime_purchased, lifetime_spent, created_at, updated_at FROM user_credits;
DROP TABLE user_credits;
ALTER TABLE user_credits_new RENAME TO user_credits;

-- LEDGER + PURCHASES + USAGE + IMAGES: additive app_id, backfilled by default.
ALTER TABLE credit_transactions ADD COLUMN app_id TEXT NOT NULL DEFAULT 'pixie';
ALTER TABLE credit_purchases    ADD COLUMN app_id TEXT NOT NULL DEFAULT 'pixie';
ALTER TABLE usage_records       ADD COLUMN app_id TEXT NOT NULL DEFAULT 'pixie';
ALTER TABLE stored_images       ADD COLUMN app_id TEXT NOT NULL DEFAULT 'pixie';

-- USAGE generalization: capability + credits + free-form metadata. Image columns
-- stay (legacy); non-image capabilities insert '' / 0 sentinels.
ALTER TABLE usage_records ADD COLUMN capability TEXT NOT NULL DEFAULT 'image.generate';
ALTER TABLE usage_records ADD COLUMN credits_charged INTEGER NOT NULL DEFAULT 0;
ALTER TABLE usage_records ADD COLUMN metadata TEXT;

-- LOCKS: scope per app -> rebuild for composite PK.
CREATE TABLE user_locks_new (
    app_id TEXT NOT NULL DEFAULT 'pixie',
    user_id TEXT NOT NULL,
    acquired_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (app_id, user_id)
);
INSERT INTO user_locks_new (app_id, user_id, acquired_at)
    SELECT 'pixie', user_id, acquired_at FROM user_locks;
DROP TABLE user_locks;
ALTER TABLE user_locks_new RENAME TO user_locks;

-- DEVICE AUTH: scope per app.
ALTER TABLE device_auth_flows ADD COLUMN app_id TEXT NOT NULL DEFAULT 'pixie';

-- Composite indexes for the hot paths.
CREATE INDEX IF NOT EXISTS idx_usage_records_app_user ON usage_records(app_id, user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_credit_transactions_app_user ON credit_transactions(app_id, user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_credit_purchases_app_payment ON credit_purchases(app_id, payment_provider, payment_id);
