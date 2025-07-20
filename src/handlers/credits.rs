use worker::{Request, Response, RouteContext, Result};
use crate::error::AppError;
use crate::auth::validate_api_key;
use crate::credits::{
    get_user_balance, get_user_transactions, get_credit_packs, 
    record_purchase, complete_purchase, add_credits, estimate_image_cost
};
use serde::{Deserialize, Serialize};
use serde_json::json;

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
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CompletePurchaseRequest {
    pub purchase_id: String,
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
    
    // TODO: Add proper admin authentication
    // For now, check if the API key belongs to a specific admin user
    let admin_user_id = match validate_api_key(&req) {
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
                    let email = value.get("email").and_then(|v| v.as_str()).unwrap_or("");
                    // Simple admin check - in production, use a proper admin flag
                    if !email.contains("admin") && !email.contains("marcus") {
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
    
    let transaction_type = if adjust_req.amount > 0 { "admin_adjustment" } else { "admin_adjustment" };
    let description = format!("Admin adjustment by {}: {}", admin_user_id, adjust_req.reason);
    
    let new_balance = add_credits(
        &adjust_req.user_id,
        adjust_req.amount.abs() as u32,
        transaction_type,
        &description,
        None,
        &db,
    ).await?;
    
    Response::from_json(&json!({
        "user_id": adjust_req.user_id,
        "adjustment": adjust_req.amount,
        "new_balance": new_balance,
        "reason": adjust_req.reason,
    }))
}

pub async fn admin_system_stats(_req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let env = ctx.env;
    
    // TODO: Add proper admin authentication
    
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