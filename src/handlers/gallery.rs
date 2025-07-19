use worker::{Request, Response, RouteContext, Result};
use crate::error::AppError;
use serde::{Deserialize, Serialize};
use serde_json::json;

#[derive(Debug, Serialize, Deserialize)]
pub struct ImageMetadata {
    pub id: String,
    pub url: String,
    pub prompt: String,
    pub created_at: String,
    pub user_id: String,
    pub size: String,
    pub model: String,
    pub quality: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ListImagesResponse {
    pub images: Vec<ImageMetadata>,
    pub total: usize,
    pub page: usize,
    pub per_page: usize,
}

pub async fn list_images(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let env = ctx.env;
    let url = req.url()?;
    let query_params: std::collections::HashMap<String, String> = url
        .query_pairs()
        .into_owned()
        .collect();
    
    let page = query_params
        .get("page")
        .and_then(|p| p.parse::<i32>().ok())
        .unwrap_or(1)
        .max(1);
    
    let per_page = query_params
        .get("per_page")
        .and_then(|p| p.parse::<i32>().ok())
        .unwrap_or(20)
        .min(100);
    
    let offset = (page - 1) * per_page;
    
    let db = env.d1("DB")?;
    
    let count_stmt = db.prepare("SELECT COUNT(*) as count FROM stored_images");
    let count_result = count_stmt.first::<serde_json::Value>(None).await?;
    let total = count_result
        .and_then(|v| v.get("count").and_then(|count| count.as_i64()))
        .unwrap_or(0) as usize;
    
    let images_stmt = db.prepare(
        "SELECT id, user_id, r2_key, prompt, model, size, quality, created_at 
         FROM stored_images 
         ORDER BY created_at DESC 
         LIMIT ? OFFSET ?"
    );
    
    let images_result = images_stmt
        .bind(&[per_page.into(), offset.into()])?
        .all()
        .await?;
    
    let mut images = Vec::new();
    if let Ok(results) = images_result.results() {
        for row in results {
            if let Ok(value) = serde_json::from_value::<serde_json::Value>(row) {
                images.push(ImageMetadata {
                    id: value.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                    url: format!("https://openai-image-proxy.guitaripod.workers.dev/r2/{}", 
                        value.get("r2_key").and_then(|v| v.as_str()).unwrap_or("")),
                    prompt: value.get("prompt").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                    created_at: value.get("created_at").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                    user_id: value.get("user_id").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                    size: value.get("size").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                    model: value.get("model").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                    quality: value.get("quality").and_then(|v| v.as_str()).map(|s| s.to_string()),
                });
            }
        }
    }
    
    let response = ListImagesResponse {
        images,
        total,
        page: page as usize,
        per_page: per_page as usize,
    };
    
    Response::from_json(&response)
}

pub async fn list_user_images(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let user_id = ctx.param("user_id")
        .ok_or_else(|| AppError::BadRequest("Missing user_id parameter".to_string()))?
        .to_string();
    
    let env = ctx.env;
    let url = req.url()?;
    let query_params: std::collections::HashMap<String, String> = url
        .query_pairs()
        .into_owned()
        .collect();
    
    let page = query_params
        .get("page")
        .and_then(|p| p.parse::<i32>().ok())
        .unwrap_or(1)
        .max(1);
    
    let per_page = query_params
        .get("per_page")
        .and_then(|p| p.parse::<i32>().ok())
        .unwrap_or(20)
        .min(100);
    
    let offset = (page - 1) * per_page;
    
    let db = env.d1("DB")?;
    
    let count_stmt = db.prepare("SELECT COUNT(*) as count FROM stored_images WHERE user_id = ?");
    let count_result = count_stmt
        .bind(&[user_id.clone().into()])?
        .first::<serde_json::Value>(None)
        .await?;
    let total = count_result
        .and_then(|v| v.get("count").and_then(|count| count.as_i64()))
        .unwrap_or(0) as usize;
    
    let images_stmt = db.prepare(
        "SELECT id, user_id, r2_key, prompt, model, size, quality, created_at 
         FROM stored_images 
         WHERE user_id = ?
         ORDER BY created_at DESC 
         LIMIT ? OFFSET ?"
    );
    
    let images_result = images_stmt
        .bind(&[user_id.clone().into(), per_page.into(), offset.into()])?
        .all()
        .await?;
    
    let mut images = Vec::new();
    if let Ok(results) = images_result.results() {
        for row in results {
            if let Ok(value) = serde_json::from_value::<serde_json::Value>(row) {
                images.push(ImageMetadata {
                    id: value.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                    url: format!("https://openai-image-proxy.guitaripod.workers.dev/r2/{}", 
                        value.get("r2_key").and_then(|v| v.as_str()).unwrap_or("")),
                    prompt: value.get("prompt").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                    created_at: value.get("created_at").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                    user_id: value.get("user_id").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                    size: value.get("size").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                    model: value.get("model").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                    quality: value.get("quality").and_then(|v| v.as_str()).map(|s| s.to_string()),
                });
            }
        }
    }
    
    Response::from_json(&json!({
        "user_id": user_id,
        "images": images,
        "total": total,
        "page": page as usize,
        "per_page": per_page as usize,
    }))
}

pub async fn get_image(_req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let image_id = ctx.param("image_id")
        .ok_or_else(|| AppError::BadRequest("Missing image_id parameter".to_string()))?
        .to_string();
    
    let env = ctx.env;
    let db = env.d1("DB")?;
    let stmt = db.prepare(
        "SELECT id, user_id, r2_key, prompt, model, size, quality, created_at 
         FROM stored_images 
         WHERE id = ?"
    );
    
    let result = stmt
        .bind(&[image_id.clone().into()])?
        .first::<serde_json::Value>(None)
        .await?;
    
    match result {
        Some(value) => {
            let metadata = ImageMetadata {
                id: value.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                url: format!("https://openai-image-proxy.guitaripod.workers.dev/r2/{}", 
                    value.get("r2_key").and_then(|v| v.as_str()).unwrap_or("")),
                prompt: value.get("prompt").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                created_at: value.get("created_at").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                user_id: value.get("user_id").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                size: value.get("size").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                model: value.get("model").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                quality: value.get("quality").and_then(|v| v.as_str()).map(|s| s.to_string()),
            };
            Response::from_json(&metadata)
        }
        None => {
            AppError::NotFound(format!("Image {} not found", image_id)).to_response()
        }
    }
}