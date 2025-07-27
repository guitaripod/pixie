import Foundation

struct DeviceAuthStatus: Codable {
    let status: String
    let message: String
}

struct ErrorResponse: Codable {
    let error: ErrorDetail
}

struct ErrorDetail: Codable {
    let message: String
    let code: String?
}

struct PurchaseRequest: Codable {
    let packId: String
    let paymentProvider: String
    let paymentId: String
    let paymentCurrency: String?
    
    enum CodingKeys: String, CodingKey {
        case packId = "pack_id"
        case paymentProvider = "payment_provider"
        case paymentId = "payment_id"
        case paymentCurrency = "payment_currency"
    }
}

struct CryptoPurchaseResponse: Codable {
    let purchaseId: String
    let paymentId: String
    let status: String
    let credits: Int
    let amountUsd: String
    let cryptoAddress: String
    let cryptoAmount: String
    let cryptoCurrency: String
    let expiresAt: String
    
    enum CodingKeys: String, CodingKey {
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

struct StripePurchaseResponse: Codable {
    let purchaseId: String
    let sessionId: String
    let checkoutUrl: String
    
    enum CodingKeys: String, CodingKey {
        case purchaseId = "purchase_id"
        case sessionId = "session_id"
        case checkoutUrl = "checkout_url"
    }
}

struct PurchaseStatusResponse: Codable {
    let purchaseId: String
    let status: String
    let paymentStatus: String?
    
    enum CodingKeys: String, CodingKey {
        case purchaseId = "purchase_id"
        case status
        case paymentStatus = "payment_status"
    }
}