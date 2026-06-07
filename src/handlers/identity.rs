use worker::{Request, Response, RouteContext, Result, console_log, D1Database, Fetch, Method, Headers, RequestInit};
use crate::error::AppError;
use crate::auth::{resolve_app_id, authenticate};
use crate::credits::{initialize_user_credits, add_credits, get_user_balance};
use crate::handlers::oauth_native::validate_apple_identity_token;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use uuid::Uuid;
use chrono::Utc;

#[cfg(not(target_os = "windows"))]
use jwt_simple::prelude::*;

const ANON_PROVIDER: &str = "anonymous";
const DEVICECHECK_HOST_PROD: &str = "https://api.devicecheck.apple.com";
const DEVICECHECK_HOST_DEV: &str = "https://api.development.devicecheck.apple.com";

#[derive(Debug, Serialize)]
pub struct IdentityResponse {
    pub api_key: String,
    pub user_id: String,
}

#[derive(Debug, Deserialize)]
pub struct AnonymousRegisterRequest {
    /// Apple DeviceCheck token (DCDevice.generateToken) — proves a genuine device.
    pub device_token: Option<String>,
    /// Stable per-app device id persisted in the Keychain — the per-app idempotency key.
    pub client_device_id: Option<String>,
    /// Non-production simulator/dev fallback only.
    pub device_id: Option<String>,
    pub unverified: Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct LinkRequest {
    pub identity_token: String,
}

pub async fn anonymous_register(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    match anonymous_register_inner(req, ctx).await {
        Ok(response) => Ok(response),
        Err(e) => e.to_response(),
    }
}

async fn anonymous_register_inner(
    mut req: Request,
    ctx: RouteContext<()>,
) -> std::result::Result<Response, AppError> {
    let app_id = resolve_app_id(&req);
    let body: AnonymousRegisterRequest = req
        .json()
        .await
        .map_err(|_| AppError::BadRequest("Invalid request body".to_string()))?;

    let db = ctx.env.d1("DB")?;

    if let Some(device_token) = body.device_token.as_ref().filter(|t| !t.is_empty()) {
        let client_device_id = body
            .client_device_id
            .as_deref()
            .filter(|s| !s.is_empty())
            .ok_or_else(|| AppError::BadRequest("Missing client_device_id".to_string()))?;
        return register_with_devicecheck(&ctx, &db, &app_id, device_token, client_device_id).await;
    }

    if body.unverified == Some(true) {
        let device_id = verify_unverified(&ctx, body.device_id.as_deref())?;
        let (user_id, api_key) = create_or_reuse_anonymous(&db, &app_id, &device_id).await?;
        return Response::from_json(&IdentityResponse { api_key, user_id }).map_err(AppError::from);
    }

    Err(AppError::BadRequest("Missing device_token or unverified device_id".to_string()))
}

#[cfg(target_os = "windows")]
async fn register_with_devicecheck(
    _ctx: &RouteContext<()>,
    _db: &D1Database,
    _app_id: &str,
    _device_token: &str,
    _client_device_id: &str,
) -> std::result::Result<Response, AppError> {
    Err(AppError::InternalError("DeviceCheck is not supported on Windows servers".to_string()))
}

#[cfg(not(target_os = "windows"))]
async fn register_with_devicecheck(
    ctx: &RouteContext<()>,
    db: &D1Database,
    app_id: &str,
    device_token: &str,
    client_device_id: &str,
) -> std::result::Result<Response, AppError> {
    let cfg = DeviceCheckConfig::load(ctx)?;
    let jwt = cfg.sign_jwt()?;

    // Gate: prove this request comes from a genuine Apple device (blocks
    // emulator/script farming). Apple performs the verification server-side.
    cfg.validate_device(&jwt, device_token).await?;

    // Per-app, per-device idempotent grant. The unique index
    // (app_id, provider, provider_id) makes first-insert-wins atomic, so a real
    // device gets the free trial exactly once per app regardless of concurrency.
    let (user_id, api_key) = create_or_reuse_anonymous(db, app_id, client_device_id).await?;
    Response::from_json(&IdentityResponse { api_key, user_id }).map_err(AppError::from)
}

#[cfg(not(target_os = "windows"))]
struct DeviceCheckConfig {
    base: String,
    team_id: String,
    key_id: String,
    private_key: String,
}

#[cfg(not(target_os = "windows"))]
impl DeviceCheckConfig {
    fn load(ctx: &RouteContext<()>) -> std::result::Result<Self, AppError> {
        let team_id = ctx
            .env
            .var("APPLE_TEAM_ID")
            .map(|v| v.to_string())
            .map_err(|_| AppError::InternalError("APPLE_TEAM_ID not configured".to_string()))?;

        let key_id = ctx
            .env
            .var("DEVICECHECK_KEY_ID")
            .map(|v| v.to_string())
            .or_else(|_| ctx.env.secret("DEVICECHECK_KEY_ID").map(|v| v.to_string()))
            .map_err(|_| AppError::InternalError("DEVICECHECK_KEY_ID not configured".to_string()))?;

        let private_key = ctx
            .env
            .secret("DEVICECHECK_PRIVATE_KEY")
            .map(|v| v.to_string())
            .map_err(|_| AppError::InternalError("DEVICECHECK_PRIVATE_KEY not configured".to_string()))?;

        let base = Self::resolve_base(ctx).to_string();

        Ok(Self { base, team_id, key_id, private_key })
    }

