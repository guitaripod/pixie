use worker::{Request, Response, RouteContext, Result};
use crate::models::{ImageGenerationRequest, ImageEditRequest, ImageResponse, ImageData, UsageRecord, ErrorResponse, ErrorDetail};
use crate::error::AppError;
use crate::auth::validate_api_key;
use crate::storage::store_image_from_bytes;
use crate::credits::{check_and_reserve_credits, deduct_credits};
use crate::rate_limit::{check_and_acquire_lock, release_lock};
use crate::providers::{self, UnifiedImageRequest, UnifiedEditRequest};
use crate::{log_debug, log_error};
use serde_json::json;
use uuid::Uuid;
use chrono::Utc;
use base64::{Engine as _, engine::general_purpose::STANDARD as BASE64};

pub async fn handle_generation(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let start_time = worker::Date::now().as_millis();
    let env = ctx.env;
    
    let user_id = match validate_api_key(&req) {
        Err(e) => return e.to_response(),
        Ok(api_key) => {
            let db = env.d1("DB")?;
            let stmt = db.prepare("SELECT id, preferred_model, openai_api_key, gemini_api_key FROM users WHERE api_key = ?");
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

    if generation_req.stream {
        return AppError::BadRequest("Streaming is not supported yet".to_string()).to_response();
    }
    
    let db = env.d1("DB")?;
    
    if let Err(_) = check_and_acquire_lock(&user_id, &db).await {
        return Ok(Response::error("Another request is already in progress", 429)?);
    }
    
    let provider = match providers::get_provider(&generation_req.model, &env) {
        Ok(p) => p,
        Err(e) => {
            let _ = release_lock(&user_id, &db).await;
            return Err(e);
        }
    };

    let unified_request = UnifiedImageRequest {
        prompt: generation_req.prompt.clone(),
        model: generation_req.model.clone(),
        n: Some(generation_req.n),
        size: Some(generation_req.size.clone()),
        quality: Some(generation_req.quality.clone()),
        background: Some(generation_req.background.clone()),
        moderation: generation_req.moderation.clone(),
        output_compression: generation_req.output_compression,
        output_format: Some(generation_req.output_format.clone()),
        partial_images: Some(generation_req.partial_images),
        user: generation_req.user.clone(),
        api_key: generation_req.openai_api_key.clone(),
    };

    let cost_estimate = provider.estimate_cost(&unified_request);
    
    if let Err(e) = check_and_reserve_credits(&user_id, cost_estimate.credits, &db).await {
        let _ = release_lock(&user_id, &db).await;
        return AppError::from(e).to_response();
    }

    log_debug!("Sending request to provider", json!({
        "provider": provider.get_name(),
        "model": &generation_req.model,
        "prompt_length": generation_req.prompt.len(),
        "n": generation_req.n,
    }));

    let provider_response = match provider.generate_image(&unified_request).await {
        Ok(resp) => resp,
        Err(e) => {
            let _ = release_lock(&user_id, &db).await;
            
            let error_msg = e.to_string();
            if error_msg.contains("content_policy_violation") || error_msg.contains("moderation") {
                let custom_error = ErrorResponse {
                    error: ErrorDetail {
                        message: "Our AI backend is being a bit too cautious with this image. Nothing wrong on your end - just the underlying service being overly protective. Try a different prompt and you should be good to go!".to_string(),
                        error_type: "moderation_error".to_string(),
                        param: None,
                        code: Some("moderation_blocked".to_string()),
                    }
                };
                return Response::from_json(&custom_error)
                    .map(|r| r.with_status(400));
            }
            
            return Err(e);
        }
    };

    let mut image_data_list = Vec::new();
    let mut r2_keys = Vec::new();
    let mut images_stored = 0;
    
    for (i, image_bytes) in provider_response.images.iter().enumerate() {
        let _base64_string = BASE64.encode(&image_bytes.data);
        
        match store_image_from_bytes(
            &env,
            &user_id,
            &image_bytes.data,
            &generation_req.prompt,
            &generation_req.model,
            &generation_req.size,
            Some(&generation_req.quality),
            provider.get_name(),
        ).await {
            Ok(stored_image) => {
                let db = env.d1("DB")?;
                
                let per_image_credits = cost_estimate.credits / generation_req.n as u32;
                let cost_cents = (cost_estimate.credits as f32 / 3.0) as i32;
                
                let stmt = db.prepare(
                    "INSERT INTO stored_images (id, user_id, r2_key, prompt, provider, model, size, quality, created_at, expires_at, cost_cents, credits_charged) 
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
                );
                
                let _ = stmt
                    .bind(&[
                        stored_image.id.clone().into(),
                        stored_image.user_id.clone().into(),
                        stored_image.r2_key.clone().into(),
                        stored_image.prompt.clone().into(),
                        provider.get_name().into(),
                        stored_image.model.clone().into(),
                        stored_image.size.clone().into(),
                        generation_req.quality.clone().into(),
                        stored_image.created_at.to_rfc3339().into(),
                        stored_image.expires_at.to_rfc3339().into(),
                        cost_cents.into(),
                        per_image_credits.into(),
                    ])?
                    .run()
                    .await?;
                
                r2_keys.push(stored_image.r2_key.clone());
                
                let revised_prompt = provider_response.revised_prompts
                    .get(i)
                    .and_then(|p| p.clone());
                
                image_data_list.push(ImageData {
                    b64_json: None,
                    url: Some(stored_image.url.clone()),
                    revised_prompt,
                });
                
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
    
    if images_stored > 0 {
        let actual_credits_to_charge = (cost_estimate.credits * images_stored) / generation_req.n as u32;
        let description = format!("Generated {} image(s) using {}", images_stored, generation_req.model);
        
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
        }
    }

    let response_time_ms = (worker::Date::now().as_millis() - start_time) as u32;
    let usage = provider_response.usage.as_ref();
    
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
        "INSERT INTO usage_records (id, user_id, request_type, provider, model, prompt, image_size, image_quality, 
         image_count, input_images_count, total_tokens, input_tokens, output_tokens, text_tokens, 
         image_tokens, r2_keys, response_time_ms, simplified_cost, error, created_at) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    );
    
    let simplified_cost = provider.get_name() == "gemini";
    
    let _ = stmt
        .bind(&[
            _usage_record.id.into(),
            _usage_record.user_id.into(),
            _usage_record.request_type.into(),
            provider.get_name().into(),
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
            simplified_cost.into(),
            worker::wasm_bindgen::JsValue::NULL,
            _usage_record.created_at.to_rfc3339().into(),
        ])?
        .run()
        .await?;

    let _ = release_lock(&user_id, &db).await;
    
    let response = ImageResponse {
        created: Utc::now().timestamp() as u64,
        data: image_data_list,
        background: if provider.get_name() == "openai" { Some(generation_req.background) } else { None },
        output_format: Some(generation_req.output_format),
        size: Some(generation_req.size),
        quality: if provider.get_name() == "openai" { Some(generation_req.quality) } else { None },
        usage: provider_response.usage,
    };
    
    Response::from_json(&response)
}

pub async fn handle_edit(mut req: Request, ctx: RouteContext<()>) -> Result<Response> {
    let start_time = worker::Date::now().as_millis();
    let env = ctx.env;
    
    let user_id = match validate_api_key(&req) {
        Err(e) => return e.to_response(),
        Ok(api_key) => {
            let db = env.d1("DB")?;
            let stmt = db.prepare("SELECT id, preferred_model, openai_api_key, gemini_api_key FROM users WHERE api_key = ?");
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

    if edit_req.stream {
        return AppError::BadRequest("Streaming is not supported yet".to_string()).to_response();
    }
    
    let db = env.d1("DB")?;
    
    if let Err(_) = check_and_acquire_lock(&user_id, &db).await {
        return Ok(Response::error("Another request is already in progress", 429)?);
    }
    
    let provider = match providers::get_provider(&edit_req.model, &env) {
        Ok(p) => p,
        Err(e) => {
            let _ = release_lock(&user_id, &db).await;
            return Err(e);
        }
    };

    if !provider.get_supported_features().supports_edit {
        let _ = release_lock(&user_id, &db).await;
        return AppError::BadRequest(format!("Model {} does not support image editing", edit_req.model)).to_response();
    }

    let unified_request = UnifiedEditRequest {
        image: edit_req.image.clone(),
        prompt: edit_req.prompt.clone(),
        mask: edit_req.mask.clone(),
        model: edit_req.model.clone(),
        n: Some(edit_req.n),
        size: Some(edit_req.size.clone()),
        quality: Some(edit_req.quality.clone()),
        background: Some(edit_req.background.clone()),
        input_fidelity: Some(edit_req.input_fidelity.clone()),
        output_compression: edit_req.output_compression,
        output_format: Some(edit_req.output_format.clone()),
        partial_images: Some(edit_req.partial_images),
        user: edit_req.user.clone(),
        api_key: edit_req.openai_api_key.clone(),
    };

    let cost_estimate = provider.estimate_edit_cost(&unified_request);
    
    if let Err(e) = check_and_reserve_credits(&user_id, cost_estimate.credits, &db).await {
        let _ = release_lock(&user_id, &db).await;
        return AppError::from(e).to_response();
    }

    log_debug!("Sending edit request to provider", json!({
        "provider": provider.get_name(),
        "model": &edit_req.model,
        "prompt_length": edit_req.prompt.len(),
        "n": edit_req.n,
    }));

    let provider_response = match provider.edit_image(&unified_request).await {
        Ok(resp) => resp,
        Err(e) => {
            let _ = release_lock(&user_id, &db).await;
            
            let error_msg = e.to_string();
            if error_msg.contains("content_policy_violation") || error_msg.contains("moderation") {
                let custom_error = ErrorResponse {
                    error: ErrorDetail {
                        message: "Our AI backend is being a bit too cautious with this image. Nothing wrong on your end - just the underlying service being overly protective. Try a different image and you should be good to go!".to_string(),
                        error_type: "moderation_error".to_string(),
                        param: None,
                        code: Some("moderation_blocked".to_string()),
                    }
                };
                return Response::from_json(&custom_error)
                    .map(|r| r.with_status(400));
            }
            
            return Err(e);
        }
    };

    let mut image_data_list = Vec::new();
    let mut r2_keys = Vec::new();
    let mut images_stored = 0;
    
    for (i, image_bytes) in provider_response.images.iter().enumerate() {
        match store_image_from_bytes(
            &env,
            &user_id,
            &image_bytes.data,
            &edit_req.prompt,
            &edit_req.model,
            &edit_req.size,
            Some(&edit_req.quality),
            provider.get_name(),
        ).await {
            Ok(stored_image) => {
                let db = env.d1("DB")?;
                
                let per_image_credits = cost_estimate.credits / edit_req.n as u32;
                let cost_cents = (cost_estimate.credits as f32 / 3.0) as i32;
                
                let stmt = db.prepare(
                    "INSERT INTO stored_images (id, user_id, r2_key, prompt, provider, model, size, quality, created_at, expires_at, cost_cents, credits_charged) 
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
                );
                
                let _ = stmt
                    .bind(&[
                        stored_image.id.clone().into(),
                        stored_image.user_id.clone().into(),
                        stored_image.r2_key.clone().into(),
                        stored_image.prompt.clone().into(),
                        provider.get_name().into(),
                        stored_image.model.clone().into(),
                        stored_image.size.clone().into(),
                        edit_req.quality.clone().into(),
                        stored_image.created_at.to_rfc3339().into(),
                        stored_image.expires_at.to_rfc3339().into(),
                        cost_cents.into(),
                        per_image_credits.into(),
                    ])?
                    .run()
                    .await?;
                
                r2_keys.push(stored_image.r2_key.clone());
                
                let revised_prompt = provider_response.revised_prompts
                    .get(i)
                    .and_then(|p| p.clone());
                
                image_data_list.push(ImageData {
                    b64_json: None,
                    url: Some(stored_image.url.clone()),
                    revised_prompt,
                });
                
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
    
    if images_stored > 0 {
        let actual_credits_to_charge = (cost_estimate.credits * images_stored) / edit_req.n as u32;
        let description = format!("Edited {} image(s) using {}", images_stored, edit_req.model);
        
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
        }
    }

    let response_time_ms = (worker::Date::now().as_millis() - start_time) as u32;
    let usage = provider_response.usage.as_ref();
    
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
        "INSERT INTO usage_records (id, user_id, request_type, provider, model, prompt, image_size, image_quality, 
         image_count, input_images_count, total_tokens, input_tokens, output_tokens, text_tokens, 
         image_tokens, r2_keys, response_time_ms, simplified_cost, error, created_at) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    );
    
    let simplified_cost = provider.get_name() == "gemini";
    
    let _ = stmt
        .bind(&[
            _usage_record.id.into(),
            _usage_record.user_id.into(),
            _usage_record.request_type.into(),
            provider.get_name().into(),
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
            simplified_cost.into(),
            worker::wasm_bindgen::JsValue::NULL,
            _usage_record.created_at.to_rfc3339().into(),
        ])?
        .run()
        .await?;

    let _ = release_lock(&user_id, &db).await;
    
    let response = ImageResponse {
        created: Utc::now().timestamp() as u64,
        data: image_data_list,
        background: if provider.get_name() == "openai" { Some(edit_req.background) } else { None },
        output_format: Some(edit_req.output_format),
        size: Some(edit_req.size),
        quality: if provider.get_name() == "openai" { Some(edit_req.quality) } else { None },
        usage: provider_response.usage,
    };
    
    Response::from_json(&response)
}