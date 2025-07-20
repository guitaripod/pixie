# OpenAI Image Proxy

A high-performance Rust-based Cloudflare Worker that proxies OpenAI's gpt-image-1 model with enhanced features like automatic image storage, usage tracking, and public galleries.

## Features

- **OpenAI API Compatibility**: Full compatibility with OpenAI's gpt-image-1 image generation and editing APIs
- **Automatic Image Storage**: All generated images stored in Cloudflare R2 with public URLs
- **Usage Tracking**: Comprehensive usage analytics with D1 database
- **Public Gallery**: Browse all generated images with their prompts
- **High Performance**: Built with Rust for optimal WASM performance
- **Image Serving**: Direct image access through worker URLs
- **Credits System**: Token-based pricing with transparent credit packs
- **Device Authentication**: OAuth device flow for CLI and mobile apps
- **Multiple Deployment Modes**: Official hosted service or self-hosted options

## Architecture

- **Runtime**: Cloudflare Workers (Rust/WASM)
- **Database**: Cloudflare D1 (SQLite)
- **Storage**: Cloudflare R2 (S3-compatible)
- **Language**: Rust with worker-rs

## Current Status

✅ **Implemented:**
- gpt-image-1 image generation endpoint
- Image editing endpoint
- R2 storage with public URL access
- D1 database integration
- Public gallery endpoints
- Usage tracking and analytics
- OAuth authentication (~~Apple~~(soon), GitHub, Google)
- Admin dashboard in CLI

🚧 **Planned:**
- Rate limiting
- Streaming responses

## Deployment Modes

The service supports two deployment modes:

### Official Mode (Hosted Service)
- Managed credit system with payment processing
- No OpenAI API key required from users
- Automatic usage tracking and billing
- Suitable for SaaS deployment

### Self-Hosted Mode
- Users provide their own OpenAI API keys
- No credit system or payment processing
- Direct pass-through to OpenAI API
- Suitable for personal or enterprise deployment

Set the deployment mode in your environment:
```bash
npx wrangler secret put DEPLOYMENT_MODE # "official" or "self-hosted"
npx wrangler secret put REQUIRE_OWN_OPENAI_KEY # "true" for self-hosted
```

## Quick Start

1. Clone the repository:
```bash
git clone https://github.com/guitaripod/openai-image-proxy.git
cd openai-image-proxy
```

2. Install dependencies:
```bash
npm install
cargo install worker-build
```

3. Configure your `wrangler.toml` with your Cloudflare account details (see [docs/wrangler.toml.example](docs/wrangler.toml.example))

4. Create the D1 database:
```bash
npx wrangler d1 create openai-image-proxy
# Update the database_id in wrangler.toml
```

5. Run migrations:
```bash
npx wrangler d1 migrations apply DB --local
```

6. Create R2 bucket:
```bash
npx wrangler r2 bucket create openai-image-proxy-images
```

7. Set secrets:
```bash
npx wrangler secret put OPENAI_API_KEY
npx wrangler secret put JWT_SECRET
# For official mode:
npx wrangler secret put STRIPE_SECRET_KEY
# For OAuth (optional):
npx wrangler secret put GITHUB_CLIENT_SECRET
npx wrangler secret put GOOGLE_CLIENT_SECRET
```

8. Deploy:
```bash
npx wrangler deploy
```

For detailed setup instructions, see [docs/SETUP.md](docs/SETUP.md).

## Credits & Billing

The service uses a credit-based pricing system where **1 credit = $0.01 USD**. Credits are deducted based on actual token usage.

### Typical Credit Costs

| Quality | Size | Credits | USD Cost |
|---------|------|---------|----------|
| Low | 1024×1024 | 3-5 | $0.03-0.05 |
| Medium | 1024×1024 | 12-15 | $0.12-0.15 |
| High | 1024×1024 | 50-55 | $0.50-0.55 |

### Credit Packs

| Pack | Credits | Price | Bonus |
|------|---------|-------|-------|
| Starter | 100 | $1.99 | - |
| Basic | 550 | $7.99 | 50 (10%) |
| Popular | 1,800 | $19.99 | 300 (20%) |
| Pro | 4,500 | $39.99 | 1,000 (40%) |
| Enterprise | 11,000 | $79.99 | 3,000 (60%) |

For detailed pricing information, see [docs/pricing.md](docs/pricing.md).

## API Documentation

### Image Generation

#### Generate Image
```bash
curl -X POST https://your-worker.workers.dev/v1/images/generations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-api-key" \
  -d '{
    "model": "gpt-image-1",
    "prompt": "A serene mountain landscape",
    "size": "1024x1024",
    "quality": "high"
  }'
```

#### Edit Image
```bash
curl -X POST https://your-worker.workers.dev/v1/images/edits \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-api-key" \
  -F image="@original.png" \
  -F mask="@mask.png" \
  -F prompt="Add a sunset to the background"
```

### Gallery & Images

#### Browse Public Gallery
```bash
curl https://your-worker.workers.dev/v1/images
```

