import Foundation

public struct UsageResponse: Codable, Sendable {
    public let userId: String
    public let totalRequests: Int64
    public let totalTokens: Int64
    public let totalImages: Int64
    public let periodStart: String
    public let periodEnd: String

    public init(userId: String, totalRequests: Int64, totalTokens: Int64, totalImages: Int64, periodStart: String, periodEnd: String) {
        self.userId = userId
        self.totalRequests = totalRequests
        self.totalTokens = totalTokens
        self.totalImages = totalImages
        self.periodStart = periodStart
        self.periodEnd = periodEnd
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case totalRequests = "total_requests"
        case totalTokens = "total_tokens"
        case totalImages = "total_images"
        case periodStart = "period_start"
        case periodEnd = "period_end"
    }
}

public struct UsageDetailsResponse: Codable, Sendable {
    public let userId: String
    public let periodStart: String
    public let periodEnd: String
    public let dailyUsage: [DailyUsage]

    public init(userId: String, periodStart: String, periodEnd: String, dailyUsage: [DailyUsage]) {
        self.userId = userId
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.dailyUsage = dailyUsage
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case dailyUsage = "daily_usage"
    }
}

public struct DailyUsage: Codable, Sendable {
    public let date: String
    public let requests: Int64
    public let tokens: Int64
    public let images: Int64

    public init(date: String, requests: Int64, tokens: Int64, images: Int64) {
        self.date = date
        self.requests = requests
        self.tokens = tokens
        self.images = images
    }
}
