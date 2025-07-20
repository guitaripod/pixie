use anyhow::Result;
use colored::*;
use serde_json::json;
use crate::config::Config;

pub async fn adjust_credits(
    api_url: &str,
    user_id: &str,
    amount: i32,
    reason: &str,
) -> Result<()> {
    let config = Config::load()?;
    if !config.is_authenticated() {
        return Err(anyhow::anyhow!(
            "Not authenticated. Run {} to authenticate",
            "pixie auth github".cyan()
        ));
    }
    
    
    println!("\n{}", "🔐 Admin: Adjusting Credits".bold().magenta());
    println!("{}", "═".repeat(50).magenta());
    println!("  User ID:    {}", user_id);
    println!("  Adjustment: {} credits", 
        if amount > 0 { 
            format!("+{}", amount).green() 
        } else { 
            amount.to_string().red() 
        }
    );
    println!("  Reason:     {}", reason);
    println!("{}", "═".repeat(50).magenta());
    
    let request_body = json!({
        "user_id": user_id,
        "amount": amount,
        "reason": reason,
    });
    
    let mut headers = reqwest::header::HeaderMap::new();
    if let Some(api_key) = &config.api_key {
        headers.insert(
            reqwest::header::AUTHORIZATION,
            reqwest::header::HeaderValue::from_str(&format!("Bearer {}", api_key))?,
        );
    }
    
    let response = reqwest::Client::new()
        .post(&format!("{}/v1/admin/credits/adjust", api_url))
        .headers(headers)
        .json(&request_body)
        .send()
        .await?;
    
    if !response.status().is_success() {
        let error = response.text().await?;
        return Err(anyhow::anyhow!("Failed to adjust credits: {}", error));
    }
    
    let result: serde_json::Value = response.json().await?;
    
    println!("\n{}", "✅ Credits adjusted successfully!".green().bold());
    println!("  New balance: {} credits", 
        result["new_balance"].as_i64().unwrap_or(0).to_string().bold()
    );
    
    Ok(())
}

pub async fn system_stats(api_url: &str) -> Result<()> {
    let config = Config::load()?;
    if !config.is_authenticated() {
        return Err(anyhow::anyhow!(
            "Not authenticated. Run {} to authenticate",
            "pixie auth github".cyan()
        ));
    }
    
    
    let mut headers = reqwest::header::HeaderMap::new();
    if let Some(api_key) = &config.api_key {
        headers.insert(
            reqwest::header::AUTHORIZATION,
            reqwest::header::HeaderValue::from_str(&format!("Bearer {}", api_key))?,
        );
    }
    
    let response = reqwest::Client::new()
        .get(&format!("{}/v1/admin/credits/stats", api_url))
        .headers(headers)
        .send()
        .await?;
    
    if !response.status().is_success() {
        let error = response.text().await?;
        return Err(anyhow::anyhow!("Failed to get system stats: {}", error));
    }
    
    let stats: serde_json::Value = response.json().await?;
    
    println!("\n{}", "📊 System Statistics".bold().blue());
    println!("{}", "═".repeat(60).blue());
    
    println!("\n{}", "👥 Users".bold());
    println!("  Total users:        {}", 
        stats["users"]["total"].as_i64().unwrap_or(0).to_string().cyan()
    );
    
    println!("\n{}", "💰 Credits".bold());
    println!("  Total balance:      {} credits", 
        stats["credits"]["total_balance"].as_i64().unwrap_or(0).to_string().yellow()
    );
    println!("  Total purchased:    {} credits", 
        stats["credits"]["total_purchased"].as_i64().unwrap_or(0).to_string().green()
    );
    println!("  Total spent:        {} credits", 
        stats["credits"]["total_spent"].as_i64().unwrap_or(0).to_string().red()
    );
    
    println!("\n{}", "💵 Revenue".bold());
    println!("  Total revenue:      {}", 
        stats["revenue"]["total_usd"].as_str().unwrap_or("$0.00").green()
    );
    println!("  OpenAI costs:       {}", 
        stats["revenue"]["openai_costs_usd"].as_str().unwrap_or("$0.00").red()
    );
    println!("  Gross profit:       {}", 
        stats["revenue"]["gross_profit_usd"].as_str().unwrap_or("$0.00").bold().green()
    );
    println!("  Profit margin:      {}", 
        stats["revenue"]["profit_margin"].as_str().unwrap_or("0%").cyan()
    );
    
    println!("\n{}", "🖼️  Images".bold());
    println!("  Total generated:    {}", 
        stats["images"]["total_generated"].as_i64().unwrap_or(0).to_string().cyan()
    );
    
    println!("\n{}", "═".repeat(60).blue());
    
    Ok(())
}

pub async fn grant_admin(
    _api_url: &str,
    user_id: &str,
) -> Result<()> {
    let _config = Config::load()?;
    
    println!("{}", "❌ Grant admin not yet implemented".red());
    println!("   To grant admin access, update the database directly:");
    println!("   UPDATE users SET is_admin = TRUE WHERE id = '{}';", user_id);
    
    Ok(())
}