import Foundation
import Combine

enum AuthState {
    case unauthenticated
    case authenticating
    case authenticated(User)
    case error(String)
}

class AuthStatePublisher: ObservableObject {
    
    static let shared = AuthStatePublisher()
    
    @Published private(set) var authState: AuthState = .unauthenticated
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var currentUser: User?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupObservers()
        checkInitialAuthState()
    }
    
    private func setupObservers() {
        NotificationCenter.default.publisher(for: .userDidAuthenticate)
            .compactMap { $0.object as? User }
            .sink { [weak self] user in
                self?.authState = .authenticated(user)
                self?.isAuthenticated = true
                self?.currentUser = user
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .userDidLogout)
            .sink { [weak self] _ in
                self?.authState = .unauthenticated
                self?.isAuthenticated = false
                self?.currentUser = nil
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .tokenDidRefresh)
            .sink { [weak self] _ in
                if let user = self?.currentUser {
                    self?.authState = .authenticated(user)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .tokenRefreshDidFail)
            .compactMap { $0.object as? Error }
            .sink { [weak self] error in
                self?.authState = .error(error.localizedDescription)
                self?.performLogout()
            }
            .store(in: &cancellables)
    }
    
    private func checkInitialAuthState() {
        Task {
            do {
                if let user = try await AuthenticationManager.shared.restoreSession() {
                    await MainActor.run {
                        self.authState = .authenticated(user)
                        self.isAuthenticated = true
                        self.currentUser = user
                    }
                }
            } catch {
                await MainActor.run {
                    self.authState = .unauthenticated
                    self.isAuthenticated = false
                    self.currentUser = nil
                }
            }
        }
    }
    
    func setAuthenticating() {
        authState = .authenticating
    }
    
    func setError(_ message: String) {
        authState = .error(message)
    }
    
    private func performLogout() {
        Task {
            do {
                try await AuthenticationManager.shared.logout()
            } catch {
                print("Logout error: \(error)")
            }
        }
    }
}

extension AuthStatePublisher {
    var authStatePublisher: AnyPublisher<AuthState, Never> {
        $authState.eraseToAnyPublisher()
    }
    
    var isAuthenticatedPublisher: AnyPublisher<Bool, Never> {
        $isAuthenticated.eraseToAnyPublisher()
    }
    
    var currentUserPublisher: AnyPublisher<User?, Never> {
        $currentUser.eraseToAnyPublisher()
    }
}