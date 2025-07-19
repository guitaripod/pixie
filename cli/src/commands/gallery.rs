use anyhow::Result;
use colored::*;
use chrono::DateTime;

use crate::api::ApiClient;
use crate::config::Config;

pub async fn list_all(api_url: &str, page: usize, limit: usize) -> Result<()> {
    let client = ApiClient::new(api_url)?;
    
    println!("Fetching public gallery (page {})...", page);
    
    let response = client.list_images(page, limit).await?;
    
    println!("\n{}", "Public Image Gallery".bold().underline());
    println!("Total images: {} | Page {} of {}", 
        response.total,
        response.page,
        (response.total + response.per_page - 1) / response.per_page
    );
    println!();
    
    for image in &response.images {
        display_image_summary(&image);
    }
    
    if response.images.is_empty() {
        println!("{}", "No images found".dimmed());
    } else {
        println!("\nUse {} to view more pages", "pixie gallery list --page N".cyan());
    }
    
    Ok(())
}

pub async fn list_mine(api_url: &str, page: usize, limit: usize) -> Result<()> {
    let config = Config::load()?;
    if !config.is_authenticated() {
        return Err(anyhow::anyhow!(
            "Not authenticated. Run {} to authenticate",
            "pixie auth github".cyan()
        ));
    }
    
    let user_id = config.user_id.as_ref().unwrap();
    let client = ApiClient::new(api_url)?;
    
    println!("Fetching your images (page {})...", page);
    
    let response = client.list_user_images(user_id, page, limit).await?;
    
    println!("\n{}", "Your Images".bold().underline());
    println!("Total images: {} | Page {} of {}", 
        response.total,
        response.page,
        (response.total + response.per_page - 1) / response.per_page
    );
    println!();
    
    for image in &response.images {
        display_image_summary(&image);
    }
    
    if response.images.is_empty() {
        println!("{}", "No images found".dimmed());
        println!("Generate some images with: {}", "pixie generate \"your prompt\"".cyan());
    } else {
        println!("\nUse {} to view more pages", "pixie gallery mine --page N".cyan());
    }
    
    Ok(())
}

pub async fn view(api_url: &str, image_id: &str) -> Result<()> {
    let client = ApiClient::new(api_url)?;
    
    println!("Fetching image details...");
    
    let image = client.get_image(image_id).await?;
    
    println!("\n{}", "Image Details".bold().underline());
    println!("ID: {}", image.id);
    println!("URL: {}", image.url.blue().underline());
    println!("Prompt: {}", image.prompt.green());
    println!("Model: {}", image.model);
    println!("Size: {}", image.size);
    if let Some(quality) = &image.quality {
        println!("Quality: {}", quality);
    }
    println!("User: {}", image.user_id);
    
    if let Ok(date) = DateTime::parse_from_rfc3339(&image.created_at) {
        println!("Created: {}", date.format("%Y-%m-%d %H:%M:%S"));
    } else {
        println!("Created: {}", image.created_at);
    }
    
    Ok(())
}

fn display_image_summary(image: &crate::api::ImageMetadata) {
    println!("{}", format!("Image {}", image.id).yellow());
    println!("  Prompt: {}", 
        if image.prompt.len() > 60 {
            format!("{}...", &image.prompt[..60])
        } else {
            image.prompt.clone()
        }.dimmed()
    );
    println!("  URL: {}", image.url.blue().underline());
    
    if let Ok(date) = DateTime::parse_from_rfc3339(&image.created_at) {
        println!("  Created: {}", date.format("%Y-%m-%d %H:%M:%S").to_string().dimmed());
    }
    
    println!();
}
