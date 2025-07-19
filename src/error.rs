use worker::{Response, Result};
use crate::models::{ErrorResponse, ErrorDetail};

#[derive(Debug)]
pub enum AppError {
    BadRequest(String),
    Unauthorized(String),
    NotFound(String),
    InternalError(String),
    RateLimitExceeded,
}

impl AppError {
    pub fn to_response(&self) -> Result<Response> {
        let (status, error_type, message) = match self {
            AppError::BadRequest(msg) => (400, "invalid_request_error", msg.clone()),
            AppError::Unauthorized(msg) => (401, "authentication_error", msg.clone()),
            AppError::NotFound(msg) => (404, "not_found", msg.clone()),
            AppError::InternalError(msg) => (500, "internal_error", msg.clone()),
            AppError::RateLimitExceeded => (429, "rate_limit_exceeded", "Rate limit exceeded. Please try again later.".to_string()),
        };

        let error_response = ErrorResponse {
            error: ErrorDetail {
                message,
                error_type: error_type.to_string(),
                param: None,
                code: None,
            },
        };

        Response::from_json(&error_response)
            .map(|r| r.with_status(status))
    }
}

impl From<worker::Error> for AppError {
    fn from(err: worker::Error) -> Self {
        AppError::InternalError(err.to_string())
    }
}

impl From<AppError> for worker::Error {
    fn from(err: AppError) -> Self {
        worker::Error::RustError(format!("{:?}", err))
    }
}