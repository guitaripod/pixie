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
  view    - View details of a specific image

EXAMPLES:
  pixie gallery list --limit 10
  pixie gallery mine --page 2
  pixie gallery view abc-123
")]
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
    
    #[command(about = "Manage credits and view pricing

Examples:
  pixie credits
  pixie credits history --limit 10
  pixie credits packs", long_about = "View your credit balance and manage credit-related operations.

Shows your current credit balance with a visual indicator and provides
access to transaction history, available credit packs, and cost estimates.

EXAMPLES:
  pixie credits                         # Show current balance
  pixie credits history                 # Show recent transactions
  pixie credits history --limit 50      # Show more transactions
  pixie credits packs                   # Show available credit packs
  pixie credits estimate                # Estimate image generation cost

CREDIT COSTS:
  Low quality:    ~4-5 credits per image
  Medium quality: ~12-15 credits per image  
  High quality:   ~50-80 credits per image
  Edit operation: +3-5 credits for input processing

1 credit = $0.01 USD")]
    Credits {
        #[command(subcommand)]
        action: Option<CreditsAction>,
    },
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

#[derive(Subcommand)]
enum CreditsAction {
    #[command(about = "View transaction history

Examples:
  pixie credits history
  pixie credits history --limit 50", long_about = "Display your recent credit transactions.

Shows:
  - Transaction type (purchase, spend, refund)
  - Amount (positive for credits added, negative for spent)
  - Description of what the credits were used for
  - Date and time
  - Balance after transaction

EXAMPLES:
  pixie credits history                 # Show last 10 transactions
  pixie credits history --limit 50      # Show last 50 transactions
  pixie credits history -l 100          # Show last 100 transactions")]
    History {
        #[arg(short, long, default_value = "10", help = "Number of transactions to show")]
        limit: usize,
    },
    
    #[command(about = "Show available credit packs

Example:
  pixie credits packs", long_about = "Display all available credit packs for purchase.

Shows:
  - Pack name and credits included
  - Price in USD
  - Bonus credits (if any)
  - Value proposition
  - Best value indicators

Purchase credits through the web interface or mobile app.")]
    Packs,
    
    #[command(about = "Estimate credit cost for an operation

Examples:
  pixie credits estimate --quality high --size 1024x1024
  pixie credits estimate -q medium --edit", long_about = "Calculate estimated credit cost before generating or editing images.

Helps you understand costs before committing to an operation.

EXAMPLES:
  pixie credits estimate                        # Interactive mode
  pixie credits estimate -q high -s 1024x1024   # High quality square
  pixie credits estimate -q medium --edit       # Medium quality edit
  pixie credits estimate -q low -n 10           # 10 low quality images")]
    Estimate {
        #[arg(short, long, help = "Quality level (low, medium, high)")]
        quality: Option<String>,
        
        #[arg(short, long, help = "Image size (1024x1024, 1536x1024, 1024x1536)")]
        size: Option<String>,
        
        #[arg(short, long, default_value = "1", help = "Number of images")]
        number: u8,
        
        #[arg(long, help = "Calculate for edit operation (adds input processing cost)")]
        edit: bool,
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
        
        Commands::Credits { action } => {
            match action {
                None => {
                    // Show balance by default
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
            }
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