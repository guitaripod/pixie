use worker::{Request, Response, RouteContext, Result};
use crate::error::AppError;
use crate::auth::resolve_app_id;
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
    pub is_public: bool,
}

fn build_image_metadata(value: &serde_json::Value) -> ImageMetadata {
    ImageMetadata {
        id: value.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string(),
        url: format!("https://openai-image-proxy.guitaripod.workers.dev/r2/{}",
            value.get("r2_key").and_then(|v| v.as_str()).unwrap_or("")),
        prompt: value.get("prompt").and_then(|v| v.as_str()).unwrap_or("").to_string(),
        created_at: value.get("created_at").and_then(|v| v.as_str()).unwrap_or("").to_string(),
        user_id: value.get("user_id").and_then(|v| v.as_str()).unwrap_or("").to_string(),
        size: value.get("size").and_then(|v| v.as_str()).unwrap_or("").to_string(),
        model: value.get("model").and_then(|v| v.as_str()).unwrap_or("").to_string(),
        quality: value.get("quality").and_then(|v| v.as_str()).map(|s| s.to_string()),
        is_public: value.get("is_public").and_then(|v| v.as_i64()).map(|v| v != 0).unwrap_or(true),
    }
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

    let app_id = resolve_app_id(&req);
    let db = env.d1("DB")?;

    let count_stmt = db.prepare("SELECT COUNT(*) as count FROM stored_images WHERE app_id = ? AND is_public = 1");
    let count_result = count_stmt
        .bind(&[app_id.clone().into()])?
        .first::<serde_json::Value>(None)
        .await?;
    let total = count_result
        .and_then(|v| v.get("count").and_then(|count| count.as_i64()))
        .unwrap_or(0) as usize;

    let images_stmt = db.prepare(
        "SELECT id, user_id, r2_key, prompt, model, size, quality, created_at, is_public
         FROM stored_images
         WHERE app_id = ? AND is_public = 1
         ORDER BY created_at DESC
         LIMIT ? OFFSET ?"
    );

    let images_result = images_stmt
        .bind(&[app_id.clone().into(), per_page.into(), offset.into()])?
        .all()
        .await?;

    let mut images = Vec::new();
    if let Ok(results) = images_result.results() {
        for row in results {
            if let Ok(value) = serde_json::from_value::<serde_json::Value>(row) {
                images.push(build_image_metadata(&value));
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

    let app_id = resolve_app_id(&req);
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

    let is_owner = crate::auth::authenticate(&req, &db)
        .await
        .map(|a| a.user_id == user_id)
        .unwrap_or(false);
    let visibility_clause = if is_owner { "" } else { " AND is_public = 1" };

    let count_stmt = db.prepare(&format!(
        "SELECT COUNT(*) as count FROM stored_images WHERE app_id = ? AND user_id = ?{}",
        visibility_clause
    ));
    let count_result = count_stmt
        .bind(&[app_id.clone().into(), user_id.clone().into()])?
        .first::<serde_json::Value>(None)
        .await?;
    let total = count_result
        .and_then(|v| v.get("count").and_then(|count| count.as_i64()))
        .unwrap_or(0) as usize;

    let images_stmt = db.prepare(&format!(
        "SELECT id, user_id, r2_key, prompt, model, size, quality, created_at, is_public
         FROM stored_images
         WHERE app_id = ? AND user_id = ?{}
         ORDER BY created_at DESC
         LIMIT ? OFFSET ?",
        visibility_clause
    ));

    let images_result = images_stmt
        .bind(&[app_id.clone().into(), user_id.clone().into(), per_page.into(), offset.into()])?
        .all()
        .await?;

    let mut images = Vec::new();
    if let Ok(results) = images_result.results() {
        for row in results {
            if let Ok(value) = serde_json::from_value::<serde_json::Value>(row) {
                images.push(build_image_metadata(&value));
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

pub async fn get_image(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let image_id = ctx.param("image_id")
        .ok_or_else(|| AppError::BadRequest("Missing image_id parameter".to_string()))?
        .to_string();

    let app_id = resolve_app_id(&req);
    let env = ctx.env;
    let db = env.d1("DB")?;
    let stmt = db.prepare(
        "SELECT id, user_id, r2_key, prompt, model, size, quality, created_at, is_public
         FROM stored_images
         WHERE app_id = ? AND id = ?"
    );

    let result = stmt
        .bind(&[app_id.clone().into(), image_id.clone().into()])?
        .first::<serde_json::Value>(None)
        .await?;

    match result {
        Some(value) => {
            let is_public = value.get("is_public").and_then(|v| v.as_i64()).map(|v| v != 0).unwrap_or(true);
            if !is_public {
                let owner_id = value.get("user_id").and_then(|v| v.as_str()).unwrap_or("");
                let is_owner = crate::auth::authenticate(&req, &db)
                    .await
                    .map(|a| a.user_id == owner_id)
                    .unwrap_or(false);
                if !is_owner {
                    return AppError::NotFound(format!("Image {} not found", image_id)).to_response();
                }
            }
            let metadata = build_image_metadata(&value);
            Response::from_json(&metadata)
        }
        None => {
            AppError::NotFound(format!("Image {} not found", image_id)).to_response()
        }
    }
}

#[derive(Debug, Deserialize)]
struct ReportImageRequest {
    reason: Option<String>,
}

pub async fn report_image(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let image_id = ctx.param("image_id")
        .ok_or_else(|| AppError::BadRequest("Missing image_id parameter".to_string()))?
        .to_string();

    let env = ctx.env;
    let db = env.d1("DB")?;
    let auth = match crate::auth::authenticate(&req, &db).await {
        Ok(a) => a,
        Err(e) => return e.to_response(),
    };
    if let Err(e) = crate::rate_limit::enforce_write_rate_limit(&env, &auth.app_id, &auth.user_id, "image.report").await {
        return e.to_response();
    }

    let reason = req.json::<ReportImageRequest>().await.ok().and_then(|r| r.reason);

    let exists = db
        .prepare("SELECT id FROM stored_images WHERE app_id = ?1 AND id = ?2")
        .bind(&[auth.app_id.clone().into(), image_id.clone().into()])?
        .first::<serde_json::Value>(None)
        .await?;
    if exists.is_none() {
        return AppError::NotFound(format!("Image {} not found", image_id)).to_response();
    }

    db.prepare(
        "INSERT OR IGNORE INTO image_reports (id, app_id, image_id, reporter_user_id, reason, created_at)
         VALUES (?1, ?2, ?3, ?4, ?5, datetime('now'))",
    )
    .bind(&[
        uuid::Uuid::new_v4().to_string().into(),
        auth.app_id.clone().into(),
        image_id.clone().into(),
        auth.user_id.clone().into(),
        reason.unwrap_or_default().into(),
    ])?
    .run()
    .await?;

    Response::from_json(&json!({ "reported": true, "image_id": image_id }))
}

#[derive(Debug, Deserialize)]
struct VisibilityRequest {
    is_public: bool,
}

/// Permanently delete one of the caller's own images: removes the R2 object, any
/// reports filed against it, and the database row. Scoped to the authenticated
/// user, so a caller can only ever delete their own image. Returns 404 for a
/// missing image OR one owned by someone else, so ownership is never disclosed.
pub async fn delete_image(req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let image_id = ctx.param("image_id")
        .ok_or_else(|| AppError::BadRequest("Missing image_id parameter".to_string()))?
        .to_string();

    let env = ctx.env;
    let db = env.d1("DB")?;
    let auth = match crate::auth::authenticate(&req, &db).await {
        Ok(a) => a,
        Err(e) => return e.to_response(),
    };
    if let Err(e) = crate::rate_limit::enforce_write_rate_limit(&env, &auth.app_id, &auth.user_id, "image.delete").await {
        return e.to_response();
    }

    let row = db
        .prepare("SELECT user_id, r2_key FROM stored_images WHERE app_id = ?1 AND id = ?2")
        .bind(&[auth.app_id.clone().into(), image_id.clone().into()])?
        .first::<serde_json::Value>(None)
        .await?;

    let row = match row {
        Some(r) if r.get("user_id").and_then(|v| v.as_str()) == Some(auth.user_id.as_str()) => r,
        _ => return AppError::NotFound(format!("Image {} not found", image_id)).to_response(),
    };

    if let Some(r2_key) = row.get("r2_key").and_then(|v| v.as_str()) {
        if let Ok(bucket) = env.bucket("IMAGES") {
            if let Err(e) = bucket.delete(r2_key).await {
                crate::log_error!("Failed to delete image from R2", json!({
                    "error": e.to_string(),
                    "r2_key": r2_key,
                }));
            }
        }
    }

    db.prepare("DELETE FROM image_reports WHERE app_id = ?1 AND image_id = ?2")
        .bind(&[auth.app_id.clone().into(), image_id.clone().into()])?
        .run()
        .await?;

    db.prepare("DELETE FROM stored_images WHERE app_id = ?1 AND id = ?2 AND user_id = ?3")
        .bind(&[auth.app_id.clone().into(), image_id.clone().into(), auth.user_id.clone().into()])?
        .run()
        .await?;

    Response::from_json(&json!({ "deleted": true, "image_id": image_id }))
}

/// Toggle whether one of the caller's own images appears in the public gallery
/// feed, without deleting it. Owner-scoped; 404 if missing or not owned.
pub async fn set_image_visibility(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let image_id = ctx.param("image_id")
        .ok_or_else(|| AppError::BadRequest("Missing image_id parameter".to_string()))?
        .to_string();

    let env = ctx.env;
    let db = env.d1("DB")?;
    let auth = match crate::auth::authenticate(&req, &db).await {
        Ok(a) => a,
        Err(e) => return e.to_response(),
    };
    if let Err(e) = crate::rate_limit::enforce_write_rate_limit(&env, &auth.app_id, &auth.user_id, "image.visibility").await {
        return e.to_response();
    }

    let body = match req.json::<VisibilityRequest>().await {
        Ok(b) => b,
        Err(e) => return AppError::BadRequest(format!("Invalid request body: {}", e)).to_response(),
    };
    let is_public: i32 = if body.is_public { 1 } else { 0 };

    let result = db
        .prepare("UPDATE stored_images SET is_public = ?1 WHERE app_id = ?2 AND id = ?3 AND user_id = ?4")
        .bind(&[
            is_public.into(),
            auth.app_id.clone().into(),
            image_id.clone().into(),
            auth.user_id.clone().into(),
        ])?
        .run()
        .await?;

    let changed = result.meta().ok().flatten().and_then(|m| m.changes).unwrap_or(0) > 0;
    if !changed {
        return AppError::NotFound(format!("Image {} not found", image_id)).to_response();
    }

    Response::from_json(&json!({ "image_id": image_id, "is_public": body.is_public }))
}

/// Bulk-set the public/private flag on every image the caller owns. Backs the
/// "also hide my existing creations" action when a user opts out of the public
/// gallery. Owner-scoped.
pub async fn set_all_visibility(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let env = ctx.env;
    let db = env.d1("DB")?;
    let auth = match crate::auth::authenticate(&req, &db).await {
        Ok(a) => a,
        Err(e) => return e.to_response(),
    };
    if let Err(e) = crate::rate_limit::enforce_write_rate_limit(&env, &auth.app_id, &auth.user_id, "image.visibility").await {
        return e.to_response();
    }

    let body = match req.json::<VisibilityRequest>().await {
        Ok(b) => b,
        Err(e) => return AppError::BadRequest(format!("Invalid request body: {}", e)).to_response(),
    };
    let is_public: i32 = if body.is_public { 1 } else { 0 };

    let result = db
        .prepare("UPDATE stored_images SET is_public = ?1 WHERE app_id = ?2 AND user_id = ?3")
        .bind(&[is_public.into(), auth.app_id.clone().into(), auth.user_id.clone().into()])?
        .run()
        .await?;

    let updated = result.meta().ok().flatten().and_then(|m| m.changes).unwrap_or(0);
    Response::from_json(&json!({ "updated": updated, "is_public": body.is_public }))
}