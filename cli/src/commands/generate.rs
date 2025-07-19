use anyhow::{Result, Context};
use colored::*;
use indicatif::{ProgressBar, ProgressStyle};
use std::path::Path;

use crate::api::{ApiClient, ImageGenerationRequest};
use crate::config::Config;

pub async fn handle(
    api_url: &str,
    prompt: &str,
    number: u8,
    size: &str,
    quality: &str,
    output: Option<&str>,
) -> Result<()> {
    let config = Config::load()?;
    if !config.is_authenticated() {
        return Err(anyhow::anyhow!(
            "Not authenticated. Run {} to authenticate",
            "oip auth github".cyan()
        ));
    }
    
    let client = ApiClient::new(api_url)?;
    
    println!("Generating {} image(s) for prompt: {}", number, prompt.cyan());
    
    let pb = ProgressBar::new_spinner();
    pb.set_style(ProgressStyle::default_spinner()
        .template("{spinner:.green} {msg}")
        .unwrap());
    pb.set_message("Sending request to API...");
    
    let request = ImageGenerationRequest {
        prompt: prompt.to_string(),
        model: "gpt-image-1".to_string(),
        n: number,
        size: size.to_string(),
        quality: quality.to_string(),
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
                
                let filename = format!("image_{}_{}.png", 
                    chrono::Local::now().format("%Y%m%d_%H%M%S"),
                    i + 1
                );
                let file_path = output_path.join(&filename);
                
                std::fs::write(&file_path, &image_data)
                    .context("Failed to save image")?;
                
                pb.finish_with_message(format!("Saved to {}", file_path.display()));
            }
        }
    }
    
    println!("\n{}", "Image generation complete!".green().bold());
    
    Ok(())
}