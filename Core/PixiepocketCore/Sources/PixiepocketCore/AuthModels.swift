import Foundation

public struct DeviceAuthStatus: Codable, Sendable {
    public let status: String
    public let message: String

    public init(status: String, message: String) {
        self.status = status
        self.message = message
    }
}

public struct ErrorResponse: Codable, Sendable {
    public let error: ErrorDetail

    public init(error: ErrorDetail) {
        self.error = error
    }
}

public struct ErrorDetail: Codable, Sendable {
    public let message: String
    public let code: String?
    public let details: ErrorDetails?

    public init(message: String, code: String?, details: ErrorDetails?) {
        self.message = message
        self.code = code
        self.details = details
    }
}

public struct ErrorDetails: Codable, Sendable {
    public let requiredCredits: Int?
    public let availableCredits: Int?

    public init(requiredCredits: Int?, availableCredits: Int?) {
        self.requiredCredits = requiredCredits
        self.availableCredits = availableCredits
    }

    enum CodingKeys: String, CodingKey {
        case requiredCredits = "required_credits"
        case availableCredits = "available_credits"
    }
}

public struct PurchaseRequest: Codable, Sendable {
    public let packId: String
    public let paymentProvider: String
    public let paymentId: String
    public let paymentCurrency: String?

    public init(packId: String, paymentProvider: String, paymentId: String, paymentCurrency: String?) {
        self.packId = packId
        self.paymentProvider = paymentProvider
        self.paymentId = paymentId
        self.paymentCurrency = paymentCurrency
    }

    enum CodingKeys: String, CodingKey {
        case packId = "pack_id"
        case paymentProvider = "payment_provider"
        case paymentId = "payment_id"
        case paymentCurrency = "payment_currency"
    }
}

public struct CryptoPurchaseResponse: Codable, Sendable {
    public let purchaseId: String
    public let paymentId: String
    public let status: String
    public let credits: Int
    public let amountUsd: String
    public let cryptoAddress: String
    public let cryptoAmount: String
    public let cryptoCurrency: String
    public let expiresAt: String

    public init(purchaseId: String, paymentId: String, status: String, credits: Int, amountUsd: String, cryptoAddress: String, cryptoAmount: String, cryptoCurrency: String, expiresAt: String) {
        self.purchaseId = purchaseId
        self.paymentId = paymentId
        self.status = status
        self.credits = credits
        self.amountUsd = amountUsd
        self.cryptoAddress = cryptoAddress
        self.cryptoAmount = cryptoAmount
        self.cryptoCurrency = cryptoCurrency
        self.expiresAt = expiresAt
    }

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

public struct StripePurchaseResponse: Codable, Sendable {
    public let purchaseId: String
    public let sessionId: String
    public let checkoutUrl: String

    public init(purchaseId: String, sessionId: String, checkoutUrl: String) {
        self.purchaseId = purchaseId
        self.sessionId = sessionId
        self.checkoutUrl = checkoutUrl
    }

    enum CodingKeys: String, CodingKey {
        case purchaseId = "purchase_id"
        case sessionId = "session_id"
        case checkoutUrl = "checkout_url"
    }
}

public struct PurchaseStatusResponse: Codable, Sendable {
    public let purchaseId: String
    public let status: String
    public let paymentStatus: String?

    public init(purchaseId: String, status: String, paymentStatus: String?) {
        self.purchaseId = purchaseId
        self.status = status
        self.paymentStatus = paymentStatus
    }

    enum CodingKeys: String, CodingKey {
        case purchaseId = "purchase_id"
        case status
        case paymentStatus = "payment_status"
    }
}
