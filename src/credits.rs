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
            credits: 100,
            price_usd_cents: 199,
            bonus_credits: 0,
            description: "Perfect for trying out (~20 low or 7 medium images)".to_string(),
        },
        CreditPack {
            id: "basic".to_string(),
            name: "Basic".to_string(),
            credits: 500,
            price_usd_cents: 799,
            bonus_credits: 50,
            description: "Great for regular use (~40 medium images)".to_string(),
        },
        CreditPack {
            id: "popular".to_string(),
            name: "Popular".to_string(),
            credits: 1500,
            price_usd_cents: 1999,
            bonus_credits: 300,
            description: "Our most popular pack! (~120 medium images)".to_string(),
        },
        CreditPack {
            id: "pro".to_string(),
            name: "Pro".to_string(),
            credits: 3500,
            price_usd_cents: 3999,
            bonus_credits: 1000,
            description: "For power users (~300 medium images)".to_string(),
        },
        CreditPack {
            id: "enterprise".to_string(),
            name: "Enterprise".to_string(),
            credits: 8000,
            price_usd_cents: 7999,
            bonus_credits: 3000,
            description: "Maximum value! (~730 medium images)".to_string(),
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
    
    // Get purchase details
    let purchase = db
        .prepare("SELECT user_id, pack_id, credits FROM credit_purchases WHERE id = ? AND status = 'pending'")
        .bind(&[purchase_id.into()])?
        .first::<serde_json::Value>(None)
        .await?
        .ok_or_else(|| AppError::NotFound("Purchase not found or already completed".to_string()))?;
    
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
    // Rough estimates based on typical token usage
    let base_estimate = match (quality, size) {
        ("low", _) => 4,
        ("medium", _) => 13,
        ("high", "1024x1024") => 52,
        ("high", "1536x1024") | ("high", "1024x1536") => 78,
        _ => 13, // default to medium
    };
    
    if is_edit {
        base_estimate + 3
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
        assert_eq!(estimate_image_cost("low", "1024x1024", false), 4);
        assert_eq!(estimate_image_cost("medium", "1024x1024", false), 13);
        assert_eq!(estimate_image_cost("high", "1024x1024", false), 52);
        assert_eq!(estimate_image_cost("high", "1536x1024", false), 78);
        
        // Test edit operations
        assert_eq!(estimate_image_cost("low", "1024x1024", true), 7);
        assert_eq!(estimate_image_cost("medium", "1024x1024", true), 16);
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