# Gemini Model Implementation Checklist

## Implementation Status
✅ **Backend Complete**: Provider abstraction, Gemini API integration, credit calculation
✅ **CLI Complete**: Model selection, simplified UI, settings management  
✅ **Android Complete**: Full model support for generation and editing, simplified UI
✅ **Testing Complete**: Both models working, proper credit tracking, multipart fix for OpenAI
✅ **Deployment Complete**: Backend deployed, GEMINI_API_KEY configured
⏳ **iOS Pending**: Still needs implementation

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
  - [x] Add `GEMINI_API_KEY` to Cloudflare secrets (already set)
  - [x] Implement Gemini API client
  - [x] Handle base64 image responses
  - [x] Convert Gemini response format to unified format
- [x] Update credit calculation
  - [x] Implement flat-rate Gemini pricing (15 credits/image)
  - [x] Add provider-specific cost calculation
  - [x] Update estimation logic

## Phase 2: API Layer Updates ✅
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

## Phase 4: Android App Updates ✅
- [x] API Service (`PixieApiService.kt`)
  - [x] Add model parameter to API calls
  - [x] Update data models for optional OpenAI fields
  - [x] Handle provider-specific responses
- [x] Settings Screen
  - [x] Add model selector with descriptions
  - [x] Store selection in DataStore preferences
  - [x] Default to Gemini for new installs
- [x] Generation UI
  - [x] Add model selector to both generate and edit modes
  - [x] Hide OpenAI options when Gemini selected
  - [x] Simplify UI for Gemini mode
  - [x] Update credit estimation display (15 credits flat)
- [x] Chat/Message Display
  - [x] Show model badge in user messages
  - [x] Conditionally display generation details
  - [x] Update collapsed/expanded toolbar states

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

## Phase 6: Testing & Validation ✅
- [x] Backend Testing
  - [x] Test Gemini API integration
  - [x] Verify credit calculations (15 credits for Gemini)
  - [x] Test provider switching
  - [x] Validate error handling
- [x] CLI Testing
  - [x] Generate images with both models
  - [x] Test model switching
  - [x] Verify settings persistence
  - [x] Test edit functionality (OpenAI edit with multipart/form-data)
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
- [x] Deployment
  - [x] Set `GEMINI_API_KEY` secret in Cloudflare
  - [x] Deploy backend with `wrangler deploy`
  - [x] Update database schema in production
  - [x] Test production endpoints
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
- Flat-rate pricing (15 credits)
- Text-to-image generation
- No quality/size/style options
- Note: Image editing not yet implemented for Gemini

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