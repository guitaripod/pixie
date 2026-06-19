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
    if let Some(is_public) = image.is_public {
        println!("Visibility: {}", if is_public { "Public".green() } else { "Private".yellow() });
    }

    if let Ok(date) = DateTime::parse_from_rfc3339(&image.created_at) {
        println!("Created: {}", date.format("%Y-%m-%d %H:%M:%S"));
    } else {
        println!("Created: {}", image.created_at);
    }

    Ok(())
}

pub async fn delete(api_url: &str, image_id: &str) -> Result<()> {
    let config = Config::load()?;
    if !config.is_authenticated() {
        return Err(anyhow::anyhow!(
            "Not authenticated. Run {} to authenticate",
            "pixie auth github".cyan()
        ));
    }

    let client = ApiClient::new(api_url)?;

    println!("Deleting image {}...", image_id);
    client.delete_image(image_id).await?;

    println!("{}", "Image deleted. It has been removed from your gallery and the public feed.".green());

    Ok(())
}

pub async fn set_visibility(api_url: &str, image_id: &str, is_public: bool) -> Result<()> {
    let config = Config::load()?;
    if !config.is_authenticated() {
        return Err(anyhow::anyhow!(
            "Not authenticated. Run {} to authenticate",
            "pixie auth github".cyan()
        ));
    }

    let client = ApiClient::new(api_url)?;
    client.set_image_visibility(image_id, is_public).await?;

    if is_public {
        println!("{}", "Image is now public — it appears in the public gallery feed.".green());
    } else {
        println!("{}", "Image is now private — removed from the public gallery feed.".yellow());
    }

    Ok(())
}

pub async fn set_all_visibility(api_url: &str, is_public: bool) -> Result<()> {
    let config = Config::load()?;
    if !config.is_authenticated() {
        return Err(anyhow::anyhow!(
            "Not authenticated. Run {} to authenticate",
            "pixie auth github".cyan()
        ));
    }

    let client = ApiClient::new(api_url)?;
    let updated = client.set_all_visibility(is_public).await?;

    if is_public {
        println!("{}", format!("{} image(s) are now public.", updated).green());
    } else {
        println!("{}", format!("{} image(s) removed from the public gallery feed.", updated).yellow());
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
