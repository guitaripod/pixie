# Gemini Model Implementation Checklist

## Context for AI Agents
This document outlines the integration of Google's Gemini 2.5 Flash Image Preview model into the Pixie image generation platform. Pixie is a Cloudflare Worker-based backend with three clients (CLI, Android, iOS) that currently only supports OpenAI's GPT-Image-1 model. 

**Key Context:**
- The app is NOT yet released, so breaking changes are acceptable
- Gemini should become the DEFAULT model (simpler, cheaper)
- OpenAI remains as an optional "advanced" mode with more parameters
- No migration needed - we can completely redesign the schema
- Gemini API is much simpler: just takes a prompt, returns base64 image
- The UI should dramatically simplify when Gemini is selected (no size, quality, background options)

**Gemini API Reference:**
```bash
# Text-to-image
curl -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image-preview:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"contents": [{"parts": [{"text": "prompt here"}]}]}'

# Image editing (text + image input)
curl -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image-preview:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"contents": [{"parts": [{"text": "edit prompt"}, {"inline_data": {"mime_type": "image/jpeg", "data": "base64_data"}}]}]}'

# Response format: JSON with base64 image in response.candidates[0].content.parts[0].inline_data.data
```

## Overview
Integrate Google Gemini 2.5 Flash as the default image generation model, with OpenAI GPT as an optional alternative.

## Phase 1: Backend Core Infrastructure ✅
- [x] Create provider abstraction layer (`/src/providers/`)
  - [x] Define `ImageProvider` trait in `providers/mod.rs`
  - [x] Implement `GeminiProvider` in `providers/gemini.rs`
  - [x] Refactor existing OpenAI code into `providers/openai.rs`
  - [x] Add provider factory/selector logic
- [x] Update database schema (`migrations/`)
  - [x] Drop and recreate tables with new schema
  - [x] Add `provider` column to relevant tables
  - [x] Add `gemini_api_key` to users table
  - [x] Set `preferred_model` default to 'gemini-2.5-flash'
- [x] Add Gemini API integration
  - [ ] Add `GEMINI_API_KEY` to Cloudflare secrets (deployment step)
  - [x] Implement Gemini API client
  - [x] Handle base64 image responses
  - [x] Convert Gemini response format to unified format
- [x] Update credit calculation
  - [ ] Implement flat-rate Gemini pricing (~3 credits/image)
  - [ ] Add provider-specific cost calculation
  - [ ] Update estimation logic

## Phase 2: API Layer Updates
- [x] Modify request handlers (`/src/handlers/images_v2.rs`)
  - [x] Update validation to accept both models
  - [x] Route requests to appropriate provider
  - [x] Make OpenAI-specific fields optional
  - [x] Set Gemini as default when model not specified
- [x] Update request/response structures
  - [x] Add `model` field validation
  - [x] Handle provider-specific parameters
  - [x] Ensure backwards compatibility
- [x] Error handling
  - [x] Add Gemini-specific error messages
  - [x] Update moderation handling for Gemini
  - [x] Unified error response format

## Phase 3: CLI Implementation ✅
- [x] Update CLI argument parser (`cli/src/main.rs`)
  - [x] Add `--model` flag (default: gemini)
  - [x] Simplify UI when Gemini selected
  - [x] Update help text to reflect Gemini as default
- [x] Modify API client (`cli/src/api.rs`)
  - [x] Include model in API requests
  - [x] Handle provider-specific UI display
  - [x] Update progress messages
- [x] Settings management
  - [x] Add `model` to config file
  - [x] Create `settings model` subcommand
  - [x] Update config initialization with Gemini default
- [ ] Update CLI documentation
  - [ ] Update README examples
  - [ ] Add model selection examples
  - [ ] Document feature differences

## Phase 4: Android App Updates
- [ ] API Service (`PixieApiService.kt`)
  - [ ] Add model parameter to API calls
  - [ ] Update data models for optional OpenAI fields
  - [ ] Handle provider-specific responses
- [ ] Settings Screen
  - [ ] Add model selector (RadioGroup/Dropdown)
  - [ ] Store selection in SharedPreferences
  - [ ] Default to Gemini for new installs
- [ ] Generation UI (`GenerateFragment.kt`)
  - [ ] Hide OpenAI options when Gemini selected
  - [ ] Simplify UI for Gemini mode
  - [ ] Update credit estimation display
- [ ] Gallery/History
  - [ ] Display which model was used
  - [ ] Update image metadata display

## Phase 5: iOS App Updates
- [ ] API Service (`APIService.swift`)
  - [ ] Add model parameter to requests
  - [ ] Update model structs for optional fields
  - [ ] Handle provider-specific responses
- [ ] Settings View (`SettingsView.swift`)
  - [ ] Add model picker (Gemini default)
  - [ ] Store in UserDefaults
  - [ ] Animate option visibility changes
- [ ] Generate View
  - [ ] Conditionally render OpenAI options
  - [ ] Simplified interface for Gemini
  - [ ] Update credit estimation
- [ ] Gallery View
  - [ ] Show model used for each image
  - [ ] Update detail view

## Phase 6: Testing & Validation
- [ ] Backend Testing
  - [ ] Test Gemini API integration
  - [ ] Verify credit calculations
  - [ ] Test provider switching
  - [ ] Validate error handling
- [ ] CLI Testing
  - [ ] Generate images with both models
  - [ ] Test model switching
  - [ ] Verify settings persistence
  - [ ] Test edit functionality (if supported)
- [ ] Android Testing
  - [ ] Test UI adaptation
  - [ ] Verify settings persistence
  - [ ] Test generation with both models
  - [ ] Check offline behavior
- [ ] iOS Testing
  - [ ] Test UI transitions
  - [ ] Verify settings sync
  - [ ] Test both providers
  - [ ] Validate SwiftUI updates

## Phase 7: Documentation & Deployment
- [ ] Update CLAUDE.md
  - [ ] Add Gemini-specific commands
  - [ ] Update testing notes
  - [ ] Document model differences
- [ ] Update API documentation
  - [ ] Document model parameter
  - [ ] List provider-specific fields
  - [ ] Add Gemini examples
- [ ] Deployment
  - [ ] Set `GEMINI_API_KEY` secret in Cloudflare
  - [ ] Deploy backend with `wrangler deploy`
  - [ ] Update database schema in production
  - [ ] Test production endpoints
- [ ] Client Releases
  - [ ] Build and test CLI binary
  - [ ] Build Android APK
  - [ ] Build iOS IPA
  - [ ] Test on real devices

## Key Implementation Notes

### Default Behavior
- Gemini is the default model when not specified
- New users automatically use Gemini
- Simplified UI is the primary experience

### Schema Changes (Clean Slate)
```sql
-- Users table
preferred_model TEXT DEFAULT 'gemini-2.5-flash'
gemini_api_key TEXT
openai_api_key TEXT  -- Renamed from api_key

-- Stored images
provider TEXT NOT NULL DEFAULT 'gemini'
model TEXT NOT NULL

-- Usage records
provider TEXT NOT NULL
simplified_cost BOOLEAN DEFAULT true  -- Gemini uses flat rate
```

### Provider-Specific Features
**Gemini** (Default):
- Simple prompt input only
- Flat-rate pricing (~3 credits)
- Text-to-image and image editing
- No quality/size/style options

**OpenAI** (Optional):
- All existing features
- Complex pricing model
- Multiple quality levels
- Size options
- Background styles
- Moderation settings

### Breaking Changes (Acceptable)
- Database schema completely revised
- Default model changed to Gemini
- API key field renamed for clarity
- Simplified UI is now default