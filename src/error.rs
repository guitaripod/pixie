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
        AppError::InternalError(err.to_string())
    }
}

impl From<AppError> for worker::Error {
    fn from(err: AppError) -> Self {
        worker::Error::RustError(format!("{:?}", err))
    }
}