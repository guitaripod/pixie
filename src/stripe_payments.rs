use worker::{Request, Result, Fetch, Method, Env, Headers};
use serde::{Deserialize, Serialize};
use crate::error::AppError;
use std::collections::HashMap;
use url::form_urlencoded;
use chrono;

// Stripe API Response Types
#[derive(Debug, Serialize, Deserialize)]
pub struct StripeCheckoutSession {
    pub id: String,
    pub object: String,
    pub amount_total: Option<i64>,
    pub currency: Option<String>,
    pub customer: Option<String>,
    pub customer_email: Option<String>,
    pub livemode: bool,
    pub metadata: HashMap<String, String>,
    pub mode: String,
    pub payment_status: String,
    pub status: String,
    pub success_url: String,
    pub cancel_url: String,
    pub url: Option<String>,
    pub created: i64,
    pub expires_at: i64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct StripePrice {
    pub id: String,
    pub object: String,
    pub active: bool,
    pub currency: String,
    pub product: String,
    pub unit_amount: i64,
    pub metadata: HashMap<String, String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct StripeProduct {
    pub id: String,
    pub object: String,
    pub active: bool,
    pub name: String,
    pub description: Option<String>,
    pub metadata: HashMap<String, String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct StripeError {
    pub error: StripeErrorDetail,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct StripeErrorDetail {
    pub code: Option<String>,
    pub message: String,
    #[serde(rename = "type")]
    pub error_type: String,
}

#[derive(Debug, Serialize)]
pub struct CreateCheckoutSessionRequest {
    pub success_url: String,
    pub cancel_url: String,
    pub mode: String,
    pub line_items: Vec<LineItem>,
    pub metadata: HashMap<String, String>,
    pub customer_email: Option<String>,
    pub expires_at: Option<i64>,
}

#[derive(Debug, Serialize)]
pub struct LineItem {
    pub price: String,
    pub quantity: u32,
}

// Stripe webhook event types
#[derive(Debug, Deserialize)]
#[allow(dead_code)]
pub struct StripeWebhookEvent {
    pub id: String,
    #[serde(rename = "type")]
    pub event_type: String,
    pub data: StripeWebhookEventData,
    pub created: i64,
    pub livemode: bool,
}

#[derive(Debug, Deserialize)]
pub struct StripeWebhookEventData {
    pub object: serde_json::Value,
}

// Helper function to create Stripe API headers
fn create_stripe_headers(api_key: &str) -> Result<Headers> {
    let headers = Headers::new();
    headers.set("Authorization", &format!("Bearer {}", api_key))?;
    headers.set("Content-Type", "application/x-www-form-urlencoded")?;
    headers.set("Stripe-Version", "2023-10-16")?; // Use a stable API version
    Ok(headers)
}

// Convert request struct to form-encoded string
fn to_form_encoded(params: &CreateCheckoutSessionRequest) -> String {
    let mut parts = vec![
        ("success_url".to_string(), params.success_url.clone()),
        ("cancel_url".to_string(), params.cancel_url.clone()),
        ("mode".to_string(), params.mode.clone()),
    ];
    
    // Add line items
    for (idx, item) in params.line_items.iter().enumerate() {
        parts.push((format!("line_items[{}][price]", idx), item.price.clone()));
        parts.push((format!("line_items[{}][quantity]", idx), item.quantity.to_string()));
    }
    
    // Add metadata
    for (key, value) in &params.metadata {
        parts.push((format!("metadata[{}]", key), value.clone()));
    }
    
    // Add optional fields
    if let Some(email) = &params.customer_email {
        parts.push(("customer_email".to_string(), email.clone()));
    }
    
    if let Some(expires_at) = params.expires_at {
        parts.push(("expires_at".to_string(), expires_at.to_string()));
    }
    
    form_urlencoded::Serializer::new(String::new())
        .extend_pairs(parts.iter())
        .finish()
}

pub async fn create_checkout_session(
    env: &Env,
    purchase_id: &str,
    pack_id: &str,
    pack_name: &str,
    credits: u32,
    price_stripe_id: &str,
    success_url: &str,
    cancel_url: &str,
    customer_email: Option<&str>,
) -> Result<StripeCheckoutSession> {
    let api_key = env.secret("STRIPE_SECRET_KEY")?.to_string();
    
    let mut metadata = HashMap::new();
    metadata.insert("purchase_id".to_string(), purchase_id.to_string());
    metadata.insert("pack_id".to_string(), pack_id.to_string());
    metadata.insert("pack_name".to_string(), pack_name.to_string());
    metadata.insert("credits".to_string(), credits.to_string());
    
    let request_data = CreateCheckoutSessionRequest {
        success_url: success_url.to_string(),
        cancel_url: cancel_url.to_string(),
        mode: "payment".to_string(),
        line_items: vec![LineItem {
            price: price_stripe_id.to_string(),
            quantity: 1,
        }],
        metadata,
        customer_email: customer_email.map(|s| s.to_string()),
        expires_at: Some(chrono::Utc::now().timestamp() + 1800), // 30 minutes
    };
    
    let headers = create_stripe_headers(&api_key)?;
    let body = to_form_encoded(&request_data);
    
    let request = Request::new_with_init(
        "https://api.stripe.com/v1/checkout/sessions",
        worker::RequestInit::new()
            .with_method(Method::Post)
            .with_headers(headers)
            .with_body(Some(body.into()))
    )?;
    
    let mut response = Fetch::Request(request).send().await?;
    
    if response.status_code() < 200 || response.status_code() >= 300 {
        let error_text = response.text().await?;
        if let Ok(stripe_error) = serde_json::from_str::<StripeError>(&error_text) {
            let user_message = match stripe_error.error.code.as_deref() {
                Some("api_key_expired") => "Payment configuration error. Please contact support.".to_string(),
                Some("insufficient_funds") => "Insufficient funds. Please try a different payment method.".to_string(),
                Some("card_declined") => "Card declined. Please check your card details or try a different card.".to_string(),
                Some("expired_card") => "Card expired. Please use a different card.".to_string(),
                Some("incorrect_cvc") => "Incorrect security code. Please check your card details.".to_string(),
                Some("processing_error") => "Payment processing error. Please try again.".to_string(),
                Some("rate_limit") => "Too many payment attempts. Please wait a moment and try again.".to_string(),
                _ => stripe_error.error.message.clone(),
            };
            return Err(AppError::BadRequest(user_message).into());
        }
        
        return match response.status_code() {
            500..=599 => Err(AppError::InternalError("Payment service temporarily unavailable".to_string()).into()),
            _ => Err(AppError::BadRequest("Payment service error. Please try again.".to_string()).into()),
        };
    }
    
    let session: StripeCheckoutSession = response.json().await?;
    Ok(session)
}

pub async fn get_checkout_session(env: &Env, session_id: &str) -> Result<StripeCheckoutSession> {
    let api_key = env.secret("STRIPE_SECRET_KEY")?.to_string();
    
    let headers = create_stripe_headers(&api_key)?;
    
    let request = Request::new_with_init(
        &format!("https://api.stripe.com/v1/checkout/sessions/{}", session_id),
        worker::RequestInit::new()
            .with_method(Method::Get)
            .with_headers(headers)
    )?;
    
    let mut response = Fetch::Request(request).send().await?;
    
    if response.status_code() < 200 || response.status_code() >= 300 {
        let error_text = response.text().await?;
        if let Ok(stripe_error) = serde_json::from_str::<StripeError>(&error_text) {
            let user_message = match stripe_error.error.code.as_deref() {
                Some("api_key_expired") => "Payment configuration error. Please contact support.".to_string(),
                Some("insufficient_funds") => "Insufficient funds. Please try a different payment method.".to_string(),
                Some("card_declined") => "Card declined. Please check your card details or try a different card.".to_string(),
                Some("expired_card") => "Card expired. Please use a different card.".to_string(),
                Some("incorrect_cvc") => "Incorrect security code. Please check your card details.".to_string(),
                Some("processing_error") => "Payment processing error. Please try again.".to_string(),
                Some("rate_limit") => "Too many payment attempts. Please wait a moment and try again.".to_string(),
                _ => stripe_error.error.message.clone(),
            };
            return Err(AppError::BadRequest(user_message).into());
        }
        
        return match response.status_code() {
            500..=599 => Err(AppError::InternalError("Payment service temporarily unavailable".to_string()).into()),
            _ => Err(AppError::BadRequest("Payment service error. Please try again.".to_string()).into()),
        };
    }
    
    let session: StripeCheckoutSession = response.json().await?;
    Ok(session)
}

pub fn verify_webhook_signature(env: &Env, signature: &str, body: &str, timestamp: &str) -> Result<bool> {
    let webhook_secret = env.secret("STRIPE_WEBHOOK_SECRET")?.to_string();
    
    // Stripe signature format: t=timestamp,v1=signature
    let parts: Vec<&str> = signature.split(',').collect();
    let mut sig_timestamp = "";
    let mut sig_value = "";
    
    for part in parts {
        let kv: Vec<&str> = part.split('=').collect();
        if kv.len() == 2 {
            match kv[0] {
                "t" => sig_timestamp = kv[1],
                "v1" => sig_value = kv[1],
                _ => {}
            }
        }
    }
    
    if sig_timestamp.is_empty() || sig_value.is_empty() {
        return Ok(false);
    }
    
    // Verify timestamp to prevent replay attacks (tolerance: 5 minutes)
    let current_time = chrono::Utc::now().timestamp();
    let sig_time = sig_timestamp.parse::<i64>().unwrap_or(0);
    if (current_time - sig_time).abs() > 300 {
        worker::console_log!("Webhook timestamp too old or in future");
        return Ok(false);
    }
    
    // Construct the signed payload
    let signed_payload = format!("{}.{}", timestamp, body);
    
    // Compute expected signature
    use hmac::{Hmac, Mac};
    use sha2::Sha256;
    
    type HmacSha256 = Hmac<Sha256>;
    
    let mut mac = HmacSha256::new_from_slice(webhook_secret.as_bytes())
        .map_err(|_| AppError::InternalError("Invalid webhook secret".to_string()))?;
    
    mac.update(signed_payload.as_bytes());
    
    let expected_signature = hex::encode(mac.finalize().into_bytes());
    
    worker::console_log!("Expected signature: {}", expected_signature);
    worker::console_log!("Received signature: {}", sig_value);
    
    Ok(sig_value == expected_signature)
}

// Helper function to get Stripe price IDs for each pack from environment variables
pub fn get_stripe_price_id(env: &Env, pack_id: &str) -> Option<String> {
    let var_name = match pack_id {
        "starter" => "STRIPE_PRICE_ID_STARTER",
        "basic" => "STRIPE_PRICE_ID_BASIC", 
        "popular" => "STRIPE_PRICE_ID_POPULAR",
        "business" => "STRIPE_PRICE_ID_BUSINESS",
        "enterprise" => "STRIPE_PRICE_ID_ENTERPRISE",
        _ => return None,
    };
    
    let result = env.var(var_name).ok().map(|v| v.to_string());
    
    if result.is_none() {
        worker::console_log!("Failed to get Stripe price ID for pack '{}', env var '{}' not found", pack_id, var_name);
    } else {
        worker::console_log!("Found Stripe price ID for pack '{}': {:?}", pack_id, result);
    }
    
    result
}