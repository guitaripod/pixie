use worker::{Request, Response, RouteContext, Result, console_log};
use crate::error::AppError;
use crate::credits::initialize_user_credits;
use serde::{Deserialize, Serialize};
use serde_json::json;
use uuid::Uuid;
use chrono::Utc;

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
pub struct OAuthStartParams {
    pub state: String,
    pub redirect_uri: String,
}

#[derive(Debug, Deserialize)]
pub struct OAuthCallbackRequest {
    pub code: String,
    #[allow(dead_code)]
    pub state: String,
    pub redirect_uri: String,
}

#[derive(Debug, Serialize)]
pub struct OAuthTokenResponse {
    pub api_key: String,
    pub user_id: String,
}

#[derive(Debug, Deserialize)]
struct GitHubAccessTokenResponse {
    access_token: String,
    #[allow(dead_code)]
    token_type: String,
    #[allow(dead_code)]
    scope: String,
}

#[derive(Debug, Deserialize)]
struct GitHubUser {
    id: i64,
    login: String,
    email: Option<String>,
    name: Option<String>,
    #[allow(dead_code)]
    avatar_url: String,
}

#[derive(Debug, Deserialize)]
struct GitHubEmail {
    email: String,
    primary: bool,
    verified: bool,
    #[allow(dead_code)]
    visibility: Option<String>,
}

