use async_trait::async_trait;
use serde_json::json;
use worker::{Env, Result, Fetch, Request as WorkerRequest, Method, Headers};
use base64::{Engine as _, engine::general_purpose::STANDARD as BASE64};
use uuid;
use crate::error::AppError;
use crate::deployment::{DeploymentConfig, DeploymentMode};
use crate::credits::estimate_image_cost;
use super::{ImageProvider, UnifiedImageRequest, UnifiedEditRequest, ProviderResponse, ImageBytes, CostEstimate, ProviderFeatures};
use crate::models::ImageResponse;

const OPENAI_API_URL: &str = "https://api.openai.com/v1/images/generations";
const OPENAI_EDIT_URL: &str = "https://api.openai.com/v1/images/edits";

pub struct OpenAIProvider {
    api_key: String,
    deployment_config: DeploymentConfig,
}

impl OpenAIProvider {
    pub fn new(env: &Env) -> Result<Self> {
        let deployment_config = DeploymentConfig::from_env(env)
            .map_err(|e| worker::Error::from(AppError::InternalError(format!("Deployment config error: {:?}", e))))?;

        let api_key = match deployment_config.mode {
            DeploymentMode::Official => {
                env.secret("OPENAI_API_KEY")
                    .map_err(|_| worker::Error::RustError("OPENAI_API_KEY not configured".to_string()))?
                    .to_string()
            }
            DeploymentMode::SelfHosted => {
                return Err(worker::Error::RustError("Self-hosted mode requires API key in request".to_string()));
            }
        };

        Ok(Self {
            api_key,
            deployment_config,
        })
    }

    pub fn with_api_key(api_key: String, deployment_config: DeploymentConfig) -> Self {
        Self {
            api_key,
            deployment_config,
        }
    }

    fn get_api_key(&self, request_api_key: Option<String>) -> Result<String> {
        match self.deployment_config.mode {
            DeploymentMode::Official => Ok(self.api_key.clone()),
            DeploymentMode::SelfHosted => {
                request_api_key.ok_or_else(|| {
                    worker::Error::RustError("OpenAI API key required for self-hosted mode".to_string())
                })
            }
        }
    }

    async fn call_openai_api(&self, url: &str, body: serde_json::Value, api_key: &str) -> Result<ImageResponse> {
        let headers = Headers::new();
        headers.set("Authorization", &format!("Bearer {}", api_key))?;
        headers.set("Content-Type", "application/json")?;

        let mut init = worker::RequestInit::new();
        init.with_method(Method::Post)
            .with_headers(headers)
            .with_body(Some(worker::wasm_bindgen::JsValue::from_str(&body.to_string())));

        let request = WorkerRequest::new_with_init(url, &init)?;
        let mut response = Fetch::Request(request).send().await?;

        if response.status_code() >= 400 {
            let error_text = response.text().await.unwrap_or_else(|_| "Unknown error".to_string());
            
            if error_text.contains("content_policy_violation") {
                return Err(AppError::BadRequest(
                    "Your request was rejected by OpenAI's content policy. Please try a different prompt.".to_string()
                ).into());
            }
            
            return Err(AppError::InternalError(format!("OpenAI API error: {}", error_text)).into());
        }

        let openai_response: ImageResponse = response.json().await
            .map_err(|e| AppError::InternalError(format!("Failed to parse OpenAI response: {}", e)))?;

        Ok(openai_response)
    }
}

