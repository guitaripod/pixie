use worker::Env;
use crate::error::AppError;

pub struct DeploymentConfig {
    pub mode: DeploymentMode,
    pub require_own_key: bool,
}

#[derive(Debug, PartialEq)]
pub enum DeploymentMode {
    Official,
    SelfHosted,
}

impl DeploymentConfig {
    pub fn from_env(env: &Env) -> Result<Self, AppError> {
        let mode_str = env.var("DEPLOYMENT_MODE")
            .map(|v| v.to_string())
            .unwrap_or_else(|_| "self-hosted".to_string());
        
        let mode = match mode_str.as_str() {
            "official" => DeploymentMode::Official,
            "self-hosted" => DeploymentMode::SelfHosted,
            _ => DeploymentMode::SelfHosted,
        };
        
        let require_own_key = env.var("REQUIRE_OWN_OPENAI_KEY")
            .map(|v| v.to_string() == "true")
            .unwrap_or(true);
        
        Ok(DeploymentConfig {
            mode,
            require_own_key,
        })
    }
    
    #[allow(dead_code)]
    pub fn is_official(&self) -> bool {
        self.mode == DeploymentMode::Official
    }
}

pub fn get_openai_key(env: &Env, config: &DeploymentConfig, user_key: Option<String>) -> Result<String, AppError> {
    match config.mode {
        DeploymentMode::Official => {
            // Official deployment uses the server's key
            env.secret("OPENAI_API_KEY")
                .map(|k| k.to_string())
                .map_err(|_| AppError::InternalError("OpenAI API key not configured".to_string()))
        }
        DeploymentMode::SelfHosted => {
            if config.require_own_key {
                // Self-hosted requires user to provide their own key
                user_key.ok_or_else(|| {
                    AppError::BadRequest("This instance requires you to provide your own OpenAI API key".to_string())
                })
            } else {
                // Self-hosted with server key (user's own deployment)
                env.secret("OPENAI_API_KEY")
                    .map(|k| k.to_string())
                    .map_err(|_| AppError::InternalError("OpenAI API key not configured".to_string()))
            }
        }
    }
}