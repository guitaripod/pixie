use worker::{Request, Response, RouteContext, Result, console_log, Fetch, Method};
use crate::error::AppError;
use crate::credits::initialize_user_credits;
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::Utc;

#[derive(Debug, Deserialize)]
pub struct GoogleTokenRequest {
    pub id_token: String,
}

#[derive(Debug, Serialize)]
pub struct AuthTokenResponse {
    pub api_key: String,
    pub user_id: String,
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
        .prepare("SELECT id, api_key FROM users WHERE provider = ?1 AND provider_id = ?2")
        .bind(&["google".into(), token_info.sub.clone().into()])?
        .first::<serde_json::Value>(None)
        .await?;
    
    let (user_id, api_key) = if let Some(user_data) = existing_user {
        let id = user_data.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string();
        let key = user_data.get("api_key").and_then(|v| v.as_str()).unwrap_or("").to_string();
        console_log!("Found existing user: {}", id);
        (id, key)
    } else {
        // Create new user
        let new_user_id = Uuid::new_v4().to_string();
        let new_api_key = format!("pixie_{}", Uuid::new_v4().to_string().replace("-", ""));
        let now = Utc::now().to_rfc3339();
        
        console_log!("Creating new user: {}", new_user_id);
        
        db
            .prepare("INSERT INTO users (id, email, provider, provider_id, name, api_key, created_at, updated_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)")
            .bind(&[
                new_user_id.clone().into(),
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
        initialize_user_credits(&new_user_id, &db).await?;
        
        (new_user_id, new_api_key)
    };
    
    let response = AuthTokenResponse {
        api_key,
        user_id,
    };
    
    Response::from_json(&response)
}