#[async_trait(?Send)]
impl ImageProvider for OpenAIProvider {
    async fn generate_image(&self, request: &UnifiedImageRequest) -> Result<ProviderResponse> {
        let api_key = self.get_api_key(request.api_key.clone())?;

        let request_body = json!({
            "model": "gpt-image-1",
            "prompt": request.prompt,
            "n": request.n.unwrap_or(1),
            "size": request.size.clone().unwrap_or_else(|| "1024x1024".to_string()),
            "quality": request.quality.clone().unwrap_or_else(|| "auto".to_string()),
            "background": request.background.clone().unwrap_or_else(|| "vivid".to_string()),
            "output_format": request.output_format.clone().unwrap_or_else(|| "png".to_string()),
            "output_compression": request.output_compression,
            "moderation": request.moderation,
            "partial_images": request.partial_images.unwrap_or(0),
            "stream": false,
            "user": request.user,
        });

        let response = self.call_openai_api(OPENAI_API_URL, request_body, &api_key).await?;

        let mut images = Vec::new();
        let mut revised_prompts = Vec::new();

        for image_data in &response.data {
            if let Some(b64_json) = &image_data.b64_json {
                let image_bytes = BASE64.decode(b64_json)
                    .map_err(|e| AppError::InternalError(format!("Failed to decode image: {}", e)))?;
                
                images.push(ImageBytes {
                    data: image_bytes,
                    format: request.output_format.clone().unwrap_or_else(|| "png".to_string()),
                });
            } else if let Some(url) = &image_data.url {
                let mut image_response = Fetch::Url(worker::Url::parse(url)?).send().await?;
                let image_bytes = image_response.bytes().await?;
                
                images.push(ImageBytes {
                    data: image_bytes,
                    format: request.output_format.clone().unwrap_or_else(|| "png".to_string()),
                });
            }
            
            revised_prompts.push(image_data.revised_prompt.clone());
        }

        Ok(ProviderResponse {
            images,
            usage: response.usage,
            revised_prompts,
        })
    }

    async fn edit_image(&self, request: &UnifiedEditRequest) -> Result<ProviderResponse> {
        let api_key = self.get_api_key(request.api_key.clone())?;

        let boundary = format!("----WebKitFormBoundary{}", uuid::Uuid::new_v4().to_string().replace("-", ""));
        let mut body_parts = Vec::new();
        
        for (i, image_data) in request.image.iter().enumerate() {
            let image_base64 = image_data.trim_start_matches("data:image/png;base64,")
                .trim_start_matches("data:image/jpeg;base64,")
                .trim_start_matches("data:image/jpg;base64,");
            let image_bytes = BASE64.decode(image_base64)
                .map_err(|e| AppError::BadRequest(format!("Invalid base64 image data: {}", e)))?;
            
            let field_name = if request.image.len() > 1 { "image[]" } else { "image" };
            
            body_parts.push(format!(
                "--{}\r\nContent-Disposition: form-data; name=\"{}\"; filename=\"image{}.png\"\r\nContent-Type: image/png\r\n\r\n",
                boundary, field_name, i
            ).into_bytes());
            body_parts.push(image_bytes);
            body_parts.push(b"\r\n".to_vec());
        }
        
        if let Some(mask_data) = &request.mask {
            let mask_base64 = mask_data.trim_start_matches("data:image/png;base64,")
                .trim_start_matches("data:image/jpeg;base64,")
                .trim_start_matches("data:image/jpg;base64,");
            let mask_bytes = BASE64.decode(mask_base64)
                .map_err(|e| AppError::BadRequest(format!("Invalid base64 mask data: {}", e)))?;
            
            body_parts.push(format!(
                "--{}\r\nContent-Disposition: form-data; name=\"mask\"; filename=\"mask.png\"\r\nContent-Type: image/png\r\n\r\n",
                boundary
            ).into_bytes());
            body_parts.push(mask_bytes);
            body_parts.push(b"\r\n".to_vec());
        }
        
        let n_str = request.n.unwrap_or(1).to_string();
        let text_fields = vec![
            ("prompt", request.prompt.as_str()),
            ("model", "gpt-image-1"),
            ("n", n_str.as_str()),
            ("size", request.size.as_deref().unwrap_or("1024x1024")),
            ("quality", request.quality.as_deref().unwrap_or("auto")),
            ("background", request.background.as_deref().unwrap_or("vivid")),
            ("input_fidelity", request.input_fidelity.as_deref().unwrap_or("medium")),
            ("output_format", request.output_format.as_deref().unwrap_or("png")),
        ];
        
        for (name, value) in text_fields {
            body_parts.push(format!(
                "--{}\r\nContent-Disposition: form-data; name=\"{}\"\r\n\r\n{}\r\n",
                boundary, name, value
            ).into_bytes());
        }
        
        if let Some(compression) = request.output_compression {
            body_parts.push(format!(
                "--{}\r\nContent-Disposition: form-data; name=\"output_compression\"\r\n\r\n{}\r\n",
                boundary, compression
            ).into_bytes());
        }
        
        body_parts.push(format!(
            "--{}\r\nContent-Disposition: form-data; name=\"partial_images\"\r\n\r\n{}\r\n",
            boundary, request.partial_images.unwrap_or(0)
        ).into_bytes());
        
        if let Some(user) = &request.user {
            body_parts.push(format!(
                "--{}\r\nContent-Disposition: form-data; name=\"user\"\r\n\r\n{}\r\n",
                boundary, user
            ).into_bytes());
        }
        
        body_parts.push(format!("--{}--\r\n", boundary).into_bytes());
        
        let body: Vec<u8> = body_parts.into_iter().flatten().collect();
        
        let headers = Headers::new();
        headers.set("Authorization", &format!("Bearer {}", api_key))?;
        headers.set("Content-Type", &format!("multipart/form-data; boundary={}", boundary))?;

        let mut init = worker::RequestInit::new();
        init.with_method(Method::Post)
            .with_headers(headers)
            .with_body(Some(worker::wasm_bindgen::JsValue::from(body)));

        let worker_request = WorkerRequest::new_with_init(OPENAI_EDIT_URL, &init)?;
        let mut response = Fetch::Request(worker_request).send().await?;

        if response.status_code() >= 400 {
            let error_text = response.text().await.unwrap_or_else(|_| "Unknown error".to_string());
            
            if error_text.contains("content_policy_violation") {
                return Err(AppError::BadRequest(
                    "Your request was rejected by OpenAI's content policy. Please try a different prompt or image.".to_string()
                ).into());
            }
            
            return Err(AppError::InternalError(format!("OpenAI API error: {}", error_text)).into());
        }

        let openai_response: ImageResponse = response.json().await
            .map_err(|e| AppError::InternalError(format!("Failed to parse OpenAI response: {}", e)))?;

        let mut images = Vec::new();
        let mut revised_prompts = Vec::new();

        for image_data in &openai_response.data {
            if let Some(b64_json) = &image_data.b64_json {
                let image_bytes = BASE64.decode(b64_json)
                    .map_err(|e| AppError::InternalError(format!("Failed to decode image: {}", e)))?;
                
                images.push(ImageBytes {
                    data: image_bytes,
                    format: request.output_format.clone().unwrap_or_else(|| "png".to_string()),
                });
            } else if let Some(url) = &image_data.url {
                let mut image_response = Fetch::Url(worker::Url::parse(url)?).send().await?;
                let image_bytes = image_response.bytes().await?;
                
                images.push(ImageBytes {
                    data: image_bytes,
                    format: request.output_format.clone().unwrap_or_else(|| "png".to_string()),
                });
            }
            
            revised_prompts.push(image_data.revised_prompt.clone());
        }

        Ok(ProviderResponse {
            images,
            usage: openai_response.usage,
            revised_prompts,
        })
    }

