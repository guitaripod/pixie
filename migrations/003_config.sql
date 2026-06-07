-- 003: per-tenant config. Non-secret config in D1 (queryable, no deploy to onboard
-- an app); secrets stay in wrangler with a per-app suffix convention.

CREATE TABLE IF NOT EXISTS apps (
    app_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    enabled INTEGER NOT NULL DEFAULT 1,
    rc_project_id TEXT,
    rc_product_prefix TEXT,
    apple_team_id TEXT,
    apple_app_bundle_id TEXT,
    enabled_capabilities TEXT NOT NULL DEFAULT 'image.generate',
    new_user_free_credits INTEGER NOT NULL DEFAULT 6,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Per-app credit packs (replaces hardcoded get_credit_packs()).
CREATE TABLE IF NOT EXISTS credit_packs (
    app_id TEXT NOT NULL DEFAULT 'pixie',
    pack_id TEXT NOT NULL,
    name TEXT NOT NULL,
    credits INTEGER NOT NULL,
    bonus_credits INTEGER NOT NULL DEFAULT 0,
    price_usd_cents INTEGER NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    sort_order INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (app_id, pack_id)
);

-- Optional per-app, per-capability cost overrides; absent -> built-in code cost fn.
CREATE TABLE IF NOT EXISTS capability_costs (
    app_id TEXT NOT NULL DEFAULT 'pixie',
    capability TEXT NOT NULL,
    flat_credits INTEGER,
    credit_multiplier REAL,
    PRIMARY KEY (app_id, capability)
);

-- Seed the live tenant so Pixie is unchanged.
INSERT OR IGNORE INTO apps
    (app_id, name, rc_project_id, rc_product_prefix, apple_team_id, apple_app_bundle_id, enabled_capabilities, new_user_free_credits)
VALUES
    ('pixie', 'Pixie', 'proj44fd2c32', 'com.guitaripod.pixie.credits.', 'P4DQK6SRKR', 'com.guitaripod.Pixie', 'image.generate,image.edit,chat.completion', 6);

-- Seed pixie packs = exact current hardcoded values.
INSERT OR IGNORE INTO credit_packs (app_id, pack_id, name, credits, bonus_credits, price_usd_cents, description, sort_order) VALUES
 ('pixie','starter','Starter',150,0,299,'Perfect for trying out (~30 low or 11 medium images)',0),
 ('pixie','basic','Basic',475,25,999,'Great for regular use (~38 medium images)',1),
 ('pixie','popular','Popular',1136,114,2499,'Our most popular pack! (~96 medium images)',2),
 ('pixie','business','Business',2174,326,4999,'For power users (~192 medium images)',3),
 ('pixie','enterprise','Enterprise',4167,833,9999,'Maximum value! (~384 medium images)',4);
