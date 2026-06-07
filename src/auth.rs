use worker::{Request, D1Database};
use crate::error::AppError;

pub fn validate_api_key(req: &Request) -> Result<String, AppError> {
    let auth_header = req.headers()
        .get("Authorization")
        .ok()
        .flatten()
        .ok_or_else(|| AppError::Unauthorized("Missing Authorization header".to_string()))?;

    if !auth_header.starts_with("Bearer ") {
        return Err(AppError::Unauthorized("Invalid Authorization header format".to_string()));
    }

    let api_key = auth_header.trim_start_matches("Bearer ");
    if api_key.is_empty() {
        return Err(AppError::Unauthorized("Empty API key".to_string()));
    }

    Ok(api_key.to_string())
}

pub fn resolve_app_id(req: &Request) -> String {
    req.headers()
        .get("X-App-ID")
        .ok()
        .flatten()
        .filter(|v| !v.is_empty())
        .unwrap_or_else(|| "pixie".to_string())
}

pub struct AuthedUser {
    pub user_id: String,
    pub app_id: String,
    pub is_admin: bool,
    #[allow(dead_code)]
    pub preferred_model: Option<String>,
    #[allow(dead_code)]
    pub openai_api_key: Option<String>,
    #[allow(dead_code)]
    pub gemini_api_key: Option<String>,
}

pub async fn authenticate(req: &Request, db: &D1Database) -> Result<AuthedUser, AppError> {
    let api_key = validate_api_key(req)?;
    let app_id = resolve_app_id(req);

    let result = db
        .prepare("SELECT id, is_admin, preferred_model, openai_api_key, gemini_api_key FROM users WHERE app_id = ? AND api_key = ?")
        .bind(&[app_id.clone().into(), api_key.into()])
        .map_err(AppError::from)?
        .first::<serde_json::Value>(None)
        .await
        .map_err(AppError::from)?;

    let value = result.ok_or_else(|| AppError::Unauthorized("Invalid API key".to_string()))?;

    Ok(AuthedUser {
        user_id: value.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string(),
        app_id,
        is_admin: value.get("is_admin").and_then(|v| v.as_i64()).map(|v| v != 0).unwrap_or(false),
        preferred_model: value.get("preferred_model").and_then(|v| v.as_str()).map(|s| s.to_string()),
        openai_api_key: value.get("openai_api_key").and_then(|v| v.as_str()).map(|s| s.to_string()),
        gemini_api_key: value.get("gemini_api_key").and_then(|v| v.as_str()).map(|s| s.to_string()),
    })
}
