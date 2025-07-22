use worker::{Request, Response, RouteContext, Result, console_log};
use crate::error::AppError;
use crate::credits::initialize_user_credits;
use crate::handlers::oauth::{OAuthCallbackRequest, OAuthTokenResponse, generate_api_key};
use serde::Deserialize;
use uuid::Uuid;
use chrono::Utc;

#[cfg(not(target_os = "windows"))]
use jwt_simple::prelude::*;

#[derive(Debug, Deserialize)]
struct AppleTokenResponse {
    access_token: String,
    #[allow(dead_code)]
    token_type: String,
    #[allow(dead_code)]
    expires_in: i64,
    #[allow(dead_code)]
    refresh_token: Option<String>,
    id_token: String,
}

#[derive(Debug, Deserialize)]
struct AppleIdTokenClaims {
    sub: String, // The unique identifier for the user
    email: Option<String>,
    #[allow(dead_code)]
    email_verified: Option<bool>, // This is a boolean, not a string
    #[allow(dead_code)]
    is_private_email: Option<bool>, // This is also likely a boolean
    #[allow(dead_code)]
    auth_time: i64,
    #[allow(dead_code)]
    nonce_supported: bool,
}


pub async fn apple_auth_start(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    #[cfg(target_os = "windows")]
    {
        return Response::error("Sign in with Apple is not supported on Windows servers", 501);
    }
    
    #[cfg(not(target_os = "windows"))]
    {
    let env = ctx.env;
    let url = req.url()?;
    let query_params: std::collections::HashMap<String, String> = url
        .query_pairs()
        .into_owned()
        .collect();
    
    let state = query_params.get("state")
        .ok_or_else(|| AppError::BadRequest("Missing state parameter".to_string()))?;
    let redirect_uri = query_params.get("redirect_uri")
        .ok_or_else(|| AppError::BadRequest("Missing redirect_uri parameter".to_string()))?;
    
    let client_id = env.var("APPLE_SERVICE_ID")
        .map_err(|_| AppError::InternalError("Apple service ID not configured".to_string()))?
        .to_string();
    
    let apple_auth_url = format!(
        "https://appleid.apple.com/auth/authorize?client_id={}&redirect_uri={}&response_type=code&response_mode=form_post&scope=email%20name&state={}",
        client_id,
        urlencoding::encode(redirect_uri),
        state
    );
    
    Response::redirect(apple_auth_url.parse()?)
    }
}

