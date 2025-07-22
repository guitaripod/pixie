use anyhow::Result;
use colored::*;
use serde::{Deserialize, Serialize};
use std::time::Duration;

use crate::config::Config;

#[derive(Debug, Serialize)]
struct DeviceCodeRequest {
    client_type: String,
    provider: String,
}

#[derive(Debug, Deserialize)]
struct DeviceCodeResponse {
    device_code: String,
    user_code: String,
    #[allow(dead_code)]
    verification_uri: String,
    verification_uri_complete: String,
    expires_in: u32,
    interval: u32,
}

#[derive(Debug, Serialize)]
struct DeviceTokenRequest {
    device_code: String,
    client_type: String,
}

#[derive(Debug, Deserialize)]
struct DeviceTokenResponse {
    api_key: String,
    user_id: String,
}

#[derive(Debug, Deserialize)]
struct ErrorResponse {
    error: ErrorDetail,
}

#[derive(Debug, Deserialize)]
struct ErrorDetail {
    message: String,
    #[serde(rename = "type")]
    #[allow(dead_code)]
    error_type: String,
}

async fn authenticate_provider(api_url: &str, provider: &str) -> Result<()> {
    let client = reqwest::Client::new();
    
    println!("Starting {} authentication...\n", provider);
    
    let device_response = client
        .post(&format!("{}/v1/auth/device/code", api_url))
        .json(&DeviceCodeRequest {
            client_type: "cli".to_string(),
            provider: provider.to_string(),
        })
        .send()
        .await?;
    
    if !device_response.status().is_success() {
        let error = device_response.text().await?;
        return Err(anyhow::anyhow!("Failed to start device flow: {}", error));
    }
    
    let device_data: DeviceCodeResponse = device_response.json().await?;
    
    println!("{}", "Please visit this URL to authenticate:".bold());
    println!("{}\n", device_data.verification_uri_complete.blue().underline());
    
    println!("{}", "Or manually enter this code:".bold());
    println!("{}\n", device_data.user_code.green().bold());
    
    println!("Opening browser...");
    webbrowser::open(&device_data.verification_uri_complete)?;
    
    println!("\n{}", "Waiting for authorization...".yellow());
    
    let spinner_chars = vec!["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
    let mut spinner_idx = 0;
    
    let interval = Duration::from_secs(device_data.interval as u64);
    let timeout = tokio::time::Instant::now() + Duration::from_secs(device_data.expires_in as u64);
    
    loop {
        if tokio::time::Instant::now() > timeout {
            return Err(anyhow::anyhow!("Authentication timeout"));
        }
        
        print!("\r{} Polling for authorization...", spinner_chars[spinner_idx].green());
        use std::io::Write;
        std::io::stdout().flush()?;
        
        spinner_idx = (spinner_idx + 1) % spinner_chars.len();
        
        let token_response = client
            .post(&format!("{}/v1/auth/device/token", api_url))
            .json(&DeviceTokenRequest {
                device_code: device_data.device_code.clone(),
                client_type: "cli".to_string(),
            })
            .send()
            .await?;
        
        if token_response.status().is_success() {
            print!("\r");
            
            let token_data: DeviceTokenResponse = token_response.json().await?;
            
            let mut config = Config::load()?;
            config.api_key = Some(token_data.api_key);
            config.user_id = Some(token_data.user_id);
            config.auth_provider = Some(provider.to_string());
            config.api_url = Some(api_url.to_string());
            config.save()?;
            
            println!("{}", "✓ Authentication successful!".green().bold());
            println!("User ID: {}", config.user_id.as_ref().unwrap());
            
            return Ok(());
        }
        
        let error_text = token_response.text().await?;
        
        if let Ok(error_response) = serde_json::from_str::<ErrorResponse>(&error_text) {
            match error_response.error.message.as_str() {
                "Authorization pending" => {},
                "Slow down" => {
                    // Increase interval
                    tokio::time::sleep(interval * 2).await;
                    continue;
                },
                "Device code expired" => {
                    print!("\r");
                    return Err(anyhow::anyhow!("Device code expired. Please try again."));
                },
                "Access denied" => {
                    print!("\r");
                    return Err(anyhow::anyhow!("Access denied by user"));
                },
                _ => {
                    print!("\r");
                    return Err(anyhow::anyhow!("Authentication failed: {}", error_response.error.message));
                }
            }
        }
        
        tokio::time::sleep(interval).await;
    }
}

pub async fn authenticate_github(api_url: &str) -> Result<()> {
    authenticate_provider(api_url, "github").await
}

pub async fn authenticate_google(api_url: &str) -> Result<()> {
    authenticate_provider(api_url, "google").await
}

pub async fn authenticate_apple(api_url: &str) -> Result<()> {
    println!("Starting Apple authentication...\n");
    
    // Generate a random state for security
    let state = uuid::Uuid::new_v4().to_string();
    
    // Construct the OAuth URL
    let auth_url = format!(
        "{}/v1/auth/apple?state={}&redirect_uri={}/v1/auth/apple/callback",
        api_url,
        urlencoding::encode(&state),
        urlencoding::encode(api_url)
    );
    
    println!("{}", "Please visit this URL to authenticate:".bold());
    println!("{}\n", auth_url.blue().underline());
    
    println!("Opening browser...");
    webbrowser::open(&auth_url)?;
    
    println!("\n{}", "After authenticating in your browser, you'll receive an API key and User ID.".yellow());
    println!("{}", "Please enter them below:\n".dimmed());
    
    // Prompt for API key
    print!("API Key: ");
    use std::io::Write;
    std::io::stdout().flush()?;
    
    let mut api_key = String::new();
    std::io::stdin().read_line(&mut api_key)?;
    let api_key = api_key.trim().to_string();
    
    // Prompt for User ID
    print!("User ID: ");
    std::io::stdout().flush()?;
    
    let mut user_id = String::new();
    std::io::stdin().read_line(&mut user_id)?;
    let user_id = user_id.trim().to_string();
    
    // Save the credentials
    let mut config = Config::load()?;
    config.api_key = Some(api_key);
    config.user_id = Some(user_id);
    config.auth_provider = Some("apple".to_string());
    config.api_url = Some(api_url.to_string());
    config.save()?;
    
    println!("\n{}", "✓ Authentication successful!".green().bold());
    println!("User ID: {}", config.user_id.as_ref().unwrap());
    
    Ok(())
}