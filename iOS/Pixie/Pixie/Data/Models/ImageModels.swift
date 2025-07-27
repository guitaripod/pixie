import Foundation

struct ImageGenerationRequest: Codable {
    let prompt: String
    let model: String
    let n: Int
    let size: String
    let quality: String
    let background: String?
    let moderation: String?
    let outputCompression: Int?
    let outputFormat: String?
    let partialImages: Int?
    let stream: Bool?
    let user: String?
    
    enum CodingKeys: String, CodingKey {
        case prompt, model, n, size, quality, background, moderation
        case outputCompression = "output_compression"
        case outputFormat = "output_format"
        case partialImages = "partial_images"
        case stream, user
    }
}

struct ImageEditRequest: Codable {
    let image: [String]
    let prompt: String
    let mask: String?
    let model: String
    let n: Int
    let size: String
    let quality: String
    let background: String
    let inputFidelity: String
    let outputFormat: String
    let outputCompression: Int?
    let partialImages: Int
    let stream: Bool
    let user: String?
    
    enum CodingKeys: String, CodingKey {
        case image, prompt, mask, model, n, size, quality, background
        case inputFidelity = "input_fidelity"
        case outputFormat = "output_format"
        case outputCompression = "output_compression"
        case partialImages = "partial_images"
        case stream, user
    }
}

struct ImageResponse: Codable {
    let created: TimeInterval
    let data: [ImageData]
}

struct ImageData: Codable {
    let url: String?
    let b64Json: String?
    let revisedPrompt: String?
    
    enum CodingKeys: String, CodingKey {
        case url
        case b64Json = "b64_json"
        case revisedPrompt = "revised_prompt"
    }
}

struct GalleryResponse: Codable {
    let images: [ImageMetadata]
    let total: Int
    let page: Int
    let perPage: Int
    
    enum CodingKeys: String, CodingKey {
        case images, total, page
        case perPage = "per_page"
    }
}

struct UserGalleryResponse: Codable {
    let userId: String
    let images: [ImageMetadata]
    let total: Int
    let page: Int
    let perPage: Int
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case images, total, page
        case perPage = "per_page"
    }
}

struct ImageMetadata: Codable {
    let id: String
    let url: String
    let prompt: String
    let createdAt: String
    let userId: String
    let size: String
    let model: String
    let quality: String?
    
    enum CodingKeys: String, CodingKey {
        case id, url, prompt
        case createdAt = "created_at"
        case userId = "user_id"
        case size, model, quality
    }
}