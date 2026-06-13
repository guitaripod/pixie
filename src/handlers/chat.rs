use worker::{Request, Response, RouteContext, Result, console_log, Fetch, Method, Headers, RequestInit};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use uuid::Uuid;
use crate::error::AppError;
use crate::auth::authenticate;
use crate::credits::{check_and_reserve_credits, deduct_credits, get_flat_capability_cost};
use crate::rate_limit::{check_and_acquire_lock, release_lock};

const GEMINI_BASE: &str = "https://generativelanguage.googleapis.com/v1beta/models";
const DEFAULT_CHAT_MODEL: &str = "gemini-3-flash-preview";
const CREDIT_MULTIPLIER: f64 = 3.0;
const MIN_BALANCE_GUARD: u32 = 2;

/// Per-1M-token USD prices (input, output) across providers, used to convert
/// real token usage into credits. Defaults to a mid-tier estimate for unknown
/// models. (Apps with a flat capability cost ignore this entirely.)
fn model_prices(model: &str) -> (f64, f64) {
    match model {
        "gemini-3.1-flash-lite" => (0.25, 1.50),
        "gemini-3.5-flash" => (1.50, 9.00),
        "gemini-2.5-flash" => (0.30, 2.50),
        "gpt-5-mini" => (0.25, 2.00),
        "gpt-5-nano" => (0.05, 0.40),
        "gpt-5" => (1.25, 10.00),
        "gpt-4.1-mini" => (0.40, 1.60),
        "gpt-4.1" => (2.00, 8.00),
        _ => (0.50, 3.00),
    }
}

/// Which upstream a chat model routes to. Selected purely by model id so a
/// tenant (or request) can pick any model and hit the right provider + key.
enum Provider {
    Gemini,
    OpenAI,
}

impl Provider {
    fn for_model(model: &str) -> Provider {
        let m = model.to_ascii_lowercase();
        if m.starts_with("gpt") || m.starts_with("o1") || m.starts_with("o3")
            || m.starts_with("o4") || m.starts_with("chatgpt")
        {
            Provider::OpenAI
        } else {
            Provider::Gemini
        }
    }

    fn secret_name(&self) -> &'static str {
        match self {
            Provider::Gemini => "GEMINI_API_KEY",
            Provider::OpenAI => "OPENAI_API_KEY",
        }
    }
}

/// The tenant's configured default chat model (apps.default_chat_model), used
/// when a request doesn't pin one. Any failure (column absent, no row) falls
/// through to the global DEFAULT_CHAT_MODEL so existing tenants are unaffected.
async fn app_default_chat_model(app_id: &str, db: &worker::D1Database) -> Option<String> {
    let row = db
        .prepare("SELECT default_chat_model FROM apps WHERE app_id = ?1")
        .bind(&[app_id.into()])
        .ok()?
        .first::<serde_json::Value>(None)
        .await
        .ok()??;
    row.get("default_chat_model")
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string())
}

fn credits_from_tokens(model: &str, prompt_tokens: u64, output_tokens: u64) -> u32 {
    let (price_in, price_out) = model_prices(model);
    let cost_usd =
        (prompt_tokens as f64 / 1_000_000.0) * price_in + (output_tokens as f64 / 1_000_000.0) * price_out;
    ((cost_usd * CREDIT_MULTIPLIER * 100.0).ceil() as u32).max(1)
}

#[derive(Deserialize)]
struct ChatMessage {
    role: String,
    content: String,
}

#[derive(Deserialize)]
struct ChatRequest {
    messages: Vec<ChatMessage>,
    #[serde(default)]
    images: Vec<String>,
    #[serde(default)]
    response_json: bool,
    model: Option<String>,
}

#[derive(Serialize)]
struct ChatUsage {
    prompt_tokens: u64,
    output_tokens: u64,
    total_tokens: u64,
}

#[derive(Serialize)]
struct ChatResponse {
    content: String,
    model: String,
    credits_charged: u32,
    usage: ChatUsage,
}

pub async fn chat_completion(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    match chat_completion_inner(req, ctx).await {
        Ok(response) => Ok(response),
        Err(e) => e.to_response(),
    }
}

