use worker::{Request, Response, RouteContext, Result, console_log, Fetch, Method};
use crate::error::AppError;
use crate::auth::resolve_app_id;
use crate::credits::initialize_user_credits;
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::Utc;
use base64::{Engine as _, engine::general_purpose};
use std::collections::HashSet;

#[cfg(not(target_os = "windows"))]
use jwt_simple::prelude::*;

const APPLE_ISSUER: &str = "https://appleid.apple.com";
const APPLE_JWKS_URL: &str = "https://appleid.apple.com/auth/keys";

#[derive(Debug, Deserialize)]
pub struct GoogleTokenRequest {
    pub id_token: String,
}

#[derive(Debug, Serialize)]
pub struct AuthTokenResponse {
    pub api_key: String,
    pub user_id: String,
    pub is_admin: bool,
}

#[derive(Debug, Deserialize)]
struct GoogleIdTokenClaims {
    aud: String,  // Client ID
    sub: String,  // Google user ID
    email: String,
    name: Option<String>,
    #[allow(dead_code)]
    picture: Option<String>,
    // Google's tokeninfo returns this as a string "true"/"false"
    email_verified: Option<String>,
}

/// Handle native Google Sign-In tokens from mobile/desktop apps
pub async fn google_token_auth(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let app_id = resolve_app_id(&req);
    let token_req: GoogleTokenRequest = req.json().await?;
    
    // Get all valid client IDs from environment
    let mut valid_client_ids = Vec::new();
    
    // Add web client ID if it exists
    if let Ok(web_client_id) = ctx.env.var("GOOGLE_CLIENT_ID") {
        valid_client_ids.push(web_client_id.to_string());
    }
    
    // Add Android client ID if it exists
    if let Ok(android_client_id) = ctx.env.var("GOOGLE_ANDROID_CLIENT_ID") {
        valid_client_ids.push(android_client_id.to_string());
    }
    
    // Add iOS client ID if it exists
    if let Ok(ios_client_id) = ctx.env.var("GOOGLE_IOS_CLIENT_ID") {
        valid_client_ids.push(ios_client_id.to_string());
    }
    
    if valid_client_ids.is_empty() {
        return Err(AppError::InternalError("No Google client IDs configured".to_string()).into());
    }
    
    // Verify the ID token with Google
    let verify_url = format!(
        "https://oauth2.googleapis.com/tokeninfo?id_token={}",
        urlencoding::encode(&token_req.id_token)
    );
    
    let fetch_request = Request::new(&verify_url, Method::Get)?;
    let mut verify_response = Fetch::Request(fetch_request).send().await?;
    
    if verify_response.status_code() != 200 {
        return Err(AppError::Unauthorized("Invalid ID token".to_string()).into());
    }
    
    let token_info: GoogleIdTokenClaims = verify_response
        .json()
        .await
        .map_err(|e| AppError::InternalError(format!("Failed to parse token info: {}", e)))?;
    
    // Verify the audience (client ID) is one of our valid client IDs
    if !valid_client_ids.contains(&token_info.aud) {
        console_log!("Invalid client ID: {} not in {:?}", token_info.aud, valid_client_ids);
        return Err(AppError::Unauthorized("Invalid client ID".to_string()).into());
    }
    
    // Verify email is verified (Google returns "true"/"false" as strings)
    if token_info.email_verified != Some("true".to_string()) {
        return Err(AppError::Unauthorized("Email not verified".to_string()).into());
    }
    
    // Get database connection
    let db = ctx.env.d1("DB")?;
    
    // Check if user exists with this Google ID
    let existing_user = db
        .prepare("SELECT id, api_key, is_admin FROM users WHERE app_id = ?1 AND provider = ?2 AND provider_id = ?3")
        .bind(&[app_id.clone().into(), "google".into(), token_info.sub.clone().into()])?
        .first::<serde_json::Value>(None)
        .await?;

    let (user_id, api_key, is_admin) = if let Some(user_data) = existing_user {
        let id = user_data.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string();
        let key = user_data.get("api_key").and_then(|v| v.as_str()).unwrap_or("").to_string();
        let admin = user_data.get("is_admin").and_then(|v| v.as_i64()).unwrap_or(0) == 1;
        console_log!("Found existing user: {}", id);
        (id, key, admin)
    } else {
        // Create new user
        let new_user_id = Uuid::new_v4().to_string();
        let new_api_key = format!("pixie_{}", Uuid::new_v4().to_string().replace("-", ""));
        let now = Utc::now().to_rfc3339();

        console_log!("Creating new user: {}", new_user_id);

        db
            .prepare("INSERT INTO users (id, app_id, email, provider, provider_id, name, api_key, created_at, updated_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)")
            .bind(&[
                new_user_id.clone().into(),
                app_id.clone().into(),
                token_info.email.clone().into(),
                "google".into(),
                token_info.sub.into(),
                token_info.name.unwrap_or_else(|| "Google User".to_string()).into(),
                new_api_key.clone().into(),
                now.clone().into(),
                now.into(),
            ])?
            .run()
            .await?;

        // Initialize credits for new user
        initialize_user_credits(&app_id, &new_user_id, &db).await?;

        (new_user_id, new_api_key, false)
    };
    
    let response = AuthTokenResponse {
        api_key,
        user_id,
        is_admin,
    };
    
    Response::from_json(&response)
}

