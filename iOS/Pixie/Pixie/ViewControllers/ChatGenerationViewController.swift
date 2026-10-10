import UIKit
import PhotosUI
import Photos
import Combine
import UniformTypeIdentifiers

class ChatGenerationViewController: UIViewController {
    enum ViewState {
        case suggestions
        case chat
    }
    private var currentState: ViewState = .suggestions
    private let suggestionsView = FullScreenSuggestionsView()
    private let chatView = ChatTableView()
    private let inputBar = ChatInputBar()
    private let selectedSuggestionsManager = SelectedSuggestionsManager()
    private var toolbarMode: ToolbarMode = .generate
    private let chatId = UUID().uuidString
    private lazy var viewModel = GenerationViewModel(chatId: self.chatId)
    private var cancellables = Set<AnyCancellable>()
    private var currentOptions = GenerationOptions.default
    private let haptics = HapticManager.shared
    private var suggestionsBottomConstraint: NSLayoutConstraint!
    private var chatBottomConstraint: NSLayoutConstraint!
    private let offlineBanner = OfflineBanner()
    private let keyboardTracker = KeyboardOverlapView()
    private let creditsViewModel = CreditsViewModel()
    private let topBar = ChatTopBar()
    private let topFade = EdgeFadeView(edge: .top)
    private let topBand: UIView = {
        let band = UIView()
        band.translatesAutoresizingMaskIntoConstraints = false
        band.backgroundColor = Theme.Color.canvas
        band.isUserInteractionEnabled = false
        band.isAccessibilityElement = false
        return band
    }()
    private var composerWidthConstraint: NSLayoutConstraint!
    private let bottomFade = EdgeFadeView(edge: .bottom)
    private var notificationObserver: NSObjectProtocol?
    private var presetLinkObserver: NSObjectProtocol?
    private var pendingPreset: EditPreset?
    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    #if DEBUG
    enum DemoScenario {
        case edit, create, empty, fresh
        case home(UIImage)
        case compose(UIImage, String)
        case conversation([ChatMessage])
    }
    var demoMode: DemoScenario?
    #endif
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupTopBar()
        setupHandlers()
        setupBindings()
        setupNotificationObserver()
        setupKeyboardCommands()
        setupDragAndDrop()
        transitionToState(.suggestions, animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        inputBar.refitExpandedHeight()
        updateSuggestionsInsets()
        chatView.topBarBottom = topBar.frame.maxY
        updateComposerWidth()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        topBar.setShowsAdminBadge(AuthenticationManager.shared.currentUser?.isAdmin ?? false)
        #if DEBUG
        if DemoMode.isActive { return }
        #endif
        Task { await creditsViewModel.loadBalance() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let navigationController, navigationController.topViewController !== self {
            navigationController.setNavigationBarHidden(false, animated: animated)
        }
    }

    private var onboardingShown = false
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        #if DEBUG
        if let demoMode = demoMode, !demoApplied {
            demoApplied = true
            applyDemoScenario(demoMode)
        }
        if DemoMode.isActive { return }
        if let prompt = ProcessInfo.processInfo.environment["PX_AUTOGENERATE"], !demoApplied {
            demoApplied = true
            autogenerate(prompt)
            return
        }
        #endif
        presentOnboardingIfNeeded()
        consumePresetLink()
    }

    /// Starts a preset that arrived through a `pixie://preset/…` link once nothing is
    /// covering this screen; onboarding, when showing, finishes first. A link always asks
    /// for a fresh photo rather than spending credits on whatever image was last held.
    private func consumePresetLink() {
        guard viewIfLoaded?.window != nil, presentedViewController == nil, !viewModel.isGenerating,
              let preset = PresetLink.take() else { return }
        if case .edit = toolbarMode {
            switchToGenerateMode()
        }
        transitionToState(.suggestions, animated: false)
        pendingPreset = preset
        presentPhotoPicker()
    }

    private func presentOnboardingIfNeeded() {
        guard !onboardingShown, !Onboarding.isCompleted, presentedViewController == nil else { return }
        onboardingShown = true
        let onboarding = OnboardingViewController()
        onboarding.modalPresentationStyle = .fullScreen
        onboarding.onFinished = { [weak self] in
            self?.dismiss(animated: true)
        }
        present(onboarding, animated: false)
    }

    #if DEBUG
    private var demoApplied = false

    #if DEBUG
    /// `PX_AUTOGENERATE=<prompt>` starts a generation as soon as the chat appears, skipping the
    /// consent and balance checks; with `PX_FAKE_GENERATION` it exercises the whole result path,
    /// Live Activity included, without a server.
    private func autogenerate(_ prompt: String) {
        transitionToState(.chat, animated: false)
        viewModel.prompt = prompt
        currentOptions.prompt = prompt
        currentOptions.model = ImageModel.gemini.value
        viewModel.generateImages(with: currentOptions)
    }
    #endif

