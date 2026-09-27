import ActivityKit
import Foundation

public struct ImageGenerationAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public enum Phase: String, Codable, Hashable {
            case working
            case ready
            case failed
            case paused
        }

        public var phase: Phase
        public var startedAt: Date
        public var expectedDuration: TimeInterval
        public var endedAt: Date?
        public var resultFile: String?
        public var message: String?

        public init(
            phase: Phase, startedAt: Date, expectedDuration: TimeInterval, endedAt: Date? = nil,
            resultFile: String? = nil, message: String? = nil
        ) {
            self.phase = phase
            self.startedAt = startedAt
            self.expectedDuration = expectedDuration
            self.endedAt = endedAt
            self.resultFile = resultFile
            self.message = message
        }

        public var expectedEnd: Date { startedAt.addingTimeInterval(max(expectedDuration, 1)) }
    }

    public var chatId: String
    public var prompt: String
    public var isEdit: Bool
    public var modelName: String?
    public var sourceFile: String?

    public init(chatId: String, prompt: String, isEdit: Bool, modelName: String?, sourceFile: String?) {
        self.chatId = chatId
        self.prompt = prompt
        self.isEdit = isEdit
        self.modelName = modelName
        self.sourceFile = sourceFile
    }
}

/// The pictures a card shows live in the app group as small files, because ActivityKit caps a
/// card's whole payload at 4 KB and a thumbnail squeezed into that is a smear of pixels.
public enum GenerationActivityFiles {
    public static let appGroup = "group.com.guitaripod.Pixie"

    public static var directory: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("LiveActivity", isDirectory: true)
    }

    public static func url(for name: String) -> URL? {
        directory?.appendingPathComponent(name)
    }
}
