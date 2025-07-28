import UIKit

struct ChatMessage: Hashable {
    let id: UUID
    let role: Role
    let content: String?
    let images: [UIImage]?
    let timestamp: Date
    
    enum Role {
        case user
        case assistant
        case loading
    }
    
    init(role: Role, content: String? = nil, images: [UIImage]? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.images = images
        self.timestamp = Date()
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}