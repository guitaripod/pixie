# Pixie iOS App Development Plan

## Overview
Native Swift iOS app targeting iOS 16+ that replicates all functionality of the Pixie CLI with an intuitive mobile UI, following protocol-oriented design principles and modern UIKit architecture with programmatic UI.

## Development Phases

### Phase 1: Project Setup & Core Infrastructure

#### 1.1 Project Initialization
- [x] Create new iOS project with UIKit App Delegate lifecycle
- [x] Set minimum deployment target to iOS 16.0
- [x] Configure app capabilities: Associated Domains, Sign in with Apple, In-App Purchase
- [x] Set up version control with .gitignore for iOS/Xcode
- [x] Configure Info.plist for privacy permissions (Photo Library)

#### 1.2 Dependencies & Architecture
- [x] Add networking: URLSession with async/await
- [x] Add Keychain for secure storage
- [x] Implement protocol-oriented architecture with clear separation of concerns
- [x] Create core protocols: NetworkServiceProtocol, AuthenticationProtocol
- [x] Set up modern UIKit patterns: UICollectionViewDiffableDataSource, UITableViewDiffableDataSource
- [x] Configure cell registration with UICollectionView.CellRegistration and UITableView.CellRegistration

#### 1.3 Networking Layer
- [x] Create URLSession-based networking service with async/await
- [x] Implement Codable models matching OpenAPI spec
- [x] Create custom URLRequest builder with auth headers
- [x] Implement comprehensive error handling with custom Error types
- [x] Add network reachability monitoring with NWPathMonitor
- [x] Create request/response logging for debug builds

#### 1.4 Local Storage
- [x] Set up Keychain wrapper for secure credential storage
- [x] Create UserDefaults wrapper with property wrappers for settings
- [x] Create ConfigurationManager with NotificationCenter for updates
- [x] Use NSCache for in-memory image caching

### Phase 2: Authentication System

#### 2.1 OAuth Infrastructure
- [x] Create OAuth coordinator with ASWebAuthenticationSession
- [x] Implement OAuth state parameter generation and validation
- [x] Handle universal links for OAuth callbacks
- [x] Create authentication flow with delegate pattern
- [x] Implement secure credential storage in Keychain

#### 2.2 Provider Implementations
- [x] Implement GitHub OAuth with ASWebAuthenticationSession
- [x] Implement native Sign in with Apple using AuthenticationServices
- [x] Implement Google Sign-In with official SDK
- [x] Create unified authentication protocol for all providers
- [x] Implement official button styles following brand guidelines

#### 2.3 Session Management
- [x] Create AuthenticationManager with completion handlers and delegates
- [x] Implement automatic token refresh logic
- [x] Create logout functionality with complete cleanup
- [x] Add session persistence across app launches
- [x] Implement auth state publisher for reactive UI updates. For UIKit.

### Phase 3: Image Generation Feature

#### 3.1 Generation UI
- [x] Create chat-based timeline interface with UITableView using UITableViewDiffableDataSource
- [x] Implement ChatMessage sealed class hierarchy (UserMessage, ImageResponse)
- [x] Create message bubble cells with purple user messages and image response cells
- [x] Add automatic scroll to bottom on new messages
- [x] Implement expandable bottom toolbar (80pt collapsed, 520pt expanded). Make sure it's constrained to screen edges (bottom and horizontal).
- [x] Add toolbar spring animations with corner radius (28pt → 24pt) and shadow (12pt → 24pt)
- [x] Create drag handle indicator for toolbar
- [x] Adjust content padding based on toolbar state (620pt expanded, 120pt collapsed)
- [x] Add haptic feedback for all interactions. Create Haptics manager centralized.
- [x] Create spring animations for UI elements (scale: 0.95 on press)

#### 3.3 Generation Process
- [x] Create generation service with delegate pattern and closures
- [x] Implement data binding using Combine publishers and diffable data sources
- [x] Implement progress tracking with Combine publishers
- [x] Add proper error handling with user-friendly messages. Check what the backend reports.
- [x] Create loading states
- [x] Implement animated loading indicators in chat bubbles
- [x] Add request cancellation support

