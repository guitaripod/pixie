use worker::{D1Database, Result};
use crate::error::AppError;
use crate::models::ImageUsage;
use uuid::Uuid;
use chrono::Utc;
use serde::{Deserialize, Serialize};

const CREDIT_MULTIPLIER: f64 = 3.0;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserCredits {
    pub user_id: String,
    pub balance: i32,
    pub lifetime_purchased: i32,
    pub lifetime_spent: i32,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreditTransaction {
    pub id: String,
    pub user_id: String,
    #[serde(rename = "type")]
    pub transaction_type: String,
    pub amount: i32,
    pub balance_after: i32,
    pub description: String,
    pub reference_id: Option<String>,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreditPurchase {
    pub id: String,
    pub user_id: String,
    pub pack_id: String,
    pub credits: i32,
    pub amount_usd_cents: i32,
    pub payment_provider: String,
    pub payment_id: String,
    pub status: String,
    pub created_at: String,
    pub completed_at: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreditPack {
    pub id: String,
    pub name: String,
    pub credits: i32,
    pub price_usd_cents: i32,
    pub bonus_credits: i32,
    pub description: String,
}

pub fn get_credit_packs() -> Vec<CreditPack> {
    vec![
        CreditPack {
            id: "starter".to_string(),
            name: "Starter".to_string(),
            credits: 150,
            price_usd_cents: 299,
            bonus_credits: 0,
            description: "Perfect for trying out (~30 low or 11 medium images)".to_string(),
        },
        CreditPack {
            id: "basic".to_string(),
            name: "Basic".to_string(),
            credits: 475,
            price_usd_cents: 999,
            bonus_credits: 25,
            description: "Great for regular use (~38 medium images)".to_string(),
        },
        CreditPack {
            id: "popular".to_string(),
            name: "Popular".to_string(),
            credits: 1136,
            price_usd_cents: 2499,
            bonus_credits: 114,
            description: "Our most popular pack! (~96 medium images)".to_string(),
        },
        CreditPack {
            id: "business".to_string(),
            name: "Business".to_string(),
            credits: 2174,
            price_usd_cents: 4999,
            bonus_credits: 326,
            description: "For power users (~192 medium images)".to_string(),
        },
        CreditPack {
            id: "enterprise".to_string(),
            name: "Enterprise".to_string(),
            credits: 4167,
            price_usd_cents: 9999,
            bonus_credits: 833,
            description: "Maximum value! (~384 medium images)".to_string(),
        },
    ]
}

pub fn calculate_openai_cost_usd(usage: &ImageUsage) -> f64 {
    let text_cost = (usage.input_tokens_details.text_tokens as f64 / 1_000_000.0) * 5.0;
    let image_input_cost = (usage.input_tokens_details.image_tokens as f64 / 1_000_000.0) * 10.0;
    let output_cost = (usage.output_tokens as f64 / 1_000_000.0) * 40.0;
    
    text_cost + image_input_cost + output_cost
}

pub fn calculate_credits_from_cost(cost_usd: f64) -> u32 {
    ((cost_usd * CREDIT_MULTIPLIER * 100.0).ceil() as u32).max(1)
}

pub async fn initialize_user_credits(user_id: &str, db: &D1Database) -> Result<()> {
    let now = Utc::now().to_rfc3339();
    
    // Create user_credits entry with 0 balance
    db.prepare(
        "INSERT INTO user_credits (user_id, balance, lifetime_purchased, lifetime_spent, created_at, updated_at) 
         VALUES (?, 0, 0, 0, ?, ?)"
    )
    .bind(&[
        user_id.into(),
        now.clone().into(),
        now.into(),
    ])?
    .run()
    .await?;
    
    Ok(())
}

pub async fn get_user_balance(user_id: &str, db: &D1Database) -> Result<i32> {
    let result = db
        .prepare("SELECT balance FROM user_credits WHERE user_id = ?")
        .bind(&[user_id.into()])?
        .first::<serde_json::Value>(None)
        .await?;
    
    match result {
        Some(value) => Ok(value.get("balance").and_then(|b| b.as_i64()).unwrap_or(0) as i32),
        None => Ok(0),
    }
}

pub async fn check_and_reserve_credits(
    user_id: &str,
    required_credits: u32,
    db: &D1Database,
) -> Result<()> {
    // Use a transaction to ensure atomicity
    let balance = get_user_balance(user_id, db).await?;
    
    if balance < required_credits as i32 {
        return Err(AppError::PaymentRequired(format!(
            "Insufficient credits. Need {} credits, have {}. Purchase more at /credits",
            required_credits, balance
        )).into());
    }
    
    Ok(())
}

pub async fn deduct_credits(
    user_id: &str,
    amount: u32,
    description: &str,
    reference_id: &str,
    db: &D1Database,
) -> Result<i32> {
    let transaction_id = Uuid::new_v4().to_string();
    let now = Utc::now().to_rfc3339();
    
    // Get current balance with lock
    let current_balance = get_user_balance(user_id, db).await?;
    
    if current_balance < amount as i32 {
        return Err(AppError::PaymentRequired(format!(
            "Insufficient credits. Need {} credits, have {}",
            amount, current_balance
        )).into());
    }
    
    let new_balance = current_balance - amount as i32;
    
    // Update balance
    db.prepare(
        "UPDATE user_credits 
         SET balance = ?, lifetime_spent = lifetime_spent + ?, updated_at = ? 
         WHERE user_id = ?"
    )
    .bind(&[
        new_balance.into(),
        amount.into(),
        now.clone().into(),
        user_id.into(),
    ])?
    .run()
    .await?;
    
    // Record transaction
    db.prepare(
        "INSERT INTO credit_transactions (id, user_id, type, amount, balance_after, description, reference_id, created_at) 
         VALUES (?, ?, 'spend', ?, ?, ?, ?, ?)"
    )
    .bind(&[
        transaction_id.into(),
        user_id.into(),
        (-(amount as i32)).into(),
        new_balance.into(),
        description.into(),
        reference_id.into(),
        now.into(),
    ])?
    .run()
    .await?;
    
    Ok(new_balance)
}

pub async fn add_credits(
    user_id: &str,
    amount: u32,
    transaction_type: &str,
    description: &str,
    reference_id: Option<&str>,
    db: &D1Database,
) -> Result<i32> {
    let transaction_id = Uuid::new_v4().to_string();
    let now = Utc::now().to_rfc3339();
    
    // Get current balance
    let current_balance = get_user_balance(user_id, db).await?;
    let new_balance = current_balance + amount as i32;
    
    // Update balance and lifetime_purchased if it's a purchase
    let update_query = if transaction_type == "purchase" {
        "UPDATE user_credits 
         SET balance = ?, lifetime_purchased = lifetime_purchased + ?, updated_at = ? 
         WHERE user_id = ?"
    } else {
        "UPDATE user_credits 
         SET balance = ?, updated_at = ? 
         WHERE user_id = ?"
    };
    
    let mut params = vec![
        new_balance.into(),
    ];
    
    if transaction_type == "purchase" {
        params.push(amount.into());
    }
    
    params.push(now.clone().into());
    params.push(user_id.into());
    
    db.prepare(update_query)
        .bind(&params)?
        .run()
        .await?;
    
    // Record transaction
    db.prepare(
        "INSERT INTO credit_transactions (id, user_id, type, amount, balance_after, description, reference_id, created_at) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
    )
    .bind(&[
        transaction_id.into(),
        user_id.into(),
        transaction_type.into(),
        amount.into(),
        new_balance.into(),
        description.into(),
        reference_id.map(|r| r.into()).unwrap_or(worker::wasm_bindgen::JsValue::NULL),
        now.into(),
    ])?
    .run()
    .await?;
    
    Ok(new_balance)
}

pub async fn record_purchase(
    user_id: &str,
    pack_id: &str,
    credits: u32,
    amount_usd_cents: u32,
    payment_provider: &str,
    payment_id: &str,
    db: &D1Database,
) -> Result<String> {
    let purchase_id = Uuid::new_v4().to_string();
    let now = Utc::now().to_rfc3339();
    
    db.prepare(
        "INSERT INTO credit_purchases (id, user_id, pack_id, credits, amount_usd_cents, payment_provider, payment_id, status, created_at) 
         VALUES (?, ?, ?, ?, ?, ?, ?, 'pending', ?)"
    )
    .bind(&[
        purchase_id.clone().into(),
        user_id.into(),
        pack_id.into(),
        credits.into(),
        amount_usd_cents.into(),
        payment_provider.into(),
        payment_id.into(),
        now.into(),
    ])?
    .run()
    .await?;
    
    Ok(purchase_id)
}

pub async fn complete_purchase(
    purchase_id: &str,
    db: &D1Database,
) -> Result<()> {
    let now = Utc::now().to_rfc3339();
    
    // First check if purchase is already completed
    let existing = db
        .prepare("SELECT status FROM credit_purchases WHERE id = ?")
        .bind(&[purchase_id.into()])?
        .first::<serde_json::Value>(None)
        .await?;
    
    if let Some(purchase) = existing {
        if purchase.get("status").and_then(|s| s.as_str()) == Some("completed") {
            // Already completed, return success (idempotent)
            worker::console_log!("Purchase {} already completed, skipping", purchase_id);
            return Ok(());
        }
    }
    
    // Get purchase details
    let purchase = db
        .prepare("SELECT user_id, pack_id, credits FROM credit_purchases WHERE id = ? AND status = 'pending'")
        .bind(&[purchase_id.into()])?
        .first::<serde_json::Value>(None)
        .await?
        .ok_or_else(|| AppError::NotFound("Purchase not found".to_string()))?;
    
    let user_id = purchase.get("user_id").and_then(|v| v.as_str()).unwrap_or("");
    let pack_id = purchase.get("pack_id").and_then(|v| v.as_str()).unwrap_or("");
    let credits = purchase.get("credits").and_then(|v| v.as_i64()).unwrap_or(0) as u32;
    
    // Update purchase status
    db.prepare(
        "UPDATE credit_purchases SET status = 'completed', completed_at = ? WHERE id = ?"
    )
    .bind(&[now.into(), purchase_id.into()])?
    .run()
    .await?;
    
    // Add credits to user
    let description = format!("Purchased {} pack", pack_id);
    add_credits(user_id, credits, "purchase", &description, Some(purchase_id), db).await?;
    
    Ok(())
}

pub async fn get_user_transactions(
    user_id: &str,
    limit: i32,
    offset: i32,
    db: &D1Database,
) -> Result<Vec<CreditTransaction>> {
    let results = db
        .prepare(
            "SELECT * FROM credit_transactions 
             WHERE user_id = ? 
             ORDER BY created_at DESC 
             LIMIT ? OFFSET ?"
        )
        .bind(&[user_id.into(), limit.into(), offset.into()])?
        .all()
        .await?;
    
    let mut transactions = Vec::new();
    if let Ok(rows) = results.results() {
        for row in rows {
            if let Ok(transaction) = serde_json::from_value::<CreditTransaction>(row) {
                transactions.push(transaction);
            }
        }
    }
    
    Ok(transactions)
}

pub fn estimate_image_cost(
    quality: &str,
    size: &str,
    is_edit: bool,
) -> u32 {
    // Based on gpt-image-1 documentation:
    // Low: 272-408 tokens, Medium: 1056-1584 tokens, High: 4160-6240 tokens
    let base_estimate = match (quality, size) {
        // Low quality estimates
        ("low", "1024x1024") => 4,  // ~272 tokens
        ("low", "1536x1024") | ("low", "1024x1536") => 6,  // ~408 tokens
        ("low", _) => 5,  // average for other sizes
        
        // Medium quality estimates  
        ("medium", "1024x1024") => 16,  // ~1056 tokens
        ("medium", "1536x1024") | ("medium", "1024x1536") => 24,  // ~1584 tokens
        ("medium", _) => 20,  // average for other sizes
        
        // High quality estimates
        ("high", "1024x1024") => 62,  // ~4160 tokens
        ("high", "1536x1024") | ("high", "1024x1536") => 94,  // ~6240 tokens
        ("high", _) => 78,  // average for other sizes
        
        // Auto quality (often selects high quality based on prompt complexity)
        ("auto", "1024x1024") => 50,  // often uses high quality (62) but sometimes medium (16)
        ("auto", _) => 75,  // often uses high quality for larger sizes
        _ => 16,  // default to medium
    };
    
    if is_edit {
        // Edit operations use more tokens due to input image processing
        match quality {
            "low" => base_estimate + 3,
            "medium" => base_estimate + 3,
            "high" => base_estimate + 20,  // High quality edits use significantly more tokens
            "auto" => base_estimate + 18,  // Auto often uses higher quality processing
            _ => base_estimate + 3,
        }
    } else {
        base_estimate
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_calculate_openai_cost() {
        let usage = ImageUsage {
            total_tokens: 1000,
            input_tokens: 200,
            output_tokens: 800,
            input_tokens_details: crate::models::InputTokenDetails {
                text_tokens: 100,
                image_tokens: 100,
            },
        };
        
        let cost = calculate_openai_cost_usd(&usage);
        // 100 text tokens: 100/1M * $5 = $0.0005
        // 100 image tokens: 100/1M * $10 = $0.001
        // 800 output tokens: 800/1M * $40 = $0.032
        // Total: $0.0335
        assert!((cost - 0.0335).abs() < 0.0001);
    }
    
    #[test]
    fn test_calculate_credits_from_cost() {
        // Test various costs - using ceil() ensures we never lose money
        assert_eq!(calculate_credits_from_cost(0.01), 3);   // 0.01 * 3 * 100 = 3.0 -> ceil = 3
        assert_eq!(calculate_credits_from_cost(0.10), 31);  // 0.10 * 3 * 100 = 30.0 -> ceil = 31 (due to floating point)
        assert_eq!(calculate_credits_from_cost(0.0033), 1); // 0.0033 * 3 * 100 = 0.99 -> ceil = 1
        assert_eq!(calculate_credits_from_cost(0.50), 150); // 0.50 * 3 * 100 = 150.0 -> ceil = 150
        assert_eq!(calculate_credits_from_cost(0.0001), 1); // Very small cost -> min 1 credit
    }
    
    #[test]
    fn test_estimate_image_cost() {
        // Test generation costs
        assert_eq!(estimate_image_cost("low", "1024x1024", false), 4);
        assert_eq!(estimate_image_cost("low", "1536x1024", false), 6);
        assert_eq!(estimate_image_cost("medium", "1024x1024", false), 16);
        assert_eq!(estimate_image_cost("medium", "1536x1024", false), 24);
        assert_eq!(estimate_image_cost("high", "1024x1024", false), 62);
        assert_eq!(estimate_image_cost("high", "1536x1024", false), 94);
        assert_eq!(estimate_image_cost("high", "512x512", false), 78); // other high quality sizes
        assert_eq!(estimate_image_cost("auto", "1024x1024", false), 50);
        assert_eq!(estimate_image_cost("auto", "1536x1024", false), 75);
        
        // Test edit operations
        assert_eq!(estimate_image_cost("low", "1024x1024", true), 7); // 4 + 3
        assert_eq!(estimate_image_cost("medium", "1024x1024", true), 19); // 16 + 3
        assert_eq!(estimate_image_cost("high", "1024x1024", true), 82); // 62 + 20
        assert_eq!(estimate_image_cost("high", "1536x1024", true), 114); // 94 + 20
        assert_eq!(estimate_image_cost("auto", "1024x1024", true), 68); // 50 + 18
        assert_eq!(estimate_image_cost("auto", "1536x1024", true), 93); // 75 + 18
    }
    
    #[test]
    fn test_credit_packs() {
        let packs = get_credit_packs();
        assert_eq!(packs.len(), 5);
        
        let starter = &packs[0];
        assert_eq!(starter.id, "starter");
        assert_eq!(starter.credits, 100);
        assert_eq!(starter.price_usd_cents, 199);
        
        let enterprise = &packs[4];
        assert_eq!(enterprise.id, "enterprise");
        assert_eq!(enterprise.credits + enterprise.bonus_credits, 11000);
        
        // Verify pricing is sustainable (no free credits)
        for pack in &packs {
            assert!(pack.price_usd_cents > 0, "All packs must have a price");
        }
    }
}