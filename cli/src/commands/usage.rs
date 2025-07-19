use anyhow::Result;
use colored::*;
use chrono::DateTime;

use crate::api::ApiClient;
use crate::config::Config;

pub async fn show(
    api_url: &str,
    start: Option<&str>,
    end: Option<&str>,
    detailed: bool,
) -> Result<()> {
    let config = Config::load()?;
    if !config.is_authenticated() {
        return Err(anyhow::anyhow!(
            "Not authenticated. Run {} to authenticate",
            "oip auth github".cyan()
        ));
    }
    
    let user_id = config.user_id.as_ref().unwrap();
    let client = ApiClient::new(api_url)?;
    
    if detailed {
        println!("Fetching detailed usage statistics...");
        let response = client.get_usage_details(user_id, start, end).await?;
        
        println!("\n{}", "Usage Details".bold().underline());
        println!("Period: {} to {}", 
            format_date(&response.period_start),
            format_date(&response.period_end)
        );
        println!();
        
        if response.daily_usage.is_empty() {
            println!("{}", "No usage data found for this period".dimmed());
        } else {
            println!("{:<12} {:>10} {:>10} {:>10}", 
                "Date".bold(), 
                "Requests".bold(), 
                "Tokens".bold(), 
                "Images".bold()
            );
            println!("{}", "-".repeat(45));
            
            let mut total_requests = 0;
            let mut total_tokens = 0;
            let mut total_images = 0;
            
            for usage in &response.daily_usage {
                println!("{:<12} {:>10} {:>10} {:>10}",
                    usage.date,
                    usage.requests,
                    usage.tokens,
                    usage.images
                );
                
                total_requests += usage.requests;
                total_tokens += usage.tokens;
                total_images += usage.images;
            }
            
            println!("{}", "-".repeat(45));
            println!("{:<12} {:>10} {:>10} {:>10}",
                "Total".bold(),
                total_requests.to_string().bold(),
                total_tokens.to_string().bold(),
                total_images.to_string().bold()
            );
        }
    } else {
        println!("Fetching usage statistics...");
        let response = client.get_usage(user_id, start, end).await?;
        
        println!("\n{}", "Usage Summary".bold().underline());
        println!("Period: {} to {}", 
            format_date(&response.period_start),
            format_date(&response.period_end)
        );
        println!();
        
        println!("Total Requests: {}", response.total_requests.to_string().green());
        println!("Total Tokens: {}", response.total_tokens.to_string().yellow());
        println!("Total Images: {}", response.total_images.to_string().cyan());
        
        if response.total_requests == 0 {
            println!("\n{}", "No usage during this period".dimmed());
        }
    }
    
    Ok(())
}

fn format_date(date_str: &str) -> String {
    if let Ok(date) = DateTime::parse_from_rfc3339(date_str) {
        date.format("%Y-%m-%d").to_string()
    } else {
        date_str.to_string()
    }
}