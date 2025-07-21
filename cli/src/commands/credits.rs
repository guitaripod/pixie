use anyhow::Result;
use colored::*;
use std::io::{self, Write};
use crate::{api::{ApiClient, CreditEstimateRequest}, config::Config};
use dialoguer::{Select, theme::ColorfulTheme};

pub async fn show_balance(api_url: &str) -> Result<()> {
    let config = Config::load()?;
    
    if !config.is_authenticated() {
        println!("{}", "You need to authenticate first. Run: pixie auth github".yellow());
        return Ok(());
    }
    
    let client = ApiClient::new(api_url)?;
    let balance = client.get_credit_balance().await?;
    
    // Create a visual representation of the balance
    println!();
    println!("{}", "💰 Credit Balance".bold().green());
    println!("{}", "═".repeat(50).green());
    
    // Display the balance with visual indicator
    let balance_display = format!("{} credits", balance.balance);
    let value_display = format!("(${:.2} USD)", balance.balance as f64 / 100.0);
    
    if balance.balance == 0 {
        println!("  {} {}", 
            balance_display.bold().red(),
            value_display.dimmed()
        );
        println!();
        println!("  {}", "⚠️  No credits remaining!".yellow());
        println!("  {}", "Purchase credits to continue generating images.".dimmed());
    } else if balance.balance < 50 {
        println!("  {} {}", 
            balance_display.bold().yellow(),
            value_display.dimmed()
        );
        println!();
        println!("  {}", "⚠️  Low balance warning".yellow());
        println!("  {}", "Consider purchasing more credits soon.".dimmed());
    } else {
        println!("  {} {}", 
            balance_display.bold().green(),
            value_display.dimmed()
        );
    }
    
    println!();
    
    // Show what they can do with their balance
    if balance.balance > 0 {
        println!("{}", "📊 Estimated Usage:".bold());
        let low_images = balance.balance / 5;
        let medium_images = balance.balance / 13;
        let high_images = balance.balance / 55;
        
        if low_images > 0 {
            println!("  • Low quality:    ~{} images", low_images.to_string().cyan());
        }
        if medium_images > 0 {
            println!("  • Medium quality: ~{} images", medium_images.to_string().cyan());
        }
        if high_images > 0 {
            println!("  • High quality:   ~{} images", high_images.to_string().cyan());
        }
        println!();
    }
    
    println!("{}", "═".repeat(50).green());
    println!();
    println!("{}  {}", "Tip:".bold(), "Run 'pixie credits history' to see recent transactions".dimmed());
    println!("     {}", "Run 'pixie credits packs' to see available credit packs".dimmed());
    
    Ok(())
}

pub async fn show_history(api_url: &str, limit: usize) -> Result<()> {
    let config = Config::load()?;
    
    if !config.is_authenticated() {
        println!("{}", "You need to authenticate first. Run: pixie auth github".yellow());
        return Ok(());
    }
    
    let client = ApiClient::new(api_url)?;
    let response = client.get_credit_transactions(limit).await?;
    
    println!();
    println!("{}", format!("📜 Credit Transaction History (Last {})", limit).bold().blue());
    println!("{}", "═".repeat(80).blue());
    
    if response.transactions.is_empty() {
        println!("  {}", "No transactions found.".dimmed());
    } else {
        // Header
        println!("  {:<20} {:<12} {:<10} {:<10} {}",
            "Date".bold(),
            "Type".bold(),
            "Amount".bold(),
            "Balance".bold(),
            "Description".bold()
        );
        println!("  {}", "─".repeat(78).dimmed());
        
        for transaction in &response.transactions {
            // Parse and format the date
            let date = transaction.created_at.split('T').next().unwrap_or(&transaction.created_at);
            
            // Format type with color
            let type_display = match transaction.transaction_type.as_str() {
                "purchase" => "Purchase".green(),
                "spend" => "Spent".red(),
                "refund" => "Refund".cyan(),
                "bonus" => "Bonus".yellow(),
                "admin_adjustment" => "Adjustment".blue(),
                _ => transaction.transaction_type.normal(),
            };
            
            // Format amount with + or -
            let amount_display = if transaction.amount > 0 {
                format!("+{}", transaction.amount).green()
            } else {
                transaction.amount.to_string().red()
            };
            
            println!("  {:<20} {:<12} {:<10} {:<10} {}",
                date,
                type_display,
                amount_display,
                transaction.balance_after.to_string().bold(),
                transaction.description.dimmed()
            );
        }
    }
    
    println!("{}", "═".repeat(80).blue());
    println!();
    
    Ok(())
}

