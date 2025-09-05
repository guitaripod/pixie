use worker::{Env, Result};
use crate::models::StoredImage;
use crate::error::AppError;
use uuid::Uuid;
use chrono::{Utc, Duration};
use base64::{Engine as _, engine::general_purpose};

pub async fn store_image_in_r2(
    env: &Env,
    user_id: &str,
    base64_data: &str,
    prompt: &str,
    model: &str,
    size: &str,
    quality: Option<&str>,
) -> Result<StoredImage> {
    let r2 = env.bucket("IMAGES").map_err(|e| AppError::InternalError(format!("Failed to get R2 bucket: {}", e)))?;
    
    let image_id = Uuid::new_v4().to_string();
    let r2_key = format!("{}/{}.png", user_id, image_id);
    
    let image_bytes = general_purpose::STANDARD
        .decode(base64_data)
        .map_err(|e| AppError::BadRequest(format!("Invalid base64 image data: {}", e)))?;
    
    r2.put(&r2_key, image_bytes)
        .execute()
        .await
        .map_err(|e| AppError::InternalError(format!("Failed to store image in R2: {}", e)))?;
    
    let service_url = env.var("SERVICE_URL")
        .map(|v| v.to_string())
        .unwrap_or_else(|_| "https://openai-image-proxy.guitaripod.workers.dev".to_string());
    let url = format!("{}/r2/{}", service_url, r2_key);
    
    let now = Utc::now();
    let expires_at = now + Duration::days(7);
    
    let stored_image = StoredImage {
        id: image_id,
        user_id: user_id.to_string(),
        r2_key,
        url,
        prompt: prompt.to_string(),
        model: model.to_string(),
        size: size.to_string(),
        quality: quality.map(|q| q.to_string()),
        created_at: now,
        expires_at,
    };
    
    Ok(stored_image)
}

pub async fn store_image_from_bytes(
    env: &Env,
    user_id: &str,
    image_bytes: &[u8],
    prompt: &str,
    model: &str,
    size: &str,
    quality: Option<&str>,
    _provider: &str,
) -> Result<StoredImage> {
    let r2 = env.bucket("IMAGES").map_err(|e| AppError::InternalError(format!("Failed to get R2 bucket: {}", e)))?;
    
    let image_id = Uuid::new_v4().to_string();
    let r2_key = format!("{}/{}.png", user_id, image_id);
    
    r2.put(&r2_key, image_bytes.to_vec())
        .execute()
        .await
        .map_err(|e| AppError::InternalError(format!("Failed to store image in R2: {}", e)))?;
    
    let service_url = env.var("SERVICE_URL")
        .map(|v| v.to_string())
        .unwrap_or_else(|_| "https://openai-image-proxy.guitaripod.workers.dev".to_string());
    let url = format!("{}/r2/{}", service_url, r2_key);
    
    let now = Utc::now();
    let expires_at = now + Duration::days(7);
    
    let stored_image = StoredImage {
        id: image_id,
        user_id: user_id.to_string(),
        r2_key,
        url,
        prompt: prompt.to_string(),
        model: model.to_string(),
        size: size.to_string(),
        quality: quality.map(|q| q.to_string()),
        created_at: now,
        expires_at,
    };
    
    Ok(stored_image)
}