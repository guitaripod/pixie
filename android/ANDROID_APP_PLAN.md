# Pixie Android App Development Plan

## Overview
Native Kotlin Android app that replicates all functionality of the Pixie CLI with an intuitive mobile UI.

## Development Phases

### Phase 1: Project Setup & Core Infrastructure

#### 1.1 Project Initialization ✅
- [x] Create new Android project with Kotlin DSL build scripts
- [x] Set minimum SDK to 24 (Android 7.0) for 98%+ device coverage
- [x] Configure Material Design 3 theme with dynamic color support
- [x] Set up version control with .gitignore for Android

#### 1.2 Dependencies & Architecture ✅
- [x] Add core dependencies: Retrofit, Moshi, Coroutines, ~~Hilt~~ Manual DI
- [x] Add UI dependencies: Jetpack Compose, Navigation Compose, Coil
- [x] Add security dependencies: DataStore (encrypted), BiometricPrompt
- [x] Set up MVVM architecture with Clean Architecture layers
- [x] Create base classes: BaseViewModel, BaseRepository, BaseUseCase

#### 1.3 Networking Layer ✅
- [x] Create Retrofit service interface matching OpenAPI spec
- [x] Implement custom OkHttp interceptor for auth headers
- [x] Create data models matching API responses
- [x] Implement error handling with sealed classes
- [x] Add network connectivity observer

#### 1.4 Local Storage ✅
- [x] Set up encrypted SharedPreferences for storing config (api_key, user_id, auth_provider)
- [x] Create preferences DataStore for non-sensitive settings (theme, default quality, custom api_url)
- [x] Implement PreferencesRepository for centralized access
- [x] Add config data class matching CLI structure

### Phase 2: Authentication System ✅

#### 2.1 OAuth Infrastructure ✅
- [x] Create OAuth activity with Chrome Custom Tabs
- [x] Implement OAuth state parameter for security
- [x] Handle deep links for OAuth callbacks
- [x] Create auth interceptor for API requests

#### 2.2 Provider Implementations ✅
- [x] Implement GitHub OAuth flow with web redirect
- [x] Implement Google OAuth with native Google Sign-In SDK
- [x] Implement Apple Sign In with manual credential entry
- [ ] Add biometric authentication for app access

#### 2.3 Session Management ✅
- [x] Create ConfigManager with encrypted storage for credentials
- [x] Implement logout functionality with credential cleanup
- [x] Create auth state flow for UI updates
- [x] Fetch and use official UI components for each login button

