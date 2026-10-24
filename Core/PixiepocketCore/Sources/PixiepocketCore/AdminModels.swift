import Foundation

public struct SystemStatsResponse: Codable, Sendable {
    public let users: UserStats
    public let credits: CreditStats
    public let revenue: RevenueStats
    public let images: ImageStats

    public init(users: UserStats, credits: CreditStats, revenue: RevenueStats, images: ImageStats) {
        self.users = users
        self.credits = credits
        self.revenue = revenue
        self.images = images
    }
}

public struct UserStats: Codable, Sendable {
    public let total: Int

    public init(total: Int) {
        self.total = total
    }
}

public struct CreditStats: Codable, Sendable {
    public let totalBalance: Int
    public let totalPurchased: Int
    public let totalSpent: Int

    public init(totalBalance: Int, totalPurchased: Int, totalSpent: Int) {
        self.totalBalance = totalBalance
        self.totalPurchased = totalPurchased
        self.totalSpent = totalSpent
    }

    enum CodingKeys: String, CodingKey {
        case totalBalance = "total_balance"
        case totalPurchased = "total_purchased"
        case totalSpent = "total_spent"
    }
}

public struct RevenueStats: Codable, Sendable {
    public let totalUsd: String
    public let openaiCostsUsd: String
    public let grossProfitUsd: String
    public let profitMargin: String

    public init(totalUsd: String, openaiCostsUsd: String, grossProfitUsd: String, profitMargin: String) {
        self.totalUsd = totalUsd
        self.openaiCostsUsd = openaiCostsUsd
        self.grossProfitUsd = grossProfitUsd
        self.profitMargin = profitMargin
    }

    enum CodingKeys: String, CodingKey {
        case totalUsd = "total_usd"
        case openaiCostsUsd = "openai_costs_usd"
        case grossProfitUsd = "gross_profit_usd"
        case profitMargin = "profit_margin"
    }
}

public struct ImageStats: Codable, Sendable {
    public let totalGenerated: Int

    public init(totalGenerated: Int) {
        self.totalGenerated = totalGenerated
    }

    enum CodingKeys: String, CodingKey {
        case totalGenerated = "total_generated"
    }
}

public struct AdminCreditAdjustmentRequest: Codable, Sendable {
    public let userId: String
    public let amount: Int
    public let reason: String

    public init(userId: String, amount: Int, reason: String) {
        self.userId = userId
        self.amount = amount
        self.reason = reason
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case amount, reason
    }
}

public struct AdminCreditAdjustmentResponse: Codable, Sendable {
    public let newBalance: Int

    public init(newBalance: Int) {
        self.newBalance = newBalance
    }

    enum CodingKeys: String, CodingKey {
        case newBalance = "new_balance"
    }
}

public struct UserSearchResult: Codable, Sendable {
    public let id: String
    public let email: String?
    public let isAdmin: Bool
    public let credits: Int
    public let createdAt: String

    public init(id: String, email: String?, isAdmin: Bool, credits: Int, createdAt: String) {
        self.id = id
        self.email = email
        self.isAdmin = isAdmin
        self.credits = credits
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, email, credits
        case isAdmin = "is_admin"
        case createdAt = "created_at"
    }
}

public struct AdjustmentHistoryItem: Codable, Sendable {
    public let id: String
    public let userId: String
    public let adminId: String
    public let amount: Int
    public let reason: String
    public let createdAt: String
    public let newBalance: Int

    public init(id: String, userId: String, adminId: String, amount: Int, reason: String, createdAt: String, newBalance: Int) {
        self.id = id
        self.userId = userId
        self.adminId = adminId
        self.amount = amount
        self.reason = reason
        self.createdAt = createdAt
        self.newBalance = newBalance
    }

    enum CodingKeys: String, CodingKey {
        case id, amount, reason
        case userId = "user_id"
        case adminId = "admin_id"
        case createdAt = "created_at"
        case newBalance = "new_balance"
    }
}

public struct AdjustmentHistoryResponse: Codable, Sendable {
    public let adjustments: [AdjustmentHistoryItem]

    public init(adjustments: [AdjustmentHistoryItem]) {
        self.adjustments = adjustments
    }
}
