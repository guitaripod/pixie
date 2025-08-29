import Foundation

struct CreditBalance: Codable {
    let balance: Int
    let currency: String
}

struct CreditTransactionsResponse: Codable {
    let transactions: [CreditTransaction]
    let page: Int
    let perPage: Int
    
    enum CodingKeys: String, CodingKey {
        case transactions, page
        case perPage = "per_page"
    }
}

struct CreditTransaction: Codable {
    let id: String
    let userId: String
    let transactionType: String
    let amount: Int
    let balanceAfter: Int
    let description: String
    let referenceId: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case transactionType = "type"
        case amount
        case balanceAfter = "balance_after"
        case description
        case referenceId = "reference_id"
        case createdAt = "created_at"
    }
}

struct CreditPacksResponse: Codable {
    let packs: [CreditPack]
}

struct CreditPack: Codable {
    let id: String
    let name: String
    let credits: Int
    let priceUsdCents: Int
    let bonusCredits: Int
    let description: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, credits
        case priceUsdCents = "price_usd_cents"
        case bonusCredits = "bonus_credits"
        case description
    }
}

struct CreditEstimateRequest: Codable {
    let prompt: String?
    let quality: String
    let size: String
    let n: Int?
    let isEdit: Bool?
    
    enum CodingKeys: String, CodingKey {
        case prompt, quality, size, n
        case isEdit = "is_edit"
    }
}

struct CreditEstimateResponse: Codable {
    let estimatedCredits: Int
    let estimatedUsd: String
    let note: String
    
    enum CodingKeys: String, CodingKey {
        case estimatedCredits = "estimated_credits"
        case estimatedUsd = "estimated_usd"
        case note
    }
}

struct RevenueCatPurchaseValidationResponse: Codable {
    let success: Bool
    let purchaseId: String
    let creditsAdded: Int
    let newBalance: Int
    
    enum CodingKeys: String, CodingKey {
        case success
        case purchaseId = "purchase_id"
        case creditsAdded = "credits_added"
        case newBalance = "new_balance"
    }
}