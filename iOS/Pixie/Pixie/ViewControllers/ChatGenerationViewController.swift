import UIKit
import PhotosUI
import Combine

class ChatGenerationViewController: UIViewController {
    
    // MARK: - Types
    
    enum ViewState {
        case suggestions
        case chat
    }
    
    // MARK: - Properties
    
    private var currentState: ViewState = .suggestions
    
    private let suggestionsView = FullScreenSuggestionsView()
    private let chatView = ChatTableView()
    private let inputBar = ChatInputBar()
    private let selectedSuggestionsManager = SelectedSuggestionsManager()
    
    private let viewModel = GenerationViewModel()
    private var cancellables = Set<AnyCancellable>()
    private var currentOptions = GenerationOptions.default
    
    private let haptics = HapticManager.shared
    
    // MARK: - Constraints
    
    private var suggestionsBottomConstraint: NSLayoutConstraint!
    private var chatBottomConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupNavigationBar()
        setupHandlers()
        setupBindings()
        transitionToState(.suggestions, animated: false)
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
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBar.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        suggestionsBottomConstraint = suggestionsView.bottomAnchor.constraint(equalTo: inputBar.topAnchor)
        NSLayoutConstraint.activate([
            suggestionsView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            suggestionsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            suggestionsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            suggestionsBottomConstraint
        ])
        chatBottomConstraint = chatView.bottomAnchor.constraint(equalTo: inputBar.topAnchor)
        NSLayoutConstraint.activate([
            chatView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
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
        let settingsButton = UIBarButtonItem(image: UIImage(systemName: "gearshape"), style: .plain, target: self, action: #selector(settingsTapped))
        
        navigationItem.rightBarButtonItems = [settingsButton, creditsButton, galleryButton]
    }
    
    private func setupHandlers() {
        inputBar.onSend = { [weak self] prompt in
            self?.handleSendPrompt(prompt)
        }
        
        inputBar.onExpandedChanged = { [weak self] isExpanded in
        }
        suggestionsView.onEditImageTapped = { [weak self] in
            self?.presentPhotoPicker()
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
                    self?.showError(error)
                }
            }
            .store(in: &cancellables)
        
        viewModel.progressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                
            }
            .store(in: &cancellables)
    }
    
    // MARK: - State Management
    
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
    
    // MARK: - Actions
    
    private func handleSendPrompt(_ prompt: String) {
        guard !prompt.isEmpty else { return }
        if currentState == .suggestions {
            transitionToState(.chat, animated: true)
        }
        
        viewModel.prompt = prompt
        currentOptions.prompt = prompt
        currentOptions.size = inputBar.selectedSize.value
        currentOptions.quality = inputBar.selectedQuality.value
        currentOptions.outputFormat = inputBar.selectedFormat
        currentOptions.compression = inputBar.selectedFormat != "png" ? inputBar.compressionLevel : nil
        currentOptions.background = inputBar.selectedBackground
        currentOptions.moderation = inputBar.selectedModeration
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
            // Just add square crop modifier, don't change selected size
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
    
    // MARK: - Navigation Actions
    
    @objc private func newChatTapped() {
        haptics.impact(.click)
        viewModel.resetChat()
        // Reset options but preserve user's selected settings
        currentOptions = GenerationOptions.default
        currentOptions.size = inputBar.selectedSize.value
        currentOptions.quality = inputBar.selectedQuality.value
        currentOptions.outputFormat = inputBar.selectedFormat
        currentOptions.compression = inputBar.selectedFormat != "png" ? inputBar.compressionLevel : nil
        currentOptions.background = inputBar.selectedBackground
        currentOptions.moderation = inputBar.selectedModeration
        selectedSuggestionsManager.clearAll()
        inputBar.updateIndicators()
        inputBar.clear()
        suggestionsView.refreshView()
        transitionToState(.suggestions, animated: true)
    }
    
    @objc private func galleryTapped() {
        haptics.impact(.click)
    }
    
    @objc private func creditsTapped() {
        haptics.impact(.click)
    }
    
    @objc private func settingsTapped() {
        haptics.impact(.click)
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
            let settingsButton = UIBarButtonItem(image: UIImage(systemName: "gearshape"), style: .plain, target: self, action: #selector(settingsTapped))
            navigationItem.rightBarButtonItems = [settingsButton, creditsButton, galleryButton]
        }
    }
    
    // MARK: - Photo Picker
    
    private func presentPhotoPicker() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    // MARK: - Keyboard Handling
    
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
    
    @objc private func handleBackgroundTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        let inputBarFrame = inputBar.convert(inputBar.bounds, to: view)
        
        if !inputBarFrame.contains(location) && inputBar.isExpanded {
            inputBar.collapse()
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension ChatGenerationViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UIButton || touch.view is UICollectionViewCell {
            return false
        }
        return true
    }
}

// MARK: - PHPickerViewControllerDelegate

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
        transitionToState(.chat, animated: true)
        viewModel.updateSelectedImage(image)
        viewModel.updateToolbarMode(.edit)
        inputBar.setText("Edit this image")
    }
}

// MARK: - ChatTableViewDelegate

extension ChatGenerationViewController: ChatTableViewDelegate {
    func chatTableView(_ chatTableView: ChatTableView, didTapImageAt index: Int, in message: ChatMessage) {
        haptics.impact(.click)
        
        guard let images = message.images,
              index < images.count else { return }
        
        let image = images[index]
        
        // Present full screen image preview
        let previewVC = ImagePreviewViewController(image: image)
        previewVC.modalPresentationStyle = .pageSheet
        
        present(previewVC, animated: true)
    }
    
    func chatTableView(_ chatTableView: ChatTableView, didLongPressImageAt index: Int, in message: ChatMessage) {
        // Context menu handles this now
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