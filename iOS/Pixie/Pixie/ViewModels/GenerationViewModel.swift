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
         hapticManager: HapticManager = .shared) {
        self.generationService = generationService ?? GenerationService(apiService: AppContainer.shared.apiService)
        self.imageRepository = imageRepository
        self.hapticManager = hapticManager
        
        setupBindings()
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
    
    func generateImages(with options: GenerationOptions) {
        guard !prompt.isEmpty else { return }
        
        isGenerating = true
        error = nil
        
        let userMessage = ChatMessage(role: .user, content: prompt)
        messages.append(userMessage)
        
        let loadingMessage = ChatMessage(role: .loading)
        messages.append(loadingMessage)
        
        generationService.generateImages(
            prompt: prompt,
            options: options
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleGenerationResult(result)
            }
        }
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
        
        generationService.editImage(
            imageUri: imageUri,
            prompt: options.prompt,
            options: options
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleGenerationResult(result)
            }
        }
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
        switch state {
        case .idle:
            isGenerating = false
            progress = 0
        case .generating:
            isGenerating = true
        case .completed:
            isGenerating = false
            progress = 1.0
        case .failed(let error):
            isGenerating = false
            self.error = error
        case .cancelled:
            isGenerating = false
            progress = 0
        }
    }
    
    private func handleGenerationResult(_ result: Result<[UIImage], GenerationError>) {
        messages.removeAll { $0.role == .loading }
        
        switch result {
        case .success(let images):
            let assistantMessage = ChatMessage(
                role: .assistant,
                content: "Here are your generated images:",
                images: images
            )
            messages.append(assistantMessage)
            hapticManager.impact(.success)
            
        case .failure(let error):
            self.error = error
            hapticManager.impact(.error)
            
            let errorMessage = ChatMessage(
                role: .assistant,
                content: "Generation failed: \(error.localizedDescription)"
            )
            messages.append(errorMessage)
        }
        
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