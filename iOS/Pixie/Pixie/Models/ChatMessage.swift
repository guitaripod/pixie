import UIKit

struct ChatMessage: Hashable {
    let id: String
    let text: String?
    let images: [UIImage]?
    let isUser: Bool
    let timestamp: Date
    let metadata: MessageMetadata?
    let editingImage: UIImage?
    
    struct MessageMetadata {
        let size: String?
        let quality: String?
        let credits: Int?
        let sizeDisplay: String?
        let background: String?
        let format: String?
        let compression: Int?
        let moderation: String?
        let isEditMode: Bool
    }
    var role: Role {
        if text == nil && images == nil {
            return .loading
        }
        return isUser ? .user : .assistant
    }
    var content: String? {
        return text
    }
    enum Role {
        case user
        case assistant
        case loading
    }
    init(id: String = UUID().uuidString,
         text: String? = nil,
         images: [UIImage]? = nil,
         isUser: Bool,
         timestamp: Date = Date(),
         metadata: MessageMetadata? = nil,
         editingImage: UIImage? = nil) {
        self.id = id
        self.text = text
        self.images = images
        self.isUser = isUser
        self.timestamp = timestamp
        self.metadata = metadata
        self.editingImage = editingImage
    }
    init(role: Role, content: String? = nil, images: [UIImage]? = nil) {
        self.id = UUID().uuidString
        self.text = content
        self.images = images
        self.isUser = role == .user
        self.timestamp = Date()
        self.metadata = nil
        self.editingImage = nil
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}