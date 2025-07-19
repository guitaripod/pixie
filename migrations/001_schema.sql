-- Drop all existing tables
DROP TABLE IF EXISTS device_auth_flows;
DROP TABLE IF EXISTS usage_records;
DROP TABLE IF EXISTS stored_images;
DROP TABLE IF EXISTS users;

-- Create users table
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    provider TEXT NOT NULL,
    provider_id TEXT NOT NULL,
    email TEXT,
    name TEXT,
    api_key TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    UNIQUE(provider, provider_id)
);

CREATE INDEX idx_users_api_key ON users(api_key);
CREATE INDEX idx_users_provider ON users(provider, provider_id);

-- Create stored_images table
CREATE TABLE stored_images (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    r2_key TEXT NOT NULL,
    prompt TEXT NOT NULL,
    model TEXT NOT NULL,
    size TEXT NOT NULL,
    quality TEXT,
    created_at TIMESTAMP NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    token_usage INTEGER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_stored_images_user_id ON stored_images(user_id);
CREATE INDEX idx_stored_images_created_at ON stored_images(created_at);

-- Create usage_records table
CREATE TABLE usage_records (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    request_type TEXT NOT NULL,
    model TEXT NOT NULL,
    prompt TEXT NOT NULL,
    image_size TEXT NOT NULL,
    image_quality TEXT NOT NULL,
    image_count INTEGER NOT NULL,
    input_images_count INTEGER,
    total_tokens INTEGER NOT NULL,
    input_tokens INTEGER NOT NULL,
    output_tokens INTEGER NOT NULL,
    text_tokens INTEGER NOT NULL,
    image_tokens INTEGER NOT NULL,
    r2_keys TEXT NOT NULL,
    response_time_ms INTEGER NOT NULL,
    error TEXT,
    created_at TIMESTAMP NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_usage_records_user_id ON usage_records(user_id);
CREATE INDEX idx_usage_records_created_at ON usage_records(created_at);

-- Create device_auth_flows table
CREATE TABLE device_auth_flows (
    id TEXT PRIMARY KEY,
    device_code TEXT NOT NULL,
    user_code TEXT NOT NULL,
    client_type TEXT NOT NULL,
    provider TEXT NOT NULL DEFAULT 'github',
    user_id TEXT,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_device_auth_flows_device_code ON device_auth_flows(device_code);
CREATE INDEX idx_device_auth_flows_expires_at ON device_auth_flows(expires_at);