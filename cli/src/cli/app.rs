use clap::{Parser, Subcommand};
use super::{AuthProvider, GalleryAction, CreditsAction, AdminAction};

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
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,
    
    #[arg(long, global = true, help = "API base URL")]
    pub api_url: Option<String>,
}

#[derive(Subcommand)]
pub enum Commands {
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
  pixie generate \"abstract art\" -s landscape -q high
  pixie generate \"logo\" -s square -b transparent -f png
  pixie generate \"product photo\" -b white -f jpeg -c 85
  pixie generate \"wallpaper\" -s landscape --moderation low

For more examples and detailed usage, use: pixie generate --help", long_about = "Generate stunning images from text descriptions using gpt-image-1.

EXAMPLES:
  # Simple generation (uses defaults)
  pixie generate \"a serene mountain landscape at sunset\"
  pixie generate \"cyberpunk cityscape\"
  
  # Multiple images
  pixie generate \"cute robot\" -n 4 -o ./images
  pixie generate \"fantasy creature\" -n 10 -o creatures/
  
  # Size variations
  pixie generate \"banner art\" -s landscape               # 1536x1024
  pixie generate \"poster\" -s portrait                    # 1024x1536
  pixie generate \"icon design\" -s square                  # 1024x1024
  pixie generate \"banner image\" -s auto                   # Auto-select
  
  # Quality options (affects detail and credits)
  pixie generate \"minimalist logo\" -q low -n 10 -o logos/   # ~4-6 credits each
  pixie generate \"product photo\" -q medium                  # ~16-24 credits
  pixie generate \"detailed artwork\" -q high -s landscape    # ~78-94 credits
  pixie generate \"quick sketch\" -q auto                     # AI selects (4-94)
  
  # Output directory
  pixie generate \"nature scene\" -o ~/Pictures/
  pixie generate \"test image\" -o .                        # Current directory
  pixie generate \"wallpaper\" -o /tmp/images/
  
  # Complex prompts
  pixie generate \"A steampunk owl wearing goggles, highly detailed, 4k\"
  pixie generate \"Minimalist japanese ink painting of mountains\"
  
  # Advanced features
  pixie generate \"logo\" -b transparent -f png             # Transparent background
  pixie generate \"product photo\" -b white -c 85 -f jpeg   # White bg, compressed
  pixie generate \"artwork\" --moderation low               # Less restrictive
  
  # All parameters
  pixie generate \"futuristic car\" -n 3 -s landscape -q high -o ./cars/

PARAMETERS:
  -n, --number    Number of images (1-10, default: 1)
  -s, --size      Size: square, landscape, portrait, auto
  -b, --background Background: auto, transparent, white, black
  -f, --format    Output: png, jpeg, webp
  -c, --compress  Compression: 0-100 (JPEG/WebP only)
  -q, --quality   Quality: low, medium, high, auto
  -o, --output    Save directory (optional)
  --moderation    Strictness: auto (default), low

CREDIT COSTS:
  Low:    ~4-6 credits per image
  Medium: ~16-24 credits per image
  High:   ~62-94 credits per image (varies by size)
  Auto:   ~4-94 credits (AI selects based on prompt)")]
    Generate {
        #[arg(help = "Text description of the image you want to create")]
        prompt: String,
        
        #[arg(short, long, default_value = "1", help = "Number of images to generate (1-10)")]
        number: u8,
        
        #[arg(short, long, default_value = "auto", help = "Size: square, landscape, portrait, auto, or dimensions (1024x1024)")]
        size: String,
        
        #[arg(short, long, default_value = "auto", help = "Output quality (low, medium, high, auto)")]
        quality: String,
        
        #[arg(short, long, help = "Directory to save generated images")]
        output: Option<String>,
        
        #[arg(short = 'b', long, help = "Background style (auto, transparent, white, black)")]
        background: Option<String>,
        
        #[arg(short = 'f', long, help = "Output format (png, jpeg, webp)")]
        format: Option<String>,
        
        #[arg(short = 'c', long, help = "Compression level for JPEG/WebP (0-100)")]
        compress: Option<u8>,
        
        #[arg(long, help = "Moderation level (auto, low)")]
        moderation: Option<String>,
    },
    
    #[command(about = "Edit existing images with AI

Examples:
  pixie edit photo.png \"add a rainbow\"
  pixie edit gallery:abc-123 \"add neon lights\" -o .
  pixie edit banner.jpg \"enhance colors\" -s landscape -q high
  pixie edit portrait.png \"add glasses\" --fidelity high
  pixie edit logo.png \"3D effect\" -n 3 -o variations/

For more examples and detailed usage, use: pixie edit --help", long_about = "Transform existing images using AI-powered editing.

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
  
  # Size options (using aliases)
  pixie edit icon.png \"higher resolution\" -s square
  pixie edit banner.jpg \"resize and enhance\" -s landscape
  
  # Quality variations (affects credits)
  pixie edit sketch.png \"quick colorize\" -q low              # ~7 credits
  pixie edit photo.jpg \"enhance details\" -q medium           # ~16 credits
  pixie edit artwork.png \"ultra HD version\" -q high -s landscape  # ~98-110 credits
  
  # Output directories
  pixie edit input.png \"artistic style\" -o ~/Pictures/
  pixie edit photo.jpg \"variations\" -n 4 -o ./results/
  
  # Complex edits
  pixie edit room.jpg \"add modern furniture, warm lighting, plants\"
  pixie edit car.png \"change color to red, add racing stripes, sporty wheels\"
  
  # High fidelity (preserve face/logo details)
  pixie edit portrait.jpg \"add company logo to shirt\" --fidelity high
  pixie edit product.png \"change background, keep logo sharp\" --fidelity high
  
  # All parameters
  pixie edit photo.png \"dramatic lighting\" -m mask.png -n 3 -s portrait -q high -o edits/

PARAMETERS:
  image           Local path or gallery:<id>
  prompt          Description of changes
  -m, --mask      Mask image (transparent = edit area)
  -n, --number    Number of variations (1-10, default: 1)
  -s, --size      Output size (same as generate)
  -q, --quality   Output quality (same as generate)
  --fidelity      Input preservation: low (default), high
  -o, --output    Save directory

CREDIT COSTS:
  Base edit cost + quality cost:
  Low:    ~7 credits (4 base + 3 input)
  Medium: ~16 credits (13 base + 3 input)
  High:   ~72-110 credits (varies by size)
  Auto:   ~23-36 credits (varies by size)")]
    Edit {
        #[arg(help = "Local image path or gallery:<id> for gallery images")]
        image: String,
        
        #[arg(help = "Description of how to transform the image")]
        prompt: String,
        
        #[arg(short, long, help = "Mask image path (transparent areas will be edited)")]
        mask: Option<String>,
        
        #[arg(short, long, default_value = "1", help = "Number of edited variations (1-10)")]
        number: u8,
        
        #[arg(short, long, default_value = "auto", help = "Size: square, landscape, portrait, auto, or dimensions")]
        size: String,
        
        #[arg(short, long, default_value = "auto", help = "Output quality (low, medium, high, auto)")]
        quality: String,
        
        #[arg(long, default_value = "low", help = "Input fidelity: low, high (preserves more detail)")]
        fidelity: String,
        
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