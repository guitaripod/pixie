use anyhow::{Result, Context};
use reqwest::{Client, header::{HeaderMap, HeaderValue, AUTHORIZATION}};
use serde::{Deserialize, Serialize};
use crate::config::Config;

pub struct ApiClient {
    client: Client,
    base_url: String,
    api_key: Option<String>,
}

impl ApiClient {
    pub fn new(base_url: &str) -> Result<Self> {
        let config = Config::load()?;
        let client = Client::builder()
            .timeout(std::time::Duration::from_secs(300))
            .build()?;
        
        Ok(Self {
            client,
            base_url: base_url.to_string(),
            api_key: config.api_key,
        })
    }
    
    fn headers(&self) -> Result<HeaderMap> {
        let mut headers = HeaderMap::new();
        
        if let Some(api_key) = &self.api_key {
            headers.insert(
                AUTHORIZATION,
                HeaderValue::from_str(&format!("Bearer {}", api_key))
                    .context("Invalid API key format")?
            );
        }
        
        Ok(headers)
    }
    
    pub async fn generate_images(&self, request: &ImageGenerationRequest) -> Result<ImageResponse> {
        let url = format!("{}/v1/images/generations", self.base_url);
        
        let response = self.client
            .post(&url)
            .headers(self.headers()?)
            .json(request)
            .send()
            .await?;
        
        if !response.status().is_success() {
            let error = response.text().await?;
            return Err(anyhow::anyhow!("API error: {}", error));
        }
        
        response.json().await
            .context("Failed to parse image generation response")
    }
    
    pub async fn edit_image(&self, request: &ImageEditRequest) -> Result<ImageResponse> {
        let url = format!("{}/v1/images/edits", self.base_url);
        
        let response = self.client
            .post(&url)
            .headers(self.headers()?)
            .json(request)
            .send()
            .await?;
        
        if !response.status().is_success() {
            let error = response.text().await?;
            return Err(anyhow::anyhow!("API error: {}", error));
        }
        
        response.json().await
            .context("Failed to parse image edit response")
    }
    
    pub async fn list_images(&self, page: usize, per_page: usize) -> Result<GalleryResponse> {
        let url = format!("{}/v1/images?page={}&per_page={}", self.base_url, page, per_page);
        
        let response = self.client
            .get(&url)
            .headers(self.headers()?)
            .send()
            .await?;
        
        if !response.status().is_success() {
            let error = response.text().await?;
            return Err(anyhow::anyhow!("API error: {}", error));
        }
        
        response.json().await
            .context("Failed to parse gallery response")
    }
    
    pub async fn list_user_images(&self, user_id: &str, page: usize, per_page: usize) -> Result<UserGalleryResponse> {
        let url = format!("{}/v1/images/user/{}?page={}&per_page={}", 
            self.base_url, user_id, page, per_page);
        
        let response = self.client
            .get(&url)
            .headers(self.headers()?)
            .send()
            .await?;
        
        if !response.status().is_success() {
            let error = response.text().await?;
            return Err(anyhow::anyhow!("API error: {}", error));
        }
        
        response.json().await
            .context("Failed to parse user gallery response")
    }
    
    pub async fn get_image(&self, image_id: &str) -> Result<ImageMetadata> {
        let url = format!("{}/v1/images/{}", self.base_url, image_id);
        
        let response = self.client
            .get(&url)
            .headers(self.headers()?)
            .send()
            .await?;
        
        if !response.status().is_success() {
            let error = response.text().await?;
            return Err(anyhow::anyhow!("API error: {}", error));
        }
        
        response.json().await
            .context("Failed to parse image metadata")
    }
    
    pub async fn download_image(&self, url: &str) -> Result<Vec<u8>> {
        let response = self.client
            .get(url)
            .send()
            .await?;
        
        if !response.status().is_success() {
            return Err(anyhow::anyhow!("Failed to download image"));
        }
        
        response.bytes().await
            .map(|b| b.to_vec())
            .context("Failed to read image data")
    }
    