pub async fn apple_auth_callback(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    #[cfg(target_os = "windows")]
    {
        return Response::error("Sign in with Apple is not supported on Windows servers", 501);
    }
    
    #[cfg(not(target_os = "windows"))]
    {
    let env = ctx.env;
    
    let callback_req: OAuthCallbackRequest = match req.json().await {
        Ok(req) => req,
        Err(e) => return AppError::BadRequest(format!("Invalid request body: {}", e)).to_response(),
    };
    
    let client_id = env.var("APPLE_SERVICE_ID")
        .map_err(|_| AppError::InternalError("Apple service ID not configured".to_string()))?
        .to_string();
    
    let team_id = env.var("APPLE_TEAM_ID")
        .map_err(|_| AppError::InternalError("Apple team ID not configured".to_string()))?
        .to_string();
    
    let key_id = env.var("APPLE_KEY_ID")
        .map_err(|_| AppError::InternalError("Apple key ID not configured".to_string()))?
        .to_string();
    
    let private_key = env.secret("APPLE_PRIVATE_KEY")
        .map_err(|_| AppError::InternalError("Apple private key not configured".to_string()))?
        .to_string();
    
    // Generate client secret JWT
    let client_secret = generate_apple_client_secret(&team_id, &client_id, &key_id, &private_key)?;
    
    let token_url = "https://appleid.apple.com/auth/token";
    let token_body = format!(
        "client_id={}&client_secret={}&code={}&grant_type=authorization_code&redirect_uri={}",
        urlencoding::encode(&client_id),
        urlencoding::encode(&client_secret),
        urlencoding::encode(&callback_req.code),
        urlencoding::encode(&callback_req.redirect_uri)
    );
    
    let headers = worker::Headers::new();
    headers.set("Content-Type", "application/x-www-form-urlencoded")?;
    
    let token_req = worker::Request::new_with_init(
        token_url,
        worker::RequestInit::new()
            .with_method(worker::Method::Post)
            .with_headers(headers)
            .with_body(Some(worker::wasm_bindgen::JsValue::from_str(&token_body)))
    )?;
    
    let mut token_resp = worker::Fetch::Request(token_req).send().await?;
    let token_response_text = token_resp.text().await?;
    
    console_log!("Apple token response: {}", token_response_text);
    
    let token_data: AppleTokenResponse = serde_json::from_str(&token_response_text)
        .map_err(|e| AppError::InternalError(format!("Failed to parse Apple token response: {}", e)))?;
    
    // Decode the ID token to get user info
    let id_token_parts: Vec<&str> = token_data.id_token.split('.').collect();
    if id_token_parts.len() != 3 {
        return Err(AppError::InternalError("Invalid ID token format".to_string()).into());
    }
    
    let claims_base64 = id_token_parts[1];
    use base64::{Engine as _, engine::general_purpose};
    let claims_json = general_purpose::URL_SAFE_NO_PAD.decode(claims_base64)
        .map_err(|e| AppError::InternalError(format!("Failed to decode ID token: {}", e)))?;
    
    let claims: AppleIdTokenClaims = serde_json::from_slice(&claims_json)
        .map_err(|e| AppError::InternalError(format!("Failed to parse ID token claims: {}", e)))?;
    
    let db = env.d1("DB")?;
    
    let provider_id = claims.sub;
    let existing_user_stmt = db.prepare(
        "SELECT id, api_key FROM users WHERE provider = ? AND provider_id = ?"
    );
    
    let existing_user = existing_user_stmt
        .bind(&["apple".into(), provider_id.clone().into()])?
        .first::<serde_json::Value>(None)
        .await?;
    
    let (user_id, api_key) = if let Some(user_data) = existing_user {
        (
            user_data.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string(),
            user_data.get("api_key").and_then(|v| v.as_str()).unwrap_or("").to_string(),
        )
    } else {
        let new_user_id = Uuid::new_v4().to_string();
        let new_api_key = generate_api_key();
        let now = Utc::now().to_rfc3339();
        
        let insert_stmt = db.prepare(
            "INSERT INTO users (id, provider, provider_id, email, name, api_key, created_at, updated_at) 
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
        );
        
        insert_stmt
            .bind(&[
                new_user_id.clone().into(),
                "apple".into(),
                provider_id.into(),
                claims.email.clone().unwrap_or_default().into(),
                "Apple User".into(), // Apple doesn't provide name in ID token
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
    
    let response = OAuthTokenResponse {
        api_key,
        user_id,
    };
    
    Response::from_json(&response)
    }
}

#[cfg(not(target_os = "windows"))]
fn generate_apple_client_secret(team_id: &str, service_id: &str, key_id: &str, private_key: &str) -> Result<String> {
    // Create custom claims for Apple
    let claims = Claims::create(Duration::from_days(180))
        .with_issuer(team_id)
        .with_subject(service_id)
        .with_audience("https://appleid.apple.com");
    
    // Parse the ES256 private key and add key ID
    let key_pair = ES256KeyPair::from_pem(private_key)
        .map_err(|e| AppError::InternalError(format!("Failed to parse private key: {}", e)))?
        .with_key_id(key_id);
    
    // Sign the token (key ID is automatically included in header)
    let token = key_pair.sign(claims)
        .map_err(|e| AppError::InternalError(format!("Failed to sign JWT: {}", e)))?;
    
    Ok(token)
}