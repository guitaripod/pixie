import Foundation
import Combine
import UIKit

protocol GenerationServiceDelegate: AnyObject {
    func generationServiceDidStartGenerating(_ service: GenerationService)
    func generationService(_ service: GenerationService, didUpdateProgress progress: Float)
    func generationService(_ service: GenerationService, didGenerateImages images: [UIImage], urls: [String])
    func generationService(_ service: GenerationService, didFailWithError error: GenerationError)
    func generationServiceDidCancel(_ service: GenerationService)
}

enum GenerationError: LocalizedError {
    case insufficientCredits(required: Int, available: Int)
    case unauthorized
    case rateLimitExceeded
    case contentPolicyViolation
    case networkError
    case serverError(code: Int)
    case invalidImage
    case fileTooLarge
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .insufficientCredits(let required, let available):
            return "Insufficient credits: You have \(available) credits but need \(required) credits for this generation."
        case .unauthorized:
            return "Session expired. Please sign in again."
        case .rateLimitExceeded:
            return "Too many requests. Please wait a moment and try again."
        case .contentPolicyViolation:
            return "Your prompt was blocked by content policy. Please try a different prompt."
        case .networkError:
            return "Network error. Please check your connection."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .invalidImage:
            return "Invalid image. Please select a different image."
        case .fileTooLarge:
            return "Image file too large. Maximum size is 50MB."
        case .unknown(let message):
            return message
        }
    }
}

class GenerationService {
    
    weak var delegate: GenerationServiceDelegate?
    
    private let apiService: APIServiceProtocol
    private let imageCache: ImageCacheProtocol
    private let hapticManager: HapticManager
    
    private var currentTask: Task<Void, Never>?
    private let progressSubject = CurrentValueSubject<Float, Never>(0)
    private let stateSubject = CurrentValueSubject<GenerationState, Never>(.idle)
    
    var progressPublisher: AnyPublisher<Float, Never> {
        progressSubject.eraseToAnyPublisher()
    }
    
    var statePublisher: AnyPublisher<GenerationState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    enum GenerationState {
        case idle
        case generating(prompt: String)
        case completed(images: [UIImage])
        case failed(error: GenerationError)
        case cancelled
    }
    
    init(apiService: APIServiceProtocol,
         imageCache: ImageCacheProtocol = ImageCache.shared,
         hapticManager: HapticManager = .shared) {
        self.apiService = apiService
        self.imageCache = imageCache
        self.hapticManager = hapticManager
    }
    
