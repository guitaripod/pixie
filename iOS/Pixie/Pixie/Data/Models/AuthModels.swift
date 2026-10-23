import Foundation

nonisolated struct DeviceAuthStatus: Codable {
    let status: String
    let message: String
}

nonisolated struct ErrorResponse: Codable {
    let error: ErrorDetail
}

nonisolated struct ErrorDetail: Codable {
    let message: String
    let code: String?
    let details: ErrorDetails?
}

nonisolated struct ErrorDetails: Codable {
    let requiredCredits: Int?
    let availableCredits: Int?
    
    nonisolated enum CodingKeys: String, CodingKey {
        case requiredCredits = "required_credits"
        case availableCredits = "available_credits"
    }
}

nonisolated struct PurchaseRequest: Codable {
    let packId: String
    let paymentProvider: String
    let paymentId: String
    let paymentCurrency: String?
    
    nonisolated enum CodingKeys: String, CodingKey {
        case packId = "pack_id"
        case paymentProvider = "payment_provider"
        case paymentId = "payment_id"
        case paymentCurrency = "payment_currency"
    }
}

nonisolated struct CryptoPurchaseResponse: Codable {
    let purchaseId: String
    let paymentId: String
    let status: String
    let credits: Int
    let amountUsd: String
    let cryptoAddress: String
    let cryptoAmount: String
    let cryptoCurrency: String
    let expiresAt: String
    
    nonisolated enum CodingKeys: String, CodingKey {
        case purchaseId = "purchase_id"
        case paymentId = "payment_id"
        case status, credits
        case amountUsd = "amount_usd"
        case cryptoAddress = "crypto_address"
        case cryptoAmount = "crypto_amount"
        case cryptoCurrency = "crypto_currency"
        case expiresAt = "expires_at"
    }
}

nonisolated struct StripePurchaseResponse: Codable {
    let purchaseId: String
    let sessionId: String
    let checkoutUrl: String
    
    nonisolated enum CodingKeys: String, CodingKey {
        case purchaseId = "purchase_id"
        case sessionId = "session_id"
        case checkoutUrl = "checkout_url"
    }
}

nonisolated struct PurchaseStatusResponse: Codable {
    let purchaseId: String
    let status: String
    let paymentStatus: String?
    
    nonisolated enum CodingKeys: String, CodingKey {
        case purchaseId = "purchase_id"
        case status
        case paymentStatus = "payment_status"
    }
}