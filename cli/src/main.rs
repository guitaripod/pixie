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

EXAMPLES:
  # GitHub authentication (recommended)
  pixie auth github                              # Opens browser for GitHub OAuth
  
  # Google authentication
  pixie auth google                              # Shows device code for Google auth
  
  # With custom API endpoint
  pixie auth github --api-url https://custom.api.com

AUTHENTICATION FLOW:
  GitHub:
    1. Opens your default browser to GitHub OAuth page
    2. You authorize the application
    3. Credentials are saved locally
    4. You can start using pixie commands
  
  Google:
    1. Shows a device code to enter
    2. Opens browser to Google's device page
    3. You enter the code and authorize
    4. Credentials are saved locally

SECURITY:
  - API keys are stored in: ~/.config/pixie/config.json (Linux/Mac)
  - API keys are stored in: %APPDATA%/pixie/config.json (Windows)
  - Keys are never transmitted except to the API server
  - Use 'pixie logout' to remove stored credentials

TROUBLESHOOTING:
  - If browser doesn't open, manually visit the URL shown
  - For headless systems, copy the URL to another device
  - Check 'pixie config' to verify authentication status")]
    Auth {
        #[command(subcommand)]
        provider: AuthProvider,
    },
    
    #[command(about = "Generate images from text prompts

Examples:
  pixie generate \"cute robot\" -n 4 -o ./images
  pixie generate \"abstract art\" -s 1536x1024 -q high", long_about = "Generate stunning images from text descriptions using gpt-image-1.

EXAMPLES:
  # Simple generation (uses defaults)
  pixie generate \"a serene mountain landscape at sunset\"
  pixie generate \"cyberpunk cityscape\"
  
  # Multiple images
  pixie generate \"cute robot\" -n 4 -o ./images
  pixie generate \"fantasy creature\" -n 10 -o creatures/
  
  # Size variations
  pixie generate \"abstract art\" -s 1536x1024              # Wide
  pixie generate \"portrait in oil painting style\" -s 1024x1536  # Tall
  pixie generate \"icon design\" -s 1024x1024               # Square
  pixie generate \"banner image\" -s auto                   # Auto-select
  
  # Quality options (affects detail and credits)
  pixie generate \"minimalist logo\" -q low -n 10 -o logos/   # ~4-5 credits each
  pixie generate \"product photo\" -q medium                  # ~12-15 credits
  pixie generate \"detailed artwork\" -q high -s 1536x1024    # ~78 credits
  pixie generate \"quick sketch\" -q auto                     # Auto-select
  
  # Output directory
  pixie generate \"nature scene\" -o ~/Pictures/
  pixie generate \"test image\" -o .                        # Current directory
  pixie generate \"wallpaper\" -o /tmp/images/
  
  # Complex prompts
  pixie generate \"A steampunk owl wearing goggles, highly detailed, 4k\"
  pixie generate \"Minimalist japanese ink painting of mountains\"
  
  # All parameters
  pixie generate \"futuristic car\" -n 3 -s 1536x1024 -q high -o ./cars/

PARAMETERS:
  -n, --number    Number of images (1-10, default: 1)
  -s, --size      Dimensions: 1024x1024, 1536x1024, 1024x1536, auto
  -q, --quality   Quality: low, medium, high, auto
  -o, --output    Save directory (optional)