#### 3.4 Image Saving & Sharing
- [x] Implement PHPhotoLibrary integration with proper permissions
- [x] Create custom "Pixie" album in Photos app
- [x] Add share functionality with UIActivityViewController
- [x] Implement contextual save/share menu on image tap

### Phase 4: Suggestions & Quick Actions

#### 4.2 Recent Images Integration
- [x] Create horizontal scrolling recent images with UICollectionViewCompositionalLayout orthogonal scrolling
- [x] Implement permission-aware UI that adapts to photo access
- [x] Add image picker integration for quick selection
- [x] Create loading states for permission requests
- [x] Add empty state with call-to-action

### Phase 5: Image Editing Feature

#### 5.1 Image Selection
- [x] Create unified image picker with PhotosUI framework
- [ ] Add gallery browser for user's images (gallery:id support)
- [x] Create image preview with pinch-to-zoom gesture
- [x] Implement image selection using PHPickerViewController for modern photo access
- [x] Add recent edits quick access section

#### 5.2 Editing Interface
- [x] Implement Edit Mode Quick Actions (17 total): Recolor, Lighting, Art Style, Remove, Enhance, Night, Weather, Season, Age, Expression, Background, Blur, Dreamy, Vintage, Cyberpunk, Minimal, Dramatic
- [x] Implement Generate Mode Quick Actions (14 total): Portrait, Landscape, Digital Art, Architecture, Animals, Food, Cyberpunk, Fantasy, Space, Macro, Surreal, Retro, Underwater, Miniature
- [x] Create edit mode UI matching generation chat interface. Use the existing Toolbar and have it display in an "Edit-mode"

#### 5.3 Edit Options
- [x] Implement size preservation or custom sizing
- [x] Add quality selector with credit preview
- [x] Create fidelity toggle (low/high) with explanation

### Phase 6: Gallery Features

#### 6.1 Gallery Implementation
- [x] Create tab bar that's at the top of the view with "My Images" and "Explore" tabs using UIPageViewController for swipe navigation
- [x] Implement gallery grid with UICollectionViewCompositionalLayout (adaptive columns, 180pt min width)
- [x] Use staggered layout with UICollectionViewDiffableDataSource
- [x] Add infinite scroll with 100 image limit for public gallery (show notice card)
- [x] Create image cards showing: thumbnail, prompt, time ago, credits used
- [x] Implement long-press contextual menu: Edit, Copy Prompt, Download, Share
- [x] Create image detail bottom sheet with full metadata
- [x] Add animated item appearance
- [x] Implement pull-to-refresh functionality
- [x] Add empty states with action buttons

#### 6.2 Gallery Features
- [x] Implement session caching
- [ ] Add search and filter capabilities with UISearchController
- [ ] Create batch selection mode using UICollectionViewDiffableDataSource with selection state
- [x] Add empty state with generation CTA for personal gallery
- [x] Add empty state with explore prompt for public gallery
- [x] Implement local cache to reduce API calls
- [ ] Create loading shimmer effects for gallery items

#### 6.3 Gallery Actions
- [x] Create contextual menu with haptic feedback
- [x] Implement prompt copying to clipboard
- [x] Add edit action with navigation to edit mode
- [x] Create download with progress indicator
- [x] Add share sheet integration

### Phase 7: Usage & Credits

#### 7.1 Credits Main Hub
- [x] Create credits main screen with large balance card
- [x] Add skeleton loader animation for balance
- [x] Implement quick action cards (Buy Credits, Estimate)
- [x] Create feature cards with descriptions
- [x] Add recent transactions preview section
- [x] Implement tips card at bottom

#### 7.3 Credit Management
- [x] Add real-time credit updates with Combine
- [x] Create credit pack browser with enhanced purchase flow
- [x] Add cost estimator calculator with interactive UI
- [x] Implement low credit warnings
- [x] Add transaction history view with proper alignment and icons
- [ ] Create RevenueCat integration for purchases with the backend.

#### 7.4 In-App Purchases
- [ ] Integrate RevenueCat SDK configuration
- [ ] Create purchase flow with loading states
- [ ] Implement receipt validation through RevenueCat
- [ ] Add purchase restoration functionality
- [ ] Create subscription management UI
- [ ] Implement cross-platform purchase sync
- [ ] Add App Store review prompt logic

