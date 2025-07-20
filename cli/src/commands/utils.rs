use anyhow::Result;
use colored::*;
use crate::api::{ApiClient, CreditEstimateRequest};

pub async fn check_credits_and_estimate(
    client: &ApiClient,
    quality: &str,
    size: &str,
    number: u8,
    is_edit: bool,
    prompt: &str,
) -> Result<(i32, u32)> {
    let balance = client.get_credit_balance().await?;
    let estimate_request = CreditEstimateRequest {
        prompt: Some(prompt.to_string()),
        quality: quality.to_string(),
        size: size.to_string(),
        n: Some(number),
        is_edit: Some(is_edit),
    };
    let estimate = client.estimate_credit_cost(&estimate_request).await?;
    
    println!("\n{}", "💰 Credit Check".bold().blue());
    println!("  Current balance: {} credits", balance.balance.to_string().green());
    println!("  Estimated cost:  {} credits {}", 
        estimate.estimated_credits.to_string().yellow(),
        format!("({})", estimate.estimated_usd).dimmed()
    );
    
    if balance.balance < estimate.estimated_credits as i32 {
        println!("\n{}", "❌ Insufficient credits!".red().bold());
        println!("  You need {} more credits to complete this request.", 
            (estimate.estimated_credits as i32 - balance.balance).to_string().red()
        );
        println!("  Run {} to see available packs.", "pixie credits packs".cyan());
        return Err(anyhow::anyhow!("Insufficient credits"));
    }
    
    println!("  After request:   {} credits\n", 
        (balance.balance - estimate.estimated_credits as i32).to_string().blue()
    );
    
    Ok((balance.balance, estimate.estimated_credits))
}

pub async fn show_credits_used(
    client: &ApiClient,
    initial_balance: i32,
) -> Result<()> {
    if let Ok(new_balance) = client.get_credit_balance().await {
        let credits_used = initial_balance - new_balance.balance;
        println!("\n{}", "💳 Credits Used".bold());
        println!("  Credits spent: {} credits", credits_used.to_string().yellow());
        println!("  New balance:   {} credits", new_balance.balance.to_string().green());
    }
    Ok(())
}

pub async fn health_check(api_url: &str) -> Result<()> {
    println!("Checking API health at: {}", api_url.blue());
    
    let client = reqwest::Client::new();
    let start = std::time::Instant::now();
    
    match client.get(api_url).send().await {
        Ok(response) => {
            let latency = start.elapsed();
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            
            if status.is_success() {
                println!("\n{} API is healthy", "✓".green().bold());
                println!("  Status:   {}", status.to_string().green());
                println!("  Response: {}", body.trim());
                println!("  Latency:  {:?}", latency);
            } else {
                println!("\n{} API returned error", "✗".red().bold());
                println!("  Status:   {}", status.to_string().red());
                println!("  Response: {}", body.trim());
            }
        }
        Err(e) => {
            println!("\n{} API is unreachable", "✗".red().bold());
            println!("  Error: {}", e.to_string().red());
            return Err(anyhow::anyhow!("Failed to reach API"));
        }
    }
    
    Ok(())
}