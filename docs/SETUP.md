# Self-Hosting Setup Guide

This guide will help you deploy your own instance of the OpenAI Image Proxy on Cloudflare Workers.

## Prerequisites

- A Cloudflare account
- Node.js and npm installed
- Rust toolchain (for development)
- An OpenAI API key (optional for self-hosted mode)

## Step 1: Clone and Configure

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/pixie.git
   cd pixie
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Copy the example configuration:
   ```bash
   cp wrangler.toml.example wrangler.toml
   ```

## Step 2: Set Up Cloudflare Resources

### Create a D1 Database

```bash
npx wrangler d1 create openai-image-proxy
```

Note the database ID and update it in your `wrangler.toml`:
```toml
[[d1_databases]]
binding = "DB"
database_name = "openai-image-proxy"
database_id = "your-database-id-here"
```

### Create an R2 Bucket

```bash
npx wrangler r2 bucket create openai-image-proxy-images
```

Update your `wrangler.toml`:
```toml
[[r2_buckets]]
binding = "IMAGES"
bucket_name = "openai-image-proxy-images"
```

### Initialize the Database

```bash
npx wrangler d1 execute openai-image-proxy --file=migrations/001_schema.sql
```

## Step 3: Configure OAuth (Optional)

If you want to use OAuth authentication, you'll need to register OAuth applications:

### GitHub OAuth
1. Go to https://github.com/settings/developers
2. Create a new OAuth App
3. Set the callback URL to: `https://your-worker.workers.dev/v1/auth/github/callback`
4. Update `GITHUB_CLIENT_ID` in `wrangler.toml`
5. Set the client secret: `npx wrangler secret put GITHUB_CLIENT_SECRET`

### Google OAuth
1. Go to https://console.cloud.google.com/
2. Create a new project or select existing
3. Enable Google+ API
4. Create OAuth 2.0 credentials:
   - Web application (for web flow)
   - TV and Limited Input devices (for CLI)
5. Update `GOOGLE_CLIENT_ID` and `GOOGLE_DEVICE_CLIENT_ID` in `wrangler.toml`
6. Set the secrets:
   ```bash
   npx wrangler secret put GOOGLE_CLIENT_SECRET
   npx wrangler secret put GOOGLE_DEVICE_CLIENT_SECRET
   ```

## Step 4: Configure Deployment Mode

### Option A: Self-Hosted with User's OpenAI Keys
Users provide their own OpenAI API keys with each request:

```toml
[vars]
DEPLOYMENT_MODE = "self-hosted"
REQUIRE_OWN_OPENAI_KEY = "true"
```

### Option B: Self-Hosted with Your OpenAI Key
You provide the OpenAI API key for all users:

```toml
[vars]
DEPLOYMENT_MODE = "self-hosted"
REQUIRE_OWN_OPENAI_KEY = "false"
```

Then set your OpenAI API key:
```bash
npx wrangler secret put OPENAI_API_KEY
```

## Step 5: Update Service URLs

Update the service URLs in `wrangler.toml` to match your deployment:

```toml
SERVICE_URL = "https://your-worker.workers.dev"
API_BASE_URL = "https://your-worker.workers.dev"
```

## Step 6: Deploy

```bash
npx wrangler deploy
```

## Step 7: Using the CLI

### Install the CLI
```bash
cd cli
cargo install --path .
```

### Configure the CLI
Set the API endpoint to your deployment:
```bash
export PIXIE_API_URL="https://your-worker.workers.dev"
```

Or pass it directly:
```bash
pixie --api-url https://your-worker.workers.dev auth github
```

### For Self-Hosted Mode with User Keys
When making requests, include your OpenAI API key:
```bash
# This would need to be implemented in the CLI
pixie generate "A cute cat" --openai-key "sk-..."
```

## Security Considerations

1. **API Keys**: Never commit API keys to the repository
2. **CORS**: Configure CORS headers if needed for web access
3. **Rate Limiting**: Consider implementing rate limiting for production use
4. **Usage Tracking**: Monitor your Cloudflare Workers usage and costs

## Deployment Modes Explained

### Official Mode
- Used for the official hosted service
- Users authenticate via OAuth
- Server provides the OpenAI API key
- Usage is tracked and may be limited

### Self-Hosted Mode
- For individuals/organizations hosting their own instance
- Can require users to provide their own OpenAI keys
- Full control over the deployment
- No usage limits from the service itself

## Troubleshooting

### Database Issues
If you get foreign key errors, ensure all tables are created:
```bash
npx wrangler d1 execute openai-image-proxy --file=migrations/001_schema.sql --remote
```

### Authentication Issues
- Ensure OAuth credentials are correctly configured
- Check that callback URLs match your deployment
- Verify secrets are set correctly

### Image Storage Issues
- Ensure R2 bucket is created and accessible
- Check that the bucket binding matches in wrangler.toml

## Support

For issues and questions:
- Open an issue on GitHub
- Check the [API documentation](./API.md)
- Review the example scripts in the `examples/` directory