### Phase 8: Admin Features

#### 8.1 Admin Access
- [x] Check user admin status on authentication
- [x] Create admin section in settings
- [x] Add admin indicator badge

#### 8.2 System Dashboard
- [x] Create admin dashboard with system metrics

#### 8.3 User Management
- [x] Create user search with debouncing
- [x] Implement credit adjustment interface
- [x] Add adjustment history viewer

### Phase 9: Polish & Performance

#### 9.1 UI/UX Enhancements
- [x] Implement comprehensive haptic feedback system (9 types: click, longPress, toggle, error, success, warning, sliderTick, confirm, reject)
- [ ] Add offline mode banner with expand/shrink animation
- [ ] Create loading skeletons and shimmer effects
- [x] Implement empty states with illustrations and action buttons
- [x] Add keyboard avoidance using UIKeyboardLayoutGuide
- [x] Create smooth transitions between screens
- [ ] Implement pull-to-dismiss for UISheetPresentationController
- [ ] Add notification permission handling with UI feedback

#### 9.2 Animations & Interactions
- [x] Add spring animations for interactive elements
- [x] Implement gesture-driven navigation
- [ ] Create parallax effects for scrolling
- [ ] Add shimmer effects for loading states

#### 9.3 Performance Optimization
- [x] Implement image caching strategy
- [ ] Add request debouncing for search
- [ ] Create background task handling
- [x] Optimize UIView updates and layout cycles
- [ ] Implement lazy loading with UICollectionViewDataSourcePrefetching
- [ ] Add memory pressure handling

#### 9.4 Accessibility
- [ ] Add VoiceOver labels for all UI elements
- [ ] Implement Dynamic Type support
- [ ] Create high contrast mode support
- [ ] Add reduced motion alternatives
- [ ] Implement voice control support
- [ ] Create accessibility shortcuts

#### 9.5 Error Handling
- [ ] Create unified error presentation
- [ ] Add offline mode detection and UI
- [ ] Implement debug menu for development
- [ ] Create crash reporting integration
- [ ] Add user feedback mechanism

### Phase 10: Settings & Profile

#### 10.1 Settings Implementation
- [x] Create settings screen with card-based sections
- [x] Implement Appearance section: Theme selector (Light/Dark/System) with segmented control
- [x] Add Defaults section: Quality, Size, Format, Compression, Background, Moderation with segmented controls
- [x] Create Storage section: Cache management with size display and clear functionality
- [x] Implement API section: Connection test with real-time status indicators
- [x] Add conditional Admin section for admin users
- [x] Create Help & Support section with local documentation (Getting Started, Features, FAQ)
- [x] Implement Account section with user ID display and logout confirmation
- [x] Apply saved theme on app launch
- [x] Sync all toolbar defaults with saved settings across the app

### Phase 11: Testing & Release

#### 11.1 Testing
- [ ] Write unit tests for all view controllers and services
- [ ] Create UI tests with XCUITest
- [ ] Implement snapshot testing for views
- [ ] Add performance testing suite
- [ ] Create manual test plans
- [ ] Implement beta testing with TestFlight

#### 11.2 Release Preparation
- [ ] Create app icon set with all sizes
- [ ] Design launch screen with brand colors
- [ ] Write App Store description and keywords
- [ ] Create screenshots for all device sizes
- [ ] Prepare App Store preview video
- [ ] Set up CI/CD with Xcode Cloud

#### 11.3 Launch
- [ ] Create production build configuration
- [ ] Set up App Store Connect
- [ ] Configure RevenueCat products
- [ ] Submit for App Store review
- [ ] Prepare launch marketing materials

## Technical Specifications

### Architecture
- **Pattern**: MVVM-C (Model-View-ViewModel-Coordinator)
- **Design**: Protocol-Oriented Programming
- **UI Framework**: UIKit with programmatic UI (no Storyboards/XIBs)
- **Concurrency**: Swift Concurrency (async/await, actors)
- **Reactive**: Combine for data binding

