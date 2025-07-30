use worker::{Request, Response, RouteContext, Result};
use crate::models::{ImageGenerationRequest, ImageEditRequest, ImageResponse, UsageRecord, ErrorResponse, ErrorDetail};
use crate::error::AppError;
use crate::auth::validate_api_key;
use crate::storage::store_image_in_r2;
use crate::deployment::{DeploymentConfig, get_openai_key};
use crate::credits::{check_and_reserve_credits, deduct_credits, calculate_openai_cost_usd, calculate_credits_from_cost, estimate_image_cost};
use crate::rate_limit::{check_and_acquire_lock, release_lock};
use crate::{log_debug, log_error, log_info};
use serde_json::json;
use uuid::Uuid;
use chrono::Utc;

pub async fn handle_generation(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let start_time = worker::Date::now().as_millis();
    let env = ctx.env;
    
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

    let generation_req: ImageGenerationRequest = match req.json().await {
        Ok(req) => req,
        Err(e) => return AppError::BadRequest(format!("Invalid request body: {}", e)).to_response(),
    };

    if generation_req.model != "gpt-image-1" {
        return AppError::BadRequest(format!("Only gpt-image-1 model is supported, got: {}", generation_req.model)).to_response();
    }

    if generation_req.stream {
        return AppError::BadRequest("Streaming is not supported yet".to_string()).to_response();
    }
    
    let db = env.d1("DB")?;
    
    // Acquire per-user lock to prevent concurrent requests
    if let Err(_) = check_and_acquire_lock(&user_id, &db).await {
        return Ok(Response::error("Another request is already in progress", 429)?);
    }
    
    // Estimate credit cost and check balance
    let estimated_credits = estimate_image_cost(
        &generation_req.quality, 
        &generation_req.size,
        false
    ) * generation_req.n as u32;
    
    if let Err(e) = check_and_reserve_credits(&user_id, estimated_credits, &db).await {
        let _ = release_lock(&user_id, &db).await;
        return AppError::from(e).to_response();
    }

    let deployment_config = match DeploymentConfig::from_env(&env) {
        Ok(config) => config,
        Err(e) => {
            let _ = release_lock(&user_id, &db).await;
            return e.to_response();
        }
    };

    let openai_key = match get_openai_key(&env, &deployment_config, generation_req.openai_api_key.clone()) {
        Ok(key) => key,
        Err(e) => {
            let _ = release_lock(&user_id, &db).await;
            return e.to_response();
        }
    };
    let openai_url = "https://api.openai.com/v1/images/generations";
    let headers = worker::Headers::new();
    headers.set("Authorization", &format!("Bearer {}", openai_key))?;
    headers.set("Content-Type", "application/json")?;

    let request_body = serde_json::json!({
        "model": "gpt-image-1",
        "prompt": generation_req.prompt,
        "n": generation_req.n,
        "size": generation_req.size,
        "quality": generation_req.quality,
        "background": generation_req.background,
        "output_format": generation_req.output_format,
        "output_compression": generation_req.output_compression,
        "moderation": generation_req.moderation,
        "partial_images": generation_req.partial_images,
        "stream": false,
        "user": generation_req.user,
    });

    log_debug!("Sending request to OpenAI", json!({
        "model": "gpt-image-1",
        "prompt_length": generation_req.prompt.len(),
        "n": generation_req.n,
        "size": &generation_req.size,
        "quality": &generation_req.quality
    }));

    let openai_req = worker::Request::new_with_init(
        openai_url,
        worker::RequestInit::new()
            .with_method(worker::Method::Post)
            .with_headers(headers)
            .with_body(Some(worker::wasm_bindgen::JsValue::from_str(&request_body.to_string())))
    )?;

    let mut openai_resp = worker::Fetch::Request(openai_req).send().await?;
    let resp_body = openai_resp.text().await?;
    
    let mut image_response: ImageResponse = match serde_json::from_str(&resp_body) {
        Ok(resp) => resp,
        Err(_) => {
            // Check if it's a moderation error
            if let Ok(error_resp) = serde_json::from_str::<ErrorResponse>(&resp_body) {
                if error_resp.error.code.as_deref() == Some("moderation_blocked") {
                    let custom_error = ErrorResponse {
                        error: ErrorDetail {
                            message: "Our AI backend is being a bit too cautious with this image. Nothing wrong on your end - just the underlying service being overly protective. Try a different image and you should be good to go!".to_string(),
                            error_type: error_resp.error.error_type,
                            param: error_resp.error.param,
                            code: error_resp.error.code,
                        }
                    };
                    let _ = release_lock(&user_id, &db).await;
                    return Response::from_json(&custom_error)
                        .map(|r| r.with_status(openai_resp.status_code()));
                }
            }
            
            let mut response = Response::from_bytes(resp_body.into_bytes())?;
            response.headers_mut().set("Content-Type", "application/json")?;
            let _ = release_lock(&user_id, &db).await;
            return Ok(response.with_status(openai_resp.status_code()));
        }
    };

    // Calculate actual credit cost based on usage
    let actual_cost_usd = if let Some(usage) = &image_response.usage {
        calculate_openai_cost_usd(usage)
    } else {
        // Fallback estimate
        0.05
    };
    let credits_to_charge = calculate_credits_from_cost(actual_cost_usd);
    let openai_cost_cents = (actual_cost_usd * 100.0) as i32;
    
    let mut r2_keys = Vec::new();
    let mut images_stored = 0;
    
    for image_data in &mut image_response.data {
        if let Some(base64_data) = &image_data.b64_json {
            match store_image_in_r2(
                &env,
                &user_id,
                base64_data,
                &generation_req.prompt,
                &generation_req.model,
                &image_response.size.as_deref().unwrap_or(&generation_req.size),
                image_response.quality.as_deref(),
            ).await {
                Ok(stored_image) => {
                    let db = env.d1("DB")?;
                    
                    // Calculate per-image credit cost
                    let per_image_credits = credits_to_charge / generation_req.n as u32;
                    let per_image_cost_cents = openai_cost_cents / generation_req.n as i32;
                    
                    let stmt = db.prepare(
                        "INSERT INTO stored_images (id, user_id, r2_key, prompt, model, size, quality, created_at, expires_at, token_usage, openai_cost_cents, credits_charged) 
                         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
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
                            image_response.usage.as_ref().map(|u| u.total_tokens).unwrap_or(0).into(),
                            per_image_cost_cents.into(),
                            per_image_credits.into(),
                        ])?
                        .run()
                        .await?;
                    
                    r2_keys.push(stored_image.r2_key.clone());
                    image_data.url = Some(stored_image.url.clone());
                    image_data.b64_json = None;
                    images_stored += 1;
                }
                Err(e) => {
                    log_error!("Failed to store image in R2", json!({
                        "error": e.to_string(),
                        "user_id": &user_id,
                        "prompt": &generation_req.prompt
                    }));
                }
            }
        }
    }
    
    // Only deduct credits for successfully stored images
    if images_stored > 0 {
        let actual_credits_to_charge = (credits_to_charge * images_stored) / generation_req.n as u32;
        let description = format!("Generated {} image(s) - {}, {}", images_stored, generation_req.quality, generation_req.size);
        
        if let Err(e) = deduct_credits(
            &user_id,
            actual_credits_to_charge,
            &description,
            &r2_keys.join(","),
            &db
        ).await {
            log_error!("Failed to deduct credits", json!({
                "error": e.to_string(),
                "user_id": &user_id,
                "credits": actual_credits_to_charge,
                "images_stored": images_stored
            }));
            // Credits couldn't be deducted but images are already stored
            // This is logged but we don't fail the request
        }
    }

    let response_time_ms = (worker::Date::now().as_millis() - start_time) as u32;
    let usage = image_response.usage.as_ref();
    
    let _usage_record = UsageRecord {
        id: Uuid::new_v4().to_string(),
        user_id: user_id.clone(),
        request_type: "generation".to_string(),
        model: generation_req.model.clone(),
        prompt: generation_req.prompt.clone(),
        image_size: generation_req.size.clone(),
        image_quality: generation_req.quality.clone(),
        image_count: generation_req.n,
        input_images_count: None,
        total_tokens: usage.map(|u| u.total_tokens).unwrap_or(0),
        input_tokens: usage.map(|u| u.input_tokens).unwrap_or(0),
        output_tokens: usage.map(|u| u.output_tokens).unwrap_or(0),
        text_tokens: usage.map(|u| u.input_tokens_details.text_tokens).unwrap_or(0),
        image_tokens: usage.map(|u| u.input_tokens_details.image_tokens).unwrap_or(0),
        r2_keys,
        response_time_ms,
        error: None,
        created_at: Utc::now(),
    };

    let db = env.d1("DB")?;
    let stmt = db.prepare(
        "INSERT INTO usage_records (id, user_id, request_type, model, prompt, image_size, image_quality, 
         image_count, input_images_count, total_tokens, input_tokens, output_tokens, text_tokens, 
         image_tokens, r2_keys, response_time_ms, error, created_at) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    );
    
    let _ = stmt
        .bind(&[
            _usage_record.id.into(),
            _usage_record.user_id.into(),
            _usage_record.request_type.into(),
            _usage_record.model.into(),
            _usage_record.prompt.into(),
            _usage_record.image_size.into(),
            _usage_record.image_quality.into(),
            _usage_record.image_count.into(),
            _usage_record.input_images_count.map(|n| n.into()).unwrap_or(worker::wasm_bindgen::JsValue::NULL),
            _usage_record.total_tokens.into(),
            _usage_record.input_tokens.into(),
            _usage_record.output_tokens.into(),
            _usage_record.text_tokens.into(),
            _usage_record.image_tokens.into(),
            serde_json::to_string(&_usage_record.r2_keys).unwrap().into(),
            _usage_record.response_time_ms.into(),
            worker::wasm_bindgen::JsValue::NULL,
            _usage_record.created_at.to_rfc3339().into(),
        ])?
        .run()
        .await?;

    let _ = release_lock(&user_id, &db).await;
    Response::from_json(&image_response)
}

