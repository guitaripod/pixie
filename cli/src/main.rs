use anyhow::Result;
use clap::Parser;
use colored::*;
use std::env;

mod auth;
mod config;
mod api;
mod commands;
mod cli;
mod error_handler;

use cli::{Cli, Commands, AuthProvider, GalleryAction, CreditsAction, AdminAction, AdminCreditsAction};

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();
    
    let config = config::Config::load()?;
    let api_url = cli.api_url.unwrap_or_else(|| {
        config.api_url.clone().unwrap_or_else(|| {
            env::var("PIXIE_API_URL")
                .unwrap_or_else(|_| "https://openai-image-proxy.guitaripod.workers.dev".to_string())
        })
    });
    
    match cli.command {
        Commands::Auth { provider } => {
            match provider {
                AuthProvider::Github => {
                    println!("{}", "Starting GitHub authentication...".green());
                    auth::authenticate_github(&api_url).await?;
                }
                AuthProvider::Google => {
                    println!("{}", "Starting Google authentication...".green());
                    auth::authenticate_google(&api_url).await?;
                }
                AuthProvider::Apple => {
                    #[cfg(target_os = "windows")]
                    {
                        println!("{}", "Sign in with Apple is not supported on Windows".red());
                        println!("Please use GitHub or Google authentication instead.");
                        return Ok(());
                    }
                    
                    #[cfg(not(target_os = "windows"))]
                    {
                        println!("{}", "Starting Apple authentication...".green());
                        auth::authenticate_apple(&api_url).await?;
                    }
                }
                AuthProvider::DeviceStatus { device_code } => {
                    commands::utils::check_device_auth_status(&api_url, &device_code).await?;
                }
            }
        }
        
        Commands::Generate { prompt, number, size, quality, output, background, format, compress, moderation, model } => {
            commands::generate::handle(&api_url, &prompt, number, &size, &quality, output.as_deref(), background.as_deref(), format.as_deref(), compress, moderation.as_deref(), &model).await?;
        }
        
        Commands::Edit { image, prompt, number, size, quality, fidelity, output, model } => {
            commands::edit::handle(&api_url, &image, &prompt, None, number, &size, &quality, &fidelity, output.as_deref(), &model).await?;
        }
        
        Commands::Gallery { action } => {
            match action {
                GalleryAction::List { page, limit } => {
                    commands::gallery::list_all(&api_url, page, limit).await?;
                }
                GalleryAction::Mine { page, limit } => {
                    commands::gallery::list_mine(&api_url, page, limit).await?;
                }
                GalleryAction::View { id } => {
                    commands::gallery::view(&api_url, &id).await?;
                }
            }
        }
        
        Commands::Usage { start, end, detailed } => {
            commands::usage::show(&api_url, start.as_deref(), end.as_deref(), detailed).await?;
        }
        
        Commands::Credits { action } => {
            match action {
                None => {
                    commands::credits::show_balance(&api_url).await?;
                }
                Some(CreditsAction::History { limit }) => {
                    commands::credits::show_history(&api_url, limit).await?;
                }
                Some(CreditsAction::Packs) => {
                    commands::credits::show_packs(&api_url).await?;
                }
                Some(CreditsAction::Estimate { quality, size, number, edit }) => {
                    commands::credits::estimate_cost(&api_url, quality.as_deref(), size.as_deref(), number, edit).await?;
                }
                Some(CreditsAction::Buy { pack, crypto }) => {
                    commands::credits::buy_credits(&api_url, pack.as_deref(), crypto.as_deref()).await?;
                }
            }
        }
        
        Commands::Admin { action } => {
            match action {
                AdminAction::Stats => {
                    commands::admin::system_stats(&api_url).await?;
                }
                AdminAction::Credits { action } => {
                    match action {
                        AdminCreditsAction::Adjust { user_id, amount, reason } => {
                            commands::admin::adjust_credits(&api_url, &user_id, amount, &reason).await?;
                        }
                    }
                }
                AdminAction::Grant { user_id } => {
                    commands::admin::grant_admin(&api_url, &user_id).await?;
                }
            }
        }
        
        Commands::Config => {
            config::show_config(&config)?;
        }
        
        Commands::Settings { setting, value } => {
            if setting == "model" {
                let mut config = config::Config::load()?;
                if value == "gemini-2.5-flash" || value == "gpt-image-1" {
                    config.preferred_model = Some(value.clone());
                    config.save()?;
                    println!("{} Model set to: {}", "✓".green(), value.cyan());
                } else {
                    println!("{} Invalid model. Choose 'gemini-2.5-flash' or 'gpt-image-1'", "✗".red());
                }
            } else {
                println!("{} Unknown setting: {}", "✗".red(), setting);
            }
        }
        
        Commands::Health => {
            commands::utils::health_check(&api_url).await?;
        }
        
        Commands::Logout => {
            config::logout()?;
            println!("{}", "Successfully logged out".green());
        }
    }
    
    Ok(())
}