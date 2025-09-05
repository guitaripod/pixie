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
    
    pub async fn get_credit_balance(&self) -> Result<CreditBalance> {
        let url = format!("{}/v1/credits/balance", self.base_url);
        
        let response = self.client
            .get(&url)
            .headers(self.headers()?)
            .send()
            .await?;
        
        if !response.status().is_success() {
            let status = response.status();
            let text = response.text().await?;
            if let Ok(error) = serde_json::from_str::<ErrorResponse>(&text) {
                anyhow::bail!("Failed to get credit balance: {}", error.error.message);
            } else {
                anyhow::bail!("Failed to get credit balance: {} - {}", status, text);
            }
        }
        
        Ok(response.json().await?)
    }
    
    pub async fn get_credit_transactions(&self, limit: usize) -> Result<CreditTransactionsResponse> {
        let url = format!("{}/v1/credits/transactions?per_page={}", self.base_url, limit);
        
        let response = self.client
            .get(&url)
            .headers(self.headers()?)
            .send()
            .await?;
        
        if !response.status().is_success() {
            let status = response.status();
            let text = response.text().await?;
            if let Ok(error) = serde_json::from_str::<ErrorResponse>(&text) {
                anyhow::bail!("Failed to get credit transactions: {}", error.error.message);
            } else {
                anyhow::bail!("Failed to get credit transactions: {} - {}", status, text);
            }
        }
        
        Ok(response.json().await?)
    }
    
    pub async fn get_credit_packs(&self) -> Result<CreditPacksResponse> {
        let url = format!("{}/v1/credits/packs", self.base_url);
        
        let response = self.client
            .get(&url)
            .headers(self.headers()?)
            .send()
            .await?;
        
        if !response.status().is_success() {
            let status = response.status();
            let text = response.text().await?;
            if let Ok(error) = serde_json::from_str::<ErrorResponse>(&text) {
                anyhow::bail!("Failed to get credit packs: {}", error.error.message);
            } else {
                anyhow::bail!("Failed to get credit packs: {} - {}", status, text);
            }
        }
        
        Ok(response.json().await?)
    }
    
    pub async fn estimate_credit_cost(&self, request: &CreditEstimateRequest) -> Result<CreditEstimateResponse> {
        let url = format!("{}/v1/credits/estimate", self.base_url);
        
        let response = self.client
            .post(&url)
            .headers(self.headers()?)
            .json(request)
            .send()
            .await?;
        
        if !response.status().is_success() {
            let status = response.status();
            let text = response.text().await?;
            if let Ok(error) = serde_json::from_str::<ErrorResponse>(&text) {
                anyhow::bail!("Failed to estimate credit cost: {}", error.error.message);
            } else {
                anyhow::bail!("Failed to estimate credit cost: {} - {}", status, text);
            }
        }
        
        Ok(response.json().await?)
    }
    
    pub async fn purchase_credits_crypto(&self, pack_id: &str, currency: &str) -> Result<CryptoPurchaseResponse> {
        let url = format!("{}/v1/credits/purchase", self.base_url);
        
        let request = PurchaseRequest {
            pack_id: pack_id.to_string(),
            payment_provider: "nowpayments".to_string(),
            payment_id: "".to_string(),
            payment_currency: Some(currency.to_string()),
        };
        
        let response = self.client
            .post(&url)
            .headers(self.headers()?)
            .json(&request)
            .send()
            .await?;
        
        if !response.status().is_success() {
            let status = response.status();
            let text = response.text().await?;
            
            // Try to parse as our API error format
            if let Ok(error_response) = serde_json::from_str::<ErrorResponse>(&text) {
                // Return a structured error that includes the error response
                return Err(anyhow::anyhow!("{}", serde_json::to_string(&error_response)?));
            }
            
            // Fallback for non-JSON responses
            match status.as_u16() {
                500..=599 => anyhow::bail!("Server error: The service is temporarily unavailable"),
                400 => anyhow::bail!("Invalid request: Please check your input and try again"),
                401 => anyhow::bail!("Authentication failed: Your API key may be invalid"),
                402 => anyhow::bail!("Payment required: Insufficient credits"),
                403 => anyhow::bail!("Access denied: You don't have permission for this action"),
                404 => anyhow::bail!("Not found: The requested resource doesn't exist"),
                429 => anyhow::bail!("Too many requests: Please wait before trying again"),
                _ => anyhow::bail!("Request failed with status {}: {}", status, text),
            }
        }
        
        Ok(response.json().await?)
    }
    
    pub async fn purchase_credits_stripe(&self, pack_id: &str) -> Result<StripePurchaseResponse> {
        let url = format!("{}/v1/credits/purchase/stripe", self.base_url);
        
        #[derive(Debug, Serialize)]
        struct StripeCheckoutRequest {
            pack_id: String,
            success_url: String,
            cancel_url: String,
        }
        
        let request = StripeCheckoutRequest {
            pack_id: pack_id.to_string(),
            success_url: "https://pixie.cli/success".to_string(),
            cancel_url: "https://pixie.cli/cancel".to_string(),
        };
        
        let response = self.client
            .post(&url)
            .headers(self.headers()?)
            .json(&request)
            .send()
            .await?;
        
        if !response.status().is_success() {
            let status = response.status();
            let text = response.text().await?;
            
            // Try to parse as our API error format
            if let Ok(error_response) = serde_json::from_str::<ErrorResponse>(&text) {
                // Return a structured error that includes the error response
                return Err(anyhow::anyhow!("{}", serde_json::to_string(&error_response)?));
            }
            
            // Fallback for non-JSON responses
            match status.as_u16() {
                500..=599 => anyhow::bail!("Server error: The service is temporarily unavailable"),
                400 => anyhow::bail!("Invalid request: Please check your input and try again"),
                401 => anyhow::bail!("Authentication failed: Your API key may be invalid"),
                402 => anyhow::bail!("Payment required: Insufficient credits"),
                403 => anyhow::bail!("Access denied: You don't have permission for this action"),
                404 => anyhow::bail!("Not found: The requested resource doesn't exist"),
                429 => anyhow::bail!("Too many requests: Please wait before trying again"),
                _ => anyhow::bail!("Request failed with status {}: {}", status, text),
            }
        }
        
        Ok(response.json().await?)
    }
    
    pub async fn check_purchase_status(&self, purchase_id: &str) -> Result<PurchaseStatusResponse> {
        let url = format!("{}/v1/credits/purchase/{}/status", self.base_url, purchase_id);
        
        let response = self.client
            .get(&url)
            .headers(self.headers()?)
            .send()
            .await?;
        
        if !response.status().is_success() {
            let status = response.status();
            let text = response.text().await?;
            if let Ok(error) = serde_json::from_str::<ErrorResponse>(&text) {
                anyhow::bail!("Failed to check payment status: {}", error.error.message);
            } else {
                anyhow::bail!("Failed to check payment status: {} - {}", status, text);
            }
        }
        
        Ok(response.json().await?)
    }

    pub async fn check_device_auth_status(&self, device_code: &str) -> Result<DeviceAuthStatus> {
        let url = format!("{}/v1/auth/device/{}/status", self.base_url, device_code);
        
        let response = self.client
            .get(&url)
            .send()
            .await?;
        
        if !response.status().is_success() {
            let error = response.text().await?;
            return Err(anyhow::anyhow!("API error: {}", error));
        }
        
        response.json().await
            .context("Failed to parse device auth status")
    }
}