    /// Pick the DeviceCheck host. Dev-signed app tokens only validate against the
    /// development host, so we default to development unless the deployment is
    /// explicitly production. Production is selected only when `ENVIRONMENT` is
    /// "production" AND `DEVICECHECK_ENV` is not "development".
    fn resolve_base(ctx: &RouteContext<()>) -> &'static str {
        let environment = ctx
            .env
            .var("ENVIRONMENT")
            .map(|v| v.to_string())
            .unwrap_or_else(|_| "development".to_string());
        let devicecheck_env = ctx
            .env
            .var("DEVICECHECK_ENV")
            .map(|v| v.to_string())
            .unwrap_or_default();

        if environment != "production" || devicecheck_env == "development" {
            DEVICECHECK_HOST_DEV
        } else {
            DEVICECHECK_HOST_PROD
        }
    }

    fn sign_jwt(&self) -> std::result::Result<String, AppError> {
        let claims = Claims::create(Duration::from_mins(10)).with_issuer(&self.team_id);

        let key_pair = ES256KeyPair::from_pem(&self.private_key)
            .map_err(|e| AppError::InternalError(format!("Failed to parse DeviceCheck key: {}", e)))?
            .with_key_id(&self.key_id);

        key_pair
            .sign(claims)
            .map_err(|e| AppError::InternalError(format!("Failed to sign DeviceCheck JWT: {}", e)))
    }

    fn request_body(&self, device_token: &str) -> Value {
        json!({
            "device_token": device_token,
            "transaction_id": Uuid::new_v4().to_string(),
            "timestamp": Utc::now().timestamp_millis(),
        })
    }

    async fn post(&self, jwt: &str, path: &str, body: &Value) -> std::result::Result<Response, AppError> {
        let url = format!("{}{}", self.base, path);
        let headers = Headers::new();
        headers.set("Authorization", &format!("Bearer {}", jwt))?;
        headers.set("Content-Type", "application/json")?;

        let body_str = body.to_string();
        let request = Request::new_with_init(
            &url,
            RequestInit::new()
                .with_method(Method::Post)
                .with_headers(headers)
                .with_body(Some(worker::wasm_bindgen::JsValue::from_str(&body_str))),
        )?;

        Fetch::Request(request)
            .send()
            .await
            .map_err(AppError::from)
    }

    /// Confirm the DeviceCheck token is a genuine, current Apple-issued device
    /// token. Any non-2xx => reject (no user created, no grant).
    async fn validate_device(&self, jwt: &str, device_token: &str) -> std::result::Result<(), AppError> {
        let body = self.request_body(device_token);
        let mut resp = self.post(jwt, "/v1/validate_device_token", &body).await?;
        let status = resp.status_code();
        if !(200..300).contains(&status) {
            let detail = resp.text().await.unwrap_or_default();
            console_log!("DeviceCheck validate_device_token failed: {} {}", status, detail);
            return Err(AppError::BadRequest("device validation failed".to_string()));
        }
        Ok(())
    }
}

