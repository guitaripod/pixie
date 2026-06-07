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

/// Gemini per-1M-token USD prices (input, output), used to convert real token
/// usage into credits. Defaults to gemini-3-flash-preview for unknown models.
fn model_prices(model: &str) -> (f64, f64) {
    match model {
        "gemini-3.1-flash-lite" => (0.25, 1.50),
        "gemini-3.5-flash" => (1.50, 9.00),
        "gemini-2.5-flash" => (0.30, 2.50),
        _ => (0.50, 3.00),
    }
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

    let body: ChatRequest = req
        .json()
        .await
        .map_err(|_| AppError::BadRequest("Invalid request body".to_string()))?;
    if body.messages.is_empty() {
        return Err(AppError::BadRequest("messages must not be empty".to_string()));
    }
    let model = body.model.clone().unwrap_or_else(|| DEFAULT_CHAT_MODEL.to_string());

    let flat_cost = get_flat_capability_cost(&auth.app_id, "chat.completion", &db).await;

    check_and_acquire_lock(&auth.app_id, &auth.user_id, &db)
        .await
        .map_err(|_| AppError::RateLimitExceeded)?;

    let guard = flat_cost.unwrap_or(MIN_BALANCE_GUARD);
    if let Err(e) = check_and_reserve_credits(&auth.app_id, &auth.user_id, guard, &db).await {
        let _ = release_lock(&auth.app_id, &auth.user_id, &db).await;
        return Err(AppError::from(e));
    }

    let api_key = match ctx.env.secret("GEMINI_API_KEY") {
        Ok(k) => k.to_string(),
        Err(_) => {
            let _ = release_lock(&auth.app_id, &auth.user_id, &db).await;
            return Err(AppError::InternalError("GEMINI_API_KEY not configured".to_string()));
        }
    };

    let (content, prompt_tokens, output_tokens) = match gemini_generate(&api_key, &model, &body).await {
        Ok(v) => v,
        Err(e) => {
            let _ = release_lock(&auth.app_id, &auth.user_id, &db).await;
            return Err(e);
        }
    };

    let credits = flat_cost.unwrap_or_else(|| credits_from_tokens(&model, prompt_tokens, output_tokens));
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
