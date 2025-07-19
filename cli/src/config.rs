use anyhow::{Result, Context};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use colored::*;

#[derive(Debug, Serialize, Deserialize, Default)]
pub struct Config {
    pub api_url: Option<String>,
    pub api_key: Option<String>,
    pub user_id: Option<String>,
    pub auth_provider: Option<String>,
}

impl Config {
    pub fn load() -> Result<Self> {
        let path = Self::config_path()?;
        
        if !path.exists() {
            return Ok(Self::default());
        }
        
        let content = std::fs::read_to_string(&path)
            .context("Failed to read config file")?;
        
        toml::from_str(&content)
            .context("Failed to parse config file")
    }
    
    pub fn save(&self) -> Result<()> {
        let path = Self::config_path()?;
        
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)
                .context("Failed to create config directory")?;
        }
        
        let content = toml::to_string_pretty(self)
            .context("Failed to serialize config")?;
        
        std::fs::write(&path, content)
            .context("Failed to write config file")?;
        
        Ok(())
    }
    
    pub fn config_path() -> Result<PathBuf> {
        let config_dir = dirs::config_dir()
            .context("Failed to find config directory")?;
        
        Ok(config_dir.join("openai-image-proxy").join("config.toml"))
    }
    
    pub fn is_authenticated(&self) -> bool {
        self.api_key.is_some() && self.user_id.is_some()
    }
}

pub fn show_config(config: &Config) -> Result<()> {
    println!("{}", "Current Configuration:".bold());
    println!("  API URL: {}", config.api_url.as_deref().unwrap_or("default"));
    
    if let Some(provider) = &config.auth_provider {
        println!("  Auth Provider: {}", provider.green());
    }
    
    if config.is_authenticated() {
        println!("  Status: {}", "Authenticated".green());
        if let Some(user_id) = &config.user_id {
            println!("  User ID: {}", user_id);
        }
    } else {
        println!("  Status: {}", "Not authenticated".yellow());
        println!("  Run {} to authenticate", "oip auth github".cyan());
    }
    
    Ok(())
}

pub fn logout() -> Result<()> {
    let mut config = Config::load()?;
    config.api_key = None;
    config.user_id = None;
    config.auth_provider = None;
    config.save()?;
    Ok(())
}