    private func applyDemoScenario(_ scenario: DemoScenario) {
        if case .fresh = scenario {
            return
        }
        if case let .home(photo) = scenario {
            toolbarMode = .edit(selectedImage: SelectedImage(image: photo, url: nil, displayName: nil))
            inputBar.setEditMode(true, selectedImage: photo)
            suggestionsView.setEditMode(true, photo: photo)
            return
        }
        if case let .compose(photo, prompt) = scenario {
            toolbarMode = .edit(selectedImage: SelectedImage(image: photo, url: nil, displayName: nil))
            inputBar.setEditMode(true, selectedImage: photo)
            suggestionsView.setEditMode(true, photo: photo)
            inputBar.setText(prompt)
            inputBar.expand()
            return
        }
        suggestionsView.alpha = 0
        chatView.alpha = 1
        currentState = .chat
        updateAccessibilityVisibility()
        updateTopBarLeading(animated: false)
        let messages: [ChatMessage]
        switch scenario {
        case .edit:
            messages = DemoChatBuilder.editConversation()
        case .create:
            messages = DemoChatBuilder.createConversation()
        case .empty, .home, .fresh, .compose:
            messages = []
        case .conversation(let conversation):
            messages = conversation
        }
        chatView.setMessages(messages, animated: false)
        if messages.last?.role == .loading {
            inputBar.setGenerating(true)
        }
        if let latest = messages.last(where: { $0.role == .assistant })?.images?.first {
            toolbarMode = .edit(selectedImage: SelectedImage(image: latest, url: nil, displayName: nil))
            inputBar.setEditMode(true, selectedImage: latest)
        }
    }
    #endif
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = presetLinkObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    private func setupUI() {
        view.backgroundColor = Theme.Color.canvas
        suggestionsView.translatesAutoresizingMaskIntoConstraints = false
        suggestionsView.alpha = 1
        suggestionsView.selectedSuggestionsManager = selectedSuggestionsManager
        view.addSubview(suggestionsView)
        chatView.translatesAutoresizingMaskIntoConstraints = false
        chatView.alpha = 0
        chatView.delegate = self
        chatView.onResultWidthChange = { [weak self] in self?.updateComposerWidth() }
        view.addSubview(chatView)
        updateAccessibilityVisibility()
        view.addSubview(topBand)
        view.addSubview(topFade)
        view.addSubview(bottomFade)
        inputBar.translatesAutoresizingMaskIntoConstraints = false
        inputBar.selectedSuggestionsManager = selectedSuggestionsManager
        view.addSubview(inputBar)
        view.addSubview(topBar)
        offlineBanner.alpha = 0
        view.addSubview(offlineBanner)
        installKeyboardTracker()
    }

    /// With no keyboard the guide rests on the bottom safe area, so anything that tall or shorter
    /// is the resting state and not a keyboard.
    private func keyboardOverlapChanged(_ guideHeight: CGFloat) {
        let covered = guideHeight > view.safeAreaInsets.bottom ? guideHeight : 0
        chatView.adjustForKeyboard(height: covered, duration: 0)
    }

