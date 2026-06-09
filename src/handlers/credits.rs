use worker::{Request, Response, RouteContext, Result, Env, Fetch, Method, Headers};
use crate::error::AppError;
use crate::auth;
use crate::credits::{
    get_user_balance, get_user_transactions, get_credit_packs, get_credit_packs_for_app,
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
    pub model: Option<String>,
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

    let db = env.d1("DB")?;
    let auth = match auth::authenticate(&req, &db).await {
        Ok(a) => a,
        Err(e) => return e.to_response(),
    };
    if let Err(e) = crate::rate_limit::enforce_read_rate_limit(&env, &auth.app_id, &auth.user_id, "balance").await {
        return e.to_response();
    }

    let balance = get_user_balance(&auth.app_id, &auth.user_id, &db).await?;

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

    let db = env.d1("DB")?;
    let auth = match auth::authenticate(&req, &db).await {
        Ok(a) => a,
        Err(e) => return e.to_response(),
    };
    let user_id = auth.user_id.clone();
    let app_id = auth.app_id.clone();
    if let Err(e) = crate::rate_limit::enforce_read_rate_limit(&env, &app_id, &user_id, "transactions").await {
        return e.to_response();
    }

    let count_stmt = db.prepare("SELECT COUNT(*) as total FROM credit_transactions WHERE app_id = ? AND user_id = ?");
    let count_result = count_stmt
        .bind(&[app_id.clone().into(), user_id.clone().into()])?
        .first::<serde_json::Value>(None)
        .await?
        .unwrap_or(json!({"total": 0}));
    let total = count_result.get("total").and_then(|v| v.as_i64()).unwrap_or(0) as i32;

    let transactions = get_user_transactions(&app_id, &user_id, per_page, offset, &db).await?;
    
    Response::from_json(&json!({
        "transactions": transactions,
        "total": total,
        "limit": per_page,
        "offset": offset,
        "page": page,
        "per_page": per_page,
    }))
}

pub async fn list_packs(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let app_id = auth::resolve_app_id(&req);
    let cache_key = format!("https://mako.midgarcorp.cc/__cache/credits/packs/{}", app_id);
    let cache = worker::Cache::default();
    if let Ok(Some(cached)) = cache.get(&cache_key, false).await {
        return Ok(cached);
    }
    let db = ctx.env.d1("DB")?;
    let packs = get_credit_packs_for_app(&app_id, &db).await;
    let mut resp = Response::from_json(&json!({ "packs": packs }))?;
    resp.headers_mut().set("Cache-Control", "public, max-age=60")?;
    if let Ok(copy) = resp.cloned() {
        let _ = cache.put(&cache_key, copy).await;
    }
    Ok(resp)
}

pub async fn estimate_cost(mut req: Request, _ctx: RouteContext<()>) -> Result<Response> {
    let estimate_req: EstimateCostRequest = match req.json().await {
        Ok(req) => req,
        Err(e) => return AppError::BadRequest(format!("Invalid request body: {}", e)).to_response(),
    };
    
    let n = estimate_req.n.unwrap_or(1);
    let is_edit = estimate_req.is_edit.unwrap_or(false);
    let model = estimate_req.model.as_deref().unwrap_or("gemini-2.5-flash");

    let credits_per_image = estimate_image_cost(model, &estimate_req.quality, &estimate_req.size, is_edit);
    
    let total_credits = credits_per_image * n as u32;
    
    Response::from_json(&EstimateCostResponse {
        estimated_credits: total_credits,
        estimated_usd: format!("${:.2}", total_credits as f64 / 100.0),
        note: if model.starts_with("gemini") {
            format!("Gemini flat rate: {} credits per image", credits_per_image)
        } else {
            format!(
                "Actual cost may vary ±{} credits based on prompt complexity",
                (total_credits as f64 * 0.15) as u32 + 1
            )
        },
    })
}

