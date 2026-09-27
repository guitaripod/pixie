import Foundation
import Combine
import UIKit

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
    private var cancellables = Set<AnyCancellable>()
    private var currentChatId: String
    private var activeBackgroundTaskId: String?
    private var generationStartTime: Date?
    private var liveRun: UUID?
    private let generationSucceededSubject = PassthroughSubject<Void, Never>()
    private var pendingSourceImage: UIImage?

    var generationSucceededPublisher: AnyPublisher<Void, Never> {
        generationSucceededSubject.eraseToAnyPublisher()
    }

    var latestResultImage: UIImage? {
        messages.last { $0.role == .assistant && !($0.images ?? []).isEmpty }?.images?.first
    }

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
    }
    
    deinit {
        let run = liveRun
        Task { @MainActor in GenerationActivity.shared.cancel(run) }
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
    
    @MainActor
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
        pendingSourceImage = nil
        Task { @MainActor in NotificationPermission.requestIfUseful() }
        
        let metadata = ChatMessage.MessageMetadata(
            model: options.model,
            size: options.size,
            quality: options.quality,
            credits: nil,
            sizeDisplay: options.sizeDisplay,
            background: options.background,
            format: options.outputFormat,
            compression: options.compression,
            moderation: options.moderation,
            isEditMode: false
        )
        
        let userMessage = ChatMessage(
            text: prompt,
            images: nil,
            isUser: true,
            metadata: metadata
        )
        messages.append(userMessage)
        
        let loadingMessage = ChatMessage(role: .loading)
        messages.append(loadingMessage)
        
        print("📸 GenerationViewModel: Calling generationService.generateImages")
        
        liveRun = GenerationActivity.shared.begin(
            chatId: currentChatId, prompt: prompt, isEdit: false,
            model: ImageModel(rawValue: options.model), source: nil)
        
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
    
    @MainActor
    func editImage(image: UIImage, options: EditOptions, displayText: String? = nil) {
        guard let imageUri = saveTemporaryImage(image) else {
            error = .invalidImage
            return
        }
        
        isGenerating = true
        error = nil
        generationStartTime = Date()
        pendingSourceImage = image
        Task { @MainActor in NotificationPermission.requestIfUseful() }
        
        let metadata = ChatMessage.MessageMetadata(
            model: options.model,
            size: options.size.value,
            quality: options.quality.value,
            credits: nil,
            sizeDisplay: String(localized: "\(options.size.displayName) (\(options.size.dimensions))"),
            background: options.background,
            format: options.outputFormat,
            compression: options.compression,
            moderation: nil,
            isEditMode: true
        )
        
        let userMessage = ChatMessage(
            id: UUID().uuidString,
            text: displayText ?? String(localized: "Edit: \(options.prompt)"),
            images: nil,
            isUser: true,
            timestamp: Date(),
            metadata: metadata,
            editingImage: image
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
        
        liveRun = GenerationActivity.shared.begin(
            chatId: currentChatId, prompt: displayText ?? options.prompt, isEdit: true,
            model: ImageModel(rawValue: options.model), source: image)
        
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
    
    @MainActor
    func cancelGeneration() {
        GenerationActivity.shared.cancel(liveRun)
        liveRun = nil
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
    
    @MainActor
    private func handleGenerationResult(_ result: Result<[UIImage], GenerationError>) {
        print("🎨 GenerationViewModel: handleGenerationResult called")
        print("🎨 GenerationViewModel: Result: \(result)")
        
        messages.removeAll { $0.role == .loading }
        
        switch result {
        case .success(let images):
            print("🎨 GenerationViewModel: Success with \(images.count) images")
            let assistantMessage = ChatMessage(
                role: .assistant,
                content: String(localized: "Here are your generated images:"),
                images: images,
                sourceImage: pendingSourceImage
            )
            pendingSourceImage = nil
            messages.append(assistantMessage)
            hapticManager.impact(.success)
            generationSucceededSubject.send(())
            if !images.isEmpty {
                Task { @MainActor in ReviewPrompt.recordSuccess() }
            }

            GenerationActivity.shared.succeed(liveRun, images: images)
            liveRun = nil
            
        case .failure(let error):
            print("🎨 GenerationViewModel: Failure with error: \(error)")
            self.error = error
            hapticManager.impact(.error)
            
            let errorMessage = ChatMessage(
                role: .assistant,
                content: String(localized: "Generation failed: \(error.localizedDescription)")
            )
            messages.append(errorMessage)
            
            GenerationActivity.shared.fail(liveRun, error: error)
            liveRun = nil
        }
        
        print("🎨 GenerationViewModel: Setting isGenerating = false")
        isGenerating = false
    }
    
    
    private func saveTemporaryImage(_ image: UIImage) -> URL? {
        guard let prepared = ImageUploadPreparer.prepare(image) else { return nil }
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(prepared.fileExtension)
        do {
            try prepared.data.write(to: fileURL)
            AppLogger.info("Prepared edit upload: \(prepared.data.count / 1024) KB \(prepared.mimeType)", category: .generation)
            return fileURL
        } catch {
            AppLogger.error("Could not stage the edit upload: \(error.localizedDescription)", category: .generation)
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
