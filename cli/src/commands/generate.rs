use anyhow::{Result, Context};
use colored::*;
use indicatif::{ProgressBar, ProgressStyle};
use std::path::Path;
use chrono;

use crate::api::{ApiClient, ImageGenerationRequest};
use crate::config::Config;
use crate::commands::utils::{check_credits_and_estimate, show_credits_used};
use crate::commands::parse_size_alias;

pub async fn handle(
    api_url: &str,
    prompt: &str,
    number: u8,
    size: &str,
    quality: &str,
    output: Option<&str>,
    background: Option<&str>,
    format: Option<&str>,
    compress: Option<u8>,
    moderation: Option<&str>,
    model: &str,
) -> Result<()> {
    let config = Config::load()?;
    if !config.is_authenticated() {
        return Err(anyhow::anyhow!(
            "Not authenticated. Run {} to authenticate",
            "pixie auth github".cyan()
        ));
    }
    
    let client = ApiClient::new(api_url)?;
    
    // Parse size alias
    let actual_size = parse_size_alias(size);
    
    // Check if using Gemini (simpler UI)
    let is_gemini = model.starts_with("gemini");
    
    // Show generation summary
    println!("\n{}", "🎨 Generation Summary".bold().magenta());
    println!("  Prompt:     {}", prompt.cyan());
    println!("  Model:      {}", model.yellow());
    
    if !is_gemini {
        // Show OpenAI-specific options
        println!("  Quality:    {}", quality.to_uppercase().yellow());
        println!("  Size:       {} {}", 
            size.green(), 
            if size != &actual_size { format!("({})", actual_size).dimmed() } else { "".dimmed() }
        );
    }
    
    println!("  Quantity:   {}", number.to_string().blue());
    
    // Show optional parameters if set (OpenAI only)
    if !is_gemini {
        if let Some(bg) = background {
            println!("  Background: {}", bg.green());
        }
        if let Some(fmt) = format {
            println!("  Format:     {}", fmt.green());
            if let Some(c) = compress {
                println!("  Compress:   {}%", c.to_string().green());
            }
        }
        if let Some(mod_level) = moderation {
            println!("  Moderation: {}", mod_level.green());
        }
    }
    
    let (initial_balance, _) = check_credits_and_estimate(
        &client,
        quality,
        &actual_size,
        number,
        false,
        prompt,
        model,
    ).await?;
    
    let pb = ProgressBar::new_spinner();
    pb.set_style(ProgressStyle::default_spinner()
        .template("{spinner:.green} {msg}")
        .unwrap());
    pb.set_message("Sending request to API...");
    
    let request = ImageGenerationRequest {
        prompt: prompt.to_string(),
        model: model.to_string(),
        n: number,
        size: actual_size,
        quality: quality.to_string(),
        background: background.map(|s| s.to_string()),
        moderation: moderation.map(|s| s.to_string()),
        output_compression: compress,
        output_format: format.map(|s| s.to_string()),
        partial_images: None,
        stream: None,
        user: None,
    };
    
    let response = client.generate_images(&request).await?;
    pb.finish_with_message(format!("Generated {} image(s)", response.data.len()));
    
    for (i, image) in response.data.iter().enumerate() {
        if let Some(url) = &image.url {
            println!("\n{}:", format!("Image {}", i + 1).bold());
            println!("  URL: {}", url.blue().underline());
            
            if let Some(revised_prompt) = &image.revised_prompt {
                println!("  Revised prompt: {}", revised_prompt.dimmed());
            }
            
            if let Some(output_dir) = output {
                let pb = ProgressBar::new_spinner();
                pb.set_style(ProgressStyle::default_spinner()
                    .template("{spinner:.green} {msg}")
                    .unwrap());
                pb.set_message(format!("Downloading image {}...", i + 1));
                
                let image_data = client.download_image(url).await?;
                
                let output_path = Path::new(output_dir);
                std::fs::create_dir_all(output_path)?;
                
                let extension = format.unwrap_or("png");
                let filename = format!("image_{}_{}.{}", 
                    chrono::Local::now().format("%Y%m%d_%H%M%S"),
                    i + 1,
                    extension
                );
                let file_path = output_path.join(&filename);
                
                std::fs::write(&file_path, &image_data)
                    .context("Failed to save image")?;
                
                pb.finish_with_message(format!("Saved to {}", file_path.display()));
            }
        }
    }
    
    println!("\n{}", "Image generation complete!".green().bold());
    
    show_credits_used(&client, initial_balance).await?;
    
    Ok(())
}
