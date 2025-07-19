use worker::{Request, Response, RouteContext, Result, console_log};
use crate::error::AppError;
use serde::{Deserialize, Serialize};
use serde_json::json;
use uuid::Uuid;
use chrono::Utc;

#[derive(Debug, Serialize, Deserialize)]
pub struct DeviceCodeRequest {
    pub client_type: String, // "cli", "mobile", etc
    pub provider: String, // "github" or "google"
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DeviceCodeResponse {
    pub device_code: String,
    pub user_code: String,
    pub verification_uri: String,
    pub verification_uri_complete: String,
    pub expires_in: u32,
    pub interval: u32,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DeviceTokenRequest {
    pub device_code: String,
    pub client_type: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DeviceTokenResponse {
    pub api_key: String,
    pub user_id: String,
}

#[derive(Debug, Deserialize)]
struct GitHubDeviceCodeResponse {
    device_code: String,
    user_code: String,
    verification_uri: String,
    expires_in: u32,
    interval: u32,
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct GitHubAccessTokenResponse {
    access_token: String,
    token_type: String,
    scope: String,
}

#[derive(Debug, Deserialize)]
struct GitHubErrorResponse {
    error: String,
    error_description: String,
}

#[derive(Debug, Deserialize)]
struct GitHubUser {
    id: i64,
    login: String,
    email: Option<String>,
    name: Option<String>,
}

#[derive(Debug, Deserialize)]
struct GoogleDeviceCodeResponse {
    device_code: String,
    user_code: String,
    verification_url: String,
    expires_in: i32,
    interval: i32,
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct GoogleAccessTokenResponse {
    access_token: String,
    expires_in: i32,
    scope: String,
    token_type: String,
    refresh_token: Option<String>,
}

#[derive(Debug, Deserialize)]
struct GoogleErrorResponse {
    error: String,
    #[allow(dead_code)]
    error_description: Option<String>,
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct GoogleUser {
    id: String,
    email: String,
    verified_email: bool,
    name: Option<String>,
    picture: Option<String>,
}

pub async fn start_device_flow(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let env = ctx.env;
    
    let device_code_req: DeviceCodeRequest = match req.json().await {
        Ok(req) => req,
        Err(e) => return AppError::BadRequest(format!("Invalid request body: {}", e)).to_response(),
    };
    
    let db = env.d1("DB")?;
    let device_auth_id = Uuid::new_v4().to_string();
    
    match device_code_req.provider.as_str() {
        "github" => {
            let client_id = env.var("GITHUB_CLIENT_ID")
                .map_err(|_| AppError::InternalError("GitHub client ID not configured".to_string()))?
                .to_string();
            
            let device_url = "https://github.com/login/device/code";
            let headers = worker::Headers::new();
            headers.set("Accept", "application/json")?;
            headers.set("Content-Type", "application/json")?;
            
            let device_request = json!({
                "client_id": client_id,
                "scope": "read:user user:email"
            });
            
            let device_req = worker::Request::new_with_init(
                device_url,
                worker::RequestInit::new()
                    .with_method(worker::Method::Post)
                    .with_headers(headers)
                    .with_body(Some(worker::wasm_bindgen::JsValue::from_str(&device_request.to_string())))
            )?;
            
            let mut device_resp = worker::Fetch::Request(device_req).send().await?;
            let device_body = device_resp.text().await?;
            
            console_log!("GitHub device response: {}", device_body);
            
            let github_response: GitHubDeviceCodeResponse = serde_json::from_str(&device_body)
                .map_err(|e| AppError::InternalError(format!("Failed to parse GitHub device response: {}", e)))?;
            
            let expires_at = Utc::now() + chrono::Duration::seconds(github_response.expires_in as i64);
            
            let stmt = db.prepare(
                "INSERT INTO device_auth_flows (id, device_code, user_code, client_type, provider, expires_at, created_at) 
                 VALUES (?, ?, ?, ?, ?, ?, ?)"
            );
            
            stmt.bind(&[
                device_auth_id.clone().into(),
                github_response.device_code.clone().into(),
                github_response.user_code.clone().into(),
                device_code_req.client_type.into(),
                "github".into(),
                expires_at.to_rfc3339().into(),
                Utc::now().to_rfc3339().into(),
            ])?
            .run()
            .await?;
            
            let response = DeviceCodeResponse {
                device_code: device_auth_id,
                user_code: github_response.user_code.clone(),
                verification_uri: github_response.verification_uri.clone(),
                verification_uri_complete: format!("{}?user_code={}", 
                    github_response.verification_uri, 
                    github_response.user_code
                ),
                expires_in: github_response.expires_in,
                interval: github_response.interval,
            };
            
            Response::from_json(&response)
        },
        "google" => {
            let client_id = env.var("GOOGLE_DEVICE_CLIENT_ID")
                .map_err(|_| AppError::InternalError("Google device client ID not configured".to_string()))?
                .to_string();
            
            let device_url = "https://oauth2.googleapis.com/device/code";
            let headers = worker::Headers::new();
            headers.set("Content-Type", "application/x-www-form-urlencoded")?;
            
            let device_request = format!(
                "client_id={}&scope=openid%20email%20profile",
                urlencoding::encode(&client_id)
            );
            
            let device_req = worker::Request::new_with_init(
                device_url,
                worker::RequestInit::new()
                    .with_method(worker::Method::Post)
                    .with_headers(headers)
                    .with_body(Some(worker::wasm_bindgen::JsValue::from_str(&device_request)))
            )?;
            
            let mut device_resp = worker::Fetch::Request(device_req).send().await?;
            let device_body = device_resp.text().await?;
            
            console_log!("Google device response: {}", device_body);
            
            let google_response: GoogleDeviceCodeResponse = serde_json::from_str(&device_body)
                .map_err(|e| AppError::InternalError(format!("Failed to parse Google device response: {}", e)))?;
            
            let expires_at = Utc::now() + chrono::Duration::seconds(google_response.expires_in as i64);
            
            let stmt = db.prepare(
                "INSERT INTO device_auth_flows (id, device_code, user_code, client_type, provider, expires_at, created_at) 
                 VALUES (?, ?, ?, ?, ?, ?, ?)"
            );
            
            stmt.bind(&[
                device_auth_id.clone().into(),
                google_response.device_code.clone().into(),
                google_response.user_code.clone().into(),
                device_code_req.client_type.into(),
                "google".into(),
                expires_at.to_rfc3339().into(),
                Utc::now().to_rfc3339().into(),
            ])?
            .run()
            .await?;
            
            let response = DeviceCodeResponse {
                device_code: device_auth_id,
                user_code: google_response.user_code.clone(),
                verification_uri: google_response.verification_url.clone(),
                verification_uri_complete: format!("{}?user_code={}", 
                    google_response.verification_url, 
                    google_response.user_code
                ),
                expires_in: google_response.expires_in as u32,
                interval: google_response.interval as u32,
            };
            
            Response::from_json(&response)
        },
        _ => {
            AppError::BadRequest(format!("Unsupported provider: {}", device_code_req.provider)).to_response()
        }
    }
}

pub async fn poll_device_token(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let env = ctx.env;
    
    let device_token_req: DeviceTokenRequest = match req.json().await {
        Ok(req) => req,
        Err(e) => return AppError::BadRequest(format!("Invalid request body: {}", e)).to_response(),
    };
    
    let db = env.d1("DB")?;
    
    let device_stmt = db.prepare(
        "SELECT device_code, expires_at, user_id, provider FROM device_auth_flows WHERE id = ?"
    );
    
    let device_result = device_stmt
        .bind(&[device_token_req.device_code.clone().into()])?
        .first::<serde_json::Value>(None)
        .await?;
    
    let device_data = match device_result {
        Some(data) => data,
        None => return AppError::NotFound("Invalid device code".to_string()).to_response(),
    };
    
    let expires_at = device_data.get("expires_at")
        .and_then(|v| v.as_str())
        .ok_or_else(|| AppError::InternalError("Invalid expiration data".to_string()))?;
    
    if let Ok(expiry) = chrono::DateTime::parse_from_rfc3339(expires_at) {
        if expiry < Utc::now() {
            return AppError::BadRequest("Device code expired".to_string()).to_response();
        }
    }
    
    if let Some(user_id) = device_data.get("user_id").and_then(|v| v.as_str()) {
        let user_stmt = db.prepare("SELECT api_key FROM users WHERE id = ?");
        let user_result = user_stmt
            .bind(&[user_id.into()])?
            .first::<serde_json::Value>(None)
            .await?;
        
        if let Some(user_data) = user_result {
            let api_key = user_data.get("api_key")
                .and_then(|v| v.as_str())
                .ok_or_else(|| AppError::InternalError("User has no API key".to_string()))?;
            
            let response = DeviceTokenResponse {
                api_key: api_key.to_string(),
                user_id: user_id.to_string(),
            };
            
            return Response::from_json(&response);
        }
    }
    
    let device_code = device_data.get("device_code")
        .and_then(|v| v.as_str())
        .ok_or_else(|| AppError::InternalError("Invalid device code data".to_string()))?;
    
    let provider = device_data.get("provider")
        .and_then(|v| v.as_str())
        .unwrap_or("github"); // Default to github for backward compatibility
    
    let (user_id, api_key) = match provider {
        "github" => {
            let client_id = env.var("GITHUB_CLIENT_ID")
                .map_err(|_| AppError::InternalError("GitHub client ID not configured".to_string()))?
                .to_string();
            
            let client_secret = env.secret("GITHUB_CLIENT_SECRET")
                .map_err(|_| AppError::InternalError("GitHub client secret not configured".to_string()))?
                .to_string();
            
            let token_url = "https://github.com/login/oauth/access_token";
            let headers = worker::Headers::new();
            headers.set("Accept", "application/json")?;
            headers.set("Content-Type", "application/json")?;
            
            let token_request = json!({
                "client_id": client_id,
                "client_secret": client_secret,
                "device_code": device_code,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
            });
            
            let token_req = worker::Request::new_with_init(
                token_url,
                worker::RequestInit::new()
                    .with_method(worker::Method::Post)
                    .with_headers(headers)
                    .with_body(Some(worker::wasm_bindgen::JsValue::from_str(&token_request.to_string())))
            )?;
            
            let mut token_resp = worker::Fetch::Request(token_req).send().await?;
            let token_body = token_resp.text().await?;
            
            console_log!("GitHub token response: {}", token_body);
            
            if let Ok(error_response) = serde_json::from_str::<GitHubErrorResponse>(&token_body) {
                if error_response.error == "authorization_pending" {
                    return AppError::BadRequest("Authorization pending".to_string()).to_response();
                } else if error_response.error == "slow_down" {
                    return AppError::BadRequest("Slow down".to_string()).to_response();
                } else if error_response.error == "expired_token" {
                    return AppError::BadRequest("Device code expired".to_string()).to_response();
                } else if error_response.error == "access_denied" {
                    return AppError::Unauthorized("Access denied".to_string()).to_response();
                }
                
                return AppError::InternalError(format!("GitHub error: {}", error_response.error_description)).to_response();
            }
            
            let token_data: GitHubAccessTokenResponse = serde_json::from_str(&token_body)
                .map_err(|e| AppError::InternalError(format!("Failed to parse GitHub token response: {}", e)))?;
            
            let user_url = "https://api.github.com/user";
            let user_headers = worker::Headers::new();
            user_headers.set("Authorization", &format!("Bearer {}", token_data.access_token))?;
            user_headers.set("Accept", "application/vnd.github.v3+json")?;
            user_headers.set("User-Agent", "OpenAI-Image-Proxy/1.0")?;
            
            let user_req = worker::Request::new_with_init(
                user_url,
                worker::RequestInit::new()
                    .with_method(worker::Method::Get)
                    .with_headers(user_headers)
            )?;
            
            let mut user_resp = worker::Fetch::Request(user_req).send().await?;
            let user_body = user_resp.text().await?;
            
            console_log!("GitHub user response: {}", user_body);
            
            let github_user: GitHubUser = serde_json::from_str(&user_body)
                .map_err(|e| AppError::InternalError(format!("Failed to parse GitHub user response: {}", e)))?;
            
            let provider_id = github_user.id.to_string();
            let existing_user_stmt = db.prepare(
                "SELECT id, api_key FROM users WHERE provider = ? AND provider_id = ?"
            );
            
            let existing_user = existing_user_stmt
                .bind(&["github".into(), provider_id.clone().into()])?
                .first::<serde_json::Value>(None)
                .await?;
            
            if let Some(user_data) = existing_user {
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
                        "github".into(),
                        provider_id.into(),
                        github_user.email.clone().unwrap_or_default().into(),
                        github_user.name.clone().unwrap_or(github_user.login.clone()).into(),
                        new_api_key.clone().into(),
                        now.clone().into(),
                        now.into(),
                    ])?
                    .run()
                    .await?;
                
                (new_user_id, new_api_key)
            }
        },
        "google" => {
            let client_id = env.var("GOOGLE_DEVICE_CLIENT_ID")
                .map_err(|_| AppError::InternalError("Google device client ID not configured".to_string()))?
                .to_string();
            
            let client_secret = env.secret("GOOGLE_DEVICE_CLIENT_SECRET")
                .map_err(|_| AppError::InternalError("Google device client secret not configured".to_string()))?
                .to_string();
            
            let token_url = "https://oauth2.googleapis.com/token";
            let headers = worker::Headers::new();
            headers.set("Content-Type", "application/x-www-form-urlencoded")?;
            
            let token_request = format!(
                "client_id={}&client_secret={}&device_code={}&grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Adevice_code",
                urlencoding::encode(&client_id),
                urlencoding::encode(&client_secret),
                urlencoding::encode(device_code)
            );
            
            let token_req = worker::Request::new_with_init(
                token_url,
                worker::RequestInit::new()
                    .with_method(worker::Method::Post)
                    .with_headers(headers)
                    .with_body(Some(worker::wasm_bindgen::JsValue::from_str(&token_request)))
            )?;
            
            let mut token_resp = worker::Fetch::Request(token_req).send().await?;
            let token_body = token_resp.text().await?;
            
            console_log!("Google token response: {}", token_body);
            
            if let Ok(error_response) = serde_json::from_str::<GoogleErrorResponse>(&token_body) {
                match error_response.error.as_str() {
                    "authorization_pending" => return AppError::BadRequest("Authorization pending".to_string()).to_response(),
                    "slow_down" => return AppError::BadRequest("Slow down".to_string()).to_response(),
                    "expired_token" => return AppError::BadRequest("Device code expired".to_string()).to_response(),
                    "access_denied" => return AppError::Unauthorized("Access denied".to_string()).to_response(),
                    _ => return AppError::InternalError(format!("Google error: {}", error_response.error)).to_response(),
                }
            }
            
            let token_data: GoogleAccessTokenResponse = serde_json::from_str(&token_body)
                .map_err(|e| AppError::InternalError(format!("Failed to parse Google token response: {}", e)))?;
            
            let user_url = "https://www.googleapis.com/oauth2/v2/userinfo";
            let user_headers = worker::Headers::new();
            user_headers.set("Authorization", &format!("Bearer {}", token_data.access_token))?;
            user_headers.set("Accept", "application/json")?;
            
            let user_req = worker::Request::new_with_init(
                user_url,
                worker::RequestInit::new()
                    .with_method(worker::Method::Get)
                    .with_headers(user_headers)
            )?;
            
            let mut user_resp = worker::Fetch::Request(user_req).send().await?;
            let user_body = user_resp.text().await?;
            
            console_log!("Google user response: {}", user_body);
            
            let google_user: GoogleUser = serde_json::from_str(&user_body)
                .map_err(|e| AppError::InternalError(format!("Failed to parse Google user response: {}", e)))?;
            
            let provider_id = google_user.id;
            let existing_user_stmt = db.prepare(
                "SELECT id, api_key FROM users WHERE provider = ? AND provider_id = ?"
            );
            
            let existing_user = existing_user_stmt
                .bind(&["google".into(), provider_id.clone().into()])?
                .first::<serde_json::Value>(None)
                .await?;
            
            if let Some(user_data) = existing_user {
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
                        "google".into(),
                        provider_id.into(),
                        google_user.email.into(),
                        google_user.name.unwrap_or_else(|| "Google User".to_string()).into(),
                        new_api_key.clone().into(),
                        now.clone().into(),
                        now.into(),
                    ])?
                    .run()
                    .await?;
                
                (new_user_id, new_api_key)
            }
        },
        _ => {
            return AppError::InternalError(format!("Unsupported provider: {}", provider)).to_response();
        }
    };
    
    let update_stmt = db.prepare(
        "UPDATE device_auth_flows SET user_id = ? WHERE id = ?"
    );
    
    update_stmt
        .bind(&[user_id.clone().into(), device_token_req.device_code.into()])?
        .run()
        .await?;
    
    let response = DeviceTokenResponse {
        api_key,
        user_id,
    };
    
    Response::from_json(&response)
}

fn generate_api_key() -> String {
    format!("oip_{}", Uuid::new_v4().to_string().replace("-", ""))
}

pub async fn device_auth_status(_req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let device_code = ctx.param("device_code")
        .ok_or_else(|| AppError::BadRequest("Missing device_code parameter".to_string()))?
        .to_string();
    
    let env = ctx.env;
    let db = env.d1("DB")?;
    
    let stmt = db.prepare(
        "SELECT user_code, expires_at, user_id FROM device_auth_flows WHERE id = ?"
    );
    
    let result = stmt
        .bind(&[device_code.into()])?
        .first::<serde_json::Value>(None)
        .await?;
    
    match result {
        Some(data) => {
            let status = if data.get("user_id").and_then(|v| v.as_str()).is_some() {
                "completed"
            } else {
                let expires_at = data.get("expires_at")
                    .and_then(|v| v.as_str())
                    .ok_or_else(|| AppError::InternalError("Invalid expiration data".to_string()))?;
                
                if let Ok(expiry) = chrono::DateTime::parse_from_rfc3339(expires_at) {
                    if expiry < Utc::now() {
                        "expired"
                    } else {
                        "pending"
                    }
                } else {
                    "pending"
                }
            };
            
            Response::from_json(&json!({
                "status": status,
                "user_code": data.get("user_code").and_then(|v| v.as_str()).unwrap_or("")
            }))
        }
        None => {
            AppError::NotFound("Invalid device code".to_string()).to_response()
        }
    }
}