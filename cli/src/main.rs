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
#[command(about = "A magical CLI for AI image generation powered by gpt-image-1", long_about = "
Pixie - OpenAI Image Proxy CLI

A powerful command-line tool for generating and editing images using OpenAI's gpt-image-1 model.
Supports image generation, editing, gallery browsing, and usage tracking.

QUICK START:
  1. Authenticate:     pixie auth github
  2. Generate image:   pixie generate \"a cute robot\" -o .
  3. Edit image:       pixie edit image.png \"add wings\" -o .
  4. Browse gallery:   pixie gallery list

COMMON WORKFLOWS:
  Generate variations:  pixie generate \"sunset\" -n 4 -o sunsets/
  Edit from gallery:    pixie edit gallery:abc-123 \"new style\"
  Check your usage:     pixie usage --start 2024-01-01

For more help on any command, use: pixie <command> --help
")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
    
    #[arg(long, global = true, help = "API base URL")]
    api_url: Option<String>,
}

#[derive(Subcommand)]
enum Commands {
    #[command(about = "Authenticate with the service

Examples:
  pixie auth github
  pixie auth google", long_about = "Authenticate with the OpenAI Image Proxy service using OAuth providers.

Supported providers:
  - GitHub: pixie auth github
  - Google: pixie auth google

Authentication tokens are stored securely in your system's config directory.")]
    Auth {
        #[command(subcommand)]
        provider: AuthProvider,
    },
    
    #[command(about = "Generate images from text prompts

Examples:
  pixie generate \"cute robot\" -n 4 -o ./images
  pixie generate \"abstract art\" -s 1536x1024 -q high", long_about = "Generate stunning images from text descriptions using gpt-image-1.

EXAMPLES:
  pixie generate \"a serene mountain landscape at sunset\"
  pixie generate \"cute robot\" -n 4 -o ./images
  pixie generate \"abstract art\" -s 1536x1024 -q high
  pixie generate \"minimalist logo\" -q low -n 10 -o logos/
  pixie generate \"portrait in oil painting style\" -s 1024x1536

SIZES: 1024x1024, 1536x1024, 1024x1536, auto
QUALITY: low, medium, high, auto")]
    Generate {
        #[arg(help = "Text description of the image you want to create")]
        prompt: String,
        
        #[arg(short, long, default_value = "1", help = "Number of images to generate (1-10)")]
        number: u8,
        
        #[arg(short, long, default_value = "auto", help = "Image dimensions (1024x1024, 1536x1024, 1024x1536, auto)")]
        size: String,
        
        #[arg(short, long, default_value = "auto", help = "Output quality (low, medium, high, auto)")]
        quality: String,
        
        #[arg(short, long, help = "Directory to save generated images")]
        output: Option<String>,
    },
    
    #[command(about = "Edit existing images with AI

Examples:
  pixie edit photo.png \"add a rainbow\"
  pixie edit gallery:abc-123 \"add neon lights\" -o .", long_about = "Transform existing images using AI-powered editing.

EXAMPLES:
  pixie edit photo.png \"add a rainbow in the sky\"
  pixie edit image.jpg \"make it cyberpunk style\" -o edited/
  pixie edit gallery:abc-123 \"add neon lights\" -o .
  pixie edit portrait.png \"change background to beach\" -m mask.png
  pixie edit logo.png \"make it 3D metallic\" -q high -n 3

GALLERY SUPPORT:
  Use gallery:<image-id> to edit images from the public gallery.
  Find image IDs with: pixie gallery list

MASK SUPPORT:
  Use -m mask.png to specify areas to edit (transparent = edit area)")]
    Edit {
        #[arg(help = "Local image path or gallery:<id> for gallery images")]
        image: String,
        
        #[arg(help = "Description of how to transform the image")]
        prompt: String,
        
        #[arg(short, long, help = "Mask image path (transparent areas will be edited)")]
        mask: Option<String>,
        
        #[arg(short, long, default_value = "1", help = "Number of edited variations (1-10)")]
        number: u8,
        
        #[arg(short, long, default_value = "auto", help = "Output dimensions (same options as generate)")]
        size: String,
        
        #[arg(short, long, default_value = "auto", help = "Output quality (same options as generate)")]
        quality: String,
        
        #[arg(short, long, help = "Directory to save edited images")]
        output: Option<String>,
    },
    
    #[command(about = "Browse image galleries

Examples:
  pixie gallery list --limit 10
  pixie gallery view abc-123", long_about = "Browse and search image galleries.

SUBCOMMANDS:
  list    - List all public images
  mine    - List your own images
  search  - Search images by prompt
  show    - Show details of a specific image
  delete  - Delete your own image

EXAMPLES:
  pixie gallery list --limit 10
  pixie gallery mine --page 2
  pixie gallery search \"robot\"
  pixie gallery show abc-123
  pixie gallery delete xyz-789")]
    Gallery {
        #[command(subcommand)]
        action: GalleryAction,
    },
    