CREDIT COSTS:
  Low:    ~4-5 credits per image
  Medium: ~12-15 credits per image
  High:   ~50-80 credits per image (varies by size)")]
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
  # Simple edits
  pixie edit photo.png \"add a rainbow in the sky\"
  pixie edit landscape.jpg \"make it winter scene\"
  pixie edit portrait.png \"add glasses\"
  
  # Style transformations
  pixie edit image.jpg \"make it cyberpunk style\" -o edited/
  pixie edit photo.png \"convert to oil painting\"
  pixie edit logo.png \"make it 3D metallic\" -q high
  
  # Multiple variations
  pixie edit product.png \"different color schemes\" -n 5
  pixie edit design.jpg \"creative variations\" -n 3 -o variations/
  
  # Gallery images
  pixie edit gallery:abc-123 \"add neon lights\" -o .
  pixie edit gallery:xyz-789 \"remove background\" -n 2
  
  # Using masks
  pixie edit portrait.png \"change background to beach\" -m mask.png
  pixie edit product.jpg \"replace logo\" -m logo-mask.png -o branded/
  
  # Size options
  pixie edit icon.png \"higher resolution\" -s 1024x1024
  pixie edit banner.jpg \"resize and enhance\" -s 1536x1024
  
  # Quality variations (affects credits)
  pixie edit sketch.png \"quick colorize\" -q low              # ~7 credits
  pixie edit photo.jpg \"enhance details\" -q medium           # ~16 credits
  pixie edit artwork.png \"ultra HD version\" -q high -s 1536x1024  # ~81 credits
  
  # Output directories
  pixie edit input.png \"artistic style\" -o ~/Pictures/
  pixie edit photo.jpg \"variations\" -n 4 -o ./results/
  
  # Complex edits
  pixie edit room.jpg \"add modern furniture, warm lighting, plants\"
  pixie edit car.png \"change color to red, add racing stripes, sporty wheels\"
  
  # All parameters
  pixie edit photo.png \"dramatic lighting\" -m mask.png -n 3 -s 1024x1536 -q high -o edits/

PARAMETERS:
  image           Local path or gallery:<id>
  prompt          Description of changes
  -m, --mask      Mask image (transparent = edit area)
  -n, --number    Number of variations (1-10, default: 1)
  -s, --size      Output size (same as generate)
  -q, --quality   Output quality (same as generate)
  -o, --output    Save directory

CREDIT COSTS:
  Base edit cost + quality cost:
  Low:    ~7 credits (4 base + 3 input)
  Medium: ~16 credits (13 base + 3 input)
  High:   ~55-81 credits (varies by size)")]
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
  # Current period
  pixie usage                                      # Today's usage
  pixie usage --detailed                           # Today with hourly breakdown
  
  # Date ranges
  pixie usage --start 2024-01-01                   # From date to now
  pixie usage --start 2024-01-01 --end 2024-01-31 # Specific date range
  pixie usage --start 2024-12-01 --detailed        # Detailed view for period
  
  # Common time periods
  pixie usage --start 2024-01-01 --end 2024-12-31 # Full year
  pixie usage --start 2024-06-01 --end 2024-06-30 # Single month
  pixie usage --start 2024-12-25 --end 2024-12-25 # Single day
  
  # With custom API
  pixie usage --api-url https://custom.api.com

OUTPUT INCLUDES:
  Summary:
    - Total API requests made
    - Total tokens consumed (input + output)
    - Images generated (by type: new/edit)
    - Estimated costs in USD
  
  Detailed mode (--detailed):
    - Daily breakdown of all metrics
    - Token usage per day
    - Image counts per day
    - Running totals

NOTES:
  - Dates must be in YYYY-MM-DD format
  - Usage data may have slight delay (few minutes)
  - Token counts include both prompt and generation
  - Cost estimates based on current pricing")]
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
    
    #[command(about = "Check API health status

Example:
  pixie health", long_about = "Check if the API server is online and responding.

Shows the API endpoint and current status.

EXAMPLES:
  pixie health                          # Check default API
  pixie health --api-url https://...    # Check custom API")]
    Health,
    
    #[command(about = "Admin commands (requires admin privileges)
    
Examples:
  pixie admin stats
  pixie admin credits adjust --user-id abc123 --amount 500 --reason \"Refund\"
  pixie admin credits adjust --user-id abc123 --amount=-100 --reason \"Correction\"", long_about = "Administrative commands for system management.

Requires admin privileges to access these commands.

EXAMPLES:
  # View system statistics
  pixie admin stats
  
  # Add credits to a user
  pixie admin credits adjust --user-id abc123 --amount 500 --reason \"Customer refund\"
  pixie admin credits adjust --user-id abc123 --amount 1000 --reason \"Promotional bonus\"
  
  # Remove credits from a user (use --amount=-N format)
  pixie admin credits adjust --user-id abc123 --amount=-100 --reason \"Correction\"
  pixie admin credits adjust --user-id abc123 --amount=-50 --reason \"Testing adjustment\"
  
  # Grant admin privileges (shows SQL command)
  pixie admin grant --user-id abc123