#[derive(Debug, Deserialize)]
struct GoogleAccessTokenResponse {
    access_token: String,
    #[allow(dead_code)]
    expires_in: i64,
    #[allow(dead_code)]
    token_type: String,
    #[allow(dead_code)]
    scope: String,
    #[allow(dead_code)]
    refresh_token: Option<String>,
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct GoogleUser {
    id: String,
    email: String,
    verified_email: bool,
    name: Option<String>,
    given_name: Option<String>,
    family_name: Option<String>,
    picture: Option<String>,
}


pub async fn github_auth_start(req: Request, ctx: RouteContext<()>) -> Result<Response> {
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
    
    let client_id = env.var("GITHUB_CLIENT_ID")
        .map_err(|_| AppError::InternalError("GitHub client ID not configured".to_string()))?
        .to_string();
    
    let github_auth_url = format!(
        "https://github.com/login/oauth/authorize?client_id={}&redirect_uri={}&state={}&scope=read:user,user:email",
        client_id,
        urlencoding::encode(redirect_uri),
        state
    );
    
    Response::redirect(github_auth_url.parse()?)
}

pub async fn github_auth_callback(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let env = ctx.env;
    
    let callback_req: OAuthCallbackRequest = match req.json().await {
        Ok(req) => req,
        Err(e) => return AppError::BadRequest(format!("Invalid request body: {}", e)).to_response(),
    };
    
    let client_id = env.var("GITHUB_CLIENT_ID")
        .map_err(|_| AppError::InternalError("GitHub client ID not configured".to_string()))?
        .to_string();
    
    let client_secret = env.secret("GITHUB_CLIENT_SECRET")
        .map_err(|_| AppError::InternalError("GitHub client secret not configured".to_string()))?
        .to_string();
    
    let token_url = "https://github.com/login/oauth/access_token";
    let token_request = json!({
        "client_id": client_id,
        "client_secret": client_secret,
        "code": callback_req.code,
        "redirect_uri": callback_req.redirect_uri,
    });
    
    let headers = worker::Headers::new();
    headers.set("Accept", "application/json")?;
    headers.set("Content-Type", "application/json")?;
    
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
    
    let token_data: GitHubAccessTokenResponse = serde_json::from_str(&token_body)
        .map_err(|e| AppError::InternalError(format!("Failed to parse GitHub token response: {}", e)))?;
    
    let user_url = "https://api.github.com/user";
    let user_headers = worker::Headers::new();
    user_headers.set("Authorization", &format!("Bearer {}", token_data.access_token))?;
    user_headers.set("Accept", "application/vnd.github.v3+json")?;
    user_headers.set("User-Agent", "openai-image-proxy/1.0")?;
    
    let user_req = worker::Request::new_with_init(
        user_url,
        worker::RequestInit::new()
            .with_method(worker::Method::Get)
            .with_headers(user_headers)
    )?;
    
    let mut user_resp = worker::Fetch::Request(user_req).send().await?;
    let user_body = user_resp.text().await?;
    
    console_log!("GitHub user response: {}", user_body);
    
    let mut github_user: GitHubUser = serde_json::from_str(&user_body)
        .map_err(|e| AppError::InternalError(format!("Failed to parse GitHub user response: {}", e)))?;
    
    // If email is not present in the user response, fetch it from /user/emails
    if github_user.email.is_none() {
        let emails_url = "https://api.github.com/user/emails";
        let emails_headers = worker::Headers::new();
        emails_headers.set("Authorization", &format!("Bearer {}", token_data.access_token))?;
        emails_headers.set("Accept", "application/vnd.github.v3+json")?;
        emails_headers.set("User-Agent", "openai-image-proxy/1.0")?;
        
        let emails_req = worker::Request::new_with_init(
            emails_url,
            worker::RequestInit::new()
                .with_method(worker::Method::Get)
                .with_headers(emails_headers)
        )?;
        
        let mut emails_resp = worker::Fetch::Request(emails_req).send().await?;
        let emails_body = emails_resp.text().await?;
        
        console_log!("GitHub emails response: {}", emails_body);
        
        let github_emails: Vec<GitHubEmail> = serde_json::from_str(&emails_body)
            .map_err(|e| AppError::InternalError(format!("Failed to parse GitHub emails response: {}", e)))?;
        
        // Find the primary verified email
        if let Some(primary_email) = github_emails.iter()
            .find(|e| e.primary && e.verified)
            .or_else(|| github_emails.iter().find(|e| e.verified)) {
            github_user.email = Some(primary_email.email.clone());
        }
    }
    
    let db = env.d1("DB")?;
    
    let provider_id = github_user.id.to_string();
    let existing_user_stmt = db.prepare(
        "SELECT id, api_key FROM users WHERE provider = ? AND provider_id = ?"
    );
    
    let existing_user = existing_user_stmt
        .bind(&["github".into(), provider_id.clone().into()])?
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

pub fn generate_api_key() -> String {
    format!("pixie_{}", Uuid::new_v4().to_string().replace("-", ""))
}

pub async fn google_auth_start(req: Request, ctx: RouteContext<()>) -> Result<Response> {
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
    
    let client_id = env.var("GOOGLE_CLIENT_ID")
        .map_err(|_| AppError::InternalError("Google client ID not configured".to_string()))?
        .to_string();
    
    let google_auth_url = format!(
        "https://accounts.google.com/o/oauth2/v2/auth?client_id={}&redirect_uri={}&response_type=code&scope=openid%20email%20profile&state={}&access_type=offline&prompt=consent",
        client_id,
        urlencoding::encode(redirect_uri),
        state
    );
    
    Response::redirect(google_auth_url.parse()?)
}

pub async fn google_auth_callback(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let env = ctx.env;
    
    let callback_req: OAuthCallbackRequest = match req.json().await {
        Ok(req) => req,
        Err(e) => return AppError::BadRequest(format!("Invalid request body: {}", e)).to_response(),
    };
    
    let client_id = env.var("GOOGLE_CLIENT_ID")
        .map_err(|_| AppError::InternalError("Google client ID not configured".to_string()))?
        .to_string();
    
    let client_secret = env.secret("GOOGLE_CLIENT_SECRET")
        .map_err(|_| AppError::InternalError("Google client secret not configured".to_string()))?
        .to_string();
    
    let token_url = "https://oauth2.googleapis.com/token";
    let token_request = json!({
        "client_id": client_id,
        "client_secret": client_secret,
        "code": callback_req.code,
        "redirect_uri": callback_req.redirect_uri,
        "grant_type": "authorization_code"
    });
    
    let headers = worker::Headers::new();
    headers.set("Accept", "application/json")?;
    headers.set("Content-Type", "application/json")?;
    
    let token_req = worker::Request::new_with_init(
        token_url,
        worker::RequestInit::new()
            .with_method(worker::Method::Post)
            .with_headers(headers)
            .with_body(Some(worker::wasm_bindgen::JsValue::from_str(&token_request.to_string())))
    )?;
    
    let mut token_resp = worker::Fetch::Request(token_req).send().await?;
    let token_body = token_resp.text().await?;
    
    console_log!("Google token response: {}", token_body);
    
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
    
    let db = env.d1("DB")?;
    
    let provider_id = google_user.id;
    let existing_user_stmt = db.prepare(
        "SELECT id, api_key FROM users WHERE provider = ? AND provider_id = ?"
    );
    
    let existing_user = existing_user_stmt
        .bind(&["google".into(), provider_id.clone().into()])?
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