    fn estimate_cost(&self, request: &UnifiedImageRequest) -> CostEstimate {
        let quality = request.quality.as_deref().unwrap_or("auto");
        let size = request.size.as_deref().unwrap_or("1024x1024");
        let n = request.n.unwrap_or(1) as u32;
        
        let credits_per_image = estimate_image_cost(quality, size, false);
        
        CostEstimate {
            credits: credits_per_image * n,
            provider: "openai".to_string(),
        }
    }

    fn estimate_edit_cost(&self, request: &UnifiedEditRequest) -> CostEstimate {
        let quality = request.quality.as_deref().unwrap_or("auto");
        let size = request.size.as_deref().unwrap_or("1024x1024");
        let n = request.n.unwrap_or(1) as u32;
        
        let credits_per_image = estimate_image_cost(quality, size, true);
        
        CostEstimate {
            credits: credits_per_image * n,
            provider: "openai".to_string(),
        }
    }

    fn get_supported_features(&self) -> ProviderFeatures {
        ProviderFeatures {
            supports_size: true,
            supports_quality: true,
            supports_background: true,
            supports_moderation: true,
            supports_edit: true,
            supports_multiple_outputs: true,
            max_outputs: 10,
        }
    }

    fn get_name(&self) -> &str {
        "openai"
    }
}