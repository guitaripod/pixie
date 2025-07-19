use worker::{Request, Response, RouteContext, Result, Headers};
use crate::error::AppError;

pub async fn serve_image(_req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let user_id = ctx.param("user_id")
        .ok_or_else(|| AppError::BadRequest("Missing user_id parameter".to_string()))?
        .to_string();
    let image_id = ctx.param("image_id")
        .ok_or_else(|| AppError::BadRequest("Missing image_id parameter".to_string()))?
        .to_string();
    
    let env = ctx.env;
    
    let r2_key = format!("{}/{}", user_id, image_id);
    let r2 = env.bucket("IMAGES")
        .map_err(|e| AppError::InternalError(format!("Failed to get R2 bucket: {}", e)))?;
    
    let object = r2.get(&r2_key)
        .execute()
        .await
        .map_err(|e| AppError::InternalError(format!("Failed to get image from R2: {}", e)))?;
    
    match object {
        Some(object) => {
            let body = object.body()
                .ok_or_else(|| AppError::InternalError("Image has no body".to_string()))?;
            
            let bytes = body.bytes().await
                .map_err(|e| AppError::InternalError(format!("Failed to read image bytes: {}", e)))?;
            
            let headers = Headers::new();
            headers.set("Content-Type", "image/png")?;
            headers.set("Cache-Control", "public, max-age=86400")?;
            
            Ok(Response::from_bytes(bytes)?.with_headers(headers))
        }
        None => {
            AppError::NotFound(format!("Image not found: {}", r2_key)).to_response()
        }
    }
}