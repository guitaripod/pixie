import ActivityKit
import Foundation

public struct ImageGenerationAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var progress: Double
        public var status: GenerationStatus
        public var estimatedTimeRemaining: Int?
        public var errorMessage: String?
        
        public init(progress: Double, status: GenerationStatus, estimatedTimeRemaining: Int? = nil, errorMessage: String? = nil) {
            self.progress = progress
            self.status = status
            self.estimatedTimeRemaining = estimatedTimeRemaining
            self.errorMessage = errorMessage
        }
    }
    
    public var prompt: String
    public var taskId: String
    public var chatId: String
    public var isEdit: Bool
    public var editImageData: Data?
    
    public init(prompt: String, taskId: String, chatId: String, isEdit: Bool, editImageData: Data? = nil) {
        self.prompt = prompt
        self.taskId = taskId
        self.chatId = chatId
        self.isEdit = isEdit
        self.editImageData = editImageData
    }
}

public enum GenerationStatus: String, Codable {
    case queued = "Queued"
    case processing = "Processing"
    case generating = "Generating"
    case completed = "Completed"
    case failed = "Failed"
}