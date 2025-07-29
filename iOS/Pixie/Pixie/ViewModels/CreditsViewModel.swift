import Foundation
import Combine
import UIKit

@MainActor
class CreditsViewModel: ObservableObject {
    @Published var balance: CreditBalance?
    @Published var transactions: [CreditTransaction] = []
    @Published var creditPacks: [CreditPack] = []
    @Published var isLoadingBalance = false
    @Published var isLoadingTransactions = false
    @Published var isLoadingPacks = false
    @Published var errorMessage: String?
    
    private let apiService: APIServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: APIServiceProtocol = APIService.shared) {
        self.apiService = apiService
    }
    
    func refresh() {
        Task {
            await loadBalance()
            await loadTransactions()
            await loadCreditPacks()
        }
    }
    
    func loadBalance() async {
        isLoadingBalance = true
        errorMessage = nil
        
        do {
            let balance = try await apiService.getCreditBalance()
            self.balance = balance
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoadingBalance = false
    }
    
    func loadTransactions(limit: Int = 20) async {
        isLoadingTransactions = true
        errorMessage = nil
        
        do {
            let response = try await apiService.getCreditTransactions(limit: limit)
            self.transactions = response.transactions
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoadingTransactions = false
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