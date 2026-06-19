ALTER TABLE stored_images ADD COLUMN is_public INTEGER NOT NULL DEFAULT 1;

CREATE INDEX IF NOT EXISTS idx_stored_images_app_public_created
    ON stored_images(app_id, is_public, created_at);