**Implementation Notes:**
- GitHub: Uses web OAuth flow with `pixie://auth` deep link redirect
- Google: Uses native Google Sign-In SDK with official button component
- Apple: Uses web OAuth flow with manual credential entry (Apple doesn't support custom URI schemes)
- Apple uses external browser for better app switching UX when copying credentials
- Official button components: Google (SDK), Apple & GitHub (custom following brand guidelines)

### Phase 3: Image Generation Feature

#### 3.1 Generation UI ✅
- [x] Create prompt input screen with Material TextField
- [x] Add expandable advanced options panel
- [x] Implement size selector (square/landscape/portrait/custom)
- [x] Create quality selector with credit cost preview
- [x] Add number picker (1-10 images)
- [x] Redesign as chat-based timeline UI
- [x] Implement collapsible bottom toolbar
- [x] Add generation request message bubbles
- [x] Add image response bubbles with loading states

#### 3.2 Advanced Generation Options ✅
- [x] Implement background style selector (auto/transparent/colors)
- [x] Add output format selector (PNG/JPEG/WebP)
- [x] Create compression level slider for JPEG/WebP (only shown when applicable)
- [x] Add moderation level toggle
- [x] Correct implementation of -n flag for multiple images per generation

#### 3.3 Generation Process ✅
- [x] Create generation progress integrated into chat bubbles
- [x] Implement proper error handling with detailed messages
- [x] Add loading states with correct singular/plural text
- [x] Create error display in chat timeline
- [x] Display generated images inline in chat

#### 3.4 Image Saving ✅
- [x] Request storage permissions appropriately
- [x] Create app-specific album in gallery ("Pixie")
- [x] Implement MediaStore integration for public gallery
- [x] Add share functionality with intent chooser
- [x] Create download progress notifications
- [x] Implement tap-to-reveal save/share buttons
- [x] Add "Save all" functionality for multiple images
- [x] Separate share (temp cache) from save (gallery) functionality
- [x] Add FileProvider for secure sharing

### Phase 4: Image Editing Feature

#### 4.1 Image Selection ✅
- [x] Create image picker with gallery and camera options
- [x] Implement gallery image browser (gallery:id support)
- [x] Add recent images quick access
- [x] Create image preview with pinch-to-zoom

#### 4.2 Editing Interface ✅
- [x] Create edit prompt input with suggestions
- [x] ~~Implement mask drawing tools~~ (removed - not needed)
- [x] ~~Add mask opacity slider~~ (removed - not needed)
- [x] ~~Create undo/redo for mask editing~~ (removed - not needed)
- [x] ~~Add mask import from gallery~~ (removed - not needed)

#### 4.3 Edit Options ✅
- [x] Implement size selector for output
- [x] Add quality selector with cost preview
- [x] Create fidelity toggle (low/high)
- [x] Add variation count selector

#### 4.4 Edit Processing (Partial)
- [x] Create edit progress integrated in chat timeline
- [ ] Implement before/after comparison view
- [ ] Add swipe between variations
- [x] Create save individual/all options (reuses generation save)

### Phase 5: Gallery Features ✅

#### 5.1 Public Gallery ✅
- [x] Create gallery grid with staggered layout and lazy loading
- [x] Create image detail bottom sheet with full metadata
- [x] Add pagination with infinite scroll

#### 5.2 Personal Gallery ✅
- [x] Create "My Images" tab showing user's generated images
- [x] Create image info display (prompt, size, quality, credits, model)
- [x] Add empty states for both galleries

#### 5.3 Gallery Integration ✅
- [x] Create dropdown menu with actions (edit, copy, download, share)
- [x] Implement prompt copying functionality
- [x] Add download to device gallery
- [x] Add share functionality
- [x] Navigate to gallery from chat screen
- [x] Implement caching layer to prevent needless remote database reads.
- [x] Implement "Edit from Gallery" action (navigation ready, needs edit mode integration)

### Phase 6: Usage & Credits

#### 6.1 Usage Statistics ✅
- [x] Create usage dashboard with charts
- [x] Implement date range picker
- [x] Add daily/weekly/monthly views
- [x] Create usage breakdown by type
- [x] Add export to CSV functionality

#### 6.2 Credit Management ✅
- [x] Create credit balance display with visual indicator
- [x] Implement transaction history with infinite scroll
- [x] Add credit pack browser with descriptions
- [x] Create cost estimator tool

#### 6.3 Credit Purchase (Partially Complete)
RevenueCat was removed on 2026-11-06 (D31, P6.44). The app sells packs with Google Play Billing Library 9.1.0 and
mako verifies every purchase with the Google Play Developer API.

- [x] Pack selection UI with Play's localized prices (`EnhancedCreditPacksScreen`)
- [x] `GooglePlayStore` (`data/purchases/`): one `BillingClient` with pending one-time purchases and automatic
  service reconnection; queries the `com.guitaripod.pixie.credits.<pack>` products, shows the purchase sheet with
  the mako user id as the obfuscated account id, consumes
- [x] `PlayBillingManager`: connects with retries (1, 2, 4 s), sends each paid purchase to mako's
  `POST /v1/credits/purchase/validate` (`pack_id`, `purchase_token`, `product_id`, `platform: "android"`,
  `play_order_id`), consumes only after mako answers credited or `already_processed`, keeps a purchase mako answers
  `credit_pending`, `not_configured`, 401 or 5xx for and offers it again after 5 s, 30 s, 2 and 10 minutes, on Play's
  purchase updates (buffered until billing starts), at launch or sign-in and each time the credit packs screen opens
  (`queryPurchasesAsync`); a refused purchase is left unconsumed, so Google refunds it after three days
- [x] Restore = reconcile: credits every unconsumed pack purchase of the Google account
- [x] Unit tests for the state machine with a fake store and validator (`PlayBillingManagerTest`,
  `PurchaseValidationTest`)

**Remaining tasks:**
- [ ] Founder: Google Cloud service account with the Google Play Android Developer API enabled, invited in Play
  Console (Users and permissions) with "View financial data" and "Manage orders and subscriptions", key stored with
  `npx wrangler secret put GOOGLE_PLAY_SERVICE_ACCOUNT < key.json` on arch (until then mako answers `not_configured`)
- [ ] Deploy mako with migration 040 (`apps.play_package_name`) before any build that buys reaches testers
- [ ] Check that the five one-time products `com.guitaripod.pixie.credits.<pack>` exist and are active in Play
  Console. The RevenueCat build also matched `<pack>` and `com.guitaripod.pixie.<pack>`; mako only credits the
  `credits.` ids (`store_product_prefix`), and a Play product id cannot be renamed, so create them if the old ones differ
- [ ] Upload signed AAB to Google Play Console internal testing track
- [ ] Test the complete purchase flow with a license tester, including a slow test card (pending) and a refusal
- [ ] Test credits after reinstall (an unconsumed purchase is credited at the next start)
- [ ] Verify credits sync correctly with CLI using same account
- [x] Play refunds: mako's `*/30` cron reads Google's voided purchases and takes the credits back once
- [ ] Test a refund from Play Console on a license tester's purchase: the credits leave within about 30 minutes
- [ ] Test purchases on different Android versions (API 24+)

### Phase 7: Admin Features ✅

#### 7.1 Admin Detection ✅
- [x] Check user admin status on login
- [x] Create admin menu in settings
- [x] Add admin badge to profile

#### 7.2 System Statistics ✅
- [x] Create admin dashboard with metrics
- [x] Add user statistics viewer
- [x] Implement system health indicators
- [ ] Create usage trends charts (future enhancement)

#### 7.3 Credit Adjustments ✅
- [x] Create user search interface
- [x] Implement credit adjustment form
- [x] Add adjustment history viewer
- [x] Create confirmation dialogs

### Phase 8: Polish & Performance

#### 8.1 UI/UX Improvements
- [ ] Create loading skeletons for all screens
- [x] Implement empty states with actions
- [x] Add haptic feedback for interactions

#### 8.2 Performance
- [x] Implement image caching with Coil
- [ ] Add request debouncing for search
- [ ] Create background job for downloads

#### 8.3 Accessibility
- [ ] Add content descriptions for all images
- [ ] Add screen reader optimizations

#### 8.4 Error Handling
- [x] Add offline mode detection
- [x] Add debug mode for development

### Phase 9: Testing & Release

#### 9.1 Testing
- [ ] Write unit tests for ViewModels
- [ ] Create UI tests for critical flows
- [ ] Implement integration tests for API
- [ ] Add performance testing
- [ ] Create test plans for manual testing

#### 9.2 Release Preparation
- [ ] Create app icon and splash screen
- [ ] Write Play Store description
- [ ] Create screenshots for all device sizes
- [ ] Prepare promotional graphics
- [ ] Set up CI/CD with GitHub Actions

#### 9.3 Launch
- [ ] Create signed release build
- [x] Set up Play Console project
- [ ] Credit pack products `com.guitaripod.pixie.credits.<pack>` active in Play Console (see 6.3)
- [ ] Submit for Play Store review

## Technical Specifications

### Architecture
- **Pattern**: MVVM with Clean Architecture
- **DI**: Manual Dependency Injection (AppContainer)
- **Async**: Coroutines + Flow
- **UI**: Jetpack Compose
- **Navigation**: Navigation Compose

### Key Libraries
- **Networking**: Retrofit + OkHttp + Moshi
- **Images**: Coil
- **Storage**: DataStore + Encrypted SharedPreferences
- **Security**: BiometricPrompt + Encrypted DataStore
- **Authentication**: Google Sign-In SDK
- **Analytics**: Firebase Analytics (optional)
- **Payments**: Google Play Billing Library 9.1.0, verified server-side by mako

### API Integration
- Base URL: `https://openai-image-proxy.guitaripod.workers.dev`
- Custom endpoint support via settings
- OAuth providers: GitHub, Google, Apple
- WebSocket support for real-time updates (future)

### Security Considerations
- Encrypted storage for all credentials
- Certificate pinning for API calls
- OAuth state validation
- Biometric authentication option
- No credentials in code or resources

### Minimum Requirements
- Android 7.0 (API 24)
- 2GB RAM recommended
- Internet connection required
- 100MB storage for app + cache

## Development Timeline
- Phase 1-2: 2 weeks (Setup + Auth)
- Phase 3-4: 3 weeks (Core features)
- Phase 5-6: 2 weeks (Gallery + Credits)
- Phase 7: 1 week (Admin Features)
- Phase 8-9: 2 weeks (Polish + Release)
- **Total: ~10 weeks for MVP**

## MVP Definition
Phases 1-7 constitute the MVP, focusing on:
- Authentication (GitHub + Google)
- Image generation with basic options
- Image editing with simple masks
- Gallery browsing
- Credit management
- Admin features for system management

## Current Status
- ✅ Phase 1: Project Setup
- ✅ Phase 2: Core Infrastructure
- ✅ Phase 3: Authentication
- ✅ Phase 4: Image Generation
- ✅ Phase 5: Gallery
- ✅ Phase 6: Credits & Payments
- ✅ Phase 7: Admin Features
- ⏳ Phase 8: Polish & Performance
- ⏰ Phase 9: Testing & Release

## Recent Updates
- Completed Phase 7: Admin Features implementation
- Redesigned all app icons using Material Icons Extended library
- Added admin dashboard, system statistics, and credit adjustment features
- Integrated admin status checking and display in settings
