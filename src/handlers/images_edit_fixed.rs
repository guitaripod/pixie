// This is a fixed version of the edit handler that properly converts to multipart/form-data

use worker::*;
use serde_json;
use uuid::Uuid;
use chrono::Utc;
use base64::{Engine as _, engine::general_purpose};

pub async fn handle_edit_fixed(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let start_time = worker::Date::now().as_millis();
    let env = ctx.env;
    
    // Validate API key and get user_id
    let user_id = match validate_api_key(&req) {
        Err(e) => return e.to_response(),
        Ok(api_key) => {
            let db = env.d1("DB")?;
            let stmt = db.prepare("SELECT id FROM users WHERE api_key = ?");
            let result = stmt
                .bind(&[api_key.clone().into()])?
                .first::<serde_json::Value>(None)
                .await?;
            
            match result {
                Some(value) => value.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string(),
                None => return AppError::Unauthorized("Invalid API key".to_string()).to_response(),
            }
        }
    };

    // Parse the JSON request
    let edit_req: ImageEditRequest = match req.json().await {
        Ok(req) => req,
        Err(e) => return AppError::BadRequest(format!("Invalid request body: {}", e)).to_response(),
    };

    if edit_req.model != "gpt-image-1" {
        return AppError::BadRequest(format!("Only gpt-image-1 model is supported, got: {}", edit_req.model)).to_response();
    }

    if edit_req.stream {
        return AppError::BadRequest("Streaming is not supported yet".to_string()).to_response();
    }

    // Get deployment configuration
    let deployment_config = match DeploymentConfig::from_env(&env) {
        Ok(config) => config,
        Err(e) => return e.to_response(),
    };

    // Get OpenAI API key
    let openai_key = match get_openai_key(&env, &deployment_config, edit_req.openai_api_key.clone()) {
        Ok(key) => key,
        Err(e) => return e.to_response(),
    };

    // Build multipart form data
    let openai_url = "https://api.openai.com/v1/images/edits";
    
    // Create FormData
    let form_data = web_sys::FormData::new()?;
    
    // Add text fields
    form_data.append_with_str("prompt", &edit_req.prompt)?;
    form_data.append_with_str("model", &edit_req.model)?;
    form_data.append_with_str("n", &edit_req.n.to_string())?;
    form_data.append_with_str("size", &edit_req.size)?;
    form_data.append_with_str("quality", &edit_req.quality)?;
    form_data.append_with_str("background", &edit_req.background)?;
    form_data.append_with_str("input_fidelity", &edit_req.input_fidelity)?;
    form_data.append_with_str("output_format", &edit_req.output_format)?;
    
    if let Some(compression) = edit_req.output_compression {
        form_data.append_with_str("output_compression", &compression.to_string())?;
    }
    
    form_data.append_with_str("partial_images", &edit_req.partial_images.to_string())?;
    form_data.append_with_str("stream", &edit_req.stream.to_string())?;
    
    if let Some(user) = &edit_req.user {
        form_data.append_with_str("user", user)?;
    }
    
    // Process images - convert from data URLs to blobs
    for (index, image_data_url) in edit_req.image.iter().enumerate() {
        // Extract base64 data from data URL
        let base64_data = if image_data_url.starts_with("data:") {
            // Parse data URL: data:image/png;base64,<data>
            image_data_url
                .split(',')
                .nth(1)
                .ok_or_else(|| Error::RustError("Invalid data URL format".to_string()))?
        } else {
            // Assume it's already base64
            image_data_url
        };
        
        // Decode base64 to bytes
        let image_bytes = general_purpose::STANDARD
            .decode(base64_data)
            .map_err(|e| Error::RustError(format!("Failed to decode base64: {}", e)))?;
        
        // Create a Blob from the bytes
        let uint8_array = js_sys::Uint8Array::from(&image_bytes[..]);
        let blob_parts = js_sys::Array::new();
        blob_parts.push(&uint8_array.into());
        
        let blob_options = web_sys::BlobPropertyBag::new();
        blob_options.set_type("image/png");
        
        let blob = web_sys::Blob::new_with_u8_array_sequence_and_options(
            &blob_parts,
            &blob_options
        )?;
        
        // Append to form with array notation for multiple images
        form_data.append_with_blob_and_filename(
            &format!("image[{}]", index),
            &blob,
            &format!("image_{}.png", index)
        )?;
    }
    
    // Process mask if provided
    if let Some(mask_data_url) = &edit_req.mask {
        let base64_data = if mask_data_url.starts_with("data:") {
            mask_data_url
                .split(',')
                .nth(1)
                .ok_or_else(|| Error::RustError("Invalid mask data URL format".to_string()))?
        } else {
            mask_data_url
        };
        
        let mask_bytes = general_purpose::STANDARD
            .decode(base64_data)
            .map_err(|e| Error::RustError(format!("Failed to decode mask base64: {}", e)))?;
        
        let uint8_array = js_sys::Uint8Array::from(&mask_bytes[..]);
        let blob_parts = js_sys::Array::new();
        blob_parts.push(&uint8_array.into());
        
        let blob_options = web_sys::BlobPropertyBag::new();
        blob_options.set_type("image/png");
        
        let blob = web_sys::Blob::new_with_u8_array_sequence_and_options(
            &blob_parts,
            &blob_options
        )?;
        
        form_data.append_with_blob_and_filename("mask", &blob, "mask.png")?;
    }
    
    // Create request with multipart/form-data
    let headers = worker::Headers::new();
    headers.set("Authorization", &format!("Bearer {}", openai_key))?;
    // Don't set Content-Type - let the browser set it with boundary
    
    console_log!("Sending edit request to OpenAI (multipart/form-data)");
    
    let openai_req = worker::Request::new_with_init(
        openai_url,
        worker::RequestInit::new()
            .with_method(worker::Method::Post)
            .with_headers(headers)
            .with_body(Some(wasm_bindgen::JsValue::from(form_data)))
    )?;

    let mut openai_resp = worker::Fetch::Request(openai_req).send().await?;
    let resp_body = openai_resp.text().await?;
    
    console_log!("OpenAI response status: {}", openai_resp.status_code());

    // Parse response
    let mut image_response: ImageResponse = match serde_json::from_str(&resp_body) {
        Ok(resp) => resp,
        Err(_) => {
            // Return error response as-is
            let mut response = Response::from_bytes(resp_body.into_bytes())?;
            response.headers_mut().set("Content-Type", "application/json")?;
            return Ok(response.with_status(openai_resp.status_code()));
        }
    };

    // Store images in R2 and update response
    let mut r2_keys = Vec::new();
    for image_data in &mut image_response.data {
        if let Some(base64_data) = &image_data.b64_json {
            match store_image_in_r2(
                &env,
                &user_id,
                base64_data,
                &edit_req.prompt,
                &edit_req.model,
                &edit_req.size,
                Some(&edit_req.quality),
            ).await {
                Ok(stored_image) => {
                    // Store in database
                    let db = env.d1("DB")?;
                    let stmt = db.prepare(
                        "INSERT INTO stored_images (id, user_id, r2_key, prompt, model, size, quality, created_at, expires_at, token_usage) 
                         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
                    );
                    
                    let _ = stmt
                        .bind(&[
                            stored_image.id.clone().into(),
                            stored_image.user_id.clone().into(),
                            stored_image.r2_key.clone().into(),
                            stored_image.prompt.clone().into(),
                            stored_image.model.clone().into(),
                            stored_image.size.clone().into(),
                            stored_image.quality.clone().unwrap_or_default().into(),
                            stored_image.created_at.to_rfc3339().into(),
                            stored_image.expires_at.to_rfc3339().into(),
                            0.into(),
                        ])?
                        .run()
                        .await?;
                    
                    r2_keys.push(stored_image.r2_key.clone());
                    image_data.url = Some(stored_image.url);
                    image_data.b64_json = None;
                }
                Err(e) => {
                    console_log!("Failed to store image in R2: {:?}", e);
                }
            }
        }
    }

    // Record usage
    let response_time_ms = (worker::Date::now().as_millis() - start_time) as u32;
    let usage = image_response.usage.as_ref();
    
    let _usage_record = UsageRecord {
        id: Uuid::new_v4().to_string(),
        user_id: user_id.clone(),
        endpoint: "/v1/images/edits".to_string(),
        request_type: "edit".to_string(),
        token_usage: usage.and_then(|u| u.total_tokens).unwrap_or(0) as i32,
        images_generated: image_response.data.len() as i32,
        created_at: Utc::now(),
        response_time_ms,
        error: None,
    };

    // Record usage in database
    let db = env.d1("DB")?;
    let stmt = db.prepare(
        "INSERT INTO usage_records (id, user_id, endpoint, request_type, token_usage, images_generated, created_at, response_time_ms) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
    );
    
    let _ = stmt
        .bind(&[
            _usage_record.id.into(),
            _usage_record.user_id.into(),
            _usage_record.endpoint.into(),
            _usage_record.request_type.into(),
            _usage_record.token_usage.into(),
            _usage_record.images_generated.into(),
            _usage_record.created_at.to_rfc3339().into(),
            _usage_record.response_time_ms.into(),
        ])?
        .run()
        .await?;

    Response::from_json(&image_response)
}