fn verify_unverified(ctx: &RouteContext<()>, device_id: Option<&str>) -> std::result::Result<String, AppError> {
    let environment = ctx
        .env
        .var("ENVIRONMENT")
        .map(|v| v.to_string())
        .unwrap_or_else(|_| "production".to_string());
    if environment == "production" {
        return Err(AppError::BadRequest("unverified registration not allowed".to_string()));
    }
    let device_id = device_id
        .filter(|s| !s.is_empty())
        .ok_or_else(|| AppError::BadRequest("Missing device_id".to_string()))?;
    Ok(device_id.to_string())
}

async fn fetch_apple_app_identity(db: &D1Database, app_id: &str) -> std::result::Result<(String, String), AppError> {
    let row = db
        .prepare("SELECT apple_team_id, apple_app_bundle_id FROM apps WHERE app_id = ?")
        .bind(&[app_id.into()])?
        .first::<Value>(None)
        .await?
        .ok_or_else(|| AppError::BadRequest("Unknown app".to_string()))?;

    let team_id = row
        .get("apple_team_id")
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty())
        .ok_or_else(|| AppError::BadRequest("App missing apple_team_id".to_string()))?
        .to_string();
    let bundle_id = row
        .get("apple_app_bundle_id")
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty())
        .ok_or_else(|| AppError::BadRequest("App missing apple_app_bundle_id".to_string()))?
        .to_string();

    Ok((team_id, bundle_id))
}

/// Create the anonymous user for `device_key`, or return the existing one.
/// Idempotency is enforced atomically by the unique index
/// (app_id, provider, provider_id) via ON CONFLICT DO NOTHING: the free trial is
/// granted only on the row that is actually inserted, so concurrent or repeated
/// calls for the same device never double-grant.
async fn create_or_reuse_anonymous(
    db: &D1Database,
    app_id: &str,
    device_key: &str,
) -> std::result::Result<(String, String), AppError> {
    let new_user_id = Uuid::new_v4().to_string();
    let new_api_key = format!("pixie_{}", Uuid::new_v4().to_string().replace("-", ""));
    let now = Utc::now().to_rfc3339();

    let result = db
        .prepare(
            "INSERT INTO users (id, app_id, email, provider, provider_id, name, api_key, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
             ON CONFLICT(app_id, provider, provider_id) DO NOTHING",
        )
        .bind(&[
            new_user_id.clone().into(),
            app_id.into(),
            worker::wasm_bindgen::JsValue::NULL,
            ANON_PROVIDER.into(),
            device_key.into(),
            "Anonymous".into(),
            new_api_key.clone().into(),
            now.clone().into(),
            now.into(),
        ])?
        .run()
        .await?;

    let inserted = result.meta().ok().flatten().and_then(|m| m.changes).unwrap_or(0) > 0;

    if inserted {
        initialize_user_credits(app_id, &new_user_id, db).await?;
        console_log!("Created anonymous user: {}", new_user_id);
        return Ok((new_user_id, new_api_key));
    }

    let existing = db
        .prepare("SELECT id, api_key FROM users WHERE app_id = ? AND provider = ? AND provider_id = ?")
        .bind(&[app_id.into(), ANON_PROVIDER.into(), device_key.into()])?
        .first::<Value>(None)
        .await?
        .ok_or_else(|| AppError::InternalError("Anonymous user lookup failed".to_string()))?;

    let user_id = existing.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string();
    let api_key = existing.get("api_key").and_then(|v| v.as_str()).unwrap_or("").to_string();
    if user_id.is_empty() || api_key.is_empty() {
        return Err(AppError::InternalError("Anonymous user lookup failed".to_string()));
    }
    console_log!("Reusing anonymous user: {}", user_id);
    Ok((user_id, api_key))
}