#[derive(Debug, Deserialize)]
pub struct AppleTokenRequest {
    pub identity_token: String,
}

#[derive(Debug)]
pub struct AppleIdTokenClaims {
    pub sub: String,
    pub email: Option<String>,
    #[allow(dead_code)]
    pub email_verified: Option<bool>,
}

#[cfg(not(target_os = "windows"))]
#[derive(Debug, Serialize, Deserialize)]
struct AppleCustomClaims {
    email: Option<String>,
    #[serde(default, deserialize_with = "deserialize_apple_bool")]
    email_verified: Option<bool>,
}

#[derive(Debug, Deserialize)]
struct AppleJwk {
    kty: String,
    kid: String,
    n: String,
    e: String,
}

#[derive(Debug, Deserialize)]
struct AppleJwks {
    keys: Vec<AppleJwk>,
}

/// Apple encodes `email_verified` inconsistently as either a JSON boolean or a
/// `"true"`/`"false"` string, so both shapes are normalized to `Option<bool>`.
#[cfg(not(target_os = "windows"))]
fn deserialize_apple_bool<'de, D>(deserializer: D) -> std::result::Result<Option<bool>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    use serde::Deserialize as _;
    let value = serde_json::Value::deserialize(deserializer)?;
    Ok(match value {
        serde_json::Value::Bool(b) => Some(b),
        serde_json::Value::String(s) => Some(s == "true"),
        _ => None,
    })
}

/// Cryptographically verify an Apple Sign-In identity token.
///
/// Confirms the JWT is RS256-signed by a key currently published in Apple's
/// JWKS, enforces issuer/audience/expiry via the verifier, and only then
/// returns the decoded claims. Fails closed: any parse, network, key-lookup, or
/// signature error yields `Err`.
#[cfg(target_os = "windows")]
pub async fn validate_apple_identity_token(
    _identity_token: &str,
    _expected_bundle_id: &str,
) -> std::result::Result<AppleIdTokenClaims, AppError> {
    Err(AppError::InternalError("Apple Sign-In is not supported on Windows servers".to_string()))
}

#[cfg(not(target_os = "windows"))]
pub async fn validate_apple_identity_token(
    identity_token: &str,
    expected_bundle_id: &str,
) -> std::result::Result<AppleIdTokenClaims, AppError> {
    let metadata = Token::decode_metadata(identity_token)
        .map_err(|_| AppError::Unauthorized("Invalid ID token".to_string()))?;

    if metadata.algorithm() != "RS256" {
        return Err(AppError::Unauthorized("Unsupported token algorithm".to_string()));
    }

    let kid = metadata
        .key_id()
        .ok_or_else(|| AppError::Unauthorized("Token missing key id".to_string()))?
        .to_string();

    let jwk = fetch_apple_signing_key(&kid).await?;
    let public_key = apple_jwk_to_public_key(&jwk)?;

    let mut allowed_issuers = HashSet::new();
    allowed_issuers.insert(APPLE_ISSUER.to_string());
    let mut allowed_audiences = HashSet::new();
    allowed_audiences.insert(expected_bundle_id.to_string());

    let options = VerificationOptions {
        allowed_issuers: Some(allowed_issuers),
        allowed_audiences: Some(allowed_audiences),
        ..Default::default()
    };

    let claims = public_key
        .verify_token::<AppleCustomClaims>(identity_token, Some(options))
        .map_err(|_| AppError::Unauthorized("Invalid ID token".to_string()))?;

    let sub = claims
        .subject
        .ok_or_else(|| AppError::Unauthorized("Token missing subject".to_string()))?;

    let email = claims.custom.email;
    let email_verified = claims.custom.email_verified;

    if email.is_some() && email_verified != Some(true) {
        return Err(AppError::Unauthorized("Email not verified".to_string()));
    }

    Ok(AppleIdTokenClaims {
        sub,
        email,
        email_verified,
    })
}

