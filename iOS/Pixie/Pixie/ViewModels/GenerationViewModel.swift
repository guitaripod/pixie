import Foundation
import Combine
import UIKit
import ActivityKit

class GenerationViewModel: ObservableObject {
    
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isGenerating: Bool = false
    @Published private(set) var error: GenerationError?
    @Published private(set) var progress: Float = 0
    @Published private(set) var toolbarMode: ToolbarMode = .generate
    @Published private(set) var toolbarExpanded: Bool = false
    @Published private(set) var selectedImage: UIImage?
    @Published var prompt: String = ""
    
    enum ToolbarMode {
        case generate
        case edit
    }
    
    private let generationService: GenerationService
    private let imageRepository: ImageRepositoryProtocol
    private let hapticManager: HapticManager
    private let backgroundTaskManager = BackgroundTaskManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var currentChatId: String
    private var activeBackgroundTaskId: String?
    private var appStateObserver: NSObjectProtocol?
    private var generationStartTime: Date?
    private var currentLiveActivity: Activity<ImageGenerationAttributes>?
    
    var messagesPublisher: AnyPublisher<[ChatMessage], Never> {
        $messages.eraseToAnyPublisher()
    }
    
    var errorPublisher: AnyPublisher<GenerationError?, Never> {
        $error.eraseToAnyPublisher()
    }
    
    var progressPublisher: AnyPublisher<Float, Never> {
        $progress.eraseToAnyPublisher()
    }
    
    var isGeneratingPublisher: AnyPublisher<Bool, Never> {
        $isGenerating.eraseToAnyPublisher()
    }
    
    init(generationService: GenerationService? = nil,
         imageRepository: ImageRepositoryProtocol = AppContainer.shared.imageRepository,
         hapticManager: HapticManager = .shared,
         chatId: String? = nil) {
        self.generationService = generationService ?? GenerationService(apiService: AppContainer.shared.apiService)
        self.imageRepository = imageRepository
        self.hapticManager = hapticManager
        self.currentChatId = chatId ?? UUID().uuidString
        
        setupBindings()
        setupAppStateObserver()
    }
    
    deinit {
        if let observer = appStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupBindings() {
        generationService.progressPublisher
            .sink { [weak self] progress in
                self?.progress = progress
            }
            .store(in: &cancellables)
        
        generationService.statePublisher
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)
    }
    
