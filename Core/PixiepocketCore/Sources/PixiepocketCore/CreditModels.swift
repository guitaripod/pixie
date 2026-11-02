import Foundation

public struct CreditBalance: Codable, Sendable {
    public let balance: Int
    public let currency: String
    /// What an edit costs and what pays for it, from a server that sells edits; nil from one that does not.
    public let edits: EditsSummary?

    public init(balance: Int, currency: String, edits: EditsSummary? = nil) {
        self.balance = balance
        self.currency = currency
        self.edits = edits
    }
}

public struct CreditTransactionsResponse: Codable, Sendable {
    public let transactions: [CreditTransaction]
    public let page: Int
    public let perPage: Int
    public let total: Int?

    public init(transactions: [CreditTransaction], page: Int, perPage: Int, total: Int?) {
        self.transactions = transactions
        self.page = page
        self.perPage = perPage
        self.total = total
    }

    enum CodingKeys: String, CodingKey {
        case transactions, page, total
        case perPage = "per_page"
    }
}

public struct CreditTransaction: Codable, Sendable {
    public let id: String
    public let userId: String
    public let transactionType: String
    public let amount: Int
    public let balanceAfter: Int
    public let description: String
    public let referenceId: String?
    public let createdAt: String

    public init(id: String, userId: String, transactionType: String, amount: Int, balanceAfter: Int, description: String, referenceId: String?, createdAt: String) {
        self.id = id
        self.userId = userId
        self.transactionType = transactionType
        self.amount = amount
        self.balanceAfter = balanceAfter
        self.description = description
        self.referenceId = referenceId
        self.createdAt = createdAt
    }

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

public struct CreditPacksResponse: Codable, Sendable {
    public let packs: [CreditPack]

    public init(packs: [CreditPack]) {
        self.packs = packs
    }
}

public struct CreditPack: Codable, Sendable {
    public let id: String
    public let name: String
    public let credits: Int
    public let priceUsdCents: Int
    public let bonusCredits: Int
    public let description: String

    public init(id: String, name: String, credits: Int, priceUsdCents: Int, bonusCredits: Int, description: String) {
        self.id = id
        self.name = name
        self.credits = credits
        self.priceUsdCents = priceUsdCents
        self.bonusCredits = bonusCredits
        self.description = description
    }

    enum CodingKeys: String, CodingKey {
        case id, name, credits
        case priceUsdCents = "price_usd_cents"
        case bonusCredits = "bonus_credits"
        case description
    }
}

public struct CreditEstimateRequest: Codable, Sendable {
    public let prompt: String?
    public let quality: String
    public let size: String
    public let n: Int?
    public let isEdit: Bool?

    public init(prompt: String?, quality: String, size: String, n: Int?, isEdit: Bool?) {
        self.prompt = prompt
        self.quality = quality
        self.size = size
        self.n = n
        self.isEdit = isEdit
    }

    enum CodingKeys: String, CodingKey {
        case prompt, quality, size, n
        case isEdit = "is_edit"
    }
}

public struct CreditEstimateResponse: Codable, Sendable {
    public let estimatedCredits: Int
    public let estimatedUsd: String
    public let note: String

    public init(estimatedCredits: Int, estimatedUsd: String, note: String) {
        self.estimatedCredits = estimatedCredits
        self.estimatedUsd = estimatedUsd
        self.note = note
    }

    enum CodingKeys: String, CodingKey {
        case estimatedCredits = "estimated_credits"
        case estimatedUsd = "estimated_usd"
        case note
    }
}
