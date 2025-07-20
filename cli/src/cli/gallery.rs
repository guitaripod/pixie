use clap::Subcommand;

#[derive(Subcommand)]
pub enum GalleryAction {
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