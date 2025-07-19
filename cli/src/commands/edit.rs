use anyhow::{Result, Context};
use colored::*;
use indicatif::{ProgressBar, ProgressStyle};
use std::path::Path;
use std::fs;
use base64::{Engine as _, engine::general_purpose::STANDARD};

use crate::api::{ApiClient, ImageEditRequest};
use crate::config::Config;

pub async fn handle(
    api_url: &str,
    image_path: &str,
    prompt: &str,
    mask_path: Option<&str>,
    number: u8,
    size: &str,
    quality: &str,
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
    
    if !Path::new(image_path).exists() {
        return Err(anyhow::anyhow!("Image file not found: {}", image_path));
    }
    
    let image_data = fs::read(image_path)
        .with_context(|| format!("Failed to read image file: {}", image_path))?;
    
    // Check file size (OpenAI limit is 50MB per image)
    if image_data.len() > 50 * 1024 * 1024 {
        return Err(anyhow::anyhow!("Image file is too large. Maximum size is 50MB, got {}MB", 
            image_data.len() / (1024 * 1024)));
    }
    
    let mime_type = if image_path.ends_with(".png") {
        "image/png"
    } else if image_path.ends_with(".jpg") || image_path.ends_with(".jpeg") {
        "image/jpeg"
    } else if image_path.ends_with(".webp") {
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
    
    println!("Editing image: {}", image_path.cyan());
    println!("With prompt: {}", prompt.cyan());
    if mask_path.is_some() {
        println!("Using mask: {}", mask_path.unwrap().cyan());
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
        size: size.to_string(),
        quality: quality.to_string(),
        background: "auto".to_string(),
        input_fidelity: "low".to_string(),
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
    
    Ok(())
}