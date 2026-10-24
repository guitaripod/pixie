import Foundation

public struct ImageGenerationRequest: Codable, Sendable {
    public let prompt: String
    public let model: String
    public let n: Int
    public let size: String
    public let quality: String
    public let background: String?
    public let moderation: String?
    public let outputCompression: Int?
    public let outputFormat: String?
    public let partialImages: Int?
    public let stream: Bool?
    public let user: String?

    public init(prompt: String, model: String, n: Int, size: String, quality: String, background: String?, moderation: String?, outputCompression: Int?, outputFormat: String?, partialImages: Int?, stream: Bool?, user: String?) {
        self.prompt = prompt
        self.model = model
        self.n = n
        self.size = size
        self.quality = quality
        self.background = background
        self.moderation = moderation
        self.outputCompression = outputCompression
        self.outputFormat = outputFormat
        self.partialImages = partialImages
        self.stream = stream
        self.user = user
    }

    enum CodingKeys: String, CodingKey {
        case prompt, model, n, size, quality, background, moderation
        case outputCompression = "output_compression"
        case outputFormat = "output_format"
        case partialImages = "partial_images"
        case stream, user
    }
}

public struct ImageEditRequest: Codable, Sendable {
    public let image: [String]
    public let prompt: String
    public let mask: String?
    public let model: String
    public let n: Int
    public let size: String
    public let quality: String
    public let background: String
    public let inputFidelity: String
    public let outputFormat: String
    public let outputCompression: Int?
    public let partialImages: Int
    public let stream: Bool
    public let user: String?

    public init(image: [String], prompt: String, mask: String?, model: String, n: Int, size: String, quality: String, background: String, inputFidelity: String, outputFormat: String, outputCompression: Int?, partialImages: Int, stream: Bool, user: String?) {
        self.image = image
        self.prompt = prompt
        self.mask = mask
        self.model = model
        self.n = n
        self.size = size
        self.quality = quality
        self.background = background
        self.inputFidelity = inputFidelity
        self.outputFormat = outputFormat
        self.outputCompression = outputCompression
        self.partialImages = partialImages
        self.stream = stream
        self.user = user
    }

    enum CodingKeys: String, CodingKey {
        case image, prompt, mask, model, n, size, quality, background
        case inputFidelity = "input_fidelity"
        case outputFormat = "output_format"
        case outputCompression = "output_compression"
        case partialImages = "partial_images"
        case stream, user
    }
}

public struct ImageResponse: Codable, Sendable {
    public let created: TimeInterval
    public let data: [ImageData]

    public init(created: TimeInterval, data: [ImageData]) {
        self.created = created
        self.data = data
    }
}

public struct ImageData: Codable, Sendable {
    public let url: String?
    public let b64Json: String?
    public let revisedPrompt: String?

    public init(url: String?, b64Json: String?, revisedPrompt: String?) {
        self.url = url
        self.b64Json = b64Json
        self.revisedPrompt = revisedPrompt
    }

    enum CodingKeys: String, CodingKey {
        case url
        case b64Json = "b64_json"
        case revisedPrompt = "revised_prompt"
    }
}

public struct GalleryResponse: Codable, Sendable {
    public let images: [ImageMetadata]
    public let total: Int
    public let page: Int
    public let perPage: Int

    public init(images: [ImageMetadata], total: Int, page: Int, perPage: Int) {
        self.images = images
        self.total = total
        self.page = page
        self.perPage = perPage
    }

    enum CodingKeys: String, CodingKey {
        case images, total, page
        case perPage = "per_page"
    }
}

public struct UserGalleryResponse: Codable, Sendable {
    public let userId: String
    public let images: [ImageMetadata]
    public let total: Int
    public let page: Int
    public let perPage: Int

    public init(userId: String, images: [ImageMetadata], total: Int, page: Int, perPage: Int) {
        self.userId = userId
        self.images = images
        self.total = total
        self.page = page
        self.perPage = perPage
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case images, total, page
        case perPage = "per_page"
    }
}

public struct ImageMetadata: Codable, Hashable, Sendable {
    public let id: String
    public let url: String
    public let prompt: String
    public let createdAt: String
    public let userId: String
    public let thumbnailUrl: String?
    public let metadata: ImageMetadataDetails?
    public let tags: [String]?

    public init(id: String, url: String, prompt: String, createdAt: String, userId: String, thumbnailUrl: String?, metadata: ImageMetadataDetails?, tags: [String]?) {
        self.id = id
        self.url = url
        self.prompt = prompt
        self.createdAt = createdAt
        self.userId = userId
        self.thumbnailUrl = thumbnailUrl
        self.metadata = metadata
        self.tags = tags
    }

    enum CodingKeys: String, CodingKey {
        case id, url, prompt
        case createdAt = "created_at"
        case userId = "user_id"
        case thumbnailUrl = "thumbnail_url"
        case metadata
        case tags
    }
}

public struct ImageMetadataDetails: Codable, Hashable, Sendable {
    public let width: Int
    public let height: Int
    public let format: String
    public let sizeBytes: Int
    public let creditsUsed: Int
    public let quality: String?
    public let model: String?
    public let revisedPrompt: String?

    public init(width: Int, height: Int, format: String, sizeBytes: Int, creditsUsed: Int, quality: String?, model: String?, revisedPrompt: String?) {
        self.width = width
        self.height = height
        self.format = format
        self.sizeBytes = sizeBytes
        self.creditsUsed = creditsUsed
        self.quality = quality
        self.model = model
        self.revisedPrompt = revisedPrompt
    }

    enum CodingKeys: String, CodingKey {
        case width, height, format
        case sizeBytes = "size_bytes"
        case creditsUsed = "credits_used"
        case quality, model
        case revisedPrompt = "revised_prompt"
    }
}