NOTES:
  - Only users with is_admin=true can use these commands
  - All adjustments are logged with admin ID and reason
  - Negative adjustments won't make balance go below 0
  - Use quotes around multi-word reasons")]
    Admin {
        #[command(subcommand)]
        action: AdminAction,
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
    
    #[command(about = "Check device authentication status", long_about = "Check the status of a device authentication flow.

EXAMPLE:
  pixie auth device-status <device-code>

PURPOSE:
Device authentication is used when a direct browser redirect isn't possible
(e.g., CLI tools, mobile apps, smart TVs). This command checks if a user
has completed the authentication process for a given device code.

WHEN TO USE:
- Debugging: Check if a user completed authentication after seeing a device code
- Support: Help users troubleshoot stuck authentication flows
- Testing: Verify device authentication is working correctly

EXPECTED STATUSES:
- pending: User hasn't completed authentication yet
- completed: Authentication successful, token was issued
- expired: Device code expired (typically after 15 minutes)
- invalid: Device code doesn't exist or was already used

NOTE: This is primarily for debugging and support purposes. Regular users
typically won't need this command as the auth flow handles polling automatically.")]
    DeviceStatus {
        #[arg(help = "Device code to check status for")]
        device_code: String,
    },
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

#[derive(Subcommand)]
enum AdminAction {
    #[command(about = "View system statistics
    
Examples:
  pixie admin stats
  pixie admin stats --api-url https://custom.workers.dev", long_about = "Display system-wide statistics and metrics.

Shows:
  - Total users
  - Total credit balance across all users
  - Lifetime credits purchased and spent
  - Revenue (total, costs, profit, margin)
  - Total images generated

EXAMPLES:
  pixie admin stats                                    # Use default API
  pixie admin stats --api-url https://custom.api.com  # Use custom API")]
    Stats,
    
    #[command(name = "credits", about = "Admin credit operations")]
    Credits {
        #[command(subcommand)]
        action: AdminCreditsAction,
    },
    
    #[command(about = "Grant admin privileges to a user
    
Example:
  pixie admin grant --user-id <id>", long_about = "Grant admin privileges to a user.

NOTE: This command is not yet implemented. To grant admin access,
update the database directly.

EXAMPLE:
  pixie admin grant --user-id 123e4567-e89b-12d3-a456-426614174000")]
    Grant {
        #[arg(long, help = "User ID to grant admin privileges")]
        user_id: String,
    },
}

#[derive(Subcommand)]
enum AdminCreditsAction {
    #[command(about = "Adjust user credits
    
Examples:
  pixie admin credits adjust --user-id abc123 --amount 500 --reason \"Refund\"
  pixie admin credits adjust --user-id abc123 --amount=-100 --reason \"Fix\"", long_about = "Add or remove credits from a user's balance.

Use positive amounts to add credits, negative to remove.
All adjustments are logged with the admin's user ID and reason.

EXAMPLES:
  # Add credits
  pixie admin credits adjust --user-id abc123 --amount 500 --reason \"Refund for issue #123\"
  pixie admin credits adjust --user-id abc123 --amount 1000 --reason \"Compensation\"
  pixie admin credits adjust --user-id abc123 --amount 50 --reason \"Test credits\"
  
  # Remove credits (use --amount=-N format)
  pixie admin credits adjust --user-id abc123 --amount=-100 --reason \"Correction\"
  pixie admin credits adjust --user-id abc123 --amount=-50 --reason \"Duplicate purchase\"
  
  # With custom API
  pixie admin credits adjust --user-id abc123 --amount 200 --reason \"Bonus\" --api-url https://custom.api.com

NOTES:
  - Balance cannot go below 0
  - If deducting more than available, only available amount is deducted
  - Transaction history shows actual amount adjusted")]
    Adjust {
        #[arg(long, help = "User ID to adjust credits for")]
        user_id: String,
        
        #[arg(long, help = "Amount to adjust (positive to add, negative to remove)")]
        amount: i32,
        
        #[arg(long, help = "Reason for adjustment")]
        reason: String,
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
                AuthProvider::DeviceStatus { device_code } => {
                    commands::utils::check_device_auth_status(&api_url, &device_code).await?;
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