    pub async fn get_usage(&self, user_id: &str, start: Option<&str>, end: Option<&str>) -> Result<UsageResponse> {
        let mut url = format!("{}/v1/usage/users/{}", self.base_url, user_id);
        
        let mut params = vec![];
        if let Some(start) = start {
            params.push(format!("start={}", start));
        }
        if let Some(end) = end {
            params.push(format!("end={}", end));
        }
        
        if !params.is_empty() {
            url.push_str(&format!("?{}", params.join("&")));
        }
        
        let response = self.client
            .get(&url)
            .headers(self.headers()?)
            .send()
            .await?;
        
        if !response.status().is_success() {
            let error = response.text().await?;
            return Err(anyhow::anyhow!("API error: {}", error));
        }
        
        response.json().await
            .context("Failed to parse usage response")
    }
    
    pub async fn get_usage_details(&self, user_id: &str, start: Option<&str>, end: Option<&str>) -> Result<UsageDetailsResponse> {
        let mut url = format!("{}/v1/usage/users/{}/details", self.base_url, user_id);
        
        let mut params = vec![];
        if let Some(start) = start {
            params.push(format!("start={}", start));
        }
        if let Some(end) = end {
            params.push(format!("end={}", end));
        }
        
        if !params.is_empty() {
            url.push_str(&format!("?{}", params.join("&")));
        }
        
        let response = self.client
            .get(&url)
            .headers(self.headers()?)
            .send()
            .await?;
        
        if !response.status().is_success() {
            let error = response.text().await?;
            return Err(anyhow::anyhow!("API error: {}", error));
        }
        
        response.json().await
            .context("Failed to parse usage details response")
    }
}

#[derive(Debug, Serialize)]
pub struct ImageGenerationRequest {
    pub prompt: String,
    pub model: String,
    pub n: u8,
    pub size: String,
    pub quality: String,
}

#[derive(Debug, Serialize)]
pub struct ImageEditRequest {
    pub image: Vec<String>,
    pub prompt: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mask: Option<String>,
    pub model: String,
    pub n: u8,
    pub size: String,
    pub quality: String,
    pub background: String,
    pub input_fidelity: String,
    pub output_format: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub output_compression: Option<u8>,
    pub partial_images: u8,
    pub stream: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub user: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct ImageResponse {
    #[allow(dead_code)]
    pub created: u64,
    pub data: Vec<ImageData>,
}

#[derive(Debug, Deserialize)]
pub struct ImageData {
    pub url: Option<String>,
    #[allow(dead_code)]
    pub b64_json: Option<String>,
    pub revised_prompt: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct GalleryResponse {
    pub images: Vec<ImageMetadata>,
    pub total: usize,
    pub page: usize,
    pub per_page: usize,
}

#[derive(Debug, Deserialize)]
pub struct UserGalleryResponse {
    #[allow(dead_code)]
    pub user_id: String,
    pub images: Vec<ImageMetadata>,
    pub total: usize,
    pub page: usize,
    pub per_page: usize,
}

#[derive(Debug, Deserialize)]
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

#[derive(Debug, Deserialize)]
pub struct UsageResponse {
    #[allow(dead_code)]
    pub user_id: String,
    pub total_requests: i64,
    pub total_tokens: i64,
    pub total_images: i64,
    pub period_start: String,
    pub period_end: String,
}

#[derive(Debug, Deserialize)]
pub struct UsageDetailsResponse {
    #[allow(dead_code)]
    pub user_id: String,
    pub period_start: String,
    pub period_end: String,
    pub daily_usage: Vec<DailyUsage>,
}

#[derive(Debug, Deserialize)]
pub struct DailyUsage {
    pub date: String,
    pub requests: i64,
    pub tokens: i64,
    pub images: i64,
}