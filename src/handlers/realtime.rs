use worker::{Request, Response, RouteContext, Result, console_log, Fetch, Method, Headers, RequestInit, Env};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use uuid::Uuid;
use chrono::Utc;
use crate::error::AppError;
use crate::auth::authenticate;
use crate::credits::{get_user_balance, get_flat_capability_cost, deduct_credits, add_credits};

const CAPABILITY: &str = "realtime.translate";
const DEFAULT_RATE_CREDITS: u32 = 1; // 1 credit per minute
/// Up-front affordability guard (minutes). The client keeps two call legs warm
/// at once, so each session reserves only this tiny guard rather than the whole
/// balance; the real cost is billed from the reported minutes at settle.
const RESERVE_GUARD_MINUTES: i32 = 1;
const OPENAI_MINT_URL: &str = "https://api.openai.com/v1/realtime/translations/client_secrets";
const OPENAI_SDP_URL: &str = "https://api.openai.com/v1/realtime/translations/calls";
const DEFAULT_MODEL: &str = "gpt-realtime-translate";

#[derive(Deserialize)]
struct StartRequest {
    /// BCP-47 language the traveler's speech is translated INTO (the local
    /// language). The translate model auto-detects the source, so only the
    /// output language is set at mint.
    language: String,
    model: Option<String>,
}

#[derive(Serialize)]
struct StartResponse {
    session_id: String,
    client_secret: String,
    expires_at: Option<i64>,
    sdp_url: String,
    model: String,
    reserved_minutes: i32,
    rate_credits: u32,
    balance: i32,
}

#[derive(Deserialize)]
struct SettleRequest {
    session_id: String,
    minutes_used: i32,
}

#[derive(Serialize)]
struct SettleResponse {
    settled: bool,
    minutes_charged: i32,
    refunded_credits: i32,
    balance: i32,
}

pub async fn start(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    match start_inner(req, ctx).await {
        Ok(r) => Ok(r),
        Err(e) => e.to_response(),
    }
}

pub async fn settle(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    match settle_inner(req, ctx).await {
        Ok(r) => Ok(r),
        Err(e) => e.to_response(),
    }
}

async fn start_inner(mut req: Request, ctx: RouteContext<()>) -> std::result::Result<Response, AppError> {
    let db = ctx.env.d1("DB")?;
    let auth = authenticate(&req, &db).await?;

    let body: StartRequest = req
        .json()
        .await
        .map_err(|_| AppError::BadRequest("Invalid request body".to_string()))?;
    if body.language.trim().is_empty() {
        return Err(AppError::BadRequest("language is required".to_string()));
    }
    let model = body.model.clone().unwrap_or_else(|| DEFAULT_MODEL.to_string());

    let rate = get_flat_capability_cost(&auth.app_id, CAPABILITY, &db)
        .await
        .unwrap_or(DEFAULT_RATE_CREDITS)
        .max(1);
    let balance = get_user_balance(&auth.app_id, &auth.user_id, &db).await?;
    let affordable_minutes = balance / rate as i32;
    if affordable_minutes < 1 {
        return Err(AppError::PaymentRequired(format!(
            "Insufficient credits. Need {} per minute, have {}.",
            rate, balance
        )));
    }
    let reserved_minutes = RESERVE_GUARD_MINUTES.min(affordable_minutes);
    let reserved_credits = reserved_minutes as u32 * rate;
    let session_id = Uuid::new_v4().to_string();

    // Reserve up-front; settle refunds the unused remainder. Deduct BEFORE the
    // mint so a session can never be opened without being paid for.
    let new_balance = deduct_credits(
        &auth.app_id,
        &auth.user_id,
        reserved_credits,
        "realtime.translate reservation",
        &session_id,
        &db,
    )
    .await
    .map_err(AppError::from)?;

    let (client_secret, expires_at) = match mint_ephemeral(&ctx.env, &model, &body.language).await {
        Ok(m) => m,
        Err(e) => {
            // No session was opened — give the reservation back.
            let _ = add_credits(
                &auth.app_id,
                &auth.user_id,
                reserved_credits,
                "refund",
                "realtime.translate mint failed",
                Some(&session_id),
                &db,
            )
            .await;
            return Err(e);
        }
    };

    let now = Utc::now().to_rfc3339();
    db.prepare(
        "INSERT INTO realtime_sessions (id, app_id, user_id, capability, rate_credits, reserved_minutes, reserved_credits, settled, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?)",
    )
    .bind(&[
        session_id.clone().into(),
        auth.app_id.clone().into(),
        auth.user_id.clone().into(),
        CAPABILITY.into(),
        rate.into(),
        reserved_minutes.into(),
        reserved_credits.into(),
        now.into(),
    ])?
    .run()
    .await?;

    Response::from_json(&StartResponse {
        session_id,
        client_secret,
        expires_at,
        sdp_url: OPENAI_SDP_URL.to_string(),
        model,
        reserved_minutes,
        rate_credits: rate,
        balance: new_balance,
    })
    .map_err(AppError::from)
}

