# OpenAI Image Proxy - Open Source Notes

## For Contributors and Self-Hosters

This project is designed to be fully self-hostable on Cloudflare Workers while maintaining a centralized official deployment.

### Important Files

- **wrangler.toml** - Contains the official deployment configuration. DO NOT commit changes to this file if you're contributing.
- **wrangler.toml.example** - Template for self-hosted deployments. Update this if adding new configuration options.
- **SETUP.md** - Comprehensive self-hosting guide

### Architecture

The codebase supports two deployment modes:

1. **Official Mode** (`DEPLOYMENT_MODE = "official"`)
   - Used for the official hosted service at https://openai-image-proxy.guitaripod.workers.dev
   - Server provides OpenAI API key
   - OAuth authentication required
   - Usage tracking and potential limits

2. **Self-Hosted Mode** (`DEPLOYMENT_MODE = "self-hosted"`)
   - For individuals/organizations running their own instance
   - Can require users to provide their own OpenAI API keys
   - Full control over the deployment
   - No service-imposed usage limits

### Key Design Decisions

1. **Everything on Cloudflare**: The entire stack runs on Cloudflare Workers, D1, and R2
2. **Multi-tenant Ready**: Single codebase supports multiple deployment configurations
3. **API Key Flexibility**: Self-hosted instances can choose whether to require user-provided OpenAI keys
4. **Environment-based Configuration**: All deployment-specific values use environment variables

### Contributing

When contributing:
- Test with a self-hosted deployment
- Don't modify wrangler.toml (use wrangler.toml.example for config changes)
- Ensure changes work in both official and self-hosted modes
- Add new environment variables to both wrangler.toml.example and SETUP.md

### Security Considerations

- Never commit API keys or secrets
- OAuth client IDs in wrangler.toml are public (secrets are stored separately)
- Self-hosters must register their own OAuth applications
- The official deployment's OAuth apps only work with the official domain

### Local Development

1. Copy wrangler.toml.example to wrangler.toml
2. Update with your own values
3. Run `npx wrangler dev` for local development
4. Use `DEPLOYMENT_MODE = "self-hosted"` for testing