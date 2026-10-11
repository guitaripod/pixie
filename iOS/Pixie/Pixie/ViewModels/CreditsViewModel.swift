import Foundation
import Combine
import UIKit

@MainActor
class CreditsViewModel: ObservableObject {
    @Published private(set) var balance: CreditBalance?
    @Published var transactions: [CreditTransaction] = []
    @Published var creditPacks: [CreditPack] = []
    @Published private(set) var isLoadingBalance = false
    @Published var isLoadingTransactions = false
    @Published var isLoadingPacks = false
    @Published var errorMessage: String?
    @Published private(set) var balanceErrorMessage: String?
    @Published private(set) var transactionsErrorMessage: String?
    @Published private(set) var balanceUpdatedAt: Date?
    @Published var lowCreditWarning: Bool = false
    @Published private(set) var hasMoreTransactions = false
    @Published private(set) var isLoadingMoreTransactions = false
    
    static let lowBalanceThreshold = 50

    private let apiService: APIServiceProtocol
    private let balanceStore: CreditBalanceStore
    private var cancellables = Set<AnyCancellable>()
    private var transactionsPage = 1
    
    init(apiService: APIServiceProtocol = APIService.shared, balanceStore: CreditBalanceStore? = nil) {
        self.apiService = apiService
        self.balanceStore = balanceStore ?? .shared
        mirrorBalanceStore()
    }
    
    func refresh() {
        Task {
            await loadBalance()
            await loadTransactions()
            await loadCreditPacks()
        }
    }
    
    func loadBalance() async {
        errorMessage = nil
        await balanceStore.refresh()
    }

    private func mirrorBalanceStore() {
        balanceStore.$balance
            .sink { [weak self] balance in
                self?.balance = balance
                if let balance { self?.lowCreditWarning = balance.balance < Self.lowBalanceThreshold }
            }
            .store(in: &cancellables)
        balanceStore.$isLoading
            .sink { [weak self] in self?.isLoadingBalance = $0 }
            .store(in: &cancellables)
        balanceStore.$errorMessage
            .sink { [weak self] in self?.balanceErrorMessage = $0 }
            .store(in: &cancellables)
        balanceStore.$updatedAt
            .sink { [weak self] in self?.balanceUpdatedAt = $0 }
            .store(in: &cancellables)
    }

    func loadTransactions(limit: Int = 20) async {
        isLoadingTransactions = true
        errorMessage = nil

        #if DEBUG
        if DemoMode.isActive {
            transactions = DemoContent.mockTransactions()
            transactionsErrorMessage = nil
            isLoadingTransactions = false
            return
        }
        #endif
        
        do {
            let response = try await apiService.getCreditTransactions(limit: limit, page: 1)
            self.transactions = response.transactions
            self.transactionsPage = 1
            self.hasMoreTransactions = Self.hasMore(after: response, loaded: response.transactions.count, limit: limit)
            self.transactionsErrorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
            self.transactionsErrorMessage = error.localizedDescription
        }
        
        isLoadingTransactions = false
    }
    
    func loadMoreTransactions(limit: Int) async {
        guard hasMoreTransactions, !isLoadingMoreTransactions, !isLoadingTransactions else { return }
        isLoadingMoreTransactions = true
        defer { isLoadingMoreTransactions = false }

        do {
            let response = try await apiService.getCreditTransactions(limit: limit, page: transactionsPage + 1)
            let known = Set(transactions.map(\.id))
            transactions += response.transactions.filter { !known.contains($0.id) }
            transactionsPage += 1
            hasMoreTransactions = Self.hasMore(after: response, loaded: transactions.count, limit: limit)
        } catch {
            AppLogger.warning("Loading more transactions failed: \(error.localizedDescription)", category: .general)
        }
    }

    /// The server reports the grand total; without it a full page is the only hint there is more.
    private static func hasMore(after response: CreditTransactionsResponse, loaded: Int, limit: Int) -> Bool {
        if let total = response.total { return loaded < total }
        return response.transactions.count >= limit
    }

    func loadCreditPacks() async {
        isLoadingPacks = true
        errorMessage = nil
        
        do {
            let response = try await apiService.getCreditPacks()
            self.creditPacks = response.packs
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoadingPacks = false
    }
    
    func estimateCredits(quality: String, size: String, isEdit: Bool, numberOfImages: Int = 1) async {
        let request = CreditEstimateRequest(
            prompt: nil,
            quality: quality,
            size: size,
            n: numberOfImages,
            isEdit: isEdit
        )
        
        do {
            _ = try await apiService.estimateCreditCost(request)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}

extension CreditBalance {
    func getBalanceColor() -> UIColor {
        switch balance {
        case 0:
            return .systemRed
        case 1..<50:
            return .systemOrange
        default:
            return .systemGreen
        }
    }
}

extension CreditTransaction {
    enum Kind {
        case spent
        case purchased
        case bonus
        case refund
        case added
    }

    var kind: Kind {
        if amount < 0 || transactionType == "spend" { return .spent }
        switch transactionType {
        case "purchase": return .purchased
        case "bonus": return .bonus
        case "refund": return .refund
        default: break
        }
        let text = description.lowercased()
        if text.contains("purchase") { return .purchased }
        if text.contains("bonus") { return .bonus }
        if text.contains("refund") { return .refund }
        return .added
    }

    var isDebit: Bool { kind == .spent }

    var kindName: String {
        switch kind {
        case .spent: return String(localized: "Spent")
        case .purchased: return String(localized: "Purchased")
        case .bonus: return String(localized: "Bonus")
        case .refund: return String(localized: "Refund")
        case .added: return String(localized: "Added")
        }
    }

    var magnitudeText: String {
        NumberFormatter.localizedString(from: NSNumber(value: abs(amount)), number: .decimal)
    }

    var signedAmountText: String {
        isDebit ? "-\(magnitudeText)" : "+\(magnitudeText)"
    }

    var spokenAmount: String {
        isDebit
            ? String(localized: "\(magnitudeText) credits spent")
            : String(localized: "\(magnitudeText) credits added")
    }

    var badgeSymbol: String {
        let text = description.lowercased()
        switch kind {
        case .spent: return symbolName
        case .purchased: return "creditcard.fill"
        case .bonus: return "gift.fill"
        case .refund: return "arrow.uturn.backward"
        case .added: return text.contains("admin") ? "person.badge.shield.checkmark.fill" : "plus"
        }
    }

    var badgeColors: [UIColor] {
        switch kind {
        case .spent: return [UIColor(hex: 0x6C47FF), UIColor(hex: 0xB04BFF)]
        case .purchased, .added: return [UIColor(hex: 0x0E9F6E), UIColor(hex: 0x34C99A)]
        case .bonus: return [UIColor(hex: 0xFF6FA3), UIColor(hex: 0xFF9A6F)]
        case .refund: return [UIColor(hex: 0x2F80ED), UIColor(hex: 0x56B8F2)]
        }
    }

    var amountColor: UIColor {
        isDebit ? Theme.Color.ink : Theme.Color.success
    }

    var symbolName: String {
        let text = description.lowercased()
        switch kind {
        case .spent:
            if text.contains("edit") { return "wand.and.rays" }
            if text.contains("upscale") { return "arrow.up.right.square" }
            return "sparkles"
        case .purchased: return "creditcard.fill"
        case .bonus: return "gift.fill"
        case .refund: return "arrow.uturn.backward.circle.fill"
        case .added: return text.contains("admin") ? "person.badge.shield.checkmark.fill" : "plus.circle.fill"
        }
    }
}