    /// Reports how much of this view the keyboard covers, read from the keyboard layout guide
    /// so it follows the keyboard in every window size and pose.
    private func installKeyboardTracker() {
        keyboardTracker.translatesAutoresizingMaskIntoConstraints = false
        keyboardTracker.isUserInteractionEnabled = false
        keyboardTracker.onHeightChange = { [weak self] height in
            self?.keyboardOverlapChanged(height)
        }
        view.insertSubview(keyboardTracker, at: 0)
        NSLayoutConstraint.activate([
            keyboardTracker.topAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            keyboardTracker.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardTracker.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardTracker.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    private func setupConstraints() {
        let safe = view.safeAreaLayoutGuide
        leadingConstraint = inputBar.leadingAnchor.constraint(equalTo: safe.leadingAnchor)
        trailingConstraint = inputBar.trailingAnchor.constraint(equalTo: safe.trailingAnchor)
        leadingConstraint.priority = .defaultHigh
        trailingConstraint.priority = .defaultHigh
        composerWidthConstraint = inputBar.widthAnchor.constraint(lessThanOrEqualToConstant: Self.composerMaximumWidth)

        NSLayoutConstraint.activate([
            leadingConstraint,
            trailingConstraint,
            inputBar.leadingAnchor.constraint(greaterThanOrEqualTo: safe.leadingAnchor),
            inputBar.trailingAnchor.constraint(lessThanOrEqualTo: safe.trailingAnchor),
            inputBar.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            composerWidthConstraint,
            inputBar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        ])

        let bannerTopConstraint = offlineBanner.topAnchor.constraint(equalTo: safe.topAnchor, constant: -36)
        offlineBanner.setTopConstraint(bannerTopConstraint)
        NSLayoutConstraint.activate([
            offlineBanner.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            offlineBanner.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            bannerTopConstraint
        ])

        let barTop = topBar.topAnchor.constraint(equalTo: safe.topAnchor, constant: Theme.Space.sm)
        barTop.priority = .defaultHigh
        NSLayoutConstraint.activate([
            barTop,
            topBar.topAnchor.constraint(greaterThanOrEqualTo: offlineBanner.bottomAnchor, constant: Theme.Space.xs),
            topBar.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: Theme.Space.md),
            topBar.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -Theme.Space.md),
            topBand.topAnchor.constraint(equalTo: view.topAnchor),
            topBand.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBand.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBand.bottomAnchor.constraint(equalTo: topBar.bottomAnchor),
            topFade.topAnchor.constraint(equalTo: topBand.bottomAnchor),
            topFade.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topFade.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topFade.heightAnchor.constraint(equalToConstant: ChatTableView.topFadeLength),
            bottomFade.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFade.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFade.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomFade.topAnchor.constraint(equalTo: inputBar.composerGuide.topAnchor, constant: -44)
        ])

        suggestionsBottomConstraint = suggestionsView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        NSLayoutConstraint.activate([
            suggestionsView.topAnchor.constraint(equalTo: view.topAnchor),
            suggestionsView.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            suggestionsView.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            suggestionsBottomConstraint
        ])
        chatBottomConstraint = chatView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        NSLayoutConstraint.activate([
            chatView.topAnchor.constraint(equalTo: view.topAnchor),
            chatView.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            chatView.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            chatBottomConstraint
        ])
    }

    private static let suggestionsTopClearance: CGFloat = 76
    private static let composerMaximumWidth: CGFloat = Theme.Width.form + 24
    private static let composerMinimumWidth: CGFloat = 360

    /// The composer is as wide as the result above it plus the margin each side, never wider
    /// than the form column and never too narrow to hold its controls, so a wide window does
    /// not set a capsule twice the width of the picture it edits.
    private func updateComposerWidth() {
        var width = Self.composerMaximumWidth
        if currentState == .chat, let resultWidth = chatView.latestResultWidth {
            width = min(max(resultWidth + Theme.Space.xxl, Self.composerMinimumWidth), width)
        }
        guard abs(composerWidthConstraint.constant - width) > 0.5 else { return }
        composerWidthConstraint.constant = width
    }

    /// The suggestions scroll under the top bar and the composer. The bottom inset follows the composer
    /// exactly, plus room for its soft edge, so the last row rests clear of it and the space is given
    /// back when a keyboard or a taller capsule goes away.
    private func updateSuggestionsInsets() {
        guard inputBar.bounds.height > 0 else { return }
        let capsuleTop = inputBar.convert(inputBar.composerGuide.layoutFrame, to: view).minY
        let covered = view.bounds.height - capsuleTop
        let fade = FullScreenSuggestionsView.composerFadeClearance
        let chatGap = traitCollection.verticalSizeClass == .compact ? ChatTableView.shortWindowComposerGap : fade
        chatView.composerClearance = max(covered - view.safeAreaInsets.bottom, 0) + chatGap
        var inset = suggestionsView.contentInset
        let top = max(inset.top, Self.suggestionsTopClearance)
        let wanted = covered + fade
        guard abs(inset.top - top) > 0.5 || abs(inset.bottom - wanted) > 0.5 else { return }
        inset.top = top
        inset.bottom = wanted
        suggestionsView.contentInset = inset
    }

    private func setupTopBar() {
        topBar.onNewChat = { [weak self] in self?.newChatTapped() }
        topBar.onCredits = { [weak self] in
            guard let self else { return }
            self.haptics.impact(.click)
            CreditStoreViewController.present(from: self)
        }
        topBar.onGallery = { [weak self] in self?.galleryTapped() }
        topBar.onSettings = { [weak self] in self?.settingsTapped() }
        topBar.setShowsAdminBadge(AuthenticationManager.shared.currentUser?.isAdmin ?? false)
        updateBalanceChip(creditsViewModel.balance?.balance)
    }

    private func updateTopBarLeading(animated: Bool) {
        topBar.setLeadingStyle(currentState == .chat ? .newChat : .wordmark, animated: animated)
    }

    private func updateBalanceChip(_ balance: Int?) {
        #if DEBUG
        if DemoMode.isActive {
            topBar.setCredits(text: NumberFormatter.localizedString(from: NSNumber(value: DemoContent.balance), number: .decimal), isLow: false, value: nil)
            return
        }
        #endif
        inputBar.setAvailableBalance(balance)
        guard let balance else {
            topBar.setCredits(text: "—", isLow: false, value: nil)
            return
        }
        let imageCost = estimatedCreditCost()
        let isLow = balance < imageCost
        let freeImages = WelcomeCredits().isOnWelcomeGrant(balance: balance)
            ? WelcomeCredits.freeImages(balance: balance, imageCost: imageCost) : nil
        let title = freeImages.map { String(localized: "\($0) free") }
            ?? NumberFormatter.localizedString(from: NSNumber(value: balance), number: .decimal)
        let spoken = freeImages.map { String(localized: "\($0) free images left") }
            ?? String(localized: "\(balance) credits")
        topBar.setCredits(text: title, isLow: isLow, value: isLow ? "\(spoken), \(String(localized: "Not enough credits"))" : spoken)
    }

    private func refreshBalanceChip() {
        updateBalanceChip(creditsViewModel.balance?.balance)
    }

    private func estimatedCreditCost() -> Int {
        if let fixedCost = inputBar.selectedModel.fixedCost { return fixedCost }
        switch inputBar.selectedQuality.value {
        case "low": return 4
        case "medium": return 16
        case "high": return 62
        default: return 50
        }
    }
    private func setupHandlers() {
        inputBar.onSend = { [weak self] prompt in
            self?.handleSendPrompt(prompt)
        }
        inputBar.onAddPhoto = { [weak self] in
            self?.pendingPreset = nil
            self?.presentPhotoPicker()
        }
        inputBar.onStop = { [weak self] in
            self?.cancelGeneration()
        }
        inputBar.onGetCredits = { [weak self] in
            guard let self else { return }
            _ = self.hasCredits(for: self.estimatedCreditCost())
        }
        inputBar.onLayoutChanged = { [weak self] in
            self?.updateSuggestionsInsets()
        }
        chatView.onStarterPromptSelected = { [weak self] prompt in
            guard let self else { return }
            self.inputBar.setText(prompt)
            _ = self.inputBar.becomeFirstResponder()
        }
        suggestionsView.onEditImageTapped = { [weak self] in
            self?.pendingPreset = nil
            self?.presentPhotoPicker()
        }
        suggestionsView.onImageTapped = { [weak self] image in
            self?.photoPicked(image)
        }
        suggestionsView.onPresetSelected = { [weak self] preset in
            self?.presetTapped(preset)
        }
        suggestionsView.onPhotoRemoved = { [weak self] in
            self?.switchToGenerateMode()
        }
        suggestionsView.onSampleTapped = { [weak self] in
            self?.sampleTapped()
        }
        inputBar.onClearEditImage = { [weak self] in
            self?.switchToGenerateMode()
        }
        inputBar.onCostInputsChanged = { [weak self] in
            self?.refreshBalanceChip()
        }
        suggestionsView.onSelectionChanged = { [weak self] in
            self?.inputBar.updateIndicators()
            if let composedPrompt = self?.selectedSuggestionsManager.composePrompt(basePrompt: "") {
                self?.inputBar.setText(composedPrompt)
            }
        }
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
        NotificationCenter.default.addObserver(self, selector: #selector(imageSelectedForEdit(_:)), name: Notification.Name("ImageSelectedForEdit"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    private func setupBindings() {
        creditsViewModel.$balance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] balance in
                self?.updateBalanceChip(balance?.balance)
            }
            .store(in: &cancellables)
        #if DEBUG
        let skipBalanceFetch = DemoMode.isActive
        #else
        let skipBalanceFetch = false
        #endif
        if !skipBalanceFetch {
            Task { await creditsViewModel.loadBalance() }
        }
        viewModel.messagesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                self?.chatView.setMessages(messages)
            }
            .store(in: &cancellables)
        viewModel.isGeneratingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isGenerating in
                self?.inputBar.setGenerating(isGenerating)
                if isGenerating {
                    Announce.say(String(localized: "Creating your image"))
                }
                if !isGenerating {
                    Task { await self?.creditsViewModel.loadBalance() }
                    self?.consumePresetLink()
                }
            }
            .store(in: &cancellables)
        viewModel.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if let error = error {
                    print("🖋️ ChatGenerationVC: Error received from viewModel: \(error)")
                    self?.showError(error)
                }
            }
            .store(in: &cancellables)
        viewModel.progressPublisher
            .receive(on: DispatchQueue.main)
            .sink { progress in
            }
            .store(in: &cancellables)
        viewModel.generationSucceededPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.continueEditingLatestResult()
                Announce.say(String(localized: "Your image is ready"))
                self?.chatView.focusLatestResult()
            }
            .store(in: &cancellables)
    }

    /// After every result the input bar holds that image, so the next message refines it
    /// the way a chat promises; the ✕ on its thumbnail goes back to making new images.
    private func continueEditingLatestResult() {
        guard let latest = viewModel.latestResultImage else { return }
        toolbarMode = .edit(selectedImage: SelectedImage(image: latest, url: nil, displayName: nil))
        inputBar.setEditMode(true, selectedImage: latest)
        inputBar.clear()
        suggestionsView.setEditMode(true, photo: latest)
    }
    
    private func setupNotificationObserver() {
        presetLinkObserver = NotificationCenter.default.addObserver(
            forName: PresetLink.didArrive,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.consumePresetLink()
        }
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .openChatFromNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let notificationChatId = userInfo["chatId"] as? String,
                  notificationChatId == self?.chatId else { return }
            
            if self?.currentState == .suggestions {
                self?.transitionToState(.chat, animated: true)
            }
        }
    }
    
    private func transitionToState(_ newState: ViewState, animated: Bool) {
        guard newState != currentState else { return }
        let fromView: UIView
        let toView: UIView
        switch (currentState, newState) {
        case (.suggestions, .chat):
            fromView = suggestionsView
            toView = chatView
        case (.chat, .suggestions):
            fromView = chatView
            toView = suggestionsView
        default:
            return
        }
        currentState = newState
        updateComposerWidth()
        updateAccessibilityVisibility()
        updateTopBarLeading(animated: animated)
        if animated {
            toView.alpha = 0
            toView.transform = CGAffineTransform(translationX: 0, y: 20)
            Motion.animate(
                0.3,
                options: [.curveEaseInOut],
                animations: {
                    fromView.alpha = 0
                    fromView.transform = CGAffineTransform(translationX: 0, y: -20)
                    toView.alpha = 1
                    toView.transform = .identity
                },
                completion: { _ in
                    fromView.transform = .identity
                }
            )
        } else {
            fromView.alpha = 0
            toView.alpha = 1
        }
    }

    /// Only the visible one of the suggestions and the chat is reachable by VoiceOver; the
    /// other is just faded out.
    private func updateAccessibilityVisibility() {
        suggestionsView.accessibilityElementsHidden = currentState != .suggestions
        chatView.accessibilityElementsHidden = currentState != .chat
    }
    private func handleSendPrompt(_ prompt: String) {
        print("🖋️ ChatGenerationVC: handleSendPrompt called with prompt: \(prompt)")
        guard !prompt.isEmpty else {
            print("🖋️ ChatGenerationVC: Prompt is empty, returning")
            return
        }
        if AIConsentViewController.presentIfNeeded(from: self, onContinue: { [weak self] in
            self?.handleSendPrompt(prompt)
        }) {
            return
        }
        if prompt == "EDIT_MODE" {
            handleEditImage()
            return
        }
        guard hasCredits(for: estimatedCreditCost()) else { return }
        if currentState == .suggestions {
            print("🖋️ ChatGenerationVC: Transitioning from suggestions to chat")
            suggestionsView.alpha = 0
            transitionToState(.chat, animated: true)
        }
        print("🖋️ ChatGenerationVC: Setting up generation options")
        viewModel.prompt = prompt
        currentOptions.prompt = prompt
        currentOptions.model = inputBar.selectedModel.value

        if inputBar.selectedModel == .openai {
            currentOptions.size = inputBar.selectedSize.value
            currentOptions.quality = inputBar.selectedQuality.value
            currentOptions.outputFormat = inputBar.selectedFormat
            currentOptions.compression = inputBar.selectedFormat != "png" ? inputBar.compressionLevel : nil
            currentOptions.background = inputBar.selectedBackground
            currentOptions.moderation = inputBar.selectedModeration
        } else {
            currentOptions.size = "auto"
            currentOptions.quality = "low"
            currentOptions.outputFormat = nil
            currentOptions.compression = nil
            currentOptions.background = nil
            currentOptions.moderation = nil
        }
        print("🖋️ ChatGenerationVC: Calling viewModel.generateImages")
        viewModel.generateImages(with: currentOptions)
    }
    /// Opens the store instead of sending a request the balance cannot cover; an unknown
    /// balance lets the request through and the server's 402 decides.
    private func hasCredits(for cost: Int) -> Bool {
        guard let balance = creditsViewModel.balance?.balance, balance < cost else { return true }
        CreditStoreViewController.present(from: self, shortfall: cost - balance)
        return false
    }

    private func presetTapped(_ preset: EditPreset) {
        haptics.impact(.click)
        if case let .edit(selected) = toolbarMode {
            runPreset(preset, on: selected.image)
        } else {
            pendingPreset = preset
            presentPhotoPicker()
        }
    }

    /// Lets a first-time person watch a one-tap edit work without choosing a photo: the bundled
    /// old photo runs through the same restore preset, consent and credit checks as any photo.
    private func sampleTapped() {
        guard let preset = EditPreset.preset(id: "restore"),
              let sample = UIImage(named: "onboarding_before_1") else { return }
        haptics.impact(.click)
        pendingPreset = nil
        switchToEditMode(with: sample, url: nil)
        runPreset(preset, on: sample)
    }

    private func runPreset(_ preset: EditPreset, on image: UIImage) {
        if AIConsentViewController.presentIfNeeded(from: self, onContinue: { [weak self] in
            self?.runPreset(preset, on: image)
        }) {
            return
        }
        let model = inputBar.selectedModel.presetModel
        let cost = (model.fixedCost ?? CreditStoreViewController.defaultImageCreditCost) * preset.imageCount
        guard hasCredits(for: cost) else { return }
        var options = EditOptions()
        options.prompt = preset.prompt
        options.model = model.value
        options.variations = preset.imageCount
        AppLogger.info("Preset \(preset.id) on \(model.value)", category: .generation)
        startEdit(of: image, options: options, displayText: preset.title)
    }

    private func startEdit(of image: UIImage, options: EditOptions, displayText: String?) {
        if currentState == .suggestions {
            suggestionsView.alpha = 0
        }
        transitionToState(.chat, animated: true)
        viewModel.editImage(image: image, options: options, displayText: displayText)
    }

    /// A picked photo goes straight into edit mode, or straight into the preset that asked
    /// for it; there is no confirmation screen in between.
    private func photoPicked(_ image: UIImage) {
        switchToEditMode(with: image, url: nil)
        guard let preset = pendingPreset else { return }
        pendingPreset = nil
        runPreset(preset, on: image)
    }

    private func handleQuickAction(_ action: String) {
        switch action {
        case "Remove background":
            currentOptions.removeBackground = true
            currentOptions.background = "transparent"
        case "Enhance quality":
            currentOptions.quality = "high"
        case "Fix lighting":
            currentOptions.modifiers.append("professional lighting")
        case "Add style":

            break
        case "Upscale 2x":
            currentOptions.upscale = 2
        case "Square crop":
            currentOptions.modifiers.append("square crop")
        case "Portrait mode":
            currentOptions.modifiers.append("portrait mode, bokeh")
        case "Remove object":

            break
        case "Change colors":

            break
        case "Add effects":

            break
        case "Auto enhance":
            currentOptions.autoEnhance = true
        case "Create variations":
            currentOptions.variations = true
        case "Extract text":
            currentOptions.extractText = true
        case "Generate similar":
            currentOptions.generateSimilar = true
        default:
            break
        }
        inputBar.setText(action)
    }
    private func showError(_ error: GenerationError) {
        Announce.say(error.localizedDescription)
        // Dismiss any existing alert first
        if presentedViewController is UIAlertController {
            dismiss(animated: false) { [weak self] in
                self?.presentErrorAlert(error)
            }
        } else {
            presentErrorAlert(error)
        }
    }
    
    private func presentErrorAlert(_ error: GenerationError) {
        if case .insufficientCredits = error {
            Task { await creditsViewModel.loadBalance() }
            CreditStoreViewController.present(from: self, shortfall: nil)
            return
        }
        let alert = UIAlertController(
            title: String(localized: "Generation Failed"),
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default))
        present(alert, animated: true)
    }
    @objc private func newChatTapped() {
        haptics.impact(.click)
        if case .edit = toolbarMode {
            switchToGenerateMode()
        }
        viewModel.resetChat()
        
        inputBar.applyDefaults()
        inputBar.clear()
        
        currentOptions = GenerationOptions.default
        currentOptions.size = inputBar.selectedSize.value
        currentOptions.quality = inputBar.selectedQuality.value
        currentOptions.outputFormat = inputBar.selectedFormat
        currentOptions.compression = inputBar.selectedFormat != "png" ? inputBar.compressionLevel : nil
        currentOptions.background = inputBar.selectedBackground
        currentOptions.moderation = inputBar.selectedModeration
        
        selectedSuggestionsManager.clearAll()
        inputBar.updateIndicators()
        suggestionsView.refreshView()
        transitionToState(.suggestions, animated: true)
        if UIAccessibility.isVoiceOverRunning {
            Announce.layoutChanged(suggestionsView)
        }
    }
    @objc private func galleryTapped() {
        haptics.impact(.click)
        let galleryVC = GalleryViewController()
        navigationController?.pushViewController(galleryVC, animated: true)
    }
    @objc private func creditsTapped() {
        haptics.impact(.click)
        CreditStoreViewController.present(from: self)
    }
    @objc private func settingsTapped() {
        haptics.impact(.click)
        let settingsVC = SettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
    }
    private func cancelGeneration() {
        viewModel.cancelGeneration()
    }
    /// The system photo picker runs out of process and needs no library permission, so
    /// picking a photo never starts with a permission prompt.
    private func presentPhotoPicker() {
        if AIConsentViewController.presentIfNeeded(from: self, onContinue: { [weak self] in
            self?.presentPhotoPicker()
        }, onDeclined: { [weak self] in
            self?.pendingPreset = nil
        }) {
            return
        }
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func switchToEditMode(with image: UIImage, url: URL?) {
        haptics.impact(.click)
        toolbarMode = .edit(selectedImage: SelectedImage(image: image, url: url, displayName: nil))
        inputBar.setEditMode(true, selectedImage: image)
        inputBar.clear()
        suggestionsView.setEditMode(true, photo: image)
    }
    private func switchToGenerateMode() {
        haptics.impact(.click)
        toolbarMode = .generate
        inputBar.setEditMode(false, selectedImage: nil)
        suggestionsView.setEditMode(false)
    }
    private func adjustChatBottomConstraint(for height: CGFloat) {
        Motion.spring(0.3, damping: 0.8) {
            self.chatBottomConstraint.constant = -height
            self.suggestionsBottomConstraint.constant = -height
            self.view.layoutIfNeeded()
        }
    }
    private func presentImagePreviewForEdit(_ image: UIImage) {
        let previewVC = ImagePreviewViewController(image: image)
        previewVC.modalPresentationStyle = .pageSheet
        previewVC.onEditConfirmed = { [weak self] in
            self?.dismiss(animated: true) {
                self?.switchToEditMode(with: image, url: nil)
            }
        }
        present(previewVC, animated: true)
    }
    private func handleEditImage() {
        guard case let .edit(selectedImage) = toolbarMode else { return }
        let editOptions = inputBar.getEditOptions()
        guard !editOptions.prompt.isEmpty, hasCredits(for: estimatedCreditCost()) else { return }
        startEdit(of: selectedImage.image, options: editOptions, displayText: editOptions.prompt)
        inputBar.clear()
    }
    @objc private func imageSelectedForEdit(_ notification: Notification) {
        guard let imageMetadata = notification.userInfo?["image"] as? ImageMetadata else { return }
        
        if let url = URL(string: imageMetadata.url) {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
                guard let data = data, let image = UIImage(data: data), error == nil else { return }
                
                DispatchQueue.main.async {
                    self?.presentImagePreviewForEdit(image)
                }
            }.resume()
        }
    }
    
    @objc private func applicationDidBecomeActive() {
        suggestionsView.refreshRecentImages()
    }
    @objc private func handleBackgroundTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        let inputBarFrame = inputBar.convert(inputBar.bounds, to: view)
        guard !inputBarFrame.contains(location) else { return }
        if inputBar.isExpanded {
            inputBar.collapse()
        } else if inputBar.isEditingText {
            inputBar.resignFirstResponder()
        }
    }
}



