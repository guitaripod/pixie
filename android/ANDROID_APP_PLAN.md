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

#### 1.3 Networking Layer
- [ ] Create Retrofit service interface matching OpenAPI spec
- [ ] Implement custom OkHttp interceptor for auth headers
- [ ] Create data models matching API responses
- [ ] Implement error handling with sealed classes
- [ ] Add network connectivity observer

#### 1.4 Local Storage
- [ ] Set up encrypted DataStore for API keys and user preferences
- [ ] Create Room database for caching gallery images and metadata
- [ ] Implement repository pattern for data access
- [ ] Add migration strategy for future updates

### Phase 2: Authentication System

#### 2.1 OAuth Infrastructure
- [ ] Create OAuth activity with Chrome Custom Tabs
- [ ] Implement OAuth state parameter for security
- [ ] Handle deep links for OAuth callbacks
- [ ] Create auth interceptor for API requests

#### 2.2 Provider Implementations
- [ ] Implement GitHub OAuth flow with device code fallback
- [ ] Implement Google OAuth with Play Services integration
- [ ] Implement Apple Sign In (exclude for initial release if complex)
- [ ] Add biometric authentication for app access

#### 2.3 Session Management
- [ ] Create UserSession manager with encrypted storage
- [ ] Implement token refresh mechanism
- [ ] Add logout functionality with credential cleanup
- [ ] Create auth state flow for UI updates

### Phase 3: Image Generation Feature

#### 3.1 Generation UI
- [ ] Create prompt input screen with Material TextField
- [ ] Add expandable advanced options panel
- [ ] Implement size selector (square/landscape/portrait/custom)
- [ ] Create quality selector with credit cost preview
- [ ] Add number picker (1-10 images)

#### 3.2 Advanced Generation Options
- [ ] Implement background style selector (auto/transparent/colors)
- [ ] Add output format selector (PNG/JPEG/WebP)
- [ ] Create compression level slider for JPEG/WebP
- [ ] Add moderation level toggle

#### 3.3 Generation Process
- [ ] Create generation progress screen with animated placeholder
- [ ] Implement queue management for multiple images
- [ ] Add real-time progress updates
- [ ] Create error recovery with retry mechanism
- [ ] Implement result preview gallery

#### 3.4 Image Saving
- [ ] Request storage permissions appropriately
- [ ] Create app-specific album in gallery
- [ ] Implement MediaStore integration for public gallery
- [ ] Add share functionality with intent chooser
- [ ] Create download progress notifications

### Phase 4: Image Editing Feature

#### 4.1 Image Selection
- [ ] Create image picker with gallery and camera options
- [ ] Implement gallery image browser (gallery:id support)
- [ ] Add recent images quick access
- [ ] Create image preview with pinch-to-zoom

#### 4.2 Editing Interface
- [ ] Create edit prompt input with suggestions
- [ ] Implement mask drawing tools (brush, eraser, clear)
- [ ] Add mask opacity slider
- [ ] Create undo/redo for mask editing
- [ ] Add mask import from gallery

#### 4.3 Edit Options
- [ ] Implement size selector for output
- [ ] Add quality selector with cost preview
- [ ] Create fidelity toggle (low/high)
- [ ] Add variation count selector

#### 4.4 Edit Processing
- [ ] Create edit progress screen
- [ ] Implement before/after comparison view
- [ ] Add swipe between variations
- [ ] Create save individual/all options

### Phase 5: Gallery Features

#### 5.1 Public Gallery
- [ ] Create gallery grid with lazy loading
- [ ] Implement pull-to-refresh
- [ ] Add search/filter capabilities
- [ ] Create image detail bottom sheet
- [ ] Add pagination with loading indicators

#### 5.2 Personal Gallery
- [ ] Create "My Images" tab with filters
- [ ] Add sort options (date, prompt, quality)
- [ ] Implement bulk selection mode
- [ ] Add bulk download/delete
- [ ] Create image info display (prompt, settings, cost)

#### 5.3 Gallery Integration
- [ ] Implement "Edit from Gallery" action
- [ ] Add "Use as Reference" for generation
- [ ] Create prompt copying functionality
- [ ] Add favorite/bookmark feature

### Phase 6: Usage & Credits

#### 6.1 Usage Statistics
- [ ] Create usage dashboard with charts
- [ ] Implement date range picker
- [ ] Add daily/weekly/monthly views
- [ ] Create usage breakdown by type
- [ ] Add export to CSV functionality

