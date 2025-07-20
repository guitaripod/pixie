# OpenAI Image Proxy - Pricing Model

## Overview

Our service uses a simple credit-based pricing system where **1 credit = $0.01 USD**. Credits are deducted based on actual token usage from OpenAI's gpt-image-1 model, ensuring fair and transparent pricing.

## How Pricing Works

### Token-Based Calculation

We calculate costs based on OpenAI's token pricing:
- Text input tokens: $5.00 per 1M tokens
- Image input tokens: $10.00 per 1M tokens  
- Image output tokens: $40.00 per 1M tokens

Your credit cost = (Actual OpenAI cost × 3.0) rounded up to the nearest credit

The 3x multiplier covers:
- Infrastructure costs (Cloudflare Workers, R2 storage, D1 database)
- Service maintenance and development
- Sustainable profit margin

### Typical Credit Costs

| Quality | Size | Typical Credits | USD Cost | Use Case |
|---------|------|-----------------|----------|----------|
| Low | 1024×1024 | 3-5 | $0.03-0.05 | Quick drafts, thumbnails |
| Medium | 1024×1024 | 12-15 | $0.12-0.15 | Social media, web content |
| High | 1024×1024 | 50-55 | $0.50-0.55 | Print quality, detailed art |
| High | 1536×1024 | 75-80 | $0.75-0.80 | Wide format, banners |

**Image Editing**: Add 2-5 credits for input image processing

*Note: Actual costs vary slightly based on prompt complexity and length*

## Credit Packs

| Pack | Credits | Price | Bonus | Value |
|------|---------|-------|-------|-------|
| **Starter** | 100 | $1.99 | - | ~20 low or 7 medium images |
| **Basic** | 550 | $7.99 | 50 (10%) | ~40 medium images |
| **Popular** ⭐ | 1,800 | $19.99 | 300 (20%) | ~120 medium images |
| **Pro** | 4,500 | $39.99 | 1,000 (40%) | ~300 medium images |
| **Enterprise** | 11,000 | $79.99 | 3,000 (60%) | ~730 medium images |


## Cost Comparison

### vs Direct OpenAI API
- **OpenAI**: Requires API key setup, technical knowledge, pay-as-you-go billing
- **Our Service**: Simple credit system, no setup required, includes storage & CDN

### vs Subscription Services
- **ChatGPT Plus**: $20/month with usage limits
- **Midjourney**: $10-120/month subscription required
- **Our Service**: No subscription, pay only for what you use

### Example Monthly Costs

| Usage Level | Images/Month | Estimated Cost |
|-------------|--------------|----------------|
| Casual | 50 medium | ~$7.50 |
| Regular | 200 medium | ~$30 |
| Power User | 500 medium | ~$75 |
| Business | 1000+ medium | ~$150+ |

## Features Included

Every credit purchase includes:
- ✅ Instant image generation via API
- ✅ 7-day cloud storage for all images
- ✅ CDN delivery for fast access
- ✅ Gallery and history tracking
- ✅ RESTful API compatible with OpenAI
- ✅ No monthly fees or subscriptions
- ✅ Usage analytics and reporting

## API Endpoints

### Check Credit Balance
```
GET /v1/credits/balance
Authorization: Bearer <your-api-key>
```

### Estimate Image Cost
```
POST /v1/credits/estimate
{
  "prompt": "Your prompt here",
  "quality": "medium",
  "size": "1024x1024"
}
```

### View Pricing
```
GET /v1/credits/pricing
```

### Purchase Credits
```
POST /v1/credits/purchase
{
  "pack_id": "popular",
  "payment_method": "stripe"
}
```

## Billing Details

### Payment Methods
- Credit/Debit cards via Stripe
- No subscription required
- Secure payment processing

### Credit Expiration
- Credits never expire
- No monthly minimums
- Use at your own pace

### Refund Policy
- Unused credits refundable within 14 days
- No refunds for used credits
- Contact support for issues

## Business Model Transparency

We believe in transparent pricing. Here's how our 3x multiplier breaks down:

| Component | Percentage |
|-----------|------------|
| OpenAI API costs | 33.3% |
| Infrastructure & Storage | 5% |
| Payment processing | 3% |
| Development & Maintenance | 20% |
| Profit margin | 38.7% |

This ensures sustainable service while keeping prices fair for users.

## Questions?

- **Email**: support@your-domain.com
- **API Status**: https://status.your-domain.com
- **Documentation**: https://docs.your-domain.com

---

*Last updated: January 2025*