extension ChatGenerationViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UIButton || touch.view is UICollectionViewCell {
            return false
        }
        return true
    }
}



extension ChatGenerationViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else {
            pendingPreset = nil
            return
        }
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
            DispatchQueue.main.async {
                guard let image = image as? UIImage else {
                    self?.pendingPreset = nil
                    AppLogger.error("Picked photo could not be loaded: \(error?.localizedDescription ?? "no image")", category: .ui)
                    return
                }
                self?.photoPicked(image)
            }
        }
    }
}



extension ChatGenerationViewController: ChatTableViewDelegate {
    func chatTableView(_ chatTableView: ChatTableView, didTapImageAt index: Int, in message: ChatMessage) {
        haptics.impact(.click)
        guard let images = message.images,
              index < images.count else { return }
        let image = images[index]
        let previewVC = ImagePreviewViewController(image: image)
        previewVC.modalPresentationStyle = .pageSheet
        present(previewVC, animated: true)
    }
    func chatTableView(_ chatTableView: ChatTableView, didLongPressImageAt index: Int, in message: ChatMessage) {
    }
    func chatTableView(_ chatTableView: ChatTableView, didSelectImageForEdit index: Int, in message: ChatMessage) {
        haptics.impact(.click)
        guard let images = message.images,
              index < images.count else { return }
        let image = images[index]
        switchToEditMode(with: image, url: nil)
    }
    func chatTableView(_ chatTableView: ChatTableView, didRequest action: ResultAction, imageIndex: Int?, for message: ChatMessage, from sourceView: UIView) {
        guard let images = message.images, let first = images.first else { return }
        let targets = imageIndex.flatMap { images.indices.contains($0) ? [images[$0]] : nil } ?? images
        switch action {
        case .save:
            PhotoSavingService.shared.saveToLibrary(targets) { [weak self] result in
                switch result {
                case .success:
                    self?.showBatchSaveSuccess(count: targets.count)
                    self?.chatView.showActionSucceeded(.save, for: message)
                case .failure(let error):
                    self?.showBatchSaveError(error)
                }
            }
        case .share:
            ImageSharingService.shared.shareImages(targets, from: self, sourceView: sourceView) { [weak self] completed, _ in
                if completed { self?.chatView.showActionSucceeded(.share, for: message) }
            }
        case .beforeAfter:
            guard let source = message.sourceImage else { return }
            let composite = BeforeAfterComposer.compose(before: source, after: targets.first ?? first)
            ImageSharingService.shared.shareImage(composite, from: self, sourceView: sourceView)
        }
    }
    private func showBatchSaveSuccess(count: Int) {
        haptics.impact(.success)
        Announce.say(String(localized: "Saved to Photos"))
    }
    private func showBatchSaveError(_ error: PhotoSavingError) {
        haptics.impact(.error)
        let alert = UIAlertController(
            title: String(localized: "Save Failed"),
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default))
        if case .permissionDenied = error {
            alert.addAction(UIAlertAction(title: String(localized: "Open Settings"), style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            })
        }
        present(alert, animated: true)
    }
}

