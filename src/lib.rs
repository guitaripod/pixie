use worker::*;

mod models;
mod error;
mod auth;
mod handlers;
mod storage;
mod deployment;

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
        .run(req, env)
        .await
}