    #[command(about = "View usage statistics

Examples:
  pixie usage
  pixie usage --start 2024-01-01 --detailed", long_about = "View your API usage statistics and history.

EXAMPLES:
  pixie usage                           # Show today's usage
  pixie usage --start 2024-01-01       # Show usage from date
  pixie usage --start 2024-01-01 --end 2024-01-31  # Date range
  pixie usage --detailed                # Show detailed daily breakdown
  pixie usage --start 2024-12-01 --detailed  # Detailed view for period

Shows:
  - Total requests and tokens used
  - Image generation count by type
  - Daily breakdown (with --detailed)
  - Cost estimates")]
    Usage {
        #[arg(long, help = "Start date (YYYY-MM-DD)")]
        start: Option<String>,
        
        #[arg(long, help = "End date (YYYY-MM-DD)")]
        end: Option<String>,
        
        #[arg(long, help = "Show detailed daily usage")]
        detailed: bool,
    },
    
    #[command(about = "Show current configuration", long_about = "Display current configuration and authentication status.

Shows:
  - Authentication status
  - API endpoint
  - Config file location
  - Current user information

EXAMPLES:
  pixie config                          # Show all configuration
  pixie config --api-url https://...    # Show config with custom API")]
    Config,
    
    #[command(about = "Log out and remove stored credentials", long_about = "Log out from the service and remove stored authentication tokens.

This will:
  - Remove stored API keys
  - Clear OAuth tokens
  - Reset configuration to defaults

You'll need to authenticate again with 'pixie auth' to use the service.

EXAMPLES:
  pixie logout                          # Log out and clear credentials")]
    Logout,
}

#[derive(Subcommand)]
enum AuthProvider {
    #[command(about = "Authenticate with GitHub OAuth", long_about = "Authenticate using your GitHub account.

EXAMPLE:
  pixie auth github

This will:
  1. Open your browser to GitHub OAuth page
  2. Request permission to authenticate
  3. Save credentials locally for future use")]
    Github,
    
    #[command(about = "Authenticate with Google OAuth", long_about = "Authenticate using your Google account.

EXAMPLE:
  pixie auth google

This will:
  1. Show a device code to enter on Google's device page
  2. Open your browser for authentication
  3. Save credentials locally for future use")]
    Google,
    
    #[command(about = "Authenticate with Apple OAuth (coming soon)", long_about = "Authenticate using your Apple ID.

EXAMPLE:
  pixie auth apple

Note: Apple authentication is coming soon!")]
    Apple,
}

#[derive(Subcommand)]
enum GalleryAction {
    #[command(about = "List all public images

Examples:
  pixie gallery list
  pixie gallery list --page 2 --limit 50", long_about = "Browse the public gallery of generated images.

Each image shows:
  - Image ID (for editing with gallery:<id>)
  - Original prompt
  - Creation date
  - Direct URL

EXAMPLES:
  pixie gallery list                    # Show first page
  pixie gallery list --page 2           # Show page 2
  pixie gallery list --limit 50         # Show 50 images per page
  pixie gallery list -p 3 -l 10         # Page 3, 10 items")]
    List {
        #[arg(short, long, default_value = "1", help = "Page number to display")]
        page: usize,
        
        #[arg(short, long, default_value = "20", help = "Number of images per page (max 100)")]
        limit: usize,
    },
    
    #[command(about = "List your images

Examples:
  pixie gallery mine
  pixie gallery mine --limit 100", long_about = "View all images you've generated.

Shows the same information as the public gallery,
but filtered to only your creations.

EXAMPLES:
  pixie gallery mine                    # Show your images
  pixie gallery mine --page 2           # Show page 2
  pixie gallery mine --limit 100        # Show up to 100 images")]
    Mine {
        #[arg(short, long, default_value = "1", help = "Page number to display")]
        page: usize,
        
        #[arg(short, long, default_value = "20", help = "Number of images per page (max 100)")]
        limit: usize,
    },
    
    #[command(about = "View details of a specific image

Example:
  pixie gallery view abc-123-def", long_about = "Display detailed information about a specific image.

Shows:
  - Full prompt and metadata
  - Generation parameters
  - Token usage
  - Direct download URL

EXAMPLES:
  pixie gallery view abc-123-def        # View specific image
  pixie gallery view 8e75dda1-4f0c      # View by ID prefix")]
    View {
        #[arg(help = "Image ID from gallery listing")]
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