#[cfg(not(target_os = "windows"))]
async fn fetch_apple_signing_key(kid: &str) -> std::result::Result<AppleJwk, AppError> {
    let request = Request::new(APPLE_JWKS_URL, Method::Get)
        .map_err(|_| AppError::Unauthorized("Unable to verify token".to_string()))?;
    let mut response = Fetch::Request(request)
        .send()
        .await
        .map_err(|_| AppError::Unauthorized("Unable to verify token".to_string()))?;

    if response.status_code() != 200 {
        return Err(AppError::Unauthorized("Unable to verify token".to_string()));
    }

    let jwks: AppleJwks = response
        .json()
        .await
        .map_err(|_| AppError::Unauthorized("Unable to verify token".to_string()))?;

    jwks
        .keys
        .into_iter()
        .find(|k| k.kid == kid && k.kty == "RSA")
        .ok_or_else(|| AppError::Unauthorized("Unknown signing key".to_string()))
}

#[cfg(not(target_os = "windows"))]
fn apple_jwk_to_public_key(jwk: &AppleJwk) -> std::result::Result<RS256PublicKey, AppError> {
    let n = general_purpose::URL_SAFE_NO_PAD
        .decode(&jwk.n)
        .map_err(|_| AppError::Unauthorized("Invalid signing key".to_string()))?;
    let e = general_purpose::URL_SAFE_NO_PAD
        .decode(&jwk.e)
        .map_err(|_| AppError::Unauthorized("Invalid signing key".to_string()))?;

    RS256PublicKey::from_components(&n, &e)
        .map_err(|_| AppError::Unauthorized("Invalid signing key".to_string()))
}

pub async fn apple_token_auth(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let app_id = resolve_app_id(&req);
    let token_req: AppleTokenRequest = req.json().await?;

    let ios_bundle_id = match ctx.env.var("APPLE_IOS_BUNDLE_ID") {
        Ok(id) => id.to_string(),
        Err(_) => match ctx.env.secret("APPLE_IOS_BUNDLE_ID") {
            Ok(secret) => secret.to_string(),
            Err(_) => "com.guitaripod.Pixie".to_string()
        }
    };

    let claims = validate_apple_identity_token(&token_req.identity_token, &ios_bundle_id).await?;

    let db = ctx.env.d1("DB")?;
    
    let existing_user = db
        .prepare("SELECT id, api_key, is_admin FROM users WHERE app_id = ?1 AND provider = ?2 AND provider_id = ?3")
        .bind(&[app_id.clone().into(), "apple".into(), claims.sub.clone().into()])?
        .first::<serde_json::Value>(None)
        .await?;

    let (user_id, api_key, is_admin) = if let Some(user_data) = existing_user {
        let id = user_data.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string();
        let key = user_data.get("api_key").and_then(|v| v.as_str()).unwrap_or("").to_string();
        let admin = user_data.get("is_admin").and_then(|v| v.as_i64()).unwrap_or(0) == 1;
        console_log!("Found existing Apple user: {}", id);
        (id, key, admin)
    } else {
        let new_user_id = Uuid::new_v4().to_string();
        let new_api_key = format!("pixie_{}", Uuid::new_v4().to_string().replace("-", ""));
        let now = Utc::now().to_rfc3339();

        console_log!("Creating new Apple user: {}", new_user_id);

        let email = claims.email.clone()
            .unwrap_or_else(|| format!("{}@privaterelay.appleid.com", claims.sub.chars().take(8).collect::<String>()));

        db
            .prepare("INSERT INTO users (id, app_id, email, provider, provider_id, name, api_key, created_at, updated_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)")
            .bind(&[
                new_user_id.clone().into(),
                app_id.clone().into(),
                email.into(),
                "apple".into(),
                claims.sub.into(),
                "Apple User".into(),
                new_api_key.clone().into(),
                now.clone().into(),
                now.into(),
            ])?
            .run()
            .await?;

        initialize_user_credits(&app_id, &new_user_id, &db).await?;

        (new_user_id, new_api_key, false)
    };
    
    let response = AuthTokenResponse {
        api_key,
        user_id,
        is_admin,
    };
    
    Response::from_json(&response)
}