### Key Frameworks & Libraries
- **UI**: UIKit, PhotosUI,
- **Modern UIKit**: UICollectionViewCompositionalLayout, UICollectionViewDiffableDataSource, UITableViewDiffableDataSource
- **Networking**: URLSession, NWPathMonitor
- **Storage**: Keychain Services, UserDefaults
- **Images**: CoreImage
- **Auth**: AuthenticationServices, LocalAuthentication
- **Payments**: RevenueCat SDK
- **Charts**: Charts framework
- **Haptics**: UIKit Haptics, CoreHaptics

### Brand Colors
- **Primary**: Pixie Purple (#6750A4)
- **Secondary**: Pixie Teal (#00BCD4)
- **Tertiary**: Pixie Orange (#FF6B35)
- **Error**: Red (#BA1A1A)
- **Theme Support**: Light/Dark/System with Material Design 3 principles

### Design Patterns
- **Protocols**: Define capabilities and behaviors
- **Dependency Injection**: Protocol-based with Coordinator pattern
- **Coordinators**: Navigation flow management
- **Repository Pattern**: Data access abstraction
- **Factory Pattern**: Object creation
- **Observer Pattern**: Combine publishers
- **Diffable Data Sources**: Type-safe data management for collection and table views
- **Cell Registration**: Type-safe cell configuration with modern registration APIs

### API Integration
- Base URL: `https://openai-image-proxy.guitaripod.workers.dev`
- Custom endpoint support via settings
- OAuth providers: GitHub, Google, Apple
- Async/await for all network calls
- Proper error handling with typed errors

### Security Considerations
- Keychain for all sensitive data
- Biometric authentication support
- Certificate pinning for API calls
- OAuth state validation
- No credentials in code or bundle
- App Transport Security compliance

### Platform Requirements
- iOS 16.0+ (for latest UIKit features)
- iPhone and iPad support
- macOS support via Catalyst (future)
- ProMotion display support
- Dynamic Island integration (iPhone 14 Pro+)

### UI/UX Specifications
- **Haptic Feedback Types**: click, longPress, toggle, error, success, warning, sliderTick, confirm, reject
- **Animation Curves**: Spring with dampingRatio: 0.8, stiffness: 200
- **Press Scale**: 0.95 with spring animation
- **Corner Radii**: 12pt (cards), 28pt (modals), 16pt (chips)
- **Gradients**: Linear gradients for style presets
- **Transitions**: UIViewControllerAnimatedTransitioning, scale, opacity
- **Toolbar Heights**: 80pt collapsed, 520pt expanded
- **Content Padding**: 120pt (collapsed toolbar), 620pt (expanded toolbar)
- **Gallery Columns**: Adaptive with 180pt minimum width
- **Image Limit**: 100 images for public gallery with notice card

## Development Timeline
- Phase 1-2: 2 weeks (Setup + Auth)
- Phase 3-4: 3 weeks (Core features + Suggestions)
- Phase 5-6: 2 weeks (Editing + Gallery)
- Phase 7-8: 2 weeks (Credits + Admin)
- Phase 9-10: 2 weeks (Polish + Settings)
- Phase 11: 1 week (Testing + Release)
- **Total: ~12 weeks for feature-complete app**

## MVP Definition
Phases 1-6 constitute the MVP, focusing on:
- Native iOS authentication (Sign in with Apple priority)
- Image generation with chat UI
- Advanced suggestions system
- Image editing capabilities
- Gallery browsing with caching
- Basic credit display

## Key Differences from Android
- Native Sign in with Apple integration
- iOS-specific haptic patterns
- Dynamic Island support
- UIKit-first approach with programmatic UI
- Protocol-oriented architecture
- Native Swift concurrency
- iOS-specific animations and transitions
- Deeper Photos app integration
- Focus on iOS 16+ features
- Modern UIKit APIs: Compositional Layout, Diffable Data Sources
- Type-safe cell registration and configuration

## Protocol-Oriented Design Principles
1. **Define protocols before implementations**
2. **Use protocol extensions for default behavior**
3. **Favor composition over inheritance**
4. **Create small, focused protocols**
5. **Use associated types for flexibility**
6. **Implement dependency injection via protocols**
7. **Test against protocols, not concrete types**

## Success Metrics
- App Store rating of 4.5+
- Feature parity with Android app
- <2 second launch time
- <100MB app size
- 99.9% crash-free rate
- Accessibility score of 100%