pub async fn show_packs(api_url: &str) -> Result<()> {
    let client = ApiClient::new(api_url)?;
    let response = client.get_credit_packs().await?;
    
    println!();
    println!("{}", "🎁 Available Credit Packs".bold().magenta());
    println!("{}", "═".repeat(70).magenta());
    println!();
    
    for (index, pack) in response.packs.iter().enumerate() {
        let total_credits = pack.credits + pack.bonus_credits;
        let price_usd = pack.price_usd_cents as f64 / 100.0;
        let price_per_credit = price_usd / total_credits as f64;
        
        // Highlight popular pack
        let is_popular = pack.id == "popular";
        
        if is_popular {
            println!("  {} {}", 
                "⭐".yellow(), 
                pack.name.bold().yellow()
            );
        } else {
            println!("  {}", pack.name.bold());
        }
        
        // Credits info
        print!("     Credits: {}", pack.credits.to_string().cyan());
        if pack.bonus_credits > 0 {
            let bonus_percent = (pack.bonus_credits as f64 / pack.credits as f64 * 100.0) as i32;
            print!(" {} {}", 
                format!("+{}", pack.bonus_credits).green().bold(),
                format!("({}% bonus)", bonus_percent).green()
            );
        }
        println!(" = {} total", total_credits.to_string().bold());
        
        // Price info
        println!("     Price: {} {}", 
            format!("${:.2}", price_usd).bold().green(),
            format!("(${:.4} per credit)", price_per_credit).dimmed()
        );
        
        // Description
        println!("     {}", pack.description.dimmed());
        
        if index < response.packs.len() - 1 {
            println!();
        }
    }
    
    println!();
    println!("{}", "═".repeat(70).magenta());
    println!();
    println!("{} {} {}", "💳".cyan(), "Pay with card:".bold(), "pixie credits buy".blue());
    println!("{} {} {}", "🪙".yellow(), "Pay with crypto:".bold(), "pixie credits buy --crypto btc".blue());
    println!();
    
    Ok(())
}

pub async fn estimate_cost(
    api_url: &str,
    quality: Option<&str>,
    size: Option<&str>,
    number: u8,
    is_edit: bool,
) -> Result<()> {
    // Interactive mode if quality or size not provided
    let quality = if let Some(q) = quality {
        q.to_string()
    } else {
        println!("{}", "📊 Credit Cost Estimator".bold().cyan());
        println!();
        println!("Select quality level:");
        println!("  1) {} - Fast generation, lower detail", "Low".yellow());
        println!("  2) {} - Balanced quality and speed", "Medium".green());
        println!("  3) {} - Maximum detail and clarity", "High".blue());
        print!("\nChoice (1-3): ");
        std::io::stdout().flush()?;
        
        let mut input = String::new();
        io::stdin().read_line(&mut input)?;
        
        match input.trim() {
            "1" => "low".to_string(),
            "2" => "medium".to_string(),
            "3" => "high".to_string(),
            _ => "medium".to_string(),
        }
    };
    
    let size = if let Some(s) = size {
        s.to_string()
    } else {
        println!("\nSelect image size:");
        println!("  1) {} - Square format", "1024x1024".yellow());
        println!("  2) {} - Wide/landscape", "1536x1024".green());
        println!("  3) {} - Tall/portrait", "1024x1536".blue());
        print!("\nChoice (1-3): ");
        std::io::stdout().flush()?;
        
        let mut input = String::new();
        io::stdin().read_line(&mut input)?;
        
        match input.trim() {
            "1" => "1024x1024".to_string(),
            "2" => "1536x1024".to_string(),
            "3" => "1024x1536".to_string(),
            _ => "1024x1024".to_string(),
        }
    };
    
    let client = ApiClient::new(api_url)?;
    let request = CreditEstimateRequest {
        prompt: Some("Sample prompt for estimation".to_string()),
        quality: quality.clone(),
        size: size.clone(),
        n: Some(number),
        is_edit: Some(is_edit),
    };
    
    let response = client.estimate_credit_cost(&request).await?;
    
    println!();
    println!("{}", "💰 Cost Estimate".bold().green());
    println!("{}", "═".repeat(50).green());
    
    // Operation details
    println!("  Operation: {}", 
        if is_edit { "Image Edit".cyan() } else { "Image Generation".cyan() }
    );
    println!("  Quality:   {}", quality.to_uppercase().bold());
    println!("  Size:      {}", size.bold());
    println!("  Quantity:  {}", number.to_string().bold());
    
    println!();
    
    // Cost breakdown
    let per_image_cost = response.estimated_credits / number as u32;
    println!("  Per image:    {} credits", per_image_cost.to_string().yellow());
    println!("  Total cost:   {} {}", 
        response.estimated_credits.to_string().bold().green(),
        format!("credits {}", response.estimated_usd).dimmed()
    );
    
    println!();
    println!("  {}", response.note.dimmed());
    
    println!("{}", "═".repeat(50).green());
    
    // Check current balance and show if they have enough
    if let Ok(config) = Config::load() {
        if config.is_authenticated() {
            if let Ok(balance) = client.get_credit_balance().await {
                println!();
                if balance.balance >= response.estimated_credits as i32 {
                    println!("  ✅ {} {} credits available", 
                        "You have".green(),
                        balance.balance.to_string().bold().green()
                    );
                } else {
                    println!("  ❌ {} Only {} credits available", 
                        "Insufficient credits!".red(),
                        balance.balance.to_string().bold().yellow()
                    );
                    let needed = response.estimated_credits as i32 - balance.balance;
                    println!("     Need {} more credits", needed.to_string().red());
                }
            }
        }
    }
    
    Ok(())
}

