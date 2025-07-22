use anyhow::{Result, Context};
use colored::*;
use indicatif::{ProgressBar, ProgressStyle};
use std::path::Path;
use std::fs;
use base64::{Engine as _, engine::general_purpose::STANDARD};
use chrono;

use crate::api::{ApiClient, ImageEditRequest};
use crate::config::Config;
use crate::commands::utils::{check_credits_and_estimate, show_credits_used};
use crate::commands::parse_size_alias;

pub async fn handle(
    api_url: &str,
    image_path: &str,
    prompt: &str,
    mask_path: Option<&str>,
    number: u8,
    size: &str,
    quality: &str,
    fidelity: &str,
    output: Option<&str>,
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
    
    // Show edit summary
    println!("\n{}", "✏️ Edit Summary".bold().magenta());
    println!("  Image:      {}", image_path.cyan());
    println!("  Prompt:     {}", prompt.cyan());
    println!("  Quality:    {}", quality.to_uppercase().yellow());
    println!("  Size:       {} {}", 
        size.green(), 
        if size != &actual_size { format!("({})", actual_size).dimmed() } else { "".dimmed() }
    );
    println!("  Quantity:   {}", number.to_string().blue());
    println!("  Fidelity:   {}", fidelity.green());
    
    // Show optional mask if provided
    if let Some(m) = mask_path {
        println!("  Mask:       {}", m.green());
    }
    
    let (initial_balance, _) = check_credits_and_estimate(
        &client,
        quality,
        &actual_size,
        number,
        true,
        prompt,
    ).await?;
    
    let (image_data, image_extension) = if image_path.starts_with("gallery:") {
        let image_id = image_path.trim_start_matches("gallery:");
        
        println!("Fetching image from gallery: {}", image_id.yellow());
        
        let gallery_response = client.list_images(1, 100).await?;
        
        let gallery_image = gallery_response.images.iter()
            .find(|img| img.id == image_id)
            .ok_or_else(|| anyhow::anyhow!("Image not found in gallery: {}", image_id))?;
        
        println!("  Original prompt: {}", gallery_image.prompt.dimmed());
        
        let data = client.download_image(&gallery_image.url).await?;
        let ext = if gallery_image.url.contains(".png") { ".png".to_string() } 
                  else if gallery_image.url.contains(".jpg") || gallery_image.url.contains(".jpeg") { ".jpg".to_string() }
                  else { ".png".to_string() };
        (data, ext)
    } else {
        if !Path::new(image_path).exists() {
            return Err(anyhow::anyhow!("Image file not found: {}", image_path));
        }
        
        let data = fs::read(image_path)
            .with_context(|| format!("Failed to read image file: {}", image_path))?;
        let ext = Path::new(image_path)
            .extension()
            .and_then(|e| e.to_str())
            .map(|e| format!(".{}", e))
            .unwrap_or_else(|| ".png".to_string());
        (data, ext)
    };
    
    // Check file size (OpenAI limit is 50MB per image)
    if image_data.len() > 50 * 1024 * 1024 {
        return Err(anyhow::anyhow!("Image file is too large. Maximum size is 50MB, got {}MB", 
            image_data.len() / (1024 * 1024)));
    }
    
    let mime_type = if image_extension == ".png" {
        "image/png"
    } else if image_extension == ".jpg" || image_extension == ".jpeg" {
        "image/jpeg"
    } else if image_extension == ".webp" {
        "image/webp"
    } else {
        "image/png"
    };
    
    let image_base64 = STANDARD.encode(&image_data);
    let image_data_url = format!("data:{};base64,{}", mime_type, image_base64);
    
    let mask_data_url = if let Some(mask) = mask_path {
        if !Path::new(mask).exists() {
            return Err(anyhow::anyhow!("Mask file not found: {}", mask));
        }
        let mask_data = fs::read(mask)
            .with_context(|| format!("Failed to read mask file: {}", mask))?;
        let mask_base64 = STANDARD.encode(&mask_data);
        Some(format!("data:image/png;base64,{}", mask_base64))
    } else {
        None
    };
    
    println!("{}", format!("Editing image: {}", image_path).cyan());
    println!("{}", format!("With prompt: {}", prompt).cyan());
    if let Some(mask) = mask_path {
        println!("{}", format!("Using mask: {}", mask).cyan());
    }
    
    let pb = ProgressBar::new_spinner();
    pb.set_style(ProgressStyle::default_spinner()
        .template("{spinner:.green} {msg}")
        .unwrap());
    pb.set_message("Sending request to API...");
    
    let request = ImageEditRequest {
        image: vec![image_data_url],
        prompt: prompt.to_string(),
        mask: mask_data_url,
        model: "gpt-image-1".to_string(),
        n: number,
        size: actual_size,
        quality: quality.to_string(),
        background: "auto".to_string(),
        input_fidelity: fidelity.to_string(),
        output_format: "png".to_string(),
        output_compression: None,
        partial_images: 0,
        stream: false,
        user: None,
    };
    
    let response = client.edit_image(&request).await?;
    pb.finish_with_message(format!("Generated {} edited image(s)", response.data.len()));
    
    for (i, image) in response.data.iter().enumerate() {
        if let Some(url) = &image.url {
            println!("\n{}:", format!("Edited Image {}", i + 1).bold());
            println!("  URL: {}", url.blue().underline());
            
            if let Some(revised_prompt) = &image.revised_prompt {
                println!("  Revised prompt: {}", revised_prompt.dimmed());
            }
            
            if let Some(output_dir) = output {
                let path = Path::new(output_dir);
                if !path.exists() {
                    fs::create_dir_all(path)?;
                }
                
                let filename = format!("edited_{}_{}.png", 
                    chrono::Local::now().format("%Y%m%d_%H%M%S"), 
                    i + 1
                );
                let file_path = path.join(&filename);
                
                println!("  Downloading to: {}", file_path.display());
                let image_data = client.download_image(url).await?;
                fs::write(&file_path, image_data)?;
                println!("  ✓ Saved as: {}", filename.green());
            }
        }
    }
    
    println!("\n{}", "Image edit complete!".green().bold());
    
    show_credits_used(&client, initial_balance).await?;
    
    Ok(())
}