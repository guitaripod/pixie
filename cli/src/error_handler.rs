use colored::Colorize;
use crate::api::ErrorResponse;

pub fn handle_api_error(error: anyhow::Error, operation: &str) -> String {
    // Try to extract API error from the error chain
    if let Some(api_error) = extract_api_error(&error) {
        format_api_error(api_error, operation)
    } else {
        format_generic_error(&error, operation)
    }
}

fn extract_api_error(error: &anyhow::Error) -> Option<ErrorResponse> {
    let error_str = error.to_string();
    
    // Try to parse as JSON-encoded ErrorResponse
    if let Ok(error_response) = serde_json::from_str::<ErrorResponse>(&error_str) {
        return Some(error_response);
    }
    
    None
}

fn format_api_error(error: ErrorResponse, operation: &str) -> String {
    let mut message = String::new();
    
    // Add icon based on error type
    let icon = match error.error.code.as_deref() {
        Some("insufficient_credits") => "💳",
        Some("unauthorized") => "🔒",
        Some("not_found") => "🔍",
        Some("rate_limit_exceeded") => "⏱️",
        _ => "❌",
    };
    
    message.push_str(&format!("\n{} {} failed\n", icon, operation.bold()));
    message.push_str(&format!("   {}\n", error.error.message.red()));
    
    // Add helpful suggestions based on error code
    match error.error.code.as_deref() {
        Some("insufficient_credits") => {
            message.push_str(&format!("\n   {} Run {} to add more credits\n", 
                "💡".yellow(), 
                "pixie credits buy".bright_blue().bold()
            ));
        }
        Some("unauthorized") => {
            message.push_str(&format!("\n   {} Your API key may be invalid. Run {} to re-authenticate\n", 
                "💡".yellow(), 
                "pixie auth login".bright_blue().bold()
            ));
        }
        Some("rate_limit_exceeded") => {
            message.push_str(&format!("\n   {} Please wait a moment before trying again\n", 
                "💡".yellow()
            ));
        }
        _ => {}
    }
    
    message
}

fn format_generic_error(error: &anyhow::Error, operation: &str) -> String {
    let mut message = String::new();
    
    message.push_str(&format!("\n❌ {} failed\n", operation.bold()));
    
    // Check for common error patterns
    if error.to_string().contains("connection refused") || 
       error.to_string().contains("network") ||
       error.to_string().contains("timed out") {
        message.push_str(&format!("   {}\n", "Network connection error".red()));
        message.push_str(&format!("\n   {} Check your internet connection and try again\n", 
            "💡".yellow()
        ));
        message.push_str(&format!("   {} Run {} to verify API connectivity\n", 
            "💡".yellow(),
            "pixie status".bright_blue().bold()
        ));
    } else if error.to_string().contains("500 Internal Server Error") {
        message.push_str(&format!("   {}\n", "The service is temporarily unavailable".red()));
        message.push_str(&format!("\n   {} Please try again in a few moments\n", 
            "💡".yellow()
        ));
    } else if error.to_string().contains("parse") || 
              error.to_string().contains("invalid") ||
              error.to_string().contains("decode") {
        message.push_str(&format!("   {}\n", "Received invalid response from server".red()));
        message.push_str(&format!("\n   {} This might be a temporary issue. Please try again\n", 
            "💡".yellow()
        ));
    } else {
        // Generic error
        message.push_str(&format!("   {}\n", error.to_string().red()));
    }
    
    message
}

// Helper function to show user-friendly error and exit
pub fn exit_with_error(error: anyhow::Error, operation: &str) -> ! {
    eprintln!("{}", handle_api_error(error, operation));
    std::process::exit(1);
}