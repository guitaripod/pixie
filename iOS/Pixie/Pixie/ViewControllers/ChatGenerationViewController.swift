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
    private var notificationObserver: NSObjectProtocol?
    private var layoutManager = AdaptiveLayoutManager(traitCollection: UITraitCollection.current)
    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupNavigationBar()
        setupHandlers()
        setupBindings()
        setupNotificationObserver()
        setupKeyboardCommands()
        setupDragAndDrop()
        transitionToState(.suggestions, animated: false)
        layoutManager.delegate = self
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    private func setupUI() {
        view.backgroundColor = .systemBackground
        suggestionsView.translatesAutoresizingMaskIntoConstraints = false
        suggestionsView.alpha = 1
        suggestionsView.selectedSuggestionsManager = selectedSuggestionsManager
        view.addSubview(suggestionsView)
        chatView.translatesAutoresizingMaskIntoConstraints = false
        chatView.alpha = 0
        chatView.delegate = self
        view.addSubview(chatView)
        inputBar.translatesAutoresizingMaskIntoConstraints = false
        inputBar.selectedSuggestionsManager = selectedSuggestionsManager
        view.addSubview(inputBar)
        offlineBanner.alpha = 0
        view.addSubview(offlineBanner)
    }
    private func setupConstraints() {
        let layout = AdaptiveLayout(traitCollection: traitCollection)
        let insets = layout.contentInsets

        leadingConstraint = inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        trailingConstraint = inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        
        NSLayoutConstraint.activate([
            leadingConstraint,
            trailingConstraint,
            inputBar.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        let bannerTopConstraint = offlineBanner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: -36)
        offlineBanner.setTopConstraint(bannerTopConstraint)
        NSLayoutConstraint.activate([
            offlineBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            offlineBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bannerTopConstraint
        ])

        suggestionsBottomConstraint = suggestionsView.bottomAnchor.constraint(equalTo: inputBar.topAnchor)
        NSLayoutConstraint.activate([
            suggestionsView.topAnchor.constraint(equalTo: offlineBanner.bottomAnchor),
            suggestionsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            suggestionsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            suggestionsBottomConstraint
        ])
        chatBottomConstraint = chatView.bottomAnchor.constraint(equalTo: inputBar.topAnchor)
        NSLayoutConstraint.activate([
            chatView.topAnchor.constraint(equalTo: offlineBanner.bottomAnchor),
            chatView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chatView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chatBottomConstraint
        ])
    }
    private func setupNavigationBar() {
        let newChatButton = UIButton(type: .system)
        newChatButton.setImage(UIImage(systemName: "sparkles"), for: .normal)
        newChatButton.setTitle(" New", for: .normal)
        newChatButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        newChatButton.addTarget(self, action: #selector(newChatTapped), for: .touchUpInside)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: newChatButton)
        
        let galleryButton = UIBarButtonItem(title: "Gallery", style: .plain, target: self, action: #selector(galleryTapped))
        let creditsButton = UIBarButtonItem(title: "Credits", style: .plain, target: self, action: #selector(creditsTapped))
        
        let isAdmin = AuthenticationManager.shared.currentUser?.isAdmin ?? false
        let settingsButton: UIBarButtonItem
        
        if isAdmin {
            let settingsView = UIView()
            let settingsImageView = UIImageView(image: UIImage(systemName: "gearshape"))
            settingsImageView.tintColor = self.view.tintColor
            settingsImageView.contentMode = .scaleAspectFit
            settingsImageView.translatesAutoresizingMaskIntoConstraints = false
            
            let badgeView = UIView()
            badgeView.backgroundColor = .systemOrange
            badgeView.layer.cornerRadius = 6
            badgeView.translatesAutoresizingMaskIntoConstraints = false
            
            settingsView.addSubview(settingsImageView)
            settingsView.addSubview(badgeView)
            
            NSLayoutConstraint.activate([
                settingsImageView.centerXAnchor.constraint(equalTo: settingsView.centerXAnchor),
                settingsImageView.centerYAnchor.constraint(equalTo: settingsView.centerYAnchor),
                settingsImageView.widthAnchor.constraint(equalToConstant: 24),
                settingsImageView.heightAnchor.constraint(equalToConstant: 24),
                
                badgeView.topAnchor.constraint(equalTo: settingsImageView.topAnchor, constant: -2),
                badgeView.trailingAnchor.constraint(equalTo: settingsImageView.trailingAnchor, constant: 2),
                badgeView.widthAnchor.constraint(equalToConstant: 12),
                badgeView.heightAnchor.constraint(equalToConstant: 12),
                
                settingsView.widthAnchor.constraint(equalToConstant: 28),
                settingsView.heightAnchor.constraint(equalToConstant: 28)
            ])
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(settingsTapped))
            settingsView.addGestureRecognizer(tapGesture)
            settingsView.isUserInteractionEnabled = true
            
            settingsButton = UIBarButtonItem(customView: settingsView)
        } else {
            settingsButton = UIBarButtonItem(image: UIImage(systemName: "gearshape"), style: .plain, target: self, action: #selector(settingsTapped))
        }
        
        navigationItem.rightBarButtonItems = [settingsButton, creditsButton, galleryButton]
    }
    private func setupHandlers() {
        inputBar.onSend = { [weak self] prompt in
            self?.handleSendPrompt(prompt)
        }
        inputBar.onExpandedChanged = { isExpanded in
        }
        suggestionsView.onEditImageTapped = { [weak self] in
            self?.presentPhotoPicker()
        }
        suggestionsView.onImageTapped = { [weak self] image in
            self?.presentImagePreviewForEdit(image)
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
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(imageSelectedForEdit(_:)), name: Notification.Name("ImageSelectedForEdit"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    private func setupBindings() {
        viewModel.messagesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                self?.chatView.setMessages(messages)
            }
            .store(in: &cancellables)
        viewModel.isGeneratingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isGenerating in
                self?.inputBar.isUserInteractionEnabled = !isGenerating
                self?.updateNavigationForGenerating(isGenerating)
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
    }
    
    private func setupNotificationObserver() {
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
        if animated {
            toView.alpha = 0
            toView.transform = CGAffineTransform(translationX: 0, y: 20)
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
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
    private func handleSendPrompt(_ prompt: String) {
        print("🖋️ ChatGenerationVC: handleSendPrompt called with prompt: \(prompt)")
        guard !prompt.isEmpty else {
            print("🖋️ ChatGenerationVC: Prompt is empty, returning")
            return
        }
        if prompt == "EDIT_MODE" {
            print("🖋️ ChatGenerationVC: Edit mode detected")
            handleEditImage()
            return
        }
        if currentState == .suggestions {
            print("🖋️ ChatGenerationVC: Transitioning from suggestions to chat")
            suggestionsView.alpha = 0
            transitionToState(.chat, animated: true)
        }
        print("🖋️ ChatGenerationVC: Setting up generation options")
        viewModel.prompt = prompt
        currentOptions.prompt = prompt
        currentOptions.size = inputBar.selectedSize.value
        currentOptions.quality = inputBar.selectedQuality.value
        currentOptions.outputFormat = inputBar.selectedFormat
        currentOptions.compression = inputBar.selectedFormat != "png" ? inputBar.compressionLevel : nil
        currentOptions.background = inputBar.selectedBackground
        currentOptions.moderation = inputBar.selectedModeration
        print("🖋️ ChatGenerationVC: Calling viewModel.generateImages")
        viewModel.generateImages(with: currentOptions)
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
        let alert = UIAlertController(
            title: "Generation Failed",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        if case .insufficientCredits = error {
            alert.addAction(UIAlertAction(title: "Buy Credits", style: .default) { [weak self] _ in
                self?.creditsTapped()
            })
        }
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
    }
    @objc private func galleryTapped() {
        haptics.impact(.click)
        let galleryVC = GalleryViewController()
        navigationController?.pushViewController(galleryVC, animated: true)
    }
    @objc private func creditsTapped() {
        haptics.impact(.click)
        let creditsVC = CreditsMainViewController()
        navigationController?.pushViewController(creditsVC, animated: true)
    }
    @objc private func settingsTapped() {
        haptics.impact(.click)
        let settingsVC = SettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
    }
    @objc private func cancelGeneration() {
        haptics.impact(.click)
        viewModel.cancelGeneration()
    }
    private func updateNavigationForGenerating(_ isGenerating: Bool) {
        if isGenerating {
            let cancelButton = UIBarButtonItem(
                title: "Cancel",
                style: .plain,
                target: self,
                action: #selector(cancelGeneration)
            )
            cancelButton.tintColor = .systemRed
            navigationItem.rightBarButtonItem = cancelButton
        } else {
            let galleryButton = UIBarButtonItem(title: "Gallery", style: .plain, target: self, action: #selector(galleryTapped))
            let creditsButton = UIBarButtonItem(title: "Credits", style: .plain, target: self, action: #selector(creditsTapped))
            
            // Check if user is admin
            let isAdmin = AuthenticationManager.shared.currentUser?.isAdmin ?? false
            let settingsButton: UIBarButtonItem
            
            if isAdmin {
                // Create settings button with admin badge
                let settingsView = UIView()
                let settingsImageView = UIImageView(image: UIImage(systemName: "gearshape"))
                settingsImageView.tintColor = self.view.tintColor
                settingsImageView.contentMode = .scaleAspectFit
                settingsImageView.translatesAutoresizingMaskIntoConstraints = false
                
                let badgeView = UIView()
                badgeView.backgroundColor = .systemOrange
                badgeView.layer.cornerRadius = 6
                badgeView.translatesAutoresizingMaskIntoConstraints = false
                
                settingsView.addSubview(settingsImageView)
                settingsView.addSubview(badgeView)
                
                NSLayoutConstraint.activate([
                    settingsImageView.centerXAnchor.constraint(equalTo: settingsView.centerXAnchor),
                    settingsImageView.centerYAnchor.constraint(equalTo: settingsView.centerYAnchor),
                    settingsImageView.widthAnchor.constraint(equalToConstant: 24),
                    settingsImageView.heightAnchor.constraint(equalToConstant: 24),
                    
                    badgeView.topAnchor.constraint(equalTo: settingsImageView.topAnchor, constant: -2),
                    badgeView.trailingAnchor.constraint(equalTo: settingsImageView.trailingAnchor, constant: 2),
                    badgeView.widthAnchor.constraint(equalToConstant: 12),
                    badgeView.heightAnchor.constraint(equalToConstant: 12),
                    
                    settingsView.widthAnchor.constraint(equalToConstant: 28),
                    settingsView.heightAnchor.constraint(equalToConstant: 28)
                ])
                
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(settingsTapped))
                settingsView.addGestureRecognizer(tapGesture)
                settingsView.isUserInteractionEnabled = true
                
                settingsButton = UIBarButtonItem(customView: settingsView)
            } else {
                settingsButton = UIBarButtonItem(image: UIImage(systemName: "gearshape"), style: .plain, target: self, action: #selector(settingsTapped))
            }
            
            navigationItem.rightBarButtonItems = [settingsButton, creditsButton, galleryButton]
        }
    }
    private func presentPhotoPicker() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self?.suggestionsView.refreshRecentImages()
                    var config = PHPickerConfiguration()
                    config.selectionLimit = 1
                    config.filter = .images
                    let picker = PHPickerViewController(configuration: config)
                    picker.delegate = self
                    self?.present(picker, animated: true)
                case .denied, .restricted:
                    self?.showPhotoPermissionAlert()
                case .notDetermined:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func showPhotoPermissionAlert() {
        let alert = UIAlertController(
            title: "Photo Access Required",
            message: "Please allow access to your photos to select images for editing.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        present(alert, animated: true)
    }
    private func switchToEditMode(with image: UIImage, url: URL?) {
        haptics.impact(.click)
        toolbarMode = .edit(selectedImage: SelectedImage(image: image, url: url, displayName: nil))
        inputBar.setEditMode(true, selectedImage: image)
        inputBar.clear()
        suggestionsView.setEditMode(true)
    }
    private func switchToGenerateMode() {
        haptics.impact(.click)
        toolbarMode = .generate
        inputBar.setEditMode(false, selectedImage: nil)
        suggestionsView.setEditMode(false)
    }
    private func adjustChatBottomConstraint(for height: CGFloat) {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
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
        let message = ChatMessage(
            id: UUID().uuidString,
            text: "Edit: \(editOptions.prompt)",
            images: [selectedImage.image],
            isUser: true,
            timestamp: Date(),
            metadata: nil
        )
        if currentState == .suggestions {
            suggestionsView.alpha = 0
        }
        transitionToState(.chat, animated: true)
        chatView.addMessage(message)
        viewModel.editImage(image: selectedImage.image, options: editOptions)
    }
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        let keyboardHeight = keyboardFrame.height
        chatView.adjustForKeyboard(height: keyboardHeight, duration: duration)
    }
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        chatView.adjustForKeyboard(height: 0, duration: duration)
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
        if !inputBarFrame.contains(location) && inputBar.isExpanded {
            inputBar.collapse()
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
        guard let result = results.first else { return }
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
            if let image = image as? UIImage {
                DispatchQueue.main.async {
                    self?.handleImageSelected(image)
                }
            }
        }
    }
    private func handleImageSelected(_ image: UIImage) {
        presentImagePreviewForEdit(image)
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
    private func showBatchSaveSuccess(count: Int) {
        haptics.impact(.success)
        let alert = UIAlertController(
            title: "Saved!",
            message: "\(count) image\(count > 1 ? "s" : "") saved to your Pixie album",
            preferredStyle: .alert
        )
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true)
        }
    }
    private func showBatchSaveError(_ error: PhotoSavingError) {
        haptics.impact(.error)
        let alert = UIAlertController(
            title: "Save Failed",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        if case .permissionDenied = error {
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
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
            quantity: 1,
            size: "1024x1024",
            sizeDisplay: "Square",
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
            layoutManager.updateLayout(for: traitCollection)
            updateLayoutForSizeClass()
        }
    }
    
    private func updateLayoutForSizeClass() {
        leadingConstraint?.constant = 0
        trailingConstraint?.constant = 0

        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    private func setupKeyboardCommands() {
        addKeyCommand(UIKeyCommand(title: "New Chat",
                                  action: #selector(newChatTapped),
                                  input: "N",
                                  modifierFlags: .command))
        
        addKeyCommand(UIKeyCommand(title: "Generate",
                                  action: #selector(generateWithKeyboard),
                                  input: "\r",
                                  modifierFlags: .command))
        
        addKeyCommand(UIKeyCommand(title: "Open Gallery",
                                  action: #selector(galleryTapped),
                                  input: "G",
                                  modifierFlags: .command))
        
        addKeyCommand(UIKeyCommand(title: "Save Image",
                                  action: #selector(saveCurrentImage),
                                  input: "S",
                                  modifierFlags: .command))
        
        addKeyCommand(UIKeyCommand(title: "Focus Input",
                                  action: #selector(focusInputField),
                                  input: "L",
                                  modifierFlags: .command))
        
        if UIDevice.isPad {
            addKeyCommand(UIKeyCommand(title: "Toggle Sidebar",
                                      action: #selector(toggleSidebar),
                                      input: "\\",
                                      modifierFlags: .command))
        }
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
        } else {
            haptics.notification(.success)
        }
    }
    
    @objc private func focusInputField() {
        inputBar.becomeFirstResponder()
    }
    
    @objc private func toggleSidebar() {
        if let splitVC = self.splitViewController as? MainSplitViewController {
            if splitVC.displayMode == .oneBesideSecondary {
                splitVC.preferredDisplayMode = .secondaryOnly
            } else {
                splitVC.preferredDisplayMode = .oneBesideSecondary
            }
        }
    }
    
    private func setupDragAndDrop() {
        if UIDevice.isPad {
            view.addInteraction(UIDropInteraction(delegate: self))
            chatView.addInteraction(UIDragInteraction(delegate: self))
        }
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
}

extension ChatGenerationViewController: AdaptiveLayoutDelegate {
    func layoutDidChange(to layout: AdaptiveLayout) {
        updateLayoutForSizeClass()
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