import Foundation

class ImageRepository: ImageRepositoryProtocol {
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }
    
    func generateImages(request: ImageGenerationRequest) async throws -> ImageResponse {
        try await apiService.generateImages(request)
    }
    
    func editImage(request: ImageEditRequest) async throws -> ImageResponse {
        try await apiService.editImage(request)
    }
    
    func getPublicGallery(page: Int, perPage: Int) async throws -> GalleryResponse {
        try await apiService.listImages(page: page, perPage: perPage)
    }
    
    func getUserGallery(userId: String, page: Int, perPage: Int) async throws -> UserGalleryResponse {
        try await apiService.listUserImages(userId: userId, page: page, perPage: perPage)
    }
    
    func getImage(id: String) async throws -> ImageMetadata {
        try await apiService.getImage(id: id)
    }
    
    func downloadImage(from url: String) async throws -> Data {
        try await apiService.downloadImage(from: url)
    }
}