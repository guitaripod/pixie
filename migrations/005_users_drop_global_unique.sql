-- 005: drop the legacy table-level UNIQUE(provider, provider_id) on users that
-- survived 002 (which only ADDED idx_users_app_provider). Per-app uniqueness must
-- govern in a multi-tenant world: the same Apple `sub` (per Apple team) can
-- legitimately exist in two apps. SQLite can't drop a table-level constraint via
-- ALTER, so rebuild (create-copy-drop-rename), data-preserving.
--
-- `users` is referenced by FKs from 6 tables. The correct, data-safe procedure
-- (per the SQLite "Making Other Kinds Of Table Schema Changes" docs) is to run
-- `PRAGMA foreign_keys=OFF` for the duration of the rebuild, NOT
-- `defer_foreign_keys` — the latter does not suppress the FK violation raised by
-- DROP TABLE's implicit delete on D1, while foreign_keys=OFF does (verified on a
-- scratch D1 loaded from a prod backup). foreign_key_check confirms integrity
-- before re-enabling; all user ids are preserved so it returns no rows.
PRAGMA foreign_keys=OFF;

CREATE TABLE users_new (
    id TEXT PRIMARY KEY,
    provider TEXT NOT NULL,
    provider_id TEXT NOT NULL,
    email TEXT,
    name TEXT,
    api_key TEXT UNIQUE NOT NULL,
    is_admin BOOLEAN NOT NULL DEFAULT FALSE,
    preferred_model TEXT NOT NULL DEFAULT 'gemini-2.5-flash',
    gemini_api_key TEXT,
    openai_api_key TEXT,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    app_id TEXT NOT NULL DEFAULT 'pixie'
);

INSERT INTO users_new (id, provider, provider_id, email, name, api_key, is_admin, preferred_model, gemini_api_key, openai_api_key, created_at, updated_at, app_id)
    SELECT id, provider, provider_id, email, name, api_key, is_admin, preferred_model, gemini_api_key, openai_api_key, created_at, updated_at, app_id FROM users;

DROP TABLE users;
ALTER TABLE users_new RENAME TO users;

CREATE INDEX idx_users_api_key ON users(api_key);
CREATE INDEX idx_users_provider ON users(provider, provider_id);
CREATE UNIQUE INDEX idx_users_app_provider ON users(app_id, provider, provider_id);
CREATE INDEX idx_users_app_api_key ON users(app_id, api_key);

PRAGMA foreign_key_check;
PRAGMA foreign_keys=ON;
