-- Drop all existing tables
DROP TABLE IF EXISTS credit_transactions;
DROP TABLE IF EXISTS credit_purchases;
DROP TABLE IF EXISTS user_credits;
DROP TABLE IF EXISTS device_auth_flows;
DROP TABLE IF EXISTS usage_records;
DROP TABLE IF EXISTS stored_images;
DROP TABLE IF EXISTS user_locks;
DROP TABLE IF EXISTS users;

-- Create users table
CREATE TABLE users (
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
    provider TEXT NOT NULL DEFAULT 'gemini',
    size TEXT NOT NULL,
    quality TEXT,
    created_at TIMESTAMP NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    token_usage INTEGER DEFAULT 0,
    openai_cost_cents INTEGER DEFAULT 0,
    cost_cents INTEGER DEFAULT 0,
    credits_charged INTEGER DEFAULT 0,
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
    provider TEXT NOT NULL DEFAULT 'gemini',
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
    simplified_cost BOOLEAN DEFAULT 0,
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

-- Create user_credits table
CREATE TABLE user_credits (
    user_id TEXT PRIMARY KEY,
    balance INTEGER NOT NULL DEFAULT 0,
    lifetime_purchased INTEGER NOT NULL DEFAULT 0,
    lifetime_spent INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Create credit_transactions table
CREATE TABLE credit_transactions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('purchase', 'spend', 'refund', 'bonus', 'admin_adjustment')),
    amount INTEGER NOT NULL,
    balance_after INTEGER NOT NULL,
    description TEXT NOT NULL,
    reference_id TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_credit_transactions_user_id ON credit_transactions(user_id);
CREATE INDEX idx_credit_transactions_created_at ON credit_transactions(created_at);

-- Create credit_purchases table
CREATE TABLE credit_purchases (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    pack_id TEXT NOT NULL,
    credits INTEGER NOT NULL,
    amount_usd_cents INTEGER NOT NULL,
    payment_provider TEXT NOT NULL,
    payment_id TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_credit_purchases_user_id ON credit_purchases(user_id);
CREATE INDEX idx_credit_purchases_status ON credit_purchases(status);

-- Create user_locks table for rate limiting (1 concurrent request per user)
CREATE TABLE user_locks (
    user_id TEXT PRIMARY KEY,
    acquired_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_locks_acquired_at ON user_locks(acquired_at);