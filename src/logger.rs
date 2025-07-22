use worker::console_log;
use serde_json::json;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
#[allow(dead_code)]
pub enum LogLevel {
    Error,
    Warn,
    Info,
    Debug,
}

impl LogLevel {
    fn as_str(&self) -> &'static str {
        match self {
            LogLevel::Error => "ERROR",
            LogLevel::Warn => "WARN",
            LogLevel::Info => "INFO",
            LogLevel::Debug => "DEBUG",
        }
    }
}

pub struct Logger;

#[allow(dead_code)]
impl Logger {
    fn log(level: LogLevel, message: &str, fields: Option<serde_json::Value>) {
        let log_entry = if let Some(fields) = fields {
            json!({
                "level": level.as_str(),
                "message": message,
                "fields": fields,
                "timestamp": chrono::Utc::now().to_rfc3339(),
            })
        } else {
            json!({
                "level": level.as_str(),
                "message": message,
                "timestamp": chrono::Utc::now().to_rfc3339(),
            })
        };
        
        console_log!("{}", log_entry.to_string());
    }
    
    pub fn error(message: &str) {
        Self::log(LogLevel::Error, message, None);
    }
    
    pub fn error_with(message: &str, fields: serde_json::Value) {
        Self::log(LogLevel::Error, message, Some(fields));
    }
    
    pub fn warn(message: &str) {
        Self::log(LogLevel::Warn, message, None);
    }
    
    pub fn warn_with(message: &str, fields: serde_json::Value) {
        Self::log(LogLevel::Warn, message, Some(fields));
    }
    
    pub fn info(message: &str) {
        Self::log(LogLevel::Info, message, None);
    }
    
    pub fn info_with(message: &str, fields: serde_json::Value) {
        Self::log(LogLevel::Info, message, Some(fields));
    }
    
    pub fn debug(message: &str) {
        #[cfg(debug_assertions)]
        Self::log(LogLevel::Debug, message, None);
        #[cfg(not(debug_assertions))]
        let _ = message;
    }
    
    pub fn debug_with(message: &str, fields: serde_json::Value) {
        #[cfg(debug_assertions)]
        Self::log(LogLevel::Debug, message, Some(fields));
        #[cfg(not(debug_assertions))]
        {
            let _ = message;
            let _ = fields;
        }
    }
}

#[macro_export]
macro_rules! log_error {
    ($msg:expr) => {
        $crate::logger::Logger::error($msg)
    };
    ($msg:expr, $fields:expr) => {
        $crate::logger::Logger::error_with($msg, $fields)
    };
}

#[macro_export]
macro_rules! log_warn {
    ($msg:expr) => {
        $crate::logger::Logger::warn($msg)
    };
    ($msg:expr, $fields:expr) => {
        $crate::logger::Logger::warn_with($msg, $fields)
    };
}

#[macro_export]
macro_rules! log_info {
    ($msg:expr) => {
        $crate::logger::Logger::info($msg)
    };
    ($msg:expr, $fields:expr) => {
        $crate::logger::Logger::info_with($msg, $fields)
    };
}

#[macro_export]
macro_rules! log_debug {
    ($msg:expr) => {
        $crate::logger::Logger::debug($msg)
    };
    ($msg:expr, $fields:expr) => {
        $crate::logger::Logger::debug_with($msg, $fields)
    };
}