async fn chat_completion_inner(
    mut req: Request,
    ctx: RouteContext<()>,
) -> std::result::Result<Response, AppError> {
    let db = ctx.env.d1("DB")?;
    let auth = authenticate(&req, &db).await?;
    crate::rate_limit::enforce_write_rate_limit(&ctx.env, &auth.app_id, &auth.user_id, "chat.completion").await?;

    let body: ChatRequest = req
        .json()
        .await
        .map_err(|_| AppError::BadRequest("Invalid request body".to_string()))?;
    if body.messages.is_empty() {
        return Err(AppError::BadRequest("messages must not be empty".to_string()));
    }
    let model = match body.model.clone() {
        Some(m) => m,
        None => app_default_chat_model(&auth.app_id, &db)
            .await
            .unwrap_or_else(|| DEFAULT_CHAT_MODEL.to_string()),
    };

    let flat_cost = get_flat_capability_cost(&auth.app_id, "chat.completion", &db).await;
    let premium = crate::handlers::credits::is_premium_user(&ctx.env, &db, &auth.app_id, &auth.user_id).await;

    check_and_acquire_lock(&auth.app_id, &auth.user_id, &db)
        .await
        .map_err(|_| AppError::RateLimitExceeded)?;

    if !premium {
        let guard = flat_cost.unwrap_or(MIN_BALANCE_GUARD);
        if let Err(e) = check_and_reserve_credits(&auth.app_id, &auth.user_id, guard, &db).await {
            let _ = release_lock(&auth.app_id, &auth.user_id, &db).await;
            return Err(AppError::from(e));
        }
    }

    let provider = Provider::for_model(&model);
    let api_key = match ctx.env.secret(provider.secret_name()) {
        Ok(k) => k.to_string(),
        Err(_) => {
            let _ = release_lock(&auth.app_id, &auth.user_id, &db).await;
            return Err(AppError::InternalError(format!("{} not configured", provider.secret_name())));
        }
    };

    let result = match provider {
        Provider::Gemini => gemini_generate(&api_key, &model, &body).await,
        Provider::OpenAI => openai_generate(&api_key, &model, &body).await,
    };
    let (content, prompt_tokens, output_tokens) = match result {
        Ok(v) => v,
        Err(e) => {
            let _ = release_lock(&auth.app_id, &auth.user_id, &db).await;
            return Err(e);
        }
    };

    let credits = if premium {
        0
    } else {
        flat_cost.unwrap_or_else(|| credits_from_tokens(&model, prompt_tokens, output_tokens))
    };
    if credits > 0 {
        let reference = format!("chat:{}", Uuid::new_v4());
        if let Err(e) = deduct_credits(&auth.app_id, &auth.user_id, credits, "chat.completion", &reference, &db).await {
            let _ = release_lock(&auth.app_id, &auth.user_id, &db).await;
            return Err(AppError::from(e));
        }
    }

    let _ = release_lock(&auth.app_id, &auth.user_id, &db).await;

    Response::from_json(&ChatResponse {
        content,
        model,
        credits_charged: credits,
        usage: ChatUsage {
            prompt_tokens,
            output_tokens,
            total_tokens: prompt_tokens + output_tokens,
        },
    })
    .map_err(AppError::from)
}

fn strip_data_url(image: &str) -> &str {
    if image.starts_with("data:") {
        image.splitn(2, ',').nth(1).unwrap_or(image)
    } else {
        image
    }
}

/// Calls Gemini generateContent with the messages (joined into one user turn)
/// plus any images as inlineData parts. Returns (text, prompt_tokens, output_tokens).
async fn gemini_generate(
    api_key: &str,
    model: &str,
    body: &ChatRequest,
) -> std::result::Result<(String, u64, u64), AppError> {
    let mut parts: Vec<Value> = Vec::new();
    let joined = body
        .messages
        .iter()
        .map(|m| format!("{}: {}", m.role, m.content))
        .collect::<Vec<_>>()
        .join("\n\n");
    parts.push(json!({ "text": joined }));
    for image in &body.images {
        parts.push(json!({
            "inlineData": { "mimeType": "image/jpeg", "data": strip_data_url(image) }
        }));
    }

    let mut request_body = json!({ "contents": [ { "role": "user", "parts": parts } ] });
    if body.response_json {
        request_body["generationConfig"] = json!({ "responseMimeType": "application/json" });
    }

    let url = format!("{}/{}:generateContent", GEMINI_BASE, model);
    let headers = Headers::new();
    headers.set("x-goog-api-key", api_key)?;
    headers.set("Content-Type", "application/json")?;

    let mut init = RequestInit::new();
    init.with_method(Method::Post)
        .with_headers(headers)
        .with_body(Some(worker::wasm_bindgen::JsValue::from_str(&request_body.to_string())));
    let request = Request::new_with_init(&url, &init)?;
    let mut resp = Fetch::Request(request).send().await?;

    if resp.status_code() >= 400 {
        let detail = resp.text().await.unwrap_or_default();
        console_log!("Gemini chat error {}: {}", resp.status_code(), detail);
        return Err(AppError::InternalError("AI provider error".to_string()));
    }

    let value: Value = resp
        .json()
        .await
        .map_err(|e| AppError::InternalError(format!("Failed to parse AI response: {}", e)))?;

    let text = value
        .get("candidates")
        .and_then(|c| c.get(0))
        .and_then(|c| c.get("content"))
        .and_then(|c| c.get("parts"))
        .and_then(|p| p.as_array())
        .map(|parts| {
            parts
                .iter()
                .filter_map(|p| p.get("text").and_then(|t| t.as_str()))
                .collect::<Vec<_>>()
                .join("")
        })
        .unwrap_or_default();

    if text.is_empty() {
        return Err(AppError::InternalError("Empty AI response".to_string()));
    }

    let usage = value.get("usageMetadata");
    let prompt_tokens = usage
        .and_then(|u| u.get("promptTokenCount"))
        .and_then(|t| t.as_u64())
        .unwrap_or(0);
    let output_tokens = usage
        .and_then(|u| u.get("candidatesTokenCount"))
        .and_then(|t| t.as_u64())
        .unwrap_or(0);

    Ok((text, prompt_tokens, output_tokens))
}