#### 6.2 Credit Management
- [ ] Create credit balance display with visual indicator
- [ ] Implement transaction history with infinite scroll
- [ ] Add credit pack browser with descriptions
- [ ] Create cost estimator tool
- [ ] Add low balance notifications

#### 6.3 Credit Purchase
- [ ] Integrate Google Play Billing for IAP
- [ ] Create pack selection UI with benefits
- [ ] Implement purchase flow with confirmations
- [ ] Add purchase restoration
- [ ] Create crypto payment web view (if needed)

### Phase 7: Admin Features

#### 7.1 Admin Detection
- [ ] Check user admin status on login
- [ ] Create admin menu in settings
- [ ] Add admin badge to profile

#### 7.2 System Statistics
- [ ] Create admin dashboard with metrics
- [ ] Add user statistics viewer
- [ ] Implement system health indicators
- [ ] Create usage trends charts

#### 7.3 Credit Adjustments
- [ ] Create user search interface
- [ ] Implement credit adjustment form
- [ ] Add adjustment history viewer
- [ ] Create confirmation dialogs

### Phase 8: Settings & Utilities

#### 8.1 App Settings
- [ ] Create settings screen with categories
- [ ] Add theme selector (light/dark/system)
- [ ] Implement default quality/size preferences
- [ ] Add notification preferences
- [ ] Create cache management tools

#### 8.2 API Configuration
- [ ] Add custom API endpoint option
- [ ] Create endpoint validation
- [ ] Implement endpoint switching
- [ ] Add connection test utility

#### 8.3 Help & Support
- [ ] Create in-app help documentation
- [ ] Add FAQ section
- [ ] Implement feedback form
- [ ] Add version info and changelog

### Phase 9: Polish & Optimization

#### 9.1 UI/UX Improvements
- [ ] Add app intro/onboarding flow
- [ ] Create loading skeletons for all screens
- [ ] Implement empty states with actions
- [ ] Add haptic feedback for interactions
- [ ] Create smooth transitions between screens

#### 9.2 Performance
- [ ] Implement image caching with Coil
- [ ] Add request debouncing for search
- [ ] Create background job for downloads
- [ ] Optimize RecyclerView performance
- [ ] Add ProGuard rules for release

#### 9.3 Accessibility
- [ ] Add content descriptions for all images
- [ ] Implement keyboard navigation
- [ ] Create high contrast theme option
- [ ] Add screen reader optimizations
- [ ] Test with TalkBack

#### 9.4 Error Handling
- [ ] Create user-friendly error messages
- [ ] Add offline mode detection
- [ ] Implement retry mechanisms
- [ ] Create error reporting (Crashlytics)
- [ ] Add debug mode for development

### Phase 10: Testing & Release

#### 10.1 Testing
- [ ] Write unit tests for ViewModels
- [ ] Create UI tests for critical flows
- [ ] Implement integration tests for API
- [ ] Add performance testing
- [ ] Create test plans for manual testing

#### 10.2 Release Preparation
- [ ] Create app icon and splash screen
- [ ] Write Play Store description
- [ ] Create screenshots for all device sizes
- [ ] Prepare promotional graphics
- [ ] Set up CI/CD with GitHub Actions

#### 10.3 Launch
- [ ] Create signed release build
- [ ] Set up Play Console project
- [ ] Configure in-app purchases
- [ ] Submit for Play Store review
- [ ] Plan phased rollout strategy

## Technical Specifications

### Architecture
- **Pattern**: MVVM with Clean Architecture
- **DI**: Hilt
- **Async**: Coroutines + Flow
- **UI**: Jetpack Compose
- **Navigation**: Navigation Compose

### Key Libraries
- **Networking**: Retrofit + OkHttp + Moshi
- **Images**: Coil
- **Storage**: DataStore + Room
- **Security**: BiometricPrompt + Encrypted DataStore
- **Analytics**: Firebase Analytics (optional)

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
- Phase 7-8: 1 week (Admin + Settings)
- Phase 9-10: 2 weeks (Polish + Release)
- **Total: ~10 weeks for MVP**

## MVP Definition
Phases 1-6 constitute the MVP, focusing on:
- Authentication (GitHub + Google)
- Image generation with basic options
- Image editing with simple masks
- Gallery browsing
- Credit management

Admin features and advanced options can be added post-launch based on user feedback.