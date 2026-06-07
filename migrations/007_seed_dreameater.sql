-- 007: seed the Dream Eater tenant (data, idempotent). Applied to prod ad-hoc on
-- 2026-06-07; kept here for reproducibility. 1 dream = a flat 1 credit
-- (chat.completion=1, image.generate folded in at 0). Premium subscribers
-- (entitlement 'premium') bypass the charge, verified server-side.
INSERT OR REPLACE INTO apps
    (app_id, name, enabled, rc_project_id, rc_product_prefix, apple_team_id, apple_app_bundle_id, enabled_capabilities, new_user_free_credits, premium_entitlement)
VALUES
    ('dreameater', 'Dream Eater', 1, 'proj664eb851', 'com.dreameater.credits.', 'P4DQK6SRKR', 'com.marcusziade.DreamEater', 'chat.completion,image.generate', 1, 'premium');

INSERT OR REPLACE INTO credit_packs (app_id, pack_id, name, credits, bonus_credits, price_usd_cents, description, sort_order) VALUES
    ('dreameater', 'small', 'Small Pack', 5, 0, 299, '5 dreams', 0),
    ('dreameater', 'large', 'Large Pack', 15, 0, 699, '15 dreams', 1),
    ('dreameater', 'mega', 'Mega Pack', 50, 0, 1499, '50 dreams', 2),
    ('dreameater', 'giga', 'Giga Pack', 100, 0, 2499, '100 dreams', 3);

INSERT OR REPLACE INTO capability_costs (app_id, capability, flat_credits) VALUES
    ('dreameater', 'chat.completion', 1),
    ('dreameater', 'image.generate', 0);