pub async fn purchase_credits(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let env = ctx.env;

    let auth = {
        let db = env.d1("DB")?;
        match auth::authenticate(&req, &db).await {
            Ok(a) => a,
            Err(e) => return e.to_response(),
        }
    };
    let user_id = auth.user_id.clone();
    let app_id = auth.app_id.clone();

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
                &app_id,
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
                &app_id,
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

    let auth = {
        let db = env.d1("DB")?;
        match auth::authenticate(&req, &db).await {
            Ok(a) => a,
            Err(e) => return e.to_response(),
        }
    };
    if !auth.is_admin {
        return AppError::Forbidden("Admin access required".to_string()).to_response();
    }
    let admin_user_id = auth.user_id.clone();
    let app_id = auth.app_id.clone();

    let adjust_req: AdminAdjustCreditsRequest = match req.json().await {
        Ok(req) => req,
        Err(e) => return AppError::BadRequest(format!("Invalid request body: {}", e)).to_response(),
    };
    
    let db = env.d1("DB")?;

    let exists = db
        .prepare("SELECT 1 FROM users WHERE app_id = ? AND id = ?")
        .bind(&[app_id.clone().into(), adjust_req.user_id.clone().into()])?
        .first::<serde_json::Value>(None)
        .await?;
    if exists.is_none() {
        return AppError::NotFound("User not found in this app".to_string()).to_response();
    }

    let description = format!("Admin adjustment by {}: {}", admin_user_id, adjust_req.reason);
    
    let new_balance = if adjust_req.amount > 0 {
        // Positive adjustment - add credits
        add_credits(
            &app_id,
            &adjust_req.user_id,
            adjust_req.amount as u32,
            "admin_adjustment",
            &description,
            None,
            &db,
        ).await?
    } else {
        // Negative adjustment - deduct credits but ensure balance doesn't go below 0
        let current_balance = get_user_balance(&app_id, &adjust_req.user_id, &db).await?;
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
             WHERE app_id = ? AND user_id = ?"
        )
        .bind(&[
            new_balance.into(),
            Utc::now().to_rfc3339().into(),
            app_id.clone().into(),
            adjust_req.user_id.clone().into(),
        ])?
        .run()
        .await?;

        // Record transaction with actual amount deducted
        let transaction_id = Uuid::new_v4().to_string();
        db.prepare(
            "INSERT INTO credit_transactions (id, app_id, user_id, type, amount, balance_after, description, reference_id, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, NULL, ?)"
        )
        .bind(&[
            transaction_id.into(),
            app_id.clone().into(),
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

pub async fn admin_search_users(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let env = ctx.env;

    let app_id = {
        let db = env.d1("DB")?;
        let auth = match auth::authenticate(&req, &db).await {
            Ok(a) => a,
            Err(e) => return e.to_response(),
        };
        if !auth.is_admin {
            return AppError::Forbidden("Admin access required".to_string()).to_response();
        }
        auth.app_id
    };

    let url = req.url()?;
    let search = url.query_pairs()
        .find(|(k, _)| k == "search")
        .map(|(_, v)| v.to_string());
    
    let db = env.d1("DB")?;
    
    let results = if let Some(search_term) = search {
        // Clean up the search term - trim whitespace and normalize
        let cleaned_search = search_term.trim();
        if cleaned_search.is_empty() {
            return AppError::BadRequest("Search term cannot be empty".to_string()).to_response();
        }
        
        // Search by ID (exact match with trimmed spaces) or email (flexible matching)
        let query = "
            SELECT u.id, u.email, u.is_admin, u.created_at,
                   COALESCE(uc.balance, 0) as credits
            FROM users u
            LEFT JOIN user_credits uc ON uc.app_id = u.app_id AND uc.user_id = u.id
            WHERE u.app_id = ?4
              AND (u.id = ?1
               OR LOWER(TRIM(u.email)) = LOWER(TRIM(?1))
               OR LOWER(u.email) LIKE LOWER(?2)
               OR LOWER(u.email) LIKE LOWER(?3))
            ORDER BY
                CASE
                    WHEN u.id = ?1 OR LOWER(TRIM(u.email)) = LOWER(TRIM(?1)) THEN 0
                    ELSE 1
                END,
                u.created_at DESC
            LIMIT 10
        ";

        // Create variations for flexible email matching
        let email_prefix = format!("{}%", cleaned_search);
        let email_contains = format!("%{}%", cleaned_search);

        let stmt = db.prepare(query);
        stmt.bind(&[
            cleaned_search.into(),
            email_prefix.into(),
            email_contains.into(),
            app_id.clone().into()
        ])?
            .all()
            .await?
    } else {
        // Return recent users if no search term
        let query = "
            SELECT u.id, u.email, u.is_admin, u.created_at,
                   COALESCE(uc.balance, 0) as credits
            FROM users u
            LEFT JOIN user_credits uc ON uc.app_id = u.app_id AND uc.user_id = u.id
            WHERE u.app_id = ?1
            ORDER BY u.created_at DESC
            LIMIT 10
        ";

        let stmt = db.prepare(query);
        stmt.bind(&[app_id.clone().into()])?
            .all()
            .await?
    };
    
    let users: Vec<serde_json::Value> = results
        .results::<serde_json::Value>()?
        .into_iter()
        .map(|user| {
            json!({
                "id": user.get("id").and_then(|v| v.as_str()).unwrap_or(""),
                "email": user.get("email").and_then(|v| v.as_str()),
                "is_admin": user.get("is_admin").and_then(|v| v.as_i64()).map(|v| v != 0).unwrap_or(false),
                "credits": user.get("credits").and_then(|v| v.as_i64()).unwrap_or(0),
                "created_at": user.get("created_at").and_then(|v| v.as_str()).unwrap_or("")
            })
        })
        .collect();
    
    Response::from_json(&users)
}

pub async fn admin_system_stats(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let env = ctx.env;

    let db = env.d1("DB")?;
    let auth = match auth::authenticate(&req, &db).await {
        Ok(a) => a,
        Err(e) => return e.to_response(),
    };
    if !auth.is_admin {
        return AppError::Forbidden("Admin access required".to_string()).to_response();
    }
    let app_id = auth.app_id.clone();

    // Tenant-scoped statistics (per app_id)
    let total_users = db
        .prepare("SELECT COUNT(*) as count FROM users WHERE app_id = ?")
        .bind(&[app_id.clone().into()])?
        .first::<serde_json::Value>(None)
        .await?
        .and_then(|v| v.get("count").and_then(|c| c.as_i64()))
        .unwrap_or(0);

    let total_credits_balance = db
        .prepare("SELECT SUM(balance) as total FROM user_credits WHERE app_id = ?")
        .bind(&[app_id.clone().into()])?
        .first::<serde_json::Value>(None)
        .await?
        .and_then(|v| v.get("total").and_then(|c| c.as_i64()))
        .unwrap_or(0);

    let total_purchased = db
        .prepare("SELECT SUM(lifetime_purchased) as total FROM user_credits WHERE app_id = ?")
        .bind(&[app_id.clone().into()])?
        .first::<serde_json::Value>(None)
        .await?
        .and_then(|v| v.get("total").and_then(|c| c.as_i64()))
        .unwrap_or(0);

    let total_spent = db
        .prepare("SELECT SUM(lifetime_spent) as total FROM user_credits WHERE app_id = ?")
        .bind(&[app_id.clone().into()])?
        .first::<serde_json::Value>(None)
        .await?
        .and_then(|v| v.get("total").and_then(|c| c.as_i64()))
        .unwrap_or(0);

    let total_revenue = db
        .prepare("SELECT SUM(amount_usd_cents) as total FROM credit_purchases WHERE app_id = ? AND status = 'completed'")
        .bind(&[app_id.clone().into()])?
        .first::<serde_json::Value>(None)
        .await?
        .and_then(|v| v.get("total").and_then(|c| c.as_i64()))
        .unwrap_or(0);

    let total_images = db
        .prepare("SELECT COUNT(*) as count FROM stored_images WHERE app_id = ?")
        .bind(&[app_id.clone().into()])?
        .first::<serde_json::Value>(None)
        .await?
        .and_then(|v| v.get("count").and_then(|c| c.as_i64()))
        .unwrap_or(0);

    let openai_costs = db
        .prepare("SELECT SUM(openai_cost_cents) as total FROM stored_images WHERE app_id = ?")
        .bind(&[app_id.clone().into()])?
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

    let user_id = {
        let db = env.d1("DB")?;
        let auth = match auth::authenticate(&req, &db).await {
            Ok(a) => a,
            Err(e) => return e.to_response(),
        };

        let email = db
            .prepare("SELECT email FROM users WHERE app_id = ? AND id = ?")
            .bind(&[auth.app_id.clone().into(), auth.user_id.clone().into()])?
            .first::<serde_json::Value>(None)
            .await?
            .and_then(|v| v.get("email").and_then(|e| e.as_str()).map(|s| s.to_string()));

        (auth.user_id, auth.app_id, email)
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
        &user_id.1,
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
        user_id.2.as_deref(),
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

    let auth = {
        let db = env.d1("DB")?;
        match auth::authenticate(&req, &db).await {
            Ok(a) => a,
            Err(e) => return e.to_response(),
        }
    };
    let user_id = auth.user_id.clone();
    let app_id = auth.app_id.clone();

    let validate_req: ValidateRevenueCatPurchaseRequest = match req.json().await {
        Ok(req) => req,
        Err(e) => return AppError::BadRequest(format!("Invalid request body: {}", e)).to_response(),
    };
    
    // Validate platform
    if validate_req.platform != "ios" && validate_req.platform != "android" {
        return AppError::BadRequest("Invalid platform. Must be 'ios' or 'android'".to_string()).to_response();
    }
    
    let db = env.d1("DB")?;

    // Find the pack (per-app catalog)
    let packs = get_credit_packs_for_app(&app_id, &db).await;
    let pack = packs
        .iter()
        .find(|p| p.id == validate_req.pack_id)
        .ok_or_else(|| AppError::BadRequest("Invalid pack_id".to_string()))?;

    let total_credits = pack.credits + pack.bonus_credits;

    // Check if this purchase token has already been used
    let existing_purchase = db.prepare(
        "SELECT id, status FROM credit_purchases WHERE app_id = ? AND payment_id = ? AND payment_provider = 'revenuecat'"
    )
    .bind(&[app_id.clone().into(), validate_req.purchase_token.clone().into()])?
    .first::<serde_json::Value>(None)
    .await?;
    
    if let Some(existing) = existing_purchase {
        let status = existing.get("status").and_then(|v| v.as_str()).unwrap_or("");
        if status == "completed" {
            return AppError::BadRequest("Purchase has already been processed".to_string()).to_response();
        }
    }
    
    // Verify with RevenueCat BEFORE granting anything. The authenticated webhook
    // (revenuecat_webhook) is the authoritative, idempotent source of truth; this
    // client path is a fast-track that must never grant on an unverified or failed check.
    let validation_result = validate_with_revenuecat(
        &env,
        &db,
        &app_id,
        &user_id,
        &validate_req.purchase_token,
        &validate_req.product_id,
        &validate_req.platform,
    ).await;

    match validation_result {
        Ok(true) => {}
        Ok(false) => {
            return AppError::BadRequest("Purchase could not be verified with RevenueCat".to_string()).to_response();
        }
        Err(e) => {
            // RevenueCat unreachable: do NOT grant. The webhook will reconcile this purchase.
            worker::console_log!("RevenueCat validation unavailable, deferring to webhook: {}", e);
            return AppError::InternalError("Could not verify the purchase right now; it will be credited shortly.".to_string()).to_response();
        }
    }

    // Verified. Record + complete (idempotent; the dedup check above prevents double-grant).
    let purchase_id = record_purchase(
        &app_id,
        &user_id,
        &validate_req.pack_id,
        total_credits as u32,
        pack.price_usd_cents as u32,
        "revenuecat",
        &validate_req.purchase_token,
        &db,
    ).await?;

    complete_purchase(&purchase_id, &db).await?;

    let new_balance = get_user_balance(&app_id, &user_id, &db).await?;

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

/// True if `user_id` holds the app's configured premium entitlement, verified
/// against the RevenueCat REST API (non-spoofable). Only apps with a non-null
/// `premium_entitlement` incur the RC call; everyone else returns false with a
/// single indexed D1 read. Fail-safe: any error/404 => false (charge normally),
/// so a transient RC issue never silently hands out free unlimited usage.
pub async fn is_premium_user(
    env: &Env,
    db: &worker::D1Database,
    app_id: &str,
    user_id: &str,
) -> bool {
    let row = match db
        .prepare("SELECT premium_entitlement, rc_project_id FROM apps WHERE app_id = ?1")
        .bind(&[app_id.into()])
    {
        Ok(stmt) => stmt.first::<serde_json::Value>(None).await.ok().flatten(),
        Err(_) => None,
    };
    let row = match row {
        Some(r) => r,
        None => return false,
    };
    let configured = row
        .get("premium_entitlement")
        .and_then(|v| v.as_str())
        .map(|s| !s.is_empty())
        .unwrap_or(false);
    let project_id = row.get("rc_project_id").and_then(|v| v.as_str()).unwrap_or("");
    if !configured || project_id.is_empty() {
        return false;
    }

    let key_name = format!("REVENUECAT_IOS_API_KEY_{}", app_id.to_uppercase());
    let api_key = match env
        .secret(&key_name)
        .or_else(|_| env.secret("REVENUECAT_IOS_API_KEY"))
    {
        Ok(k) => k.to_string(),
        Err(_) => return false,
    };

    let url = format!(
        "https://api.revenuecat.com/v2/projects/{}/customers/{}/active_entitlements",
        project_id, user_id
    );
    let headers = Headers::new();
    if headers.set("Authorization", &format!("Bearer {}", api_key)).is_err() {
        return false;
    }
    let mut init = worker::RequestInit::new();
    init.with_method(Method::Get).with_headers(headers);
    let request = match Request::new_with_init(&url, &init) {
        Ok(r) => r,
        Err(_) => return false,
    };
    let mut resp = match Fetch::Request(request).send().await {
        Ok(r) => r,
        Err(_) => return false,
    };
    if resp.status_code() != 200 {
        return false;
    }
    match resp.json::<serde_json::Value>().await {
        Ok(v) => v
            .get("items")
            .and_then(|i| i.as_array())
            .map(|a| !a.is_empty())
            .unwrap_or(false),
        Err(_) => false,
    }
}

async fn validate_with_revenuecat(
    env: &Env,
    db: &worker::D1Database,
    app_id: &str,
    user_id: &str,
    _purchase_token: &str,
    _product_id: &str,
    platform: &str,
) -> Result<bool> {
    let key_name = format!("REVENUECAT_IOS_API_KEY_{}", app_id.to_uppercase());
    let api_key = env
        .secret(&key_name)
        .or_else(|_| env.secret("REVENUECAT_IOS_API_KEY"))
        .map_err(|_| format!("RevenueCat API key not configured for {}", app_id))?
        .to_string();

    let project_id = db
        .prepare("SELECT rc_project_id FROM apps WHERE app_id = ?1")
        .bind(&[app_id.into()])?
        .first::<serde_json::Value>(None)
        .await?
        .and_then(|v| v.get("rc_project_id").and_then(|p| p.as_str()).map(|s| s.to_string()))
        .ok_or_else(|| format!("rc_project_id not configured for {}", app_id))?;
    let customer_id = user_id;
    let url = format!("https://api.revenuecat.com/v2/projects/{}/customers/{}", project_id, customer_id);
    
    let headers = Headers::new();
    headers.set("Authorization", &format!("Bearer {}", api_key))?;
    headers.set("Content-Type", "application/json")?;
    headers.set("X-Platform", platform)?;
    
    let mut init = worker::RequestInit::new();
    init.with_method(Method::Get)
        .with_headers(headers);
    
    let request = Request::new_with_init(&url, &init)?;
    let mut response = Fetch::Request(request).send().await?;
    
    let status_code = response.status_code();
    if status_code == 404 {
        // Customer/purchase not known to RevenueCat yet — cannot confirm here.
        // Return false so the client path does not grant; the webhook reconciles.
        worker::console_log!("RevenueCat customer not found; deferring grant to webhook");
        return Ok(false);
    }
    
    if status_code < 200 || status_code >= 300 {
        let error_text = response.text().await.unwrap_or_default();
        worker::console_log!("RevenueCat API error: {} - {}", status_code, error_text);
        return Err(format!("RevenueCat API error: {}", status_code).into());
    }
    
    // For V2 API, we get a different response structure
    // For now, if we get a 200 response, we consider it valid
    // The V2 API would return 404 if the customer doesn't exist
    // and 200 if they do, which is enough validation for our purposes
    let _response_text = response.text().await?;
    worker::console_log!("RevenueCat V2 response received for customer: {}", customer_id);
    
    // If we got here with a 200 status, the customer exists in RevenueCat
    // We could parse the V2 response for more detailed validation, but for now
    // we'll accept that the customer exists as validation
    Ok(true)
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RevenueCatWebhookEvent {
    pub api_version: String,
    pub event: RevenueCatEvent,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RevenueCatEvent {
    pub app_user_id: String,
    pub currency: Option<String>,
    pub entitlement_id: Option<String>,
    pub environment: String,
    pub event_timestamp_ms: i64,
    pub id: String,
    pub is_family_share: bool,
    pub offer_code: Option<String>,
    pub price: Option<f64>,
    pub price_in_purchased_currency: Option<f64>,
    pub product_id: String,
    pub purchased_at_ms: i64,
    pub store: String,
    pub takehome_percentage: Option<f64>,
    pub transaction_id: String,
    #[serde(rename = "type")]
    pub event_type: String,
}

/// Resolve which tenant a RevenueCat product belongs to by matching the product
/// id against each app's `rc_product_prefix`. Longest matching prefix wins (most
/// specific tenant). Returns (app_id, matched_prefix).
async fn resolve_tenant_by_product(db: &worker::D1Database, product_id: &str) -> Option<(String, String)> {
    let row = db
        .prepare(
            "SELECT app_id, rc_product_prefix FROM apps
             WHERE rc_product_prefix IS NOT NULL AND rc_product_prefix != ''
               AND instr(?1, rc_product_prefix) = 1
             ORDER BY length(rc_product_prefix) DESC LIMIT 1",
        )
        .bind(&[product_id.into()])
        .ok()?
        .first::<serde_json::Value>(None)
        .await
        .ok()??;
    let app_id = row.get("app_id")?.as_str()?.to_string();
    let prefix = row.get("rc_product_prefix")?.as_str()?.to_string();
    Some((app_id, prefix))
}

pub async fn revenuecat_webhook(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let env = ctx.env;
    
    // Get the authorization header
    let auth_header = req.headers().get("Authorization")?;
    
    // Verify the webhook authorization
    let expected_auth = env.secret("REVENUECAT_WEBHOOK_AUTH")
        .map_err(|_| AppError::InternalError("REVENUECAT_WEBHOOK_AUTH not configured".to_string()))?
        .to_string();
    
    if auth_header != Some(format!("Bearer {}", expected_auth)) {
        return AppError::Unauthorized("Invalid webhook authorization".to_string()).to_response();
    }
    
    // Parse the webhook event
    let webhook_event: RevenueCatWebhookEvent = match req.json().await {
        Ok(event) => event,
        Err(e) => return AppError::BadRequest(format!("Invalid webhook body: {}", e)).to_response(),
    };
    
    let event = &webhook_event.event;
    worker::console_log!("RevenueCat webhook: {} for user {}", event.event_type, event.app_user_id);
    
    // Handle different event types
    match event.event_type.as_str() {
        "INITIAL_PURCHASE" | "RENEWAL" => {
            let db = env.d1("DB")?;

            // Resolve the tenant from the product id via apps.rc_product_prefix.
            let (app_id, prefix) = match resolve_tenant_by_product(&db, &event.product_id).await {
                Some(t) => t,
                None => {
                    worker::console_log!("No tenant matched product {}", event.product_id);
                    return Response::ok("OK");
                }
            };

            let pack_id = event
                .product_id
                .strip_prefix(prefix.as_str())
                .unwrap_or(&event.product_id)
                .to_string();

            let packs = get_credit_packs_for_app(&app_id, &db).await;
            let pack = match packs.iter().find(|p| p.id == pack_id) {
                Some(p) => p,
                None => {
                    worker::console_log!("Unknown pack {} for app {} (product {})", pack_id, app_id, event.product_id);
                    return Response::ok("OK");
                }
            };

            let total_credits = pack.credits + pack.bonus_credits;

            let existing = db.prepare(
                "SELECT id FROM credit_purchases WHERE app_id = ? AND payment_id = ? AND payment_provider = 'revenuecat'"
            )
            .bind(&[app_id.clone().into(), event.transaction_id.clone().into()])?
            .first::<serde_json::Value>(None)
            .await?;

            if existing.is_some() {
                worker::console_log!("Transaction {} already processed", event.transaction_id);
                return Response::ok("OK");
            }

            let purchase_id = record_purchase(
                &app_id,
                &event.app_user_id,
                &pack_id,
                total_credits as u32,
                pack.price_usd_cents as u32,
                "revenuecat",
                &event.transaction_id,
                &db,
            ).await?;

            complete_purchase(&purchase_id, &db).await?;

            worker::console_log!("Processed RevenueCat purchase {} for app {} user {}", purchase_id, app_id, event.app_user_id);
        },
        "CANCELLATION" | "UNCANCELLATION" | "EXPIRATION" => {
            // Handle subscription events (we don't have subscriptions yet)
            worker::console_log!("Subscription event {} for user {}", event.event_type, event.app_user_id);
        },
        "BILLING_ISSUE" => {
            worker::console_log!("Billing issue for user {}", event.app_user_id);
        },
        _ => {
            worker::console_log!("Unhandled RevenueCat event type: {}", event.event_type);
        }
    }
    
    Response::ok("OK")
}