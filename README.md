# Pixie - AI Image Generation Platform

A high-performance monorepo containing the Pixie AI image generation service built on OpenAI's gpt-image-1 model. Includes a Rust-based Cloudflare Worker backend, command-line interface, Android app, and iOS app (coming soon).

## Quick Links

- [Backend API](https://openai-image-proxy.guitaripod.workers.dev)
- [CLI Client](#cli-client)
- [Android App](#android-app)
- [API Documentation](#backend-api)

## Components

<details>
<summary><b>Backend API</b></summary>

### Overview
High-performance Rust-based Cloudflare Worker that provides OpenAI-compatible image generation with enhanced features:
- Automatic image storage in Cloudflare R2
- Usage tracking and analytics
- Public galleries
- Credit-based billing system
- OAuth authentication (GitHub, Google, Apple*)

*Apple Sign In not supported on Windows servers

### Architecture
- **Runtime**: Cloudflare Workers (Rust/WASM)
- **Database**: Cloudflare D1 (SQLite)
- **Storage**: Cloudflare R2 (S3-compatible)
- **Language**: Rust with worker-rs

### Deployment Modes

#### Official Mode (Hosted Service)
- Managed credit system with payment processing
- No OpenAI API key required from users
- Automatic usage tracking and billing

#### Self-Hosted Mode
- Users provide their own OpenAI API keys
- No credit system or payment processing
- Direct pass-through to OpenAI API

### Quick Setup

1. **Clone and install dependencies**
   ```bash
   git clone https://github.com/guitaripod/openai-image-proxy.git
   cd openai-image-proxy
   npm install
   cargo install worker-build
   ```

2. **Configure Cloudflare resources**
   ```bash
   # Create database
   npx wrangler d1 create openai-image-proxy
   
   # Apply migrations
   npx wrangler d1 migrations apply DB --local
   
   # Create R2 bucket
   npx wrangler r2 bucket create openai-image-proxy-images
   ```

3. **Set secrets**
   ```bash
   npx wrangler secret put OPENAI_API_KEY
   npx wrangler secret put GITHUB_CLIENT_SECRET
   npx wrangler secret put GOOGLE_CLIENT_SECRET
   # See docs/ENVIRONMENT_VARIABLES.md for complete list
   ```

4. **Deploy**
   ```bash
   npx wrangler deploy
   ```

### API Endpoints

#### Image Generation
```bash
POST /v1/images/generations
Authorization: Bearer <api-key>

{
  "model": "gpt-image-1",
  "prompt": "A serene mountain landscape",
  "size": "1024x1024",
  "quality": "high"
}
```

#### Image Editing
```bash
POST /v1/images/edits
Authorization: Bearer <api-key>
Content-Type: multipart/form-data

image: <file>
mask: <file> (optional)
prompt: "Add a sunset"
```

#### Other Endpoints
- `GET /v1/images` - Browse public gallery
- `GET /v1/credits/balance` - Check credit balance
- `POST /v1/credits/purchase` - Buy credit packs
- `POST /v1/auth/device/code` - Start device auth flow

Full API documentation: [docs/API.md](docs/API.md)

</details>

<details>
<summary><b>CLI Client</b></summary>

### Installation
```bash
cd cli
cargo install --path .
# Installs as 'pixie'
```

### Authentication
```bash
# OAuth providers
pixie auth github
pixie auth google
pixie auth apple  # Not supported on Windows

# Check status
pixie config
```

### Image Generation
```bash
# Basic generation
pixie generate "A beautiful sunset"

# Advanced options
pixie generate "product photo" \
  -s landscape \      # Size: square, landscape, portrait
  -q medium \         # Quality: low (4-6 credits), medium (16-24), high (62-94)
  -n 3 \              # Generate 3 images
  -b white \          # Background: auto, transparent, white, black
  -f jpeg \           # Format: png, jpeg, webp
  -c 85 \             # Compression (0-100)
  -o ./images         # Output directory
```

### Image Editing
```bash
# Edit local image
pixie edit photo.png "add company logo" --fidelity high

# Edit from gallery
pixie edit gallery:abc123 "enhance colors" -s landscape
```

### Credit Management
```bash
pixie credits              # Check balance
pixie credits history      # Transaction history
pixie credits packs        # Available packs
pixie credits estimate -q high -s 1024x1024  # Cost estimation
```

### Gallery
```bash
pixie gallery list         # Browse public images
pixie gallery mine         # Your images
pixie gallery view <id>    # Image details
```

### Other Commands
```bash
pixie usage --detailed     # API usage statistics
pixie health               # Check service status
pixie admin stats          # Admin only
```

</details>

<details>
<summary><b>Android App</b></summary>

### Overview
Native Android application built with Kotlin and Jetpack Compose, providing a mobile interface for Pixie AI image generation.

### Features
- **Image Generation**: Chat-based interface with batch generation (1-10 images)
- **Image Editing**: Upload and modify existing images with AI
- **Gallery**: Browse public and personal galleries with download/share options
- **Credits**: Balance tracking, usage dashboard, and in-app purchases
- **Authentication**: OAuth with GitHub, Google, and Apple
- **Admin Panel**: System statistics and user management (admin only)

### Technical Stack
- **Language**: Kotlin
- **UI**: Jetpack Compose with Material Design 3
- **Architecture**: MVVM with Clean Architecture
- **Networking**: Retrofit + OkHttp + Moshi
- **Image Loading**: Coil
- **Payments**: RevenueCat
- **Min SDK**: 24 (Android 7.0)
- **Target SDK**: 34 (Android 14)

### Building from Source
```bash
cd android
./gradlew assembleDebug
# APK will be in app/build/outputs/apk/debug/
```

### Configuration
1. Add your OAuth client IDs to `local.properties`:
   ```properties
   GOOGLE_OAUTH_CLIENT_ID=your-client-id
   ```

2. Configure RevenueCat for in-app purchases

3. Update the API endpoint in build configuration if using self-hosted backend

### Play Store
Coming soon - currently in final testing phase.

</details>

<details>
<summary><b>iOS App</b></summary>

### Status: In Development

The iOS app is currently being developed and will provide feature parity with the Android app:
- SwiftUI interface
- Native iOS design patterns
- Same core features as Android
- Universal app for iPhone and iPad

Check back soon for updates!

</details>

<details>
<summary><b>Development</b></summary>

### Local Development

#### Backend
```bash
# Run with hot reload
npx wrangler dev

# Watch logs
npx wrangler tail

# Run with cargo watch
cargo watch -s "npx wrangler dev"
```

#### CLI
```bash
cd cli
cargo run -- generate "test prompt" -q low
```

#### Android
```bash
cd android
./gradlew installDebug
```

### Testing
- Backend: Test with CLI (`cd cli && cargo run -- [args]`)
- Cost optimization: Always use `--quality low` for testing (4-5 credits vs 50-80)
- Database: Check locks in `user_locks` table if requests hang

### Common Commands
```bash
# Apply database migrations
npx wrangler d1 execute openai-image-proxy --file=migrations/001_schema.sql --remote

# Update secrets (never use config files)
npx wrangler secret put OPENAI_API_KEY

# Check service health
curl https://your-worker.workers.dev/
```

### Project Structure
```
├── src/                # Backend source
├── cli/                # CLI application
├── android/            # Android app
├── ios/                # iOS app (coming soon)
├── migrations/         # Database schemas
├── docs/               # Documentation
└── wrangler.toml      # Worker configuration
```

</details>

<details>
<summary><b>Pricing</b></summary>

### Credit System
Images cost credits based on quality and complexity (prices don't include platform taxes):

| Quality | Typical Cost | USD Equivalent |
|---------|--------------|----------------|
| Low | 4-6 credits | $0.04-0.06 |
| Medium | 16-24 credits | $0.16-0.24 |
| High | 62-94 credits | $0.62-0.94 |

### Credit Packs

| Pack | Credits | Price | Bonus |
|------|---------|-------|-------|
| Starter | 150 | $2.99 | - |
| Basic | 500 | $9.99 | 5% |
| Popular | 1,250 | $24.99 | 10% |
| Pro | 2,500 | $49.99 | 15% |
| Enterprise | 5,000 | $99.99 | 20% |

### Payment Methods
- **Cards**: All major credit/debit cards via Stripe
- **Crypto**: BTC, ETH, DOGE, LTC (Basic pack and above only)

</details>

## Documentation

- [API Reference](docs/API.md)
- [Environment Variables](docs/ENVIRONMENT_VARIABLES.md)
- [Setup Guide](docs/SETUP.md)
- [Pricing Details](docs/pricing.md)

## Contributing

Contributions welcome! Please submit pull requests.

## License

GPL-3.0
