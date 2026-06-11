UPDATE apps SET new_user_free_credits = 25 WHERE app_id = 'pixie';

UPDATE credit_packs SET bonus_credits = 75,
    description = 'Great for regular use (~26 Nano Banana images)'
    WHERE app_id = 'pixie' AND pack_id = 'basic';
UPDATE credit_packs SET bonus_credits = 364,
    description = 'Most popular! 32% bonus credits (~71 images)'
    WHERE app_id = 'pixie' AND pack_id = 'popular';
UPDATE credit_packs SET bonus_credits = 1076,
    description = 'For power users — 49% bonus (~154 images)'
    WHERE app_id = 'pixie' AND pack_id = 'business';
UPDATE credit_packs SET bonus_credits = 2833,
    description = 'Best value — 68% bonus (~333 images)'
    WHERE app_id = 'pixie' AND pack_id = 'enterprise';
UPDATE credit_packs SET
    description = 'Perfect for trying out (~7 Nano Banana images)'
    WHERE app_id = 'pixie' AND pack_id = 'starter';

CREATE TABLE IF NOT EXISTS image_reports (
    id TEXT PRIMARY KEY,
    app_id TEXT NOT NULL,
    image_id TEXT NOT NULL,
    reporter_user_id TEXT NOT NULL,
    reason TEXT,
    created_at TIMESTAMP NOT NULL,
    UNIQUE(app_id, image_id, reporter_user_id)
);

CREATE INDEX IF NOT EXISTS idx_image_reports_app_image ON image_reports(app_id, image_id);