const OPENAI_CHAT_URL: &str = "https://api.openai.com/v1/chat/completions";

/// True for OpenAI reasoning-class models, which take `reasoning_effort` and
/// run faster when it's pinned to `minimal` for this latency-sensitive task.
fn is_reasoning_model(model: &str) -> bool {
    let m = model.to_ascii_lowercase();
    m.starts_with("gpt-5") || m.starts_with("o1") || m.starts_with("o3") || m.starts_with("o4")
}

/// Calls OpenAI chat completions with the messages (joined into one user turn)
/// plus any images as base64 image_url parts. Mirrors gemini_generate's return
/// shape: (text, prompt_tokens, output_tokens).
async fn openai_generate(
    api_key: &str,
    model: &str,
    body: &ChatRequest,
) -> std::result::Result<(String, u64, u64), AppError> {
    let joined = body
        .messages
        .iter()
        .map(|m| format!("{}: {}", m.role, m.content))
        .collect::<Vec<_>>()
        .join("\n\n");

    let mut parts: Vec<Value> = vec![json!({ "type": "text", "text": joined })];
    for image in &body.images {
        parts.push(json!({
            "type": "image_url",
            "image_url": { "url": format!("data:image/jpeg;base64,{}", strip_data_url(image)) }
        }));
    }

    let mut request_body = json!({
        "model": model,
        "messages": [ { "role": "user", "content": parts } ],
    });
    if body.response_json {
        request_body["response_format"] = json!({ "type": "json_object" });
    }
    if is_reasoning_model(model) {
        request_body["reasoning_effort"] = json!("minimal");
    }

    let headers = Headers::new();
    headers.set("Authorization", &format!("Bearer {}", api_key))?;
    headers.set("Content-Type", "application/json")?;

    let mut init = RequestInit::new();
    init.with_method(Method::Post)
        .with_headers(headers)
        .with_body(Some(worker::wasm_bindgen::JsValue::from_str(&request_body.to_string())));
    let request = Request::new_with_init(OPENAI_CHAT_URL, &init)?;
    let mut resp = Fetch::Request(request).send().await?;

    if resp.status_code() >= 400 {
        let detail = resp.text().await.unwrap_or_default();
        console_log!("OpenAI chat error {}: {}", resp.status_code(), detail);
        return Err(AppError::InternalError("AI provider error".to_string()));
    }

    let value: Value = resp
        .json()
        .await
        .map_err(|e| AppError::InternalError(format!("Failed to parse AI response: {}", e)))?;

    let text = value
        .get("choices")
        .and_then(|c| c.get(0))
        .and_then(|c| c.get("message"))
        .and_then(|m| m.get("content"))
        .and_then(|t| t.as_str())
        .unwrap_or_default()
        .to_string();

    if text.is_empty() {
        return Err(AppError::InternalError("Empty AI response".to_string()));
    }

    let usage = value.get("usage");
    let prompt_tokens = usage
        .and_then(|u| u.get("prompt_tokens"))
        .and_then(|t| t.as_u64())
        .unwrap_or(0);
    let output_tokens = usage
        .and_then(|u| u.get("completion_tokens"))
        .and_then(|t| t.as_u64())
        .unwrap_or(0);

    Ok((text, prompt_tokens, output_tokens))
}