#[derive(Debug, Serialize)]
pub struct ImageGenerationRequest {
    pub prompt: String,
    pub model: String,
    pub n: u8,
    pub size: String,
    pub quality: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub background: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub moderation: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub output_compression: Option<u8>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub output_format: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub partial_images: Option<u8>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub stream: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub user: Option<String>,
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

#[derive(Debug, Deserialize)]
pub struct CreditBalance {
    pub balance: i32,
    #[allow(dead_code)]
    pub currency: String,
}

#[derive(Debug, Deserialize)]
pub struct CreditTransactionsResponse {
    pub transactions: Vec<CreditTransaction>,
    #[allow(dead_code)]
    pub page: usize,
    #[allow(dead_code)]
    pub per_page: usize,
}

#[derive(Debug, Deserialize)]
pub struct CreditTransaction {
    #[allow(dead_code)]
    pub id: String,
    #[allow(dead_code)]
    pub user_id: String,
    #[serde(rename = "type")]
    pub transaction_type: String,
    pub amount: i32,
    pub balance_after: i32,
    pub description: String,
    #[allow(dead_code)]
    pub reference_id: Option<String>,
    pub created_at: String,
}

#[derive(Debug, Deserialize)]
pub struct CreditPacksResponse {
    pub packs: Vec<CreditPack>,
}

#[derive(Debug, Deserialize)]
pub struct CreditPack {
    pub id: String,
    pub name: String,
    pub credits: i32,
    pub price_usd_cents: i32,
    pub bonus_credits: i32,
    pub description: String,
}

#[derive(Debug, Serialize)]
pub struct CreditEstimateRequest {
    pub prompt: Option<String>,
    pub quality: String,
    pub size: String,
    pub n: Option<u8>,
    pub is_edit: Option<bool>,
    pub model: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct CreditEstimateResponse {
    pub estimated_credits: u32,
    pub estimated_usd: String,
    pub note: String,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct ErrorResponse {
    pub error: ErrorDetail,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct ErrorDetail {
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub code: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct DeviceAuthStatus {
    pub status: String,
    pub message: String,
}

#[derive(Debug, Serialize)]
pub struct PurchaseRequest {
    pub pack_id: String,
    pub payment_provider: String,
    pub payment_id: String,
    pub payment_currency: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct CryptoPurchaseResponse {
    pub purchase_id: String,
    #[allow(dead_code)]
    pub payment_id: String,
    #[allow(dead_code)]
    pub status: String,
    #[allow(dead_code)]
    pub credits: u32,
    pub amount_usd: String,
    pub crypto_address: String,
    pub crypto_amount: String,
    pub crypto_currency: String,
    pub expires_at: String,
}

#[derive(Debug, Deserialize)]
pub struct PurchaseStatusResponse {
    #[allow(dead_code)]
    pub purchase_id: String,
    pub status: String,
    pub payment_status: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct StripePurchaseResponse {
    pub purchase_id: String,
    #[allow(dead_code)]
    pub session_id: String,
    pub checkout_url: String,
}