pub async fn link(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    match link_inner(req, ctx).await {
        Ok(response) => Ok(response),
        Err(e) => e.to_response(),
    }
}

async fn link_inner(
    mut req: Request,
    ctx: RouteContext<()>,
) -> std::result::Result<Response, AppError> {
    let app_id = resolve_app_id(&req);
    let db = ctx.env.d1("DB")?;

    let anon = authenticate(&req, &db).await?;

    let body: LinkRequest = req
        .json()
        .await
        .map_err(|_| AppError::BadRequest("Invalid request body".to_string()))?;

    let (_, bundle_id) = fetch_apple_app_identity(&db, &app_id).await?;
    let claims = validate_apple_identity_token(&body.identity_token, &bundle_id).await?;

    let existing_apple = db
        .prepare("SELECT id, api_key FROM users WHERE app_id = ? AND provider = ? AND provider_id = ?")
        .bind(&[app_id.clone().into(), "apple".into(), claims.sub.clone().into()])?
        .first::<Value>(None)
        .await?;

    if let Some(apple_user) = existing_apple {
        let existing_id = apple_user.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string();
        let existing_api_key = apple_user.get("api_key").and_then(|v| v.as_str()).unwrap_or("").to_string();

        if existing_id == anon.user_id {
            return Response::from_json(&IdentityResponse {
                api_key: existing_api_key,
                user_id: existing_id,
            })
            .map_err(AppError::from);
        }

        let anon_balance = get_user_balance(&app_id, &anon.user_id, &db).await? as u32;
        if anon_balance > 0 {
            add_credits(
                &app_id,
                &existing_id,
                anon_balance,
                "admin_adjustment",
                "merge from anonymous",
                Some(&anon.user_id),
                &db,
            )
            .await?;

            zero_wallet(&db, &app_id, &anon.user_id).await?;
        }

        console_log!("Merged anonymous {} into apple user {}", anon.user_id, existing_id);
        return Response::from_json(&IdentityResponse {
            api_key: existing_api_key,
            user_id: existing_id,
        })
        .map_err(AppError::from);
    }

    relink_anonymous_to_apple(&db, &app_id, &anon.user_id, &claims).await?;

    let api_key = db
        .prepare("SELECT api_key FROM users WHERE app_id = ? AND id = ?")
        .bind(&[app_id.clone().into(), anon.user_id.clone().into()])?
        .first::<Value>(None)
        .await?
        .and_then(|v| v.get("api_key").and_then(|k| k.as_str()).map(|s| s.to_string()))
        .ok_or_else(|| AppError::InternalError("User vanished during link".to_string()))?;

    console_log!("Relinked anonymous {} to apple", anon.user_id);
    Response::from_json(&IdentityResponse {
        api_key,
        user_id: anon.user_id,
    })
    .map_err(AppError::from)
}

async fn relink_anonymous_to_apple(
    db: &D1Database,
    app_id: &str,
    user_id: &str,
    claims: &crate::handlers::oauth_native::AppleIdTokenClaims,
) -> std::result::Result<(), AppError> {
    let now = Utc::now().to_rfc3339();
    let email = claims
        .email
        .clone()
        .unwrap_or_else(|| format!("{}@privaterelay.appleid.com", claims.sub.chars().take(8).collect::<String>()));

    db.prepare("UPDATE users SET provider = ?, provider_id = ?, email = ?, name = ?, updated_at = ? WHERE app_id = ? AND id = ? AND provider = ?")
        .bind(&[
            "apple".into(),
            claims.sub.clone().into(),
            email.into(),
            "Apple User".into(),
            now.into(),
            app_id.into(),
            user_id.into(),
            ANON_PROVIDER.into(),
        ])?
        .run()
        .await?;

    Ok(())
}

async fn zero_wallet(db: &D1Database, app_id: &str, user_id: &str) -> std::result::Result<(), AppError> {
    let now = Utc::now().to_rfc3339();
    db.prepare("UPDATE user_credits SET balance = 0, updated_at = ? WHERE app_id = ? AND user_id = ?")
        .bind(&[now.into(), app_id.into(), user_id.into()])?
        .run()
        .await?;
    Ok(())
}
