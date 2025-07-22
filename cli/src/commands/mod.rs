pub mod generate;
pub mod edit;
pub mod gallery;
pub mod usage;
pub mod credits;
pub mod utils;
pub mod admin;

// Size alias mapping
pub fn parse_size_alias(size: &str) -> String {
    match size.to_lowercase().as_str() {
        "square" | "sq" => "1024x1024".to_string(),
        "landscape" | "land" | "wide" => "1536x1024".to_string(),
        "portrait" | "port" | "tall" => "1024x1536".to_string(),
        "auto" | "optimal" => "auto".to_string(),
        _ => size.to_string(), // Return as-is if not an alias
    }
}