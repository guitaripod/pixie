use worker::{Request, Response, RouteContext, Result, Env, Fetch, Method, Headers};
use crate::error::AppError;
use crate::auth::validate_api_key;
use crate::credits::{
    get_user_balance, get_user_transactions, get_credit_packs, 
    record_purchase, complete_purchase, add_credits, estimate_image_cost
};
use serde::{Deserialize, Serialize};
use serde_json::json;
use uuid::Uuid;
use chrono::Utc;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreditBalanceResponse {
    pub balance: i32,
    pub currency: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EstimateCostRequest {
    pub prompt: Option<String>,
    pub quality: String,
    pub size: String,
    pub n: Option<u8>,
    pub is_edit: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EstimateCostResponse {
    pub estimated_credits: u32,
    pub estimated_usd: String,
    pub note: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PurchaseRequest {
    pub pack_id: String,
    pub payment_provider: String,
    pub payment_id: String,
    pub payment_currency: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CompletePurchaseRequest {
    pub purchase_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateStripeCheckoutRequest {
    pub pack_id: String,
    pub success_url: String,
    pub cancel_url: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateStripeCheckoutResponse {
    pub checkout_url: String,
    pub session_id: String,
    pub purchase_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StripeConfigResponse {
    pub publishable_key: String,
    pub enabled: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AdminAdjustCreditsRequest {
    pub user_id: String,
    pub amount: i32,
    pub reason: String,
}

pub async fn get_balance(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let env = ctx.env;
    
    let user_id = match validate_api_key(&req) {
        Err(e) => return e.to_response(),
        Ok(api_key) => {
            let db = env.d1("DB")?;
            let stmt = db.prepare("SELECT id FROM users WHERE api_key = ?");
            let result = stmt
                .bind(&[api_key.clone().into()])?
                .first::<serde_json::Value>(None)
                .await?;
            
            match result {
                Some(value) => value.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                None => return AppError::Unauthorized("Invalid API key".to_string()).to_response(),
            }
        }
    };
    
    let db = env.d1("DB")?;
    let balance = get_user_balance(&user_id, &db).await?;
    
    Response::from_json(&CreditBalanceResponse {
        balance,
        currency: "credits".to_string(),
    })
}

pub async fn list_transactions(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let env = ctx.env;
    let url = req.url()?;
    let query_params: std::collections::HashMap<String, String> = url
        .query_pairs()
        .into_owned()
        .collect();
    
    let page = query_params
        .get("page")
        .and_then(|p| p.parse::<i32>().ok())
        .unwrap_or(1)
        .max(1);
    
    let per_page = query_params
        .get("per_page")
        .and_then(|p| p.parse::<i32>().ok())
        .unwrap_or(50)
        .min(100);
    
    let offset = (page - 1) * per_page;
    
    let user_id = match validate_api_key(&req) {
        Err(e) => return e.to_response(),
        Ok(api_key) => {
            let db = env.d1("DB")?;
            let stmt = db.prepare("SELECT id FROM users WHERE api_key = ?");
            let result = stmt
                .bind(&[api_key.clone().into()])?
                .first::<serde_json::Value>(None)
                .await?;
            
            match result {
                Some(value) => value.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                None => return AppError::Unauthorized("Invalid API key".to_string()).to_response(),
            }
        }
    };
    
    let db = env.d1("DB")?;
    let transactions = get_user_transactions(&user_id, per_page, offset, &db).await?;
    
    Response::from_json(&json!({
        "transactions": transactions,
        "page": page,
        "per_page": per_page,
    }))
}

pub async fn list_packs(_req: Request, _ctx: RouteContext<()>) -> Result<Response> {
    let packs = get_credit_packs();
    Response::from_json(&json!({
        "packs": packs,
    }))
}

pub async fn estimate_cost(mut req: Request, _ctx: RouteContext<()>) -> Result<Response> {
    let estimate_req: EstimateCostRequest = match req.json().await {
        Ok(req) => req,
        Err(e) => return AppError::BadRequest(format!("Invalid request body: {}", e)).to_response(),
    };
    
    let n = estimate_req.n.unwrap_or(1);
    let is_edit = estimate_req.is_edit.unwrap_or(false);
    
    let credits_per_image = estimate_image_cost(&estimate_req.quality, &estimate_req.size, is_edit);
    let total_credits = credits_per_image * n as u32;
    
    Response::from_json(&EstimateCostResponse {
        estimated_credits: total_credits,
        estimated_usd: format!("${:.2}", total_credits as f64 / 100.0),
        note: format!(
            "Actual cost may vary ±{} credits based on prompt complexity",
            (total_credits as f64 * 0.15) as u32 + 1
        ),
    })
}

pub async fn purchase_credits(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let env = ctx.env;
    
    let user_id = match validate_api_key(&req) {
        Err(e) => return e.to_response(),
        Ok(api_key) => {
            let db = env.d1("DB")?;
            let stmt = db.prepare("SELECT id FROM users WHERE api_key = ?");
            let result = stmt
                .bind(&[api_key.clone().into()])?
                .first::<serde_json::Value>(None)
                .await?;
            
            match result {
                Some(value) => value.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                None => return AppError::Unauthorized("Invalid API key".to_string()).to_response(),
            }
        }
    };
    
    let purchase_req: PurchaseRequest = match req.json().await {
        Ok(req) => req,
        Err(e) => return AppError::BadRequest(format!("Invalid request body: {}", e)).to_response(),
    };
    
    // Find the pack
    let packs = get_credit_packs();
    let pack = packs
        .iter()
        .find(|p| p.id == purchase_req.pack_id)
        .ok_or_else(|| AppError::BadRequest("Invalid pack_id".to_string()))?;
    
    let total_credits = pack.credits + pack.bonus_credits;
    
    let db = env.d1("DB")?;
    
    match purchase_req.payment_provider.as_str() {
        "stripe" => {
            let purchase_id = record_purchase(
                &user_id,
                &purchase_req.pack_id,
                total_credits as u32,
                pack.price_usd_cents as u32,
                &purchase_req.payment_provider,
                &purchase_req.payment_id,
                &db,
            ).await?;
            
            Response::from_json(&json!({
                "purchase_id": purchase_id,
                "status": "pending",
                "credits": total_credits,
                "amount_usd": format!("${:.2}", pack.price_usd_cents as f64 / 100.0),
            }))
        },
        "nowpayments" => {
            if purchase_req.pack_id == "starter" {
                return AppError::BadRequest(
                    "Crypto payments are not available for the Starter pack due to minimum transaction requirements. Please use a credit/debit card or choose a larger pack.".to_string()
                ).to_response();
            }
            
            let purchase_id = record_purchase(
                &user_id,
                &purchase_req.pack_id,
                total_credits as u32,
                pack.price_usd_cents as u32,
                &purchase_req.payment_provider,
                "",  // We'll update with payment_id after creating crypto payment
                &db,
            ).await?;
            
            let crypto_currency = purchase_req.payment_currency
                .as_deref()
                .unwrap_or("btc");
            
            let crypto_response = crate::crypto_payments::create_crypto_payment(
                &env,
                &purchase_id,
                &pack.name,
                pack.price_usd_cents as f64 / 100.0,
                total_credits as u32,
                crypto_currency,
            ).await?;
            
            // Update purchase with crypto payment_id
            db.prepare(
                "UPDATE credit_purchases SET payment_id = ? WHERE id = ?"
            )
            .bind(&[
                crypto_response.payment_id.clone().into(),
                purchase_id.into(),
            ])?
            .run()
            .await?;
            
            Response::from_json(&crypto_response)
        },
        _ => AppError::BadRequest("Invalid payment provider".to_string()).to_response()
    }
}

pub async fn complete_purchase_webhook(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let env = ctx.env;
    
    let complete_req: CompletePurchaseRequest = match req.json().await {
        Ok(req) => req,
        Err(e) => return AppError::BadRequest(format!("Invalid request body: {}", e)).to_response(),
    };
    
    let db = env.d1("DB")?;
    complete_purchase(&complete_req.purchase_id, &db).await?;
    
    Response::ok("Purchase completed")
}

// Admin endpoints
pub async fn admin_adjust_credits(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let env = ctx.env;
    
    let admin_user_id = match validate_api_key(&req) {
        Err(e) => return e.to_response(),
        Ok(api_key) => {
            let db = env.d1("DB")?;
            let stmt = db.prepare("SELECT id, email, is_admin FROM users WHERE api_key = ?");
            let result = stmt
                .bind(&[api_key.clone().into()])?
                .first::<serde_json::Value>(None)
                .await?;
            
            match result {
                Some(value) => {
                    let is_admin = value.get("is_admin")
                        .and_then(|v| v.as_i64())
                        .map(|v| v != 0)
                        .unwrap_or(false);
                    if !is_admin {
                        return AppError::Forbidden("Admin access required".to_string()).to_response();
                    }
                    value.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string()
                },
                None => return AppError::Unauthorized("Invalid API key".to_string()).to_response(),
            }
        }
    };
    
    let adjust_req: AdminAdjustCreditsRequest = match req.json().await {
        Ok(req) => req,
        Err(e) => return AppError::BadRequest(format!("Invalid request body: {}", e)).to_response(),
    };
    
    let db = env.d1("DB")?;
    
    let description = format!("Admin adjustment by {}: {}", admin_user_id, adjust_req.reason);
    
    let new_balance = if adjust_req.amount > 0 {
        // Positive adjustment - add credits
        add_credits(
            &adjust_req.user_id,
            adjust_req.amount as u32,
            "admin_adjustment",
            &description,
            None,
            &db,
        ).await?
    } else {
        // Negative adjustment - deduct credits but ensure balance doesn't go below 0
        let current_balance = get_user_balance(&adjust_req.user_id, &db).await?;
        let amount_to_deduct = adjust_req.amount.abs() as u32;
        
        // Calculate new balance, but don't go below 0
        let new_balance = if current_balance >= amount_to_deduct as i32 {
            current_balance - amount_to_deduct as i32
        } else {
            0
        };
        
        // Calculate actual amount deducted
        let actual_deduction = current_balance - new_balance;
        
        // Update balance
        db.prepare(
            "UPDATE user_credits 
             SET balance = ?, updated_at = ? 
             WHERE user_id = ?"
        )
        .bind(&[
            new_balance.into(),
            Utc::now().to_rfc3339().into(),
            adjust_req.user_id.clone().into(),
        ])?
        .run()
        .await?;
        
        // Record transaction with actual amount deducted
        let transaction_id = Uuid::new_v4().to_string();
        db.prepare(
            "INSERT INTO credit_transactions (id, user_id, type, amount, balance_after, description, reference_id, created_at) 
             VALUES (?, ?, ?, ?, ?, ?, NULL, ?)"
        )
        .bind(&[
            transaction_id.into(),
            adjust_req.user_id.clone().into(),
            "admin_adjustment".into(),
            (-actual_deduction).into(), // Negative amount for deduction
            new_balance.into(),
            description.into(),
            Utc::now().to_rfc3339().into(),
        ])?
        .run()
        .await?;
        
        new_balance
    };
    
    Response::from_json(&json!({
        "user_id": adjust_req.user_id,
        "adjustment": adjust_req.amount,
        "new_balance": new_balance,
        "reason": adjust_req.reason,
    }))
}

pub async fn admin_system_stats(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let env = ctx.env;
    
    match validate_api_key(&req) {
        Err(e) => return e.to_response(),
        Ok(api_key) => {
            let db = env.d1("DB")?;
            let stmt = db.prepare("SELECT id, is_admin FROM users WHERE api_key = ?");
            let result = stmt
                .bind(&[api_key.clone().into()])?
                .first::<serde_json::Value>(None)
                .await?;
            
            match result {
                Some(value) => {
                    let is_admin = value.get("is_admin")
                        .and_then(|v| v.as_i64())
                        .map(|v| v != 0)
                        .unwrap_or(false);
                    if !is_admin {
                        return AppError::Forbidden("Admin access required".to_string()).to_response();
                    }
                },
                None => return AppError::Unauthorized("Invalid API key".to_string()).to_response(),
            }
        }
    };
    
    let db = env.d1("DB")?;
    
    // Get system-wide statistics
    let total_users = db
        .prepare("SELECT COUNT(*) as count FROM users")
        .first::<serde_json::Value>(None)
        .await?
        .and_then(|v| v.get("count").and_then(|c| c.as_i64()))
        .unwrap_or(0);
    
    let total_credits_balance = db
        .prepare("SELECT SUM(balance) as total FROM user_credits")
        .first::<serde_json::Value>(None)
        .await?
        .and_then(|v| v.get("total").and_then(|c| c.as_i64()))
        .unwrap_or(0);
    
    let total_purchased = db
        .prepare("SELECT SUM(lifetime_purchased) as total FROM user_credits")
        .first::<serde_json::Value>(None)
        .await?
        .and_then(|v| v.get("total").and_then(|c| c.as_i64()))
        .unwrap_or(0);
    
    let total_spent = db
        .prepare("SELECT SUM(lifetime_spent) as total FROM user_credits")
        .first::<serde_json::Value>(None)
        .await?
        .and_then(|v| v.get("total").and_then(|c| c.as_i64()))
        .unwrap_or(0);
    
    let total_revenue = db
        .prepare("SELECT SUM(amount_usd_cents) as total FROM credit_purchases WHERE status = 'completed'")
        .first::<serde_json::Value>(None)
        .await?
        .and_then(|v| v.get("total").and_then(|c| c.as_i64()))
        .unwrap_or(0);
    
    let total_images = db
        .prepare("SELECT COUNT(*) as count FROM stored_images")
        .first::<serde_json::Value>(None)
        .await?
        .and_then(|v| v.get("count").and_then(|c| c.as_i64()))
        .unwrap_or(0);
    
    let openai_costs = db
        .prepare("SELECT SUM(openai_cost_cents) as total FROM stored_images")
        .first::<serde_json::Value>(None)
        .await?
        .and_then(|v| v.get("total").and_then(|c| c.as_i64()))
        .unwrap_or(0);
    
    Response::from_json(&json!({
        "users": {
            "total": total_users,
        },
        "credits": {
            "total_balance": total_credits_balance,
            "total_purchased": total_purchased,
            "total_spent": total_spent,
        },
        "revenue": {
            "total_usd": format!("${:.2}", total_revenue as f64 / 100.0),
            "openai_costs_usd": format!("${:.2}", openai_costs as f64 / 100.0),
            "gross_profit_usd": format!("${:.2}", (total_revenue - openai_costs) as f64 / 100.0),
            "profit_margin": format!("{:.1}%", ((total_revenue - openai_costs) as f64 / total_revenue as f64) * 100.0),
        },
        "images": {
            "total_generated": total_images,
        }
    }))
}

pub async fn crypto_payment_webhook(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let env = ctx.env;
    
    // Get the signature from headers
    let signature = req.headers().get("x-nowpayments-sig")?
        .ok_or_else(|| AppError::BadRequest("Missing signature header".to_string()))?;
    
    // Get the raw body for signature verification
    let body = req.text().await?;
    
    // Verify webhook signature
    if !crate::crypto_payments::verify_webhook_signature(&env, &signature, &body)? {
        return AppError::Unauthorized("Invalid webhook signature".to_string()).to_response();
    }
    
    // Parse the webhook data
    let webhook: crate::crypto_payments::NOWPaymentsWebhook = serde_json::from_str(&body)
        .map_err(|e| AppError::BadRequest(format!("Invalid webhook body: {}", e)))?;
    
    // Only process confirmed payments
    if webhook.payment_status == "finished" || webhook.payment_status == "confirmed" {
        let db = env.d1("DB")?;
        
        // Complete the purchase using the order_id (which is our purchase_id)
        complete_purchase(&webhook.order_id, &db).await?;
    }
    
    Response::ok("OK")
}

pub async fn get_purchase_status(_req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let purchase_id = ctx.param("purchase_id")
        .ok_or_else(|| AppError::BadRequest("Missing purchase_id".to_string()))?
        .to_string();
    let env = ctx.env;
    
    let db = env.d1("DB")?;
    
    // Get purchase details
    let purchase = db
        .prepare("SELECT status, payment_provider, payment_id FROM credit_purchases WHERE id = ?")
        .bind(&[purchase_id.clone().into()])?
        .first::<serde_json::Value>(None)
        .await?
        .ok_or_else(|| AppError::NotFound("Purchase not found".to_string()))?;
    
    let status = purchase.get("status")
        .and_then(|s| s.as_str())
        .unwrap_or("unknown");
    
    let payment_provider = purchase.get("payment_provider")
        .and_then(|s| s.as_str())
        .unwrap_or("");
    
    // For crypto payments, get live status from NOWPayments
    if payment_provider == "nowpayments" && status == "pending" {
        let payment_id = purchase.get("payment_id")
            .and_then(|s| s.as_str())
            .unwrap_or("");
        
        if !payment_id.is_empty() {
            match crate::crypto_payments::get_payment_status(&env, payment_id).await {
                Ok(crypto_status) => {
                    // If payment is finished, complete the purchase
                    if crypto_status == "finished" || crypto_status == "confirmed" {
                        complete_purchase(&purchase_id, &db).await?;
                        
                        Response::from_json(&json!({
                            "purchase_id": purchase_id,
                            "status": "completed",
                            "payment_status": crypto_status,
                        }))
                    } else {
                        Response::from_json(&json!({
                            "purchase_id": purchase_id,
                            "status": status,
                            "payment_status": crypto_status,
                        }))
                    }
                },
                Err(_) => {
                    Response::from_json(&json!({
                        "purchase_id": purchase_id,
                        "status": status,
                    }))
                }
            }
        } else {
            Response::from_json(&json!({
                "purchase_id": purchase_id,
                "status": status,
            }))
        }
    }
    // For Stripe payments, get live status from Stripe
    else if payment_provider == "stripe" && status == "pending" {
        let session_id = purchase.get("payment_id")
            .and_then(|s| s.as_str())
            .unwrap_or("");
        
        if !session_id.is_empty() {
            match crate::stripe_payments::get_checkout_session(&env, session_id).await {
                Ok(session) => {
                    // If payment is completed, complete the purchase
                    if session.payment_status == "paid" {
                        complete_purchase(&purchase_id, &db).await?;
                        
                        Response::from_json(&json!({
                            "purchase_id": purchase_id,
                            "status": "completed",
                            "payment_status": session.payment_status,
                            "payment_method": "stripe",
                        }))
                    } else {
                        Response::from_json(&json!({
                            "purchase_id": purchase_id,
                            "status": status,
                            "payment_status": session.payment_status,
                            "payment_method": "stripe",
                        }))
                    }
                },
                Err(_) => {
                    Response::from_json(&json!({
                        "purchase_id": purchase_id,
                        "status": status,
                        "payment_method": "stripe",
                    }))
                }
            }
        } else {
            Response::from_json(&json!({
                "purchase_id": purchase_id,
                "status": status,
                "payment_method": "stripe",
            }))
        }
    } else {
        Response::from_json(&json!({
            "purchase_id": purchase_id,
            "status": status,
        }))
    }
}

pub async fn create_stripe_checkout(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let env = ctx.env;
    
    let user_id = match validate_api_key(&req) {
        Err(e) => return e.to_response(),
        Ok(api_key) => {
            let db = env.d1("DB")?;
            let stmt = db.prepare("SELECT id, email FROM users WHERE api_key = ?");
            let result = stmt
                .bind(&[api_key.clone().into()])?
                .first::<serde_json::Value>(None)
                .await?;
            
            match result {
                Some(value) => {
                    let user_id = value.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string();
                    let email = value.get("email").and_then(|v| v.as_str());
                    (user_id, email.map(|s| s.to_string()))
                },
                None => return AppError::Unauthorized("Invalid API key".to_string()).to_response(),
            }
        }
    };
    
    let checkout_req: CreateStripeCheckoutRequest = match req.json().await {
        Ok(req) => req,
        Err(e) => return AppError::BadRequest(format!("Invalid request body: {}", e)).to_response(),
    };
    
    // Find the pack
    let packs = get_credit_packs();
    let pack = packs
        .iter()
        .find(|p| p.id == checkout_req.pack_id)
        .ok_or_else(|| AppError::BadRequest("Invalid pack_id".to_string()))?;
    
    // Get Stripe price ID for this pack
    let stripe_price_id = crate::stripe_payments::get_stripe_price_id(&env, &checkout_req.pack_id)
        .ok_or_else(|| AppError::BadRequest(
            format!("The '{}' pack is not available for card payments. Please try a different pack or payment method.", checkout_req.pack_id)
        ))?;
    
    let total_credits = pack.credits + pack.bonus_credits;
    
    let db = env.d1("DB")?;
    
    // Record the purchase in pending state
    let purchase_id = record_purchase(
        &user_id.0,
        &checkout_req.pack_id,
        total_credits as u32,
        pack.price_usd_cents as u32,
        "stripe",
        "", // We'll update with session_id after creating
        &db,
    ).await?;
    
    // Create Stripe checkout session
    let session = crate::stripe_payments::create_checkout_session(
        &env,
        &purchase_id,
        &checkout_req.pack_id,
        &pack.name,
        total_credits as u32,
        &stripe_price_id,
        &checkout_req.success_url,
        &checkout_req.cancel_url,
        user_id.1.as_deref(),
    ).await?;
    
    // Update purchase with Stripe session ID
    db.prepare(
        "UPDATE credit_purchases SET payment_id = ? WHERE id = ?"
    )
    .bind(&[
        session.id.clone().into(),
        purchase_id.clone().into(),
    ])?
    .run()
    .await?;
    
    Response::from_json(&CreateStripeCheckoutResponse {
        checkout_url: session.url.unwrap_or_else(|| "".to_string()),
        session_id: session.id,
        purchase_id,
    })
}

pub async fn stripe_webhook(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let env = ctx.env;
    
    // Get Stripe signature header
    let signature = req.headers().get("stripe-signature")?
        .ok_or_else(|| AppError::BadRequest("Missing stripe-signature header".to_string()))?;
    
    // Extract timestamp from signature
    let sig_parts: Vec<&str> = signature.split(',').collect();
    let mut timestamp = "";
    for part in &sig_parts {
        let kv: Vec<&str> = part.split('=').collect();
        if kv.len() == 2 && kv[0] == "t" {
            timestamp = kv[1];
            break;
        }
    }
    
    // Get the raw body for signature verification
    let body = req.text().await?;
    
    // Verify webhook signature
    if !crate::stripe_payments::verify_webhook_signature(&env, &signature, &body, timestamp)? {
        return AppError::Unauthorized("Invalid webhook signature".to_string()).to_response();
    }
    
    // Parse the webhook event
    let event: crate::stripe_payments::StripeWebhookEvent = serde_json::from_str(&body)
        .map_err(|e| AppError::BadRequest(format!("Invalid webhook body: {}", e)))?;
    
    worker::console_log!("Received Stripe webhook event: {}", event.event_type);
    
    // Handle different event types
    match event.event_type.as_str() {
        "checkout.session.completed" => {
            // Extract the session from the event
            let session: crate::stripe_payments::StripeCheckoutSession = serde_json::from_value(event.data.object)
                .map_err(|e| AppError::InternalError(format!("Failed to parse session: {}", e)))?;
            
            // Only process if payment is successful
            if session.payment_status == "paid" {
                // Extract purchase_id from metadata
                if let Some(purchase_id) = session.metadata.get("purchase_id") {
                    let db = env.d1("DB")?;
                    complete_purchase(purchase_id, &db).await?;
                    worker::console_log!("Completed purchase: {}", purchase_id);
                }
            }
        },
        "payment_intent.succeeded" => {
            worker::console_log!("Payment intent succeeded");
        },
        "payment_intent.payment_failed" => {
            worker::console_log!("Payment intent failed");
        },
        _ => {
            worker::console_log!("Unhandled event type: {}", event.event_type);
        }
    }
    
    Response::ok("OK")
}

pub async fn get_stripe_config(_req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let env = ctx.env;
    
    // Check if Stripe is configured
    let publishable_key = env.var("STRIPE_PUBLISHABLE_KEY")
        .ok()
        .map(|k| k.to_string())
        .unwrap_or_default();
    
    let enabled = !publishable_key.is_empty() && 
                  env.secret("STRIPE_SECRET_KEY").is_ok();
    
    Response::from_json(&StripeConfigResponse {
        publishable_key,
        enabled,
    })
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ValidateRevenueCatPurchaseRequest {
    pub pack_id: String,
    pub purchase_token: String,
    pub product_id: String,
    pub platform: String, // "ios" or "android"
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ValidateRevenueCatPurchaseResponse {
    pub success: bool,
    pub purchase_id: String,
    pub credits_added: u32,
    pub new_balance: i32,
}

pub async fn validate_revenuecat_purchase(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let env = ctx.env;
    
    let user_id = match validate_api_key(&req) {
        Err(e) => return e.to_response(),
        Ok(api_key) => {
            let db = env.d1("DB")?;
            let stmt = db.prepare("SELECT id FROM users WHERE api_key = ?");
            let result = stmt
                .bind(&[api_key.clone().into()])?
                .first::<serde_json::Value>(None)
                .await?;
            
            match result {
                Some(value) => value.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                None => return AppError::Unauthorized("Invalid API key".to_string()).to_response(),
            }
        }
    };
    
    let validate_req: ValidateRevenueCatPurchaseRequest = match req.json().await {
        Ok(req) => req,
        Err(e) => return AppError::BadRequest(format!("Invalid request body: {}", e)).to_response(),
    };
    
    // Validate platform
    if validate_req.platform != "ios" && validate_req.platform != "android" {
        return AppError::BadRequest("Invalid platform. Must be 'ios' or 'android'".to_string()).to_response();
    }
    
    // Find the pack
    let packs = get_credit_packs();
    let pack = packs
        .iter()
        .find(|p| p.id == validate_req.pack_id)
        .ok_or_else(|| AppError::BadRequest("Invalid pack_id".to_string()))?;
    
    let total_credits = pack.credits + pack.bonus_credits;
    
    let db = env.d1("DB")?;
    
    // Check if this purchase token has already been used
    let existing_purchase = db.prepare(
        "SELECT id, status FROM credit_purchases WHERE payment_id = ? AND payment_provider = 'revenuecat'"
    )
    .bind(&[validate_req.purchase_token.clone().into()])?
    .first::<serde_json::Value>(None)
    .await?;
    
    if let Some(existing) = existing_purchase {
        let status = existing.get("status").and_then(|v| v.as_str()).unwrap_or("");
        if status == "completed" {
            return AppError::BadRequest("Purchase has already been processed".to_string()).to_response();
        }
    }
    
    // Record the purchase
    let purchase_id = record_purchase(
        &user_id,
        &validate_req.pack_id,
        total_credits as u32,
        pack.price_usd_cents as u32,
        "revenuecat",
        &validate_req.purchase_token,
        &db,
    ).await?;
    
    // Validate with RevenueCat REST API
    let validation_result = validate_with_revenuecat(
        &env,
        &user_id,
        &validate_req.purchase_token,
        &validate_req.product_id,
        &validate_req.platform,
    ).await;
    
    match validation_result {
        Ok(is_valid) => {
            if !is_valid {
                // Delete the invalid purchase record
                db.prepare("DELETE FROM credit_purchases WHERE id = ?")
                    .bind(&[purchase_id.clone().into()])?
                    .run()
                    .await?;
                
                return AppError::BadRequest("Purchase validation failed with RevenueCat".to_string()).to_response();
            }
        }
        Err(e) => {
            // Log the error but continue - we don't want to block purchases if RevenueCat API is down
            worker::console_log!("RevenueCat validation error (continuing anyway): {}", e);
        }
    }
    
    // Complete the purchase
    complete_purchase(&purchase_id, &db).await?;
    
    // Add credits to user
    add_credits(
        &user_id,
        total_credits as u32,
        "purchase",
        &format!("{} purchase: {} pack", 
            if validate_req.platform == "ios" { "App Store" } else { "Google Play" },
            validate_req.pack_id
        ),
        Some(&purchase_id),
        &db
    ).await?;
    
    // Get new balance
    let new_balance = get_user_balance(&user_id, &db).await?;
    
    Response::from_json(&ValidateRevenueCatPurchaseResponse {
        success: true,
        purchase_id,
        credits_added: total_credits as u32,
        new_balance,
    })
}

#[derive(Debug, Serialize, Deserialize)]
struct RevenueCatSubscriber {
    entitlements: RevenueCatEntitlements,
    subscriber: RevenueCatSubscriberInfo,
}

#[derive(Debug, Serialize, Deserialize)]
struct RevenueCatEntitlements {
    #[serde(flatten)]
    all: std::collections::HashMap<String, RevenueCatEntitlement>,
}

#[derive(Debug, Serialize, Deserialize)]
struct RevenueCatEntitlement {
    expires_date: Option<String>,
    purchase_date: String,
    product_identifier: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct RevenueCatSubscriberInfo {
    original_app_user_id: String,
    #[serde(default)]
    non_subscriptions: std::collections::HashMap<String, Vec<RevenueCatNonSubscription>>,
}

#[derive(Debug, Serialize, Deserialize)]
struct RevenueCatNonSubscription {
    id: String,
    is_sandbox: bool,
    purchase_date: String,
    store: String,
}

async fn validate_with_revenuecat(
    env: &Env,
    _user_id: &str,
    purchase_token: &str,
    product_id: &str,
    platform: &str,
) -> Result<bool> {
    let revenuecat_api_key = env.secret("REVENUECAT_API_KEY")
        .map_err(|_| "REVENUECAT_API_KEY not configured")?;
    
    let api_key = revenuecat_api_key.to_string();
    
    // RevenueCat uses the purchase token as the subscriber ID for validation
    let subscriber_id = purchase_token;
    let url = format!("https://api.revenuecat.com/v1/subscribers/{}", subscriber_id);
    
    let headers = Headers::new();
    headers.set("X-RevCat-API-Key", &api_key)?;
    headers.set("Content-Type", "application/json")?;
    
    let mut init = worker::RequestInit::new();
    init.with_method(Method::Get)
        .with_headers(headers);
    
    let request = Request::new_with_init(&url, &init)?;
    let mut response = Fetch::Request(request).send().await?;
    
    let status_code = response.status_code();
    if status_code < 200 || status_code >= 300 {
        let error_text = response.text().await.unwrap_or_default();
        worker::console_log!("RevenueCat API error: {} - {}", status_code, error_text);
        return Err(format!("RevenueCat API error: {}", status_code).into());
    }
    
    let subscriber: RevenueCatSubscriber = response.json().await
        .map_err(|e| format!("Failed to parse RevenueCat response: {}", e))?;
    
    // Check if the user has the product in their non-subscriptions
    if let Some(non_subs) = subscriber.subscriber.non_subscriptions.get(product_id) {
        // Check if any of the purchases are valid (not refunded)
        for purchase in non_subs {
            if purchase.store.to_lowercase() == platform {
                // Purchase exists and matches the platform
                return Ok(true);
            }
        }
    }
    
    // Also check entitlements in case it's set up that way
    for (_, entitlement) in subscriber.entitlements.all.iter() {
        if entitlement.product_identifier == product_id {
            // Check if the entitlement is still valid (not expired)
            if entitlement.expires_date.is_none() {
                // No expiration means it's a one-time purchase
                return Ok(true);
            }
        }
    }
    
    Ok(false)
}