use worker::Request;
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