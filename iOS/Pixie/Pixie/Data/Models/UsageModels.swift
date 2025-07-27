import Foundation

struct UsageResponse: Codable {
    let userId: String
    let totalRequests: Int64
    let totalTokens: Int64
    let totalImages: Int64
    let periodStart: String
    let periodEnd: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case totalRequests = "total_requests"
        case totalTokens = "total_tokens"
        case totalImages = "total_images"
        case periodStart = "period_start"
        case periodEnd = "period_end"
    }
}

struct UsageDetailsResponse: Codable {
    let userId: String
    let periodStart: String
    let periodEnd: String
    let dailyUsage: [DailyUsage]
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case dailyUsage = "daily_usage"
    }
}

struct DailyUsage: Codable {
    let date: String
    let requests: Int64
    let tokens: Int64
    let images: Int64
}