pub async fn handle_edit(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let start_time = worker::Date::now().as_millis();
    let env = ctx.env;
    
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
    
    let db = env.d1("DB")?;
    
    // Acquire per-user lock to prevent concurrent requests
    if let Err(_) = check_and_acquire_lock(&user_id, &db).await {
        return Ok(Response::error("Another request is already in progress", 429)?);
    }
    
    // Estimate credit cost for edit operation and check balance
    let estimated_credits = estimate_image_cost(
        &edit_req.quality, 
        &edit_req.size,
        true // is_edit
    ) * edit_req.n as u32;
    
    if let Err(e) = check_and_reserve_credits(&user_id, estimated_credits, &db).await {
        let _ = release_lock(&user_id, &db).await;
        return AppError::from(e).to_response();
    }

    let deployment_config = match DeploymentConfig::from_env(&env) {
        Ok(config) => config,
        Err(e) => {
            let _ = release_lock(&user_id, &db).await;
            return e.to_response();
        }
    };

    let openai_key = match get_openai_key(&env, &deployment_config, edit_req.openai_api_key.clone()) {
        Ok(key) => key,
        Err(e) => {
            let _ = release_lock(&user_id, &db).await;
            return e.to_response();
        }
    };

    let boundary = format!("----WebKitFormBoundary{}", uuid::Uuid::new_v4().to_string().replace("-", ""));
    let mut body_parts = Vec::new();
    
    for (i, image_data) in edit_req.image.iter().enumerate() {
        let image_base64 = image_data.trim_start_matches("data:image/png;base64,")
            .trim_start_matches("data:image/jpeg;base64,")
            .trim_start_matches("data:image/jpg;base64,");
        let image_bytes = base64::Engine::decode(&base64::engine::general_purpose::STANDARD, image_base64)
            .map_err(|e| AppError::BadRequest(format!("Invalid base64 image data: {}", e)))?;
        
        // Use image[] for multiple images as per OpenAI docs
        let field_name = if edit_req.image.len() > 1 { "image[]" } else { "image" };
        
        body_parts.push(format!(
            "--{}\r\nContent-Disposition: form-data; name=\"{}\"; filename=\"image{}.png\"\r\nContent-Type: image/png\r\n\r\n",
            boundary, field_name, i
        ).into_bytes());
        body_parts.push(image_bytes);
        body_parts.push(b"\r\n".to_vec());
    }
    
    if let Some(mask_data) = &edit_req.mask {
        let mask_base64 = mask_data.trim_start_matches("data:image/png;base64,")
            .trim_start_matches("data:image/jpeg;base64,")
            .trim_start_matches("data:image/jpg;base64,");
        let mask_bytes = base64::Engine::decode(&base64::engine::general_purpose::STANDARD, mask_base64)
            .map_err(|e| AppError::BadRequest(format!("Invalid base64 mask data: {}", e)))?;
        
        body_parts.push(format!(
            "--{}\r\nContent-Disposition: form-data; name=\"mask\"; filename=\"mask.png\"\r\nContent-Type: image/png\r\n\r\n",
            boundary
        ).into_bytes());
        body_parts.push(mask_bytes);
        body_parts.push(b"\r\n".to_vec());
    }
    
    let n_str = edit_req.n.to_string();
    let text_fields = vec![
        ("prompt", edit_req.prompt.as_str()),
        ("model", edit_req.model.as_str()),
        ("n", n_str.as_str()),
        ("size", edit_req.size.as_str()),
        ("quality", edit_req.quality.as_str()),
        ("background", edit_req.background.as_str()),
        ("input_fidelity", edit_req.input_fidelity.as_str()),
        ("output_format", edit_req.output_format.as_str()),
    ];
    
    for (name, value) in text_fields {
        body_parts.push(format!(
            "--{}\r\nContent-Disposition: form-data; name=\"{}\"\r\n\r\n{}\r\n",
            boundary, name, value
        ).into_bytes());
    }
    
    if let Some(compression) = edit_req.output_compression {
        body_parts.push(format!(
            "--{}\r\nContent-Disposition: form-data; name=\"output_compression\"\r\n\r\n{}\r\n",
            boundary, compression
        ).into_bytes());
    }
    
    body_parts.push(format!(
        "--{}\r\nContent-Disposition: form-data; name=\"partial_images\"\r\n\r\n{}\r\n",
        boundary, edit_req.partial_images
    ).into_bytes());
    
    if let Some(user) = &edit_req.user {
        body_parts.push(format!(
            "--{}\r\nContent-Disposition: form-data; name=\"user\"\r\n\r\n{}\r\n",
            boundary, user
        ).into_bytes());
    }
    
    body_parts.push(format!("--{}--\r\n", boundary).into_bytes());
    
    let body: Vec<u8> = body_parts.into_iter().flatten().collect();
    
    log_debug!("Multipart body prepared", json!({
        "body_size_bytes": body.len(),
        "user_id": &user_id,
        "has_mask": edit_req.mask.is_some()
    }));
    
    let openai_url = "https://api.openai.com/v1/images/edits";
    let headers = worker::Headers::new();
    headers.set("Authorization", &format!("Bearer {}", openai_key))?;
    headers.set("Content-Type", &format!("multipart/form-data; boundary={}", boundary))?;
    
    log_debug!("Sending edit request to OpenAI", json!({
        "prompt": &edit_req.prompt,
        "n": edit_req.n,
        "size": &edit_req.size,
        "quality": &edit_req.quality
    }));
    
    let openai_req = worker::Request::new_with_init(
        openai_url,
        worker::RequestInit::new()
            .with_method(worker::Method::Post)
            .with_headers(headers)
            .with_body(Some(worker::wasm_bindgen::JsValue::from(body)))
    )?;

    let mut openai_resp = worker::Fetch::Request(openai_req).send().await?;
    let resp_body = openai_resp.text().await?;
    
    log_info!("OpenAI edit response received", json!({
        "status_code": openai_resp.status_code(),
        "user_id": &user_id
    }));

    let mut image_response: ImageResponse = match serde_json::from_str(&resp_body) {
        Ok(resp) => resp,
        Err(_) => {
            // Check if it's a moderation error
            if let Ok(error_resp) = serde_json::from_str::<ErrorResponse>(&resp_body) {
                if error_resp.error.code.as_deref() == Some("moderation_blocked") {
                    let custom_error = ErrorResponse {
                        error: ErrorDetail {
                            message: "Our AI backend is being a bit too cautious with this image. Nothing wrong on your end - just the underlying service being overly protective. Try a different image and you should be good to go!".to_string(),
                            error_type: error_resp.error.error_type,
                            param: error_resp.error.param,
                            code: error_resp.error.code,
                        }
                    };
                    let _ = release_lock(&user_id, &db).await;
                    return Response::from_json(&custom_error)
                        .map(|r| r.with_status(openai_resp.status_code()));
                }
            }
            
            let mut response = Response::from_bytes(resp_body.into_bytes())?;
            response.headers_mut().set("Content-Type", "application/json")?;
            let _ = release_lock(&user_id, &db).await;
            return Ok(response.with_status(openai_resp.status_code()));
        }
    };

    // Calculate actual credit cost based on usage
    let actual_cost_usd = if let Some(usage) = &image_response.usage {
        calculate_openai_cost_usd(usage)
    } else {
        // Fallback estimate for edits
        0.08
    };
    let credits_to_charge = calculate_credits_from_cost(actual_cost_usd);
    let openai_cost_cents = (actual_cost_usd * 100.0) as i32;
    
    let mut r2_keys = Vec::new();
    let mut images_stored = 0;
    
    for image_data in &mut image_response.data {
        if let Some(base64_data) = &image_data.b64_json {
            match store_image_in_r2(
                &env,
                &user_id,
                base64_data,
                &edit_req.prompt,
                &edit_req.model,
                &image_response.size.as_deref().unwrap_or(&edit_req.size),
                image_response.quality.as_deref(),
            ).await {
                Ok(stored_image) => {
                    let db = env.d1("DB")?;
                    
                    // Calculate per-image credit cost
                    let per_image_credits = credits_to_charge / edit_req.n as u32;
                    let per_image_cost_cents = openai_cost_cents / edit_req.n as i32;
                    
                    let stmt = db.prepare(
                        "INSERT INTO stored_images (id, user_id, r2_key, prompt, model, size, quality, created_at, expires_at, token_usage, openai_cost_cents, credits_charged) 
                         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
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
                            image_response.usage.as_ref().map(|u| u.total_tokens).unwrap_or(0).into(),
                            per_image_cost_cents.into(),
                            per_image_credits.into(),
                        ])?
                        .run()
                        .await?;
                    
                    r2_keys.push(stored_image.r2_key.clone());
                    image_data.url = Some(stored_image.url.clone());
                    image_data.b64_json = None;
                    images_stored += 1;
                }
                Err(e) => {
                    log_error!("Failed to store image in R2", json!({
                        "error": e.to_string(),
                        "user_id": &user_id,
                        "prompt": &edit_req.prompt
                    }));
                }
            }
        }
    }
    
    // Only deduct credits for successfully stored images
    if images_stored > 0 {
        let actual_credits_to_charge = (credits_to_charge * images_stored) / edit_req.n as u32;
        let description = format!("Edited {} image(s) - {}, {}", images_stored, edit_req.quality, edit_req.size);
        
        if let Err(e) = deduct_credits(
            &user_id,
            actual_credits_to_charge,
            &description,
            &r2_keys.join(","),
            &db
        ).await {
            log_error!("Failed to deduct credits", json!({
                "error": e.to_string(),
                "user_id": &user_id,
                "credits": actual_credits_to_charge,
                "images_stored": images_stored
            }));
            // Credits couldn't be deducted but images are already stored
            // This is logged but we don't fail the request
        }
    }

    let response_time_ms = (worker::Date::now().as_millis() - start_time) as u32;
    let usage = image_response.usage.as_ref();
    
    let _usage_record = UsageRecord {
        id: Uuid::new_v4().to_string(),
        user_id: user_id.clone(),
        request_type: "edit".to_string(),
        model: edit_req.model.clone(),
        prompt: edit_req.prompt.clone(),
        image_size: edit_req.size.clone(),
        image_quality: edit_req.quality.clone(),
        image_count: edit_req.n,
        input_images_count: Some(edit_req.image.len() as u8),
        total_tokens: usage.map(|u| u.total_tokens).unwrap_or(0),
        input_tokens: usage.map(|u| u.input_tokens).unwrap_or(0),
        output_tokens: usage.map(|u| u.output_tokens).unwrap_or(0),
        text_tokens: usage.map(|u| u.input_tokens_details.text_tokens).unwrap_or(0),
        image_tokens: usage.map(|u| u.input_tokens_details.image_tokens).unwrap_or(0),
        r2_keys,
        response_time_ms,
        error: None,
        created_at: Utc::now(),
    };

    let db = env.d1("DB")?;
    let stmt = db.prepare(
        "INSERT INTO usage_records (id, user_id, request_type, model, prompt, image_size, image_quality, 
         image_count, input_images_count, total_tokens, input_tokens, output_tokens, text_tokens, 
         image_tokens, r2_keys, response_time_ms, error, created_at) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    );
    
    let _ = stmt
        .bind(&[
            _usage_record.id.into(),
            _usage_record.user_id.into(),
            _usage_record.request_type.into(),
            _usage_record.model.into(),
            _usage_record.prompt.into(),
            _usage_record.image_size.into(),
            _usage_record.image_quality.into(),
            _usage_record.image_count.into(),
            _usage_record.input_images_count.map(|n| n.into()).unwrap_or(worker::wasm_bindgen::JsValue::NULL),
            _usage_record.total_tokens.into(),
            _usage_record.input_tokens.into(),
            _usage_record.output_tokens.into(),
            _usage_record.text_tokens.into(),
            _usage_record.image_tokens.into(),
            serde_json::to_string(&_usage_record.r2_keys).unwrap().into(),
            _usage_record.response_time_ms.into(),
            worker::wasm_bindgen::JsValue::NULL,
            _usage_record.created_at.to_rfc3339().into(),
        ])?
        .run()
        .await?;

    let _ = release_lock(&user_id, &db).await;
    Response::from_json(&image_response)
}