struct GenerationOptions {
    var prompt: String
    var model: String
    var quantity: Int
    var size: String
    var sizeDisplay: String
    var quality: String
    var stylePreset: String?
    var modifiers: [String]
    var removeBackground: Bool
    var background: String?
    var upscale: Int?
    var autoEnhance: Bool
    var variations: Bool
    var extractText: Bool
    var generateSimilar: Bool
    var outputFormat: String?
    var compression: Int?
    var moderation: String?
    static var `default`: GenerationOptions {
        GenerationOptions(
            prompt: "",
            model: "gemini-2.5-flash",
            quantity: 1,
            size: "1024x1024",
            sizeDisplay: String(localized: "Square"),
            quality: "low",
            stylePreset: nil,
            modifiers: [],
            removeBackground: false,
            background: nil,
            upscale: nil,
            autoEnhance: false,
            variations: false,
            extractText: false,
            generateSimilar: false,
            outputFormat: nil,
            compression: nil,
            moderation: nil
        )
    }
}

extension ChatGenerationViewController {
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass ||
           traitCollection.verticalSizeClass != previousTraitCollection?.verticalSizeClass {
            updateLayoutForSizeClass()
        }
    }
    
    private func updateLayoutForSizeClass() {
        leadingConstraint?.constant = 0
        trailingConstraint?.constant = 0

        Motion.animate(0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    private func setupKeyboardCommands() {
        addKeyCommand(UIKeyCommand(title: String(localized: "New Chat"),
                                  action: #selector(newChatTapped),
                                  input: "N",
                                  modifierFlags: .command))
        
        addKeyCommand(UIKeyCommand(title: String(localized: "Generate"),
                                  action: #selector(generateWithKeyboard),
                                  input: "\r",
                                  modifierFlags: .command))
        
        addKeyCommand(UIKeyCommand(title: String(localized: "Open Gallery"),
                                  action: #selector(galleryTapped),
                                  input: "G",
                                  modifierFlags: .command))
        
        addKeyCommand(UIKeyCommand(title: String(localized: "Save Image"),
                                  action: #selector(saveCurrentImage),
                                  input: "S",
                                  modifierFlags: .command))
        
        addKeyCommand(UIKeyCommand(title: String(localized: "Focus Input"),
                                  action: #selector(focusInputField),
                                  input: "L",
                                  modifierFlags: .command))
        
        addKeyCommand(UIKeyCommand(title: String(localized: "Toggle Sidebar"),
                                  action: #selector(toggleSidebarShortcut),
                                  input: "\\",
                                  modifierFlags: .command))
    }
    
    @objc private func generateWithKeyboard() {
        if let text = inputBar.getCurrentText(), !text.isEmpty {
            handleSendPrompt(text)
        }
    }
    
    @objc private func saveCurrentImage() {
        if let lastMessage = viewModel.messages.last,
           !lastMessage.isUser,
           let images = lastMessage.images,
           let firstImage = images.first {
            UIImageWriteToSavedPhotosAlbum(firstImage, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
        }
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if error != nil {
            haptics.notification(.error)
            Announce.say(String(localized: "Save Failed"))
        } else {
            haptics.notification(.success)
            Announce.say(String(localized: "Saved to Photos"))
        }
    }
    
    @objc private func focusInputField() {
        inputBar.becomeFirstResponder()
    }
    
    @objc private func toggleSidebarShortcut() {
        if let splitVC = self.splitViewController as? MainSplitViewController {
            if splitVC.displayMode == .oneBesideSecondary {
                splitVC.preferredDisplayMode = .secondaryOnly
            } else {
                splitVC.preferredDisplayMode = .oneBesideSecondary
            }
        }
    }
    
    private func setupDragAndDrop() {
        view.addInteraction(UIDropInteraction(delegate: self))
        chatView.addInteraction(UIDragInteraction(delegate: self))
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
}

extension ChatGenerationViewController: UIDropInteractionDelegate {
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.hasItemsConforming(toTypeIdentifiers: [UTType.image.identifier])
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return UIDropProposal(operation: .copy)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        session.loadObjects(ofClass: UIImage.self) { [weak self] items in
            guard let images = items as? [UIImage], let image = images.first else { return }
            DispatchQueue.main.async {
                self?.presentImagePreviewForEdit(image)
            }
        }
    }
}

extension ChatGenerationViewController: UIDragInteractionDelegate {
    func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
        guard let lastMessage = viewModel.messages.last,
              !lastMessage.isUser,
              let images = lastMessage.images,
              let image = images.first else { return [] }
        
        let provider = NSItemProvider(object: image)
        let dragItem = UIDragItem(itemProvider: provider)
        dragItem.localObject = image
        return [dragItem]
    }
}

private final class KeyboardOverlapView: UIView {
    var onHeightChange: ((CGFloat) -> Void)?
    private var reportedHeight: CGFloat = 0

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.height != reportedHeight else { return }
        reportedHeight = bounds.height
        onHeightChange?(bounds.height)
    }
}
