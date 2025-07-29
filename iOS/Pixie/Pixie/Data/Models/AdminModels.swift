import Foundation

struct SystemStatsResponse: Codable {
    let users: UserStats
    let credits: CreditStats
    let revenue: RevenueStats
    let images: ImageStats
}

struct UserStats: Codable {
    let total: Int
}

struct CreditStats: Codable {
    let totalBalance: Int
    let totalPurchased: Int
    let totalSpent: Int
    
    enum CodingKeys: String, CodingKey {
        case totalBalance = "total_balance"
        case totalPurchased = "total_purchased"
        case totalSpent = "total_spent"
    }
}

struct RevenueStats: Codable {
    let totalUsd: String
    let openaiCostsUsd: String
    let grossProfitUsd: String
    let profitMargin: String
    
    enum CodingKeys: String, CodingKey {
        case totalUsd = "total_usd"
        case openaiCostsUsd = "openai_costs_usd"
        case grossProfitUsd = "gross_profit_usd"
        case profitMargin = "profit_margin"
    }
}

struct ImageStats: Codable {
    let totalGenerated: Int
    
    enum CodingKeys: String, CodingKey {
        case totalGenerated = "total_generated"
    }
}

struct AdminCreditAdjustmentRequest: Codable {
    let userId: String
    let amount: Int
    let reason: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case amount, reason
    }
}

struct AdminCreditAdjustmentResponse: Codable {
    let newBalance: Int
    
    enum CodingKeys: String, CodingKey {
        case newBalance = "new_balance"
    }
}

struct UserSearchResult: Codable {
    let id: String
    let email: String?
    let isAdmin: Bool
    let credits: Int
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, email, credits
        case isAdmin = "is_admin"
        case createdAt = "created_at"
    }
}

struct AdjustmentHistoryItem: Codable {
    let id: String
    let userId: String
    let adminId: String
    let amount: Int
    let reason: String
    let createdAt: String
    let newBalance: Int
    
    enum CodingKeys: String, CodingKey {
        case id, amount, reason
        case userId = "user_id"
        case adminId = "admin_id"
        case createdAt = "created_at"
        case newBalance = "new_balance"
    }
}

struct AdjustmentHistoryResponse: Codable {
    let adjustments: [AdjustmentHistoryItem]
}