async fn settle_inner(mut req: Request, ctx: RouteContext<()>) -> std::result::Result<Response, AppError> {
    let db = ctx.env.d1("DB")?;
    let auth = authenticate(&req, &db).await?;
    let body: SettleRequest = req
        .json()
        .await
        .map_err(|_| AppError::BadRequest("Invalid request body".to_string()))?;

    let row = db
        .prepare(
            "SELECT rate_credits, reserved_minutes, reserved_credits, settled
             FROM realtime_sessions WHERE id = ?1 AND app_id = ?2 AND user_id = ?3",
        )
        .bind(&[
            body.session_id.clone().into(),
            auth.app_id.clone().into(),
            auth.user_id.clone().into(),
        ])?
        .first::<Value>(None)
        .await?
        .ok_or_else(|| AppError::NotFound("session not found".to_string()))?;

    let already_settled = row.get("settled").and_then(|v| v.as_i64()).unwrap_or(0) != 0;
    let reserved_credits = row.get("reserved_credits").and_then(|v| v.as_i64()).unwrap_or(0) as i32;
    let rate = row.get("rate_credits").and_then(|v| v.as_i64()).unwrap_or(1).max(1) as i32;

    // Idempotent: re-settling (e.g. retry, or settle-on-next-launch) is a no-op.
    if already_settled {
        let balance = get_user_balance(&auth.app_id, &auth.user_id, &db).await?;
        return Response::from_json(&SettleResponse {
            settled: true,
            minutes_charged: 0,
            refunded_credits: 0,
            balance,
        })
        .map_err(AppError::from);
    }

    // Bill the actual reported minutes (the guard already covered the first
    // minute). Deduct the remainder beyond the guard, floored at the available
    // balance; refund the unused guard if the session ran under a minute.
    let actual = body.minutes_used.max(0);
    let charged = actual * rate;
    let mut balance = get_user_balance(&auth.app_id, &auth.user_id, &db).await?;
    let mut refund: i32 = 0;
    if charged > reserved_credits {
        let extra = (charged - reserved_credits).min(balance.max(0)) as u32;
        if extra > 0 {
            balance = deduct_credits(
                &auth.app_id,
                &auth.user_id,
                extra,
                "realtime.translate",
                &body.session_id,
                &db,
            )
            .await
            .map_err(AppError::from)?;
        }
    } else {
        refund = (reserved_credits - charged).max(0);
        if refund > 0 {
            balance = add_credits(
                &auth.app_id,
                &auth.user_id,
                refund as u32,
                "refund",
                "realtime.translate unused",
                Some(&body.session_id),
                &db,
            )
            .await
            .map_err(AppError::from)?;
        }
    }

    let now = Utc::now().to_rfc3339();
    db.prepare(
        "UPDATE realtime_sessions SET actual_minutes = ?, refunded_credits = ?, settled = 1, settled_at = ? WHERE id = ?",
    )
    .bind(&[actual.into(), refund.into(), now.into(), body.session_id.clone().into()])?
    .run()
    .await?;

    Response::from_json(&SettleResponse {
        settled: true,
        minutes_charged: actual,
        refunded_credits: refund,
        balance,
    })
    .map_err(AppError::from)
}

/// Mints the ephemeral OpenAI realtime-translations client secret. The audio
/// itself is exchanged device<->OpenAI over WebRTC; the worker only mints + meters.
async fn mint_ephemeral(
    env: &Env,
    model: &str,
    language: &str,
) -> std::result::Result<(String, Option<i64>), AppError> {
    let api_key = env
        .secret("OPENAI_API_KEY")
        .map_err(|_| AppError::InternalError("OPENAI_API_KEY not configured".to_string()))?
        .to_string();

    let body = json!({
        "session": { "model": model, "audio": { "output": { "language": language } } }
    });
    let headers = Headers::new();
    headers.set("Authorization", &format!("Bearer {}", api_key))?;
    headers.set("Content-Type", "application/json")?;
    let mut init = RequestInit::new();
    init.with_method(Method::Post)
        .with_headers(headers)
        .with_body(Some(worker::wasm_bindgen::JsValue::from_str(&body.to_string())));
    let request = Request::new_with_init(OPENAI_MINT_URL, &init)?;
    let mut resp = Fetch::Request(request).send().await?;

    if resp.status_code() >= 400 {
        let detail = resp.text().await.unwrap_or_default();
        console_log!("realtime mint error {}: {}", resp.status_code(), detail);
        return Err(AppError::InternalError("Realtime mint failed".to_string()));
    }

    let v: Value = resp
        .json()
        .await
        .map_err(|e| AppError::InternalError(format!("mint parse: {}", e)))?;
    let value = v
        .get("value")
        .and_then(|x| x.as_str())
        .or_else(|| v.get("client_secret").and_then(|c| c.get("value")).and_then(|x| x.as_str()))
        .ok_or_else(|| AppError::InternalError("mint: no client secret".to_string()))?
        .to_string();
    let expires_at = v.get("expires_at").and_then(|x| x.as_i64());
    Ok((value, expires_at))
}
