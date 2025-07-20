use clap::Subcommand;

#[derive(Subcommand)]
pub enum AdminAction {
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
pub enum AdminCreditsAction {
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