    func generateImages(
        prompt: String,
        options: GenerationOptions,
        completion: @escaping (Result<[UIImage], GenerationError>) -> Void
    ) {
        cancel()
        
        stateSubject.send(.generating(prompt: prompt))
        delegate?.generationServiceDidStartGenerating(self)
        progressSubject.send(0.1)
        
        let shouldIncludeCompression = options.outputFormat != "png" && options.compression != nil
        
        let request = ImageGenerationRequest(
            prompt: prompt,
            model: "gpt-image-1",
            n: options.quantity,
            size: options.size,
            quality: options.quality,
            background: options.background,
            moderation: options.moderation,
            outputCompression: shouldIncludeCompression ? options.compression : nil,
            outputFormat: options.outputFormat,
            partialImages: nil,
            stream: false,
            user: nil
        )
        
        currentTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                progressSubject.send(0.3)
                delegate?.generationService(self, didUpdateProgress: 0.3)
                
                let response = try await apiService.generateImages(request)
                
                guard !Task.isCancelled else {
                    self.handleCancellation()
                    completion(.failure(.unknown("Generation cancelled")))
                    return
                }
                
                progressSubject.send(0.6)
                delegate?.generationService(self, didUpdateProgress: 0.6)
                
                let images = try await self.downloadImages(from: response.data)
                
                guard !Task.isCancelled else {
                    self.handleCancellation()
                    completion(.failure(.unknown("Generation cancelled")))
                    return
                }
                
                progressSubject.send(1.0)
                stateSubject.send(.completed(images: images))
                
                let urls = response.data.compactMap { $0.url }
                delegate?.generationService(self, didGenerateImages: images, urls: urls)
                hapticManager.impact(.success)
                
                completion(.success(images))
                
            } catch {
                let generationError = self.mapError(error)
                stateSubject.send(.failed(error: generationError))
                delegate?.generationService(self, didFailWithError: generationError)
                hapticManager.impact(.error)
                completion(.failure(generationError))
            }
        }
    }
    
    func editImage(
        imageUri: URL,
        prompt: String,
        options: EditOptions,
        completion: @escaping (Result<[UIImage], GenerationError>) -> Void
    ) {
        cancel()
        
        stateSubject.send(.generating(prompt: prompt))
        delegate?.generationServiceDidStartGenerating(self)
        progressSubject.send(0.1)
        
        currentTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                let imageData = try await self.loadImageData(from: imageUri)
                let imageBase64 = imageData.base64EncodedString()
                let imageDataUrl = "data:image/png;base64,\(imageBase64)"
                
                progressSubject.send(0.3)
                delegate?.generationService(self, didUpdateProgress: 0.3)
                
                let request = ImageEditRequest(
                    image: [imageDataUrl],
                    prompt: prompt,
                    mask: nil,
                    model: "gpt-image-1",
                    n: options.variations,
                    size: options.size.value,
                    quality: options.quality.value,
                    background: options.background ?? "auto",
                    inputFidelity: options.fidelity.value,
                    outputFormat: options.outputFormat,
                    outputCompression: options.compression,
                    partialImages: 0,
                    stream: false,
                    user: nil
                )
                
                let response = try await apiService.editImage(request)
                
                guard !Task.isCancelled else {
                    self.handleCancellation()
                    completion(.failure(.unknown("Edit cancelled")))
                    return
                }
                
                progressSubject.send(0.6)
                delegate?.generationService(self, didUpdateProgress: 0.6)
                
                let images = try await self.downloadImages(from: response.data)
                
                guard !Task.isCancelled else {
                    self.handleCancellation()
                    completion(.failure(.unknown("Edit cancelled")))
                    return
                }
                
                progressSubject.send(1.0)
                stateSubject.send(.completed(images: images))
                
                let urls = response.data.compactMap { $0.url }
                delegate?.generationService(self, didGenerateImages: images, urls: urls)
                hapticManager.impact(.success)
                
                completion(.success(images))
                
            } catch {
                let generationError = self.mapError(error)
                stateSubject.send(.failed(error: generationError))
                delegate?.generationService(self, didFailWithError: generationError)
                hapticManager.impact(.error)
                completion(.failure(generationError))
            }
        }
    }
    
    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        progressSubject.send(0)
        stateSubject.send(.cancelled)
        delegate?.generationServiceDidCancel(self)
    }
    
    private func downloadImages(from imageData: [ImageData]) async throws -> [UIImage] {
        var images: [UIImage] = []
        
        for (index, data) in imageData.enumerated() {
            if let urlString = data.url {
                if let cachedImage = imageCache.image(for: urlString) {
                    images.append(cachedImage)
                } else {
                    let imageData = try await apiService.downloadImage(from: urlString)
                    guard let image = UIImage(data: imageData) else {
                        throw GenerationError.invalidImage
                    }
                    imageCache.setImage(image, for: urlString)
                    images.append(image)
                }
                
                let progress = 0.6 + (0.4 * Float(index + 1) / Float(imageData.count))
                progressSubject.send(progress)
                delegate?.generationService(self, didUpdateProgress: progress)
            }
        }
        
        return images
    }
    
    private func loadImageData(from url: URL) async throws -> Data {
        if url.scheme?.hasPrefix("http") == true {
            return try await URLSession.shared.data(from: url).0
        } else {
            return try Data(contentsOf: url)
        }
    }
    
    private func handleCancellation() {
        stateSubject.send(.cancelled)
        delegate?.generationServiceDidCancel(self)
        progressSubject.send(0)
    }
    
    private func mapError(_ error: Error) -> GenerationError {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .unauthorized:
                return .unauthorized
            case .forbidden:
                return .contentPolicyViolation
            case .tooManyRequests:
                return .rateLimitExceeded
            case .insufficientCredits:
                return .insufficientCredits(required: 0, available: 0)
            case .serverError(let message):
                if message.contains("insufficient_credits") {
                    return .insufficientCredits(required: 0, available: 0)
                } else if message.contains("content_policy_violation") {
                    return .contentPolicyViolation
                }
                return .unknown(message)
            case .httpError(let code, _):
                return .serverError(code: code)
            case .noConnection:
                return .networkError
            case .invalidResponse:
                return .unknown("Invalid response from server")
            default:
                return .unknown(error.localizedDescription)
            }
        }
        
        return .unknown(error.localizedDescription)
    }
}

