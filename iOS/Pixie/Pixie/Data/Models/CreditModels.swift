import Foundation

nonisolated struct CreditBalance: Codable {
    let balance: Int
    let currency: String
}

nonisolated struct CreditTransactionsResponse: Codable {
    let transactions: [CreditTransaction]
    let page: Int
    let perPage: Int
    let total: Int?
    
    nonisolated enum CodingKeys: String, CodingKey {
        case transactions, page, total
        case perPage = "per_page"
    }
}

nonisolated struct CreditTransaction: Codable {
    let id: String
    let userId: String
    let transactionType: String
    let amount: Int
    let balanceAfter: Int
    let description: String
    let referenceId: String?
    let createdAt: String
    
    nonisolated enum CodingKeys: String, CodingKey {
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

nonisolated struct CreditPacksResponse: Codable {
    let packs: [CreditPack]
}

nonisolated struct CreditPack: Codable {
    let id: String
    let name: String
    let credits: Int
    let priceUsdCents: Int
    let bonusCredits: Int
    let description: String
    
    nonisolated enum CodingKeys: String, CodingKey {
        case id, name, credits
        case priceUsdCents = "price_usd_cents"
        case bonusCredits = "bonus_credits"
        case description
    }
}

nonisolated struct CreditEstimateRequest: Codable {
    let prompt: String?
    let quality: String
    let size: String
    let n: Int?
    let isEdit: Bool?
    
    nonisolated enum CodingKeys: String, CodingKey {
        case prompt, quality, size, n
        case isEdit = "is_edit"
    }
}

nonisolated struct CreditEstimateResponse: Codable {
    let estimatedCredits: Int
    let estimatedUsd: String
    let note: String
    
    nonisolated enum CodingKeys: String, CodingKey {
        case estimatedCredits = "estimated_credits"
        case estimatedUsd = "estimated_usd"
        case note
    }
}

nonisolated struct RevenueCatPurchaseValidationResponse: Codable {
    let success: Bool
    let purchaseId: String
    let creditsAdded: Int
    let newBalance: Int
    
    nonisolated enum CodingKeys: String, CodingKey {
        case success
        case purchaseId = "purchase_id"
        case creditsAdded = "credits_added"
        case newBalance = "new_balance"
    }
}