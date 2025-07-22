use worker::*;

mod models;
mod error;
mod auth;
mod handlers;
mod storage;
mod deployment;
mod credits;
mod crypto_payments;
mod stripe_payments;
mod rate_limit;

use handlers::{images, gallery, r2, usage, oauth, device_auth};

#[event(fetch)]
async fn main(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    console_error_panic_hook::set_once();
    
    let router = Router::new();
    
    router
        .get("/", |_, _| {
            Response::ok("OpenAI Image Proxy - Ready")
        })
        .post_async("/v1/images/generations", images::handle_generation)
        .post_async("/v1/images/edits", images::handle_edit)
        .get_async("/v1/images", gallery::list_images)
        .get_async("/v1/images/user/:user_id", gallery::list_user_images)
        .get_async("/v1/images/:image_id", gallery::get_image)
        .get_async("/r2/:user_id/:image_id", r2::serve_image)
        .get_async("/v1/usage/users/:user_id", usage::get_user_usage)
        .get_async("/v1/usage/users/:user_id/details", usage::get_user_usage_details)
        .get_async("/v1/usage/system", usage::get_system_usage)
        .get_async("/v1/auth/github", oauth::github_auth_start)
        .post_async("/v1/auth/github/callback", oauth::github_auth_callback)
        .get_async("/v1/auth/google", oauth::google_auth_start)
        .post_async("/v1/auth/google/callback", oauth::google_auth_callback)
        .post_async("/v1/auth/device/code", device_auth::start_device_flow)
        .post_async("/v1/auth/device/token", device_auth::poll_device_token)
        .get_async("/v1/auth/device/:device_code/status", device_auth::device_auth_status)
        .get_async("/v1/credits/balance", handlers::credits::get_balance)
        .get_async("/v1/credits/transactions", handlers::credits::list_transactions)
        .get_async("/v1/credits/packs", handlers::credits::list_packs)
        .post_async("/v1/credits/estimate", handlers::credits::estimate_cost)
        .post_async("/v1/credits/purchase", handlers::credits::purchase_credits)
        .get_async("/v1/credits/purchase/:purchase_id/status", handlers::credits::get_purchase_status)
        .post_async("/v1/credits/webhook", handlers::credits::complete_purchase_webhook)
        .post_async("/v1/credits/webhook/crypto", handlers::credits::crypto_payment_webhook)
        .post_async("/v1/ipn/nowpayments", handlers::credits::crypto_payment_webhook)
        .post_async("/v1/credits/purchase/stripe", handlers::credits::create_stripe_checkout)
        .post_async("/v1/stripe/webhook", handlers::credits::stripe_webhook)
        .get_async("/v1/stripe/config", handlers::credits::get_stripe_config)
        .post_async("/v1/admin/credits/adjust", handlers::credits::admin_adjust_credits)
        .get_async("/v1/admin/credits/stats", handlers::credits::admin_system_stats)
        .run(req, env)
        .await
}