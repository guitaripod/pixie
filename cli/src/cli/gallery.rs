use clap::{Subcommand, ValueEnum};

#[derive(Clone, Copy, ValueEnum)]
pub enum VisibilityState {
    Public,
    Private,
}

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

    #[command(about = "Delete one of your images

Example:
  pixie gallery delete abc-123-def", long_about = "Permanently delete one of your own images.

This removes the image from storage, from your gallery,
and from the public gallery feed. It cannot be undone.
You can only delete images you created.

EXAMPLES:
  pixie gallery delete abc-123-def      # Delete a specific image")]
    Delete {
        #[arg(help = "Image ID to delete (must be yours)")]
        id: String,
    },

    #[command(about = "Show or hide one of your images in the public gallery

Examples:
  pixie gallery visibility abc-123 private
  pixie gallery visibility abc-123 public", long_about = "Control whether one of your images appears in the public gallery feed.

Set to 'private' to remove it from the public feed without deleting it,
or 'public' to share it again. You can only change images you created.

EXAMPLES:
  pixie gallery visibility abc-123-def private   # Hide from public feed
  pixie gallery visibility abc-123-def public    # Show in public feed")]
    Visibility {
        #[arg(help = "Image ID to update (must be yours)")]
        id: String,

        #[arg(value_enum, help = "public or private")]
        state: VisibilityState,
    },

    #[command(name = "share-all", about = "Show or hide ALL of your images in the public gallery

Examples:
  pixie gallery share-all private
  pixie gallery share-all public", long_about = "Set every image you own to public or private in one go.

Use 'private' to pull all of your creations out of the public gallery feed
(for example after opting out of sharing), or 'public' to share them all.

EXAMPLES:
  pixie gallery share-all private   # Remove all your images from the public feed
  pixie gallery share-all public    # Share all your images in the public feed")]
    ShareAll {
        #[arg(value_enum, help = "public or private")]
        state: VisibilityState,
    },
}