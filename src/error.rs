use worker::{Response, Result};
use crate::models::{ErrorResponse, ErrorDetail};

#[derive(Debug)]
pub enum AppError {
    BadRequest(String),
    Unauthorized(String),
    Forbidden(String),
    NotFound(String),
    PaymentRequired(String),
    InternalError(String),
    RateLimitExceeded,
}

impl AppError {
    pub fn to_response(&self) -> Result<Response> {
        let (status, error_type, message, code) = match self {
            AppError::BadRequest(msg) => (400, "invalid_request_error", msg.clone(), "bad_request"),
            AppError::Unauthorized(msg) => (401, "authentication_error", msg.clone(), "unauthorized"),
            AppError::Forbidden(msg) => (403, "permission_denied", msg.clone(), "forbidden"),
            AppError::NotFound(msg) => (404, "not_found", msg.clone(), "not_found"),
            AppError::PaymentRequired(msg) => (402, "insufficient_credits", msg.clone(), "insufficient_credits"),
            AppError::InternalError(_) => (500, "internal_error", "An internal error occurred. Please try again later.".to_string(), "internal_error"),
            AppError::RateLimitExceeded => (429, "rate_limit_exceeded", "Rate limit exceeded. Please try again later.".to_string(), "rate_limit_exceeded"),
        };

        let error_response = ErrorResponse {
            error: ErrorDetail {
                message,
                error_type: error_type.to_string(),
                param: None,
                code: Some(code.to_string()),
            },
        };

        Response::from_json(&error_response)
            .map(|r| r.with_status(status))
    }
}

impl From<worker::Error> for AppError {
    fn from(err: worker::Error) -> Self {
        let error_str = err.to_string();
        
        if let Some(msg) = error_str.strip_prefix("AppError::PaymentRequired::") {
            return AppError::PaymentRequired(msg.to_string());
        }
        if let Some(msg) = error_str.strip_prefix("AppError::BadRequest::") {
            return AppError::BadRequest(msg.to_string());
        }
        if let Some(msg) = error_str.strip_prefix("AppError::Unauthorized::") {
            return AppError::Unauthorized(msg.to_string());
        }
        if let Some(msg) = error_str.strip_prefix("AppError::Forbidden::") {
            return AppError::Forbidden(msg.to_string());
        }
        if let Some(msg) = error_str.strip_prefix("AppError::NotFound::") {
            return AppError::NotFound(msg.to_string());
        }
        if error_str.starts_with("AppError::RateLimitExceeded::") {
            return AppError::RateLimitExceeded;
        }
        if let Some(msg) = error_str.strip_prefix("AppError::InternalError::") {
            return AppError::InternalError(msg.to_string());
        }
        
        AppError::InternalError(error_str)
    }
}

impl From<AppError> for worker::Error {
    fn from(err: AppError) -> Self {
        let encoded = match &err {
            AppError::BadRequest(msg) => format!("AppError::BadRequest::{}", msg),
            AppError::Unauthorized(msg) => format!("AppError::Unauthorized::{}", msg),
            AppError::Forbidden(msg) => format!("AppError::Forbidden::{}", msg),
            AppError::NotFound(msg) => format!("AppError::NotFound::{}", msg),
            AppError::PaymentRequired(msg) => format!("AppError::PaymentRequired::{}", msg),
            AppError::InternalError(msg) => format!("AppError::InternalError::{}", msg),
            AppError::RateLimitExceeded => "AppError::RateLimitExceeded::".to_string(),
        };
        worker::Error::RustError(encoded)
    }
}