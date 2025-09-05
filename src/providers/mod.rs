use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use worker::Result;
use crate::models::ImageUsage;
use crate::error::AppError;

pub mod openai;
pub mod gemini;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UnifiedImageRequest {
    pub prompt: String,
    pub model: String,
    pub n: Option<u8>,
    pub size: Option<String>,
    pub quality: Option<String>,
    pub background: Option<String>,
    pub moderation: Option<String>,
    pub output_compression: Option<u8>,
    pub output_format: Option<String>,
    pub partial_images: Option<u8>,
    pub user: Option<String>,
    pub api_key: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UnifiedEditRequest {
    pub image: Vec<String>,
    pub prompt: String,
    pub mask: Option<String>,
    pub model: String,
    pub n: Option<u8>,
    pub size: Option<String>,
    pub quality: Option<String>,
    pub background: Option<String>,
    pub input_fidelity: Option<String>,
    pub output_compression: Option<u8>,
    pub output_format: Option<String>,
    pub partial_images: Option<u8>,
    pub user: Option<String>,
    pub api_key: Option<String>,
}

#[derive(Debug, Clone)]
pub struct ProviderResponse {
    pub images: Vec<ImageBytes>,
    pub usage: Option<ImageUsage>,
    pub revised_prompts: Vec<Option<String>>,
}

#[derive(Debug, Clone)]
pub struct ImageBytes {
    pub data: Vec<u8>,
    pub format: String,
}

#[derive(Debug, Clone)]
pub struct CostEstimate {
    pub credits: u32,
    pub provider: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProviderFeatures {
    pub supports_size: bool,
    pub supports_quality: bool,
    pub supports_background: bool,
    pub supports_moderation: bool,
    pub supports_edit: bool,
    pub supports_multiple_outputs: bool,
    pub max_outputs: u8,
}

#[async_trait(?Send)]
pub trait ImageProvider {
    async fn generate_image(&self, request: &UnifiedImageRequest) -> Result<ProviderResponse>;
    
    async fn edit_image(&self, request: &UnifiedEditRequest) -> Result<ProviderResponse>;
    
    fn estimate_cost(&self, request: &UnifiedImageRequest) -> CostEstimate;
    
    fn estimate_edit_cost(&self, request: &UnifiedEditRequest) -> CostEstimate;
    
    fn get_supported_features(&self) -> ProviderFeatures;
    
    fn get_name(&self) -> &str;
}

pub fn get_provider(model: &str, env: &worker::Env) -> Result<Box<dyn ImageProvider>> {
    match model {
        "gpt-image-1" => Ok(Box::new(openai::OpenAIProvider::new(env)?)),
        "gemini-2.5-flash" | "gemini-2.5-flash-image-preview" => Ok(Box::new(gemini::GeminiProvider::new(env)?)),
        _ => Err(AppError::BadRequest(format!("Unsupported model: {}", model)).into()),
    }
}

pub fn get_default_model() -> String {
    "gemini-2.5-flash".to_string()
}