#### Get Specific Image
```bash
curl https://your-worker.workers.dev/v1/images/{image_id}
```

### Credits Management

#### Check Balance
```bash
curl https://your-worker.workers.dev/v1/credits/balance \
  -H "Authorization: Bearer your-api-key"
```

#### Estimate Cost
```bash
curl -X POST https://your-worker.workers.dev/v1/credits/estimate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-api-key" \
  -d '{
    "prompt": "Your prompt here",
    "quality": "medium",
    "size": "1024x1024"
  }'
```

#### View Credit Packs
```bash
curl https://your-worker.workers.dev/v1/credits/packs
```

#### Purchase Credits
```bash
curl -X POST https://your-worker.workers.dev/v1/credits/purchase \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-api-key" \
  -d '{
    "pack_id": "popular",
    "payment_method": "stripe"
  }'
```

#### Transaction History
```bash
curl https://your-worker.workers.dev/v1/credits/transactions \
  -H "Authorization: Bearer your-api-key"
```

### Device Authentication

#### Initialize Device Flow
```bash
curl -X POST https://your-worker.workers.dev/v1/auth/device/code \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "your-client-id"
  }'
```

#### Poll for Token
```bash
curl -X POST https://your-worker.workers.dev/v1/auth/device/token \
  -H "Content-Type: application/json" \
  -d '{
    "device_code": "XXXX-XXXX",
    "client_id": "your-client-id"
  }'
```

#### Check Device Auth Status
```bash
curl https://your-worker.workers.dev/v1/auth/device/{device_code}/status
```

### System Status

#### Health Check
```bash
curl https://your-worker.workers.dev/
```

### Admin Endpoints

#### Adjust User Credits (Admin Only)
```bash
curl -X POST https://your-worker.workers.dev/v1/admin/credits/adjust \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer admin-api-key" \
  -d '{
    "user_id": "user123",
    "amount": 100,
    "reason": "Manual adjustment"
  }'
```

#### Credit Statistics (Admin Only)
```bash
curl https://your-worker.workers.dev/v1/admin/credits/stats \
  -H "Authorization: Bearer admin-api-key"
```

## CLI Tool

A comprehensive command-line interface is available for managing the OpenAI Image Proxy service.

### Installation

```bash
cd cli
cargo install --path .
# The CLI will be installed as 'pixie'
```

### Features

- Generate images from the command line
- Manage credits and view balance
- Admin commands for system management
- Device authentication support
- View transaction history
- Comprehensive help documentation

### Basic Usage

```bash
# Authenticate with the service
pixie auth github
# or
pixie auth google

# Generate an image
pixie generate "A beautiful sunset" --quality medium -o ./images

# Edit an image
pixie edit photo.png "add a rainbow" -o ./edited

# Check credit balance
pixie credits

# Check API health
pixie health

# Browse gallery
pixie gallery list

# View help
pixie --help
```

### New Commands

#### Health Check
```bash
# Check if the API is online and responding
pixie health
pixie health --api-url https://custom-api.com
```

#### Device Authentication Status
```bash
# Check the status of a device authentication flow
pixie auth device-status DEVICE-CODE-HERE
```

For detailed CLI documentation, run `pixie help` after installation.

## Development

Run locally:
```bash
npx wrangler dev
```

Run with live reload:
```bash
cargo watch -s "npx wrangler dev"
```

View logs:
```bash
npx wrangler tail
```

## Project Structure

```
├── src/
│   ├── lib.rs              # Main worker entry point
│   ├── handlers/           # Request handlers
│   │   ├── images.rs       # Image generation
│   │   ├── images_edit.rs  # Image editing
│   │   ├── gallery.rs      # Public gallery
│   │   ├── usage.rs        # Usage tracking
│   │   ├── r2.rs           # Image serving
│   │   ├── credits.rs      # Credits management
│   │   ├── device_auth.rs  # Device authentication flow
│   │   └── admin.rs        # Admin endpoints
│   ├── models.rs           # Data models
│   ├── auth.rs             # Authentication
│   ├── credits.rs          # Credits system logic
│   ├── deployment.rs       # Deployment mode configuration
│   ├── storage.rs          # R2 storage
│   └── error.rs            # Error handling
├── cli/                    # CLI application
│   ├── src/                # CLI source code
│   └── Cargo.toml          # CLI dependencies
├── migrations/             # D1 database migrations
├── docs/                   # Documentation
│   ├── pricing.md          # Detailed pricing information
│   ├── SETUP.md            # Setup instructions
│   └── wrangler.toml.example # Example configuration
├── examples/               # Example scripts
└── wrangler.toml          # Worker configuration
```

## Documentation

Additional documentation is available in the [docs/](docs/) directory:

- [Pricing Details](docs/pricing.md) - Comprehensive pricing model and credit system
- [Setup Guide](docs/SETUP.md) - Detailed setup and configuration instructions
- [Example Configuration](docs/wrangler.toml.example) - Sample wrangler.toml configuration

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT
