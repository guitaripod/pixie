use clap::Subcommand;

#[derive(Subcommand)]
pub enum CreditsAction {
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
    
    #[command(about = "Buy credits with cryptocurrency
    
Examples:
  pixie credits buy
  pixie credits buy --pack popular --crypto btc", long_about = "Purchase credits using cryptocurrency (Bitcoin, Ethereum, or Dogecoin).

Supports:
  - Bitcoin (BTC)
  - Ethereum (ETH)
  - Dogecoin (DOGE)
  - Lightning Network (instant BTC)

The CLI will:
  1. Show available credit packs
  2. Let you choose payment cryptocurrency
  3. Display payment address and QR code
  4. Monitor for payment confirmation
  5. Automatically credit your account

EXAMPLES:
  pixie credits buy                           # Interactive mode
  pixie credits buy --pack popular            # Buy popular pack
  pixie credits buy --pack pro --crypto btc   # Buy pro pack with Bitcoin")]
    Buy {
        #[arg(short, long, help = "Credit pack to purchase (starter, basic, popular, pro, enterprise)")]
        pack: Option<String>,
        
        #[arg(short, long, help = "Cryptocurrency to use (btc, eth, doge, ltc, lightning)")]
        crypto: Option<String>,
    },
}