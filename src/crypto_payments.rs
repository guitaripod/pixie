use worker::{Request, Result, Fetch, Method, Env};
use serde::{Deserialize, Serialize};
use crate::error::AppError;

#[derive(Debug, Serialize)]
struct NOWPaymentsInvoiceRequest {
    price_amount: f64,
    price_currency: String,
    pay_currency: String,
    order_id: String,
    order_description: String,
    ipn_callback_url: String,
}

#[derive(Debug, Deserialize)]
struct NOWPaymentsInvoiceResponse {
    id: String,
    token_id: String,
    order_id: String,
    order_description: String,
    price_amount: String,
    price_currency: String,
    pay_currency: String,
    ipn_callback_url: String,
    invoice_url: String,
    success_url: String,
    cancel_url: String,
    created_at: String,
    updated_at: String,
}

#[derive(Debug, Serialize)]
struct NOWPaymentsPaymentRequest {
    price_amount: f64,
    price_currency: String,
    pay_currency: String,
    order_id: String,
    order_description: String,
}

#[derive(Debug, Deserialize)]
pub struct NOWPaymentsPaymentResponse {
    pub payment_id: serde_json::Value, // Can be string or number
    pub payment_status: String,
    pub pay_address: String,
    pub price_amount: f64,
    pub price_currency: String,
    pub pay_amount: f64,
    pub pay_currency: String,
    pub order_id: String,
    pub order_description: String,
    pub expiry_estimate: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Deserialize)]
pub struct NOWPaymentsWebhook {
    pub payment_id: i64,
    pub payment_status: String,
    pub pay_address: String,
    pub price_amount: f64,
    pub price_currency: String,
    pub pay_amount: f64,
    pub actually_paid: f64,
    pub pay_currency: String,
    pub order_id: String,
    pub order_description: String,
    pub purchase_id: String,
    pub outcome_amount: f64,
    pub outcome_currency: String,
}

#[derive(Debug, Serialize)]
pub struct CryptoPaymentResponse {
    pub purchase_id: String,
    pub payment_id: String,
    pub status: String,
    pub credits: u32,
    pub amount_usd: String,
    pub crypto_address: String,
    pub crypto_amount: String,
    pub crypto_currency: String,
    pub expires_at: String,
}

pub async fn create_crypto_payment(
    env: &Env,
    purchase_id: &str,
    pack_name: &str,
    amount_usd: f64,
    credits: u32,
    currency: &str,
) -> Result<CryptoPaymentResponse> {
    let api_key = env.secret("NOWPAYMENTS_API_KEY")?.to_string();
    
    let payment_request = NOWPaymentsPaymentRequest {
        price_amount: amount_usd,
        price_currency: "usd".to_string(),
        pay_currency: currency.to_lowercase(),
        order_id: purchase_id.to_string(),
        order_description: format!("{} Credit Pack", pack_name),
    };
    
    let headers = worker::Headers::new();
    headers.set("x-api-key", &api_key)?;
    headers.set("Content-Type", "application/json")?;
    
    let request = Request::new_with_init(
        "https://api.nowpayments.io/v1/payment",
        worker::RequestInit::new()
            .with_method(Method::Post)
            .with_headers(headers)
            .with_body(Some(serde_json::to_string(&payment_request)?.into()))
    )?;
    
    let mut response = Fetch::Request(request).send().await?;
    
    if response.status_code() < 200 || response.status_code() >= 300 {
        let error_text = response.text().await?;
        return Err(AppError::BadRequest(format!("NOWPayments error: {}", error_text)).into());
    }
    
    let payment_data: NOWPaymentsPaymentResponse = response.json().await?;
    
    // Extract payment_id as string, removing quotes if it's a JSON string
    let payment_id_str = match &payment_data.payment_id {
        serde_json::Value::Number(n) => n.to_string(),
        serde_json::Value::String(s) => s.clone(),
        _ => return Err(AppError::InternalError("Invalid payment_id type".to_string()).into()),
    };
    
    Ok(CryptoPaymentResponse {
        purchase_id: purchase_id.to_string(),
        payment_id: payment_id_str,
        status: "pending".to_string(),
        credits,
        amount_usd: format!("${:.2}", amount_usd),
        crypto_address: payment_data.pay_address,
        crypto_amount: format!("{:.8}", payment_data.pay_amount),
        crypto_currency: currency.to_uppercase(),
        expires_at: payment_data.expiry_estimate.unwrap_or_else(|| "30 minutes".to_string()),
    })
}

pub async fn get_payment_status(env: &Env, payment_id: &str) -> Result<String> {
    let api_key = env.secret("NOWPAYMENTS_API_KEY")?.to_string();
    
    let mut headers = worker::Headers::new();
    headers.set("x-api-key", &api_key)?;
    
    // Remove quotes if present
    let clean_payment_id = payment_id.trim_matches('"');
    
    worker::console_log!("Checking payment status for ID: {}", clean_payment_id);
    
    let request = Request::new_with_init(
        &format!("https://api.nowpayments.io/v1/payment/{}", clean_payment_id),
        worker::RequestInit::new()
            .with_method(Method::Get)
            .with_headers(headers)
    )?;
    
    let mut response = Fetch::Request(request).send().await?;
    
    if response.status_code() < 200 || response.status_code() >= 300 {
        let error_text = response.text().await?;
        worker::console_log!("NOWPayments API error: {} - {}", response.status_code(), error_text);
        return Err(AppError::BadRequest(format!("Failed to get payment status: {}", error_text)).into());
    }
    
    let payment_data: NOWPaymentsPaymentResponse = response.json().await?;
    Ok(payment_data.payment_status)
}

pub fn verify_webhook_signature(env: &Env, signature: &str, body: &str) -> Result<bool> {
    let ipn_secret = env.secret("NOWPAYMENTS_IPN_SECRET")?.to_string();
    
    // Parse JSON and sort keys alphabetically
    let parsed: serde_json::Value = serde_json::from_str(body)
        .map_err(|e| AppError::BadRequest(format!("Invalid JSON in webhook: {}", e)))?;
    
    // Convert to sorted JSON string
    let sorted_json = serde_json::to_string(&parsed)
        .map_err(|e| AppError::InternalError(format!("Failed to serialize JSON: {}", e)))?;
    
    // NOWPayments uses HMAC-SHA512 for webhook signatures
    use hmac::{Hmac, Mac};
    use sha2::Sha512;
    
    type HmacSha512 = Hmac<Sha512>;
    
    let mut mac = HmacSha512::new_from_slice(ipn_secret.as_bytes())
        .map_err(|_| AppError::InternalError("Invalid IPN secret".to_string()))?;
    
    mac.update(sorted_json.as_bytes());
    
    let expected_signature = hex::encode(mac.finalize().into_bytes());
    
    worker::console_log!("Expected signature: {}", expected_signature);
    worker::console_log!("Received signature: {}", signature);
    
    Ok(signature == expected_signature)
}