    private func setupAppStateObserver() {
        print("🔔 GenerationViewModel: Setting up app state observer")
        
        appStateObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🔔 GenerationViewModel: App entered background notification received")
                print("🔔 GenerationViewModel: App state = \(UIApplication.shared.applicationState.rawValue)")
                print("🔔 GenerationViewModel: isGenerating = \(self?.isGenerating ?? false)")
                
                guard UIApplication.shared.applicationState == .background else {
                    print("🔔 GenerationViewModel: App not actually in background, ignoring")
                    return
                }
                
                guard let self = self else { return }
                
                if self.isGenerating && self.generationStartTime != nil {
                    let timeSinceStart = Date().timeIntervalSince(self.generationStartTime ?? Date())
                    print("🔔 GenerationViewModel: Time since generation start: \(timeSinceStart)s")
                    
                    if timeSinceStart > 0.5 {
                        print("🔔 GenerationViewModel: Calling handleAppEnteredBackground")
                        self.handleAppEnteredBackground()
                    } else {
                        print("🔔 GenerationViewModel: Generation just started, ignoring background")
                    }
                } else {
                    print("🔔 GenerationViewModel: Not generating, ignoring background notification")
                }
            }
        }
    }
    
    private func handleAppEnteredBackground() {
        print("🌙 GenerationViewModel: handleAppEnteredBackground called")
        print("🌙 GenerationViewModel: isGenerating = \(isGenerating)")
        print("🌙 GenerationViewModel: toolbarMode = \(toolbarMode)")
        print("🌙 GenerationViewModel: prompt = \(prompt)")
        
        guard isGenerating else {
            print("🌙 GenerationViewModel: Not generating, returning")
            return
        }
        
        // Don't cancel the existing generation - Live Activity is already running
        print("🌙 GenerationViewModel: Generation continuing in background with existing Live Activity")
        
        // Update the Live Activity to show it's in background
        if let activity = currentLiveActivity {
            Task {
                let backgroundState = ImageGenerationAttributes.ContentState(
                    progress: 0.5,
                    status: .generating,
                    estimatedTimeRemaining: nil,
                    errorMessage: nil
                )
                await activity.update(ActivityContent(state: backgroundState, staleDate: Date().addingTimeInterval(60 * 30)))
            }
        }
    }
    
    private func startLiveActivityForGeneration(prompt: String, isEdit: Bool) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("❌ Live Activities are not enabled")
            return
        }
        
        let taskId = UUID().uuidString
        
        let attributes = ImageGenerationAttributes(
            prompt: prompt,
            taskId: taskId,
            chatId: currentChatId,
            isEdit: isEdit
        )
        
        let initialState = ImageGenerationAttributes.ContentState(
            progress: 0.1,
            status: .processing,
            estimatedTimeRemaining: nil,
            errorMessage: nil
        )
        
        let content = ActivityContent(state: initialState, staleDate: Date().addingTimeInterval(60 * 30))
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            
            print("✅ Live Activity started at generation begin: \(activity.id)")
            currentLiveActivity = activity
            
            // Update to generating status after a short delay
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                let generatingState = ImageGenerationAttributes.ContentState(
                    progress: 0.5,
                    status: .generating,
                    estimatedTimeRemaining: nil,
                    errorMessage: nil
                )
                await activity.update(ActivityContent(state: generatingState, staleDate: Date().addingTimeInterval(60 * 30)))
            }
                
        } catch {
            print("❌ Failed to start Live Activity: \(error)")
        }
    }
    
    func generateImages(with options: GenerationOptions) {
        print("📸 GenerationViewModel: Starting generateImages")
        print("📸 GenerationViewModel: Prompt: \(prompt)")
        print("📸 GenerationViewModel: Options: \(options)")
        
        guard !prompt.isEmpty else {
            print("❌ GenerationViewModel: Prompt is empty, returning")
            return
        }
        
        print("📸 GenerationViewModel: Setting isGenerating = true")
        isGenerating = true
        error = nil
        generationStartTime = Date()
        
        let userMessage = ChatMessage(role: .user, content: prompt)
        messages.append(userMessage)
        
        let loadingMessage = ChatMessage(role: .loading)
        messages.append(loadingMessage)
        
        print("📸 GenerationViewModel: Calling generationService.generateImages")
        
        // Start Live Activity immediately when generation begins
        startLiveActivityForGeneration(prompt: prompt, isEdit: false)
        
        let taskId = generationService.generateImages(
            prompt: prompt,
            options: options
        ) { [weak self] result in
            print("📸 GenerationViewModel: Generation completed with result: \(result)")
            DispatchQueue.main.async {
                self?.handleGenerationResult(result)
            }
        }
        
        print("📸 GenerationViewModel: Task ID: \(taskId ?? "nil")")
        activeBackgroundTaskId = taskId
    }
    
    func editImage(image: UIImage, options: EditOptions) {
        guard let imageUri = saveTemporaryImage(image) else {
            error = .invalidImage
            return
        }
        
        isGenerating = true
        error = nil
        
        let userMessage = ChatMessage(
            id: UUID().uuidString,
            text: options.prompt,
            images: [image],
            isUser: true,
            timestamp: Date(),
            metadata: nil
        )
        messages.append(userMessage)
        
        let loadingMessage = ChatMessage(
            id: UUID().uuidString,
            text: nil,
            images: nil,
            isUser: false,
            timestamp: Date(),
            metadata: nil
        )
        messages.append(loadingMessage)
        
        // Start Live Activity for edit
        startLiveActivityForGeneration(prompt: options.prompt, isEdit: true)
        
        let taskId = generationService.editImage(
            imageUri: imageUri,
            prompt: options.prompt,
            options: options
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleGenerationResult(result)
            }
        }
        
        activeBackgroundTaskId = taskId
    }
    
    func cancelGeneration() {
        generationService.cancel()
        isGenerating = false
        messages.removeAll { $0.role == .loading }
    }
    
    func resetChat() {
        messages.removeAll()
        prompt = ""
        error = nil
        progress = 0
        isGenerating = false
        toolbarMode = .generate
        toolbarExpanded = false
        selectedImage = nil
    }
    
    func updateToolbarExpanded(_ expanded: Bool) {
        toolbarExpanded = expanded
        hapticManager.impact(expanded ? .click : .toggle)
    }
    
    func updateToolbarMode(_ mode: ToolbarMode) {
        toolbarMode = mode
    }
    
    func updateSelectedImage(_ image: UIImage?) {
        selectedImage = image
        toolbarMode = image != nil ? .edit : .generate
    }
    
    private func handleStateChange(_ state: GenerationService.GenerationState) {
        print("🔄 GenerationViewModel: State changed to: \(state)")
        switch state {
        case .idle:
            print("🔄 GenerationViewModel: State = idle")
            isGenerating = false
            progress = 0
        case .generating:
            print("🔄 GenerationViewModel: State = generating")
            isGenerating = true
        case .completed:
            print("🔄 GenerationViewModel: State = completed")
            isGenerating = false
            progress = 1.0
        case .failed(let error):
            print("🔄 GenerationViewModel: State = failed with error: \(error)")
            isGenerating = false
            self.error = error
        case .cancelled:
            print("🔄 GenerationViewModel: State = cancelled")
            isGenerating = false
            progress = 0
        case .backgrounded(let taskId):
            print("🔄 GenerationViewModel: State = backgrounded with taskId: \(taskId)")
            isGenerating = false
            progress = 0
            activeBackgroundTaskId = taskId
        }
    }
    
    private func handleGenerationResult(_ result: Result<[UIImage], GenerationError>) {
        print("🎨 GenerationViewModel: handleGenerationResult called")
        print("🎨 GenerationViewModel: Result: \(result)")
        
        messages.removeAll { $0.role == .loading }
        
        switch result {
        case .success(let images):
            print("🎨 GenerationViewModel: Success with \(images.count) images")
            let assistantMessage = ChatMessage(
                role: .assistant,
                content: "Here are your generated images:",
                images: images
            )
            messages.append(assistantMessage)
            hapticManager.impact(.success)
            
            // Update Live Activity if in background
            if let activity = currentLiveActivity {
                Task {
                    let finalState = ImageGenerationAttributes.ContentState(
                        progress: 1.0,
                        status: .completed,
                        estimatedTimeRemaining: nil,
                        errorMessage: nil
                    )
                    await activity.update(ActivityContent(state: finalState, staleDate: nil))
                    
                    // Notification handled by BackgroundTaskManager
                    
                    // End activity after a delay
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await activity.end(nil, dismissalPolicy: .default)
                }
                currentLiveActivity = nil
            }
            
        case .failure(let error):
            print("🎨 GenerationViewModel: Failure with error: \(error)")
            self.error = error
            hapticManager.impact(.error)
            
            let errorMessage = ChatMessage(
                role: .assistant,
                content: "Generation failed: \(error.localizedDescription)"
            )
            messages.append(errorMessage)
            
            // Update Live Activity if in background
            if let activity = currentLiveActivity {
                Task {
                    let finalState = ImageGenerationAttributes.ContentState(
                        progress: 0.0,
                        status: .failed,
                        estimatedTimeRemaining: nil,
                        errorMessage: error.localizedDescription
                    )
                    await activity.update(ActivityContent(state: finalState, staleDate: nil))
                    
                    // Notification handled by BackgroundTaskManager
                    
                    // End activity after a delay
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await activity.end(nil, dismissalPolicy: .default)
                }
                currentLiveActivity = nil
            }
        }
        
        print("🎨 GenerationViewModel: Setting isGenerating = false")
        isGenerating = false
    }
    
    
    private func saveTemporaryImage(_ image: UIImage) -> URL? {
        guard let data = image.pngData() else { return nil }
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + ".png"
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }
}

extension GenerationViewModel: GenerationServiceDelegate {
    func generationServiceDidStartGenerating(_ service: GenerationService) {
        
    }
    
    func generationService(_ service: GenerationService, didUpdateProgress progress: Float) {
        self.progress = progress
    }
    
    func generationService(_ service: GenerationService, didGenerateImages images: [UIImage], urls: [String]) {
        
    }
    
    func generationService(_ service: GenerationService, didFailWithError error: GenerationError) {
        self.error = error
    }
    
    func generationServiceDidCancel(_ service: GenerationService) {
        messages.removeAll { $0.role == .loading }
    }
}