pub async fn buy_credits(
    api_url: &str,
    pack_id: Option<&str>,
    crypto_currency: Option<&str>,
) -> Result<()> {
    let config = Config::load()?;
    
    if !config.is_authenticated() {
        println!("{}", "You need to authenticate first. Run: pixie auth github".yellow());
        return Ok(());
    }
    
    let client = ApiClient::new(api_url)?;
    
    // Get available packs
    let packs_response = client.get_credit_packs().await?;
    
    // Interactive pack selection if not provided
    let pack_id = if let Some(id) = pack_id {
        // Validate pack ID
        if !packs_response.packs.iter().any(|p| p.id == id) {
            println!("{}", "Invalid pack ID!".red());
            println!("Available packs: starter, basic, popular, pro, enterprise");
            return Ok(());
        }
        id.to_string()
    } else {
        println!();
        println!("{}", "🎁 Select Credit Pack".bold().magenta());
        println!("{}", "═".repeat(70).magenta());
        println!();
        
        let mut pack_names = Vec::new();
        for pack in &packs_response.packs {
            let total_credits = pack.credits + pack.bonus_credits;
            let price_usd = pack.price_usd_cents as f64 / 100.0;
            
            let mut display = if pack.id == "popular" {
                format!("⭐ {} - {} credits - ${:.2}", pack.name, total_credits, price_usd)
            } else {
                format!("{} - {} credits - ${:.2}", pack.name, total_credits, price_usd)
            };
            
            if pack.bonus_credits > 0 {
                let bonus_percent = (pack.bonus_credits as f64 / pack.credits as f64 * 100.0) as i32;
                display.push_str(&format!(" (+{}% bonus)", bonus_percent));
            }
            
            pack_names.push(display);
        }
        
        let selection = Select::with_theme(&ColorfulTheme::default())
            .with_prompt("Select a credit pack")
            .items(&pack_names)
            .default(2) // Default to popular pack
            .interact()?;
        
        packs_response.packs[selection].id.clone()
    };
    
    // Get selected pack details
    let selected_pack = packs_response.packs
        .iter()
        .find(|p| p.id == pack_id)
        .unwrap();
    
    // Payment method selection
    let payment_method = if crypto_currency.is_some() {
        "crypto"
    } else {
        println!();
        println!("{}", "💳 Select Payment Method".bold().cyan());
        println!("{}", "═".repeat(50).cyan());
        
        let payment_options = vec![
            "💳 Credit/Debit Card (Stripe)",
            "🪙 Cryptocurrency (Bitcoin, Ethereum, etc.)"
        ];
        
        let selection = Select::with_theme(&ColorfulTheme::default())
            .with_prompt("How would you like to pay?")
            .items(&payment_options)
            .default(0)
            .interact()?;
        
        match selection {
            0 => "card",
            1 => "crypto",
            _ => "card"
        }
    };
    
    match payment_method {
        "card" => {
            // Stripe payment flow
            println!();
            println!("{}", "Creating Stripe checkout session...".dimmed());
            
            let payment = client.purchase_credits_stripe(&pack_id).await?;
            
            println!();
            println!("{}", "━".repeat(50).bright_white());
            println!("{}", "STRIPE PAYMENT".bold());
            println!();
            println!("Amount: {} ({})",
                format!("${:.2}", selected_pack.price_usd_cents as f64 / 100.0).bold().green(),
                format!("{} credits", selected_pack.credits + selected_pack.bonus_credits).cyan()
            );
            println!();
            println!("{}", "Opening checkout page in your browser...".dimmed());
            println!("{}", "━".repeat(50).bright_white());
            
            // Open browser
            if let Err(e) = webbrowser::open(&payment.checkout_url) {
                println!();
                println!("{}", "Could not open browser automatically.".yellow());
                println!("Please visit this URL to complete payment:");
                println!("{}", payment.checkout_url.bright_blue().underline());
                println!();
                println!("Error: {}", e);
            }
            
            // Poll for payment confirmation
            use indicatif::{ProgressBar, ProgressStyle};
            
            println!();
            println!("{}", "Waiting for payment confirmation...".dimmed());
            println!("{}", "You can close this window after completing payment in your browser.".dimmed());
            println!();
            
            let pb = ProgressBar::new_spinner();
            pb.set_style(
                ProgressStyle::default_spinner()
                    .tick_chars("⣾⣽⣻⢿⡿⣟⣯⣷")
                    .template("{spinner:.cyan} {msg}")?
            );
            pb.set_message("Waiting for payment...");
            
            let mut confirmed = false;
            let start_time = std::time::Instant::now();
            let timeout = std::time::Duration::from_secs(10 * 60); // 10 minutes
            
            while !confirmed && start_time.elapsed() < timeout {
                pb.tick();
                tokio::time::sleep(std::time::Duration::from_secs(5)).await;
                
                match client.check_purchase_status(&payment.purchase_id).await {
                    Ok(status) => {
                        if status.status == "completed" {
                            confirmed = true;
                            pb.finish_and_clear();
                            println!("  {} Payment successful!", "✓".green().bold());
                        } else if status.status == "failed" || status.status == "cancelled" {
                            pb.finish_and_clear();
                            println!("  {} Payment {}", "✗".red().bold(), status.status);
                            return Ok(());
                        }
                    }
                    Err(e) => {
                        // Continue polling on error
                        pb.set_message(format!("Checking status... ({})", e));
                    }
                }
            }
            
            if !confirmed {
                pb.finish_with_message("❌ Payment timeout - please check your payment status");
                return Ok(());
            }
            
            // Show new balance
            println!();
            if let Ok(balance) = client.get_credit_balance().await {
                let total_credits = selected_pack.credits + selected_pack.bonus_credits;
                println!("{}", format!("Successfully added {} credits to your account!", total_credits).green().bold());
                println!("New balance: {} credits", balance.balance.to_string().cyan().bold());
            }
        }
        "crypto" => {
            // Check if crypto payments are supported for this pack
            if pack_id == "starter" {
                println!();
                println!("{}", "❌ Crypto payments not available for Starter pack".red().bold());
                println!("{}", "Due to minimum transaction requirements, crypto payments are only available for Basic pack and above.".yellow());
                println!("{}", "The Starter pack ($1.99) can be purchased with credit/debit cards.".dimmed());
                return Ok(());
            }
            
            // Interactive crypto selection if not provided
            let crypto_currency = if let Some(crypto) = crypto_currency {
                match crypto.to_lowercase().as_str() {
                    "btc" | "bitcoin" => "btc",
                    "eth" | "ethereum" => "eth",
                    "doge" | "dogecoin" => "doge",
                    "ltc" | "litecoin" => "ltc",
                    "lightning" => "btc", // Lightning uses BTC
                    _ => {
                        println!("{}", "Invalid cryptocurrency!".red());
                        println!("Supported: btc, eth, doge, ltc");
                        return Ok(());
                    }
                }
            } else {
                println!();
                println!("{}", "💰 Select Cryptocurrency".bold().cyan());
                println!("{}", "═".repeat(50).cyan());
                
                let crypto_options = vec![
                    "₿  Bitcoin (BTC)",
                    "Ξ  Ethereum (ETH)",
                    "Ð  Dogecoin (DOGE)",
                    "Ł  Litecoin (LTC)"
                ];
                
                let selection = Select::with_theme(&ColorfulTheme::default())
                    .with_prompt("Select cryptocurrency")
                    .items(&crypto_options)
                    .default(0)
                    .interact()?;
                
                match selection {
                    0 => "btc",
                    1 => "eth",
                    2 => "doge",
                    3 => "ltc",
                    _ => "btc"
                }
            };
            
            // Create crypto payment
            println!();
            println!("{}", "Creating payment request...".dimmed());
            
            let payment = client.purchase_credits_crypto(&pack_id, crypto_currency).await?;
            
            // Display payment details
            println!();
            println!("{}", "━".repeat(50).bright_white());
            println!("{} {}", 
                crypto_currency.to_uppercase().bold().yellow(),
                "PAYMENT DETAILS".bold()
            );
            println!();
            println!("Amount: {} {} ({})",
                payment.crypto_amount.bold().green(),
                payment.crypto_currency,
                payment.amount_usd.dimmed()
            );
            println!("Send to: {}", payment.crypto_address.bold().cyan());
            println!();
            
            // Generate and display QR code
            use qrcode::{QrCode, render::unicode};
            
            if let Ok(code) = QrCode::new(&payment.crypto_address) {
                let image = code.render::<unicode::Dense1x2>()
                    .dark_color(unicode::Dense1x2::Light)
                    .light_color(unicode::Dense1x2::Dark)
                    .build();
                println!("{}", image);
            }
            
            println!("Payment ID: {}", payment.purchase_id.dimmed());
            println!("Expires: {}", payment.expires_at.yellow());
            println!("{}", "━".repeat(50).bright_white());
            println!();
            
            // Poll for payment confirmation
            use indicatif::{ProgressBar, ProgressStyle};
            
            // Payment progress steps
            println!();
            println!("{}", "Payment Progress:".bold());
            
            let mut waiting_shown = false;
            let mut confirming_shown = false;
            let mut processing_shown = false;
            
            // Current status spinner
            let pb = ProgressBar::new_spinner();
            pb.set_style(
                ProgressStyle::default_spinner()
                    .tick_chars("⣾⣽⣻⢿⡿⣟⣯⣷")
                    .template("{spinner:.cyan} {msg}")?
            );
            
            let mut confirmed = false;
            let start_time = std::time::Instant::now();
            let timeout = std::time::Duration::from_secs(30 * 60); // 30 minutes
            let mut _last_status = String::new();
            
            while !confirmed && start_time.elapsed() < timeout {
                pb.tick();
                tokio::time::sleep(std::time::Duration::from_secs(10)).await;
                
                match client.check_purchase_status(&payment.purchase_id).await {
                    Ok(status) => {
                        if status.status == "completed" {
                            confirmed = true;
                            if !processing_shown {
                                pb.finish_and_clear();
                                println!("  {} Payment completed", "✓".green().bold());
                            }
                        } else if let Some(payment_status) = status.payment_status {
                            // Show progress steps as they happen
                            match payment_status.as_str() {
                                "waiting" => {
                                    if !waiting_shown {
                                        waiting_shown = true;
                                        pb.set_message("Waiting for payment to be sent...");
                                    }
                                },
                                "confirming" => {
                                    if !waiting_shown {
                                        waiting_shown = true;
                                        pb.finish_and_clear();
                                        println!("  {} Payment detected", "✓".green().bold());
                                    }
                                    if !confirming_shown {
                                        confirming_shown = true;
                                        pb.set_message("Confirming on blockchain...");
                                    }
                                },
                                "confirmed" | "sending" => {
                                    if !waiting_shown {
                                        waiting_shown = true;
                                        pb.finish_and_clear();
                                        println!("  {} Payment detected", "✓".green().bold());
                                    }
                                    if !confirming_shown {
                                        confirming_shown = true;
                                        pb.finish_and_clear();
                                        println!("  {} Blockchain confirmed", "✓".green().bold());
                                    }
                                    if !processing_shown {
                                        processing_shown = true;
                                        pb.set_message("Processing payment...");
                                    }
                                },
                                "finished" => {
                                    confirmed = true;
                                    pb.finish_and_clear();
                                    if !waiting_shown {
                                        println!("  {} Payment detected", "✓".green().bold());
                                    }
                                    if !confirming_shown {
                                        println!("  {} Blockchain confirmed", "✓".green().bold());
                                    }
                                    if !processing_shown {
                                        println!("  {} Payment processed", "✓".green().bold());
                                    }
                                    println!("  {} Payment completed", "✓".green().bold());
                                },
                                "failed" | "refunded" | "expired" => {
                                    pb.finish_and_clear();
                                    println!("  {} Payment {}", "✗".red().bold(), payment_status);
                                    return Ok(());
                                },
                                _ => {}
                            }
                            _last_status = payment_status;
                        }
                    }
                    Err(e) => {
                        pb.finish_with_message(format!("❌ Error checking status: {}", e));
                        return Err(e);
                    }
                }
            }
            
            if !confirmed {
                pb.finish_with_message("❌ Payment expired");
                return Ok(());
            }
            
            // Show new balance
            println!();
            if let Ok(balance) = client.get_credit_balance().await {
                let total_credits = selected_pack.credits + selected_pack.bonus_credits;
                println!("{}", format!("Successfully added {} credits to your account!", total_credits).green().bold());
                println!("New balance: {} credits", balance.balance.to_string().cyan().bold());
            }
        }
        _ => unreachable!()
    }
    
    Ok(())
}