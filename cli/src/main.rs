use anyhow::Result;
use clap::{Parser, Subcommand};
use colored::*;
use std::env;

mod auth;
mod config;
mod api;
mod commands;

#[derive(Parser)]
#[command(name = "pixie")]
#[command(about = "A magical CLI for AI image generation", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
    
    #[arg(long, global = true, help = "API base URL")]
    api_url: Option<String>,
}

#[derive(Subcommand)]
enum Commands {
    #[command(about = "Authenticate with the service")]
    Auth {
        #[command(subcommand)]
        provider: AuthProvider,
    },
    
    #[command(about = "Generate images from text prompts")]
    Generate {
        #[arg(help = "Text prompt for image generation")]
        prompt: String,
        
        #[arg(short, long, default_value = "1", help = "Number of images to generate")]
        number: u8,
        
        #[arg(short, long, default_value = "auto", help = "Image size")]
        size: String,
        
        #[arg(short, long, default_value = "auto", help = "Image quality")]
        quality: String,
        
        #[arg(short, long, help = "Save images to directory")]
        output: Option<String>,
    },
    
    #[command(about = "Edit existing images with AI")]
    Edit {
        #[arg(help = "Path to the image to edit or gallery:<id> to use gallery image")]
        image: String,
        
        #[arg(help = "Text prompt describing the edit")]
        prompt: String,
        
        #[arg(short, long, help = "Path to mask image (optional)")]
        mask: Option<String>,
        
        #[arg(short, long, default_value = "1", help = "Number of variations to generate")]
        number: u8,
        
        #[arg(short, long, default_value = "auto", help = "Output image size")]
        size: String,
        
        #[arg(short, long, default_value = "auto", help = "Output image quality")]
        quality: String,
        
        #[arg(short, long, help = "Save edited images to directory")]
        output: Option<String>,
    },
    
    #[command(about = "Browse image galleries")]
    Gallery {
        #[command(subcommand)]
        action: GalleryAction,
    },
    
    #[command(about = "View usage statistics")]
    Usage {
        #[arg(long, help = "Start date (YYYY-MM-DD)")]
        start: Option<String>,
        
        #[arg(long, help = "End date (YYYY-MM-DD)")]
        end: Option<String>,
        
        #[arg(long, help = "Show detailed daily usage")]
        detailed: bool,
    },
    
    #[command(about = "Show current configuration")]
    Config,
    
    #[command(about = "Log out and remove stored credentials")]
    Logout,
}

#[derive(Subcommand)]
enum AuthProvider {
    #[command(about = "Authenticate with GitHub")]
    Github,
    
    #[command(about = "Authenticate with Google")]
    Google,
    
    #[command(about = "Authenticate with Apple")]
    Apple,
}

#[derive(Subcommand)]
enum GalleryAction {
    #[command(about = "List all public images")]
    List {
        #[arg(short, long, default_value = "1", help = "Page number")]
        page: usize,
        
        #[arg(short, long, default_value = "20", help = "Items per page")]
        limit: usize,
    },
    
    #[command(about = "List your images")]
    Mine {
        #[arg(short, long, default_value = "1", help = "Page number")]
        page: usize,
        
        #[arg(short, long, default_value = "20", help = "Items per page")]
        limit: usize,
    },
    
    #[command(about = "View details of a specific image")]
    View {
        #[arg(help = "Image ID")]
        id: String,
    },
}

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
                    println!("{}", "Apple authentication not yet implemented".yellow());
                }
            }
        }
        
        Commands::Generate { prompt, number, size, quality, output } => {
            commands::generate::handle(&api_url, &prompt, number, &size, &quality, output.as_deref()).await?;
        }
        
        Commands::Edit { image, prompt, mask, number, size, quality, output } => {
            commands::edit::handle(&api_url, &image, &prompt, mask.as_deref(), number, &size, &quality, output.as_deref()).await?;
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
        
        Commands::Config => {
            config::show_config(&config)?;
        }
        
        Commands::Logout => {
            config::logout()?;
            println!("{}", "Successfully logged out".green());
        }
    }
    
    Ok(())
}