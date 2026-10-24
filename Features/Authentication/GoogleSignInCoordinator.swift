import UIKit
import GoogleSignIn

protocol GoogleSignInCoordinatorDelegate: AnyObject {
    func googleSignIn(_ coordinator: GoogleSignInCoordinator, didSignInWith result: Result<(serverAuthCode: String, idToken: String), Error>)
}

class GoogleSignInCoordinator: NSObject {
    
    weak var delegate: GoogleSignInCoordinatorDelegate?
    private weak var presentingViewController: UIViewController?
    private var isAwaitingSignIn = false
    
    nonisolated enum GoogleSignInError: LocalizedError {
        case noServerAuthCode
        case noIdToken
        case configurationError
        case serviceUnavailable
        
        var errorDescription: String? {
            switch self {
            case .noServerAuthCode:
                return String(localized: "No server authorization code received")
            case .noIdToken:
                return String(localized: "No ID token received")
            case .configurationError:
                return String(localized: "Google Sign-In configuration error")
            case .serviceUnavailable:
                return String(localized: "Google Sign-In service is currently unavailable")
            }
        }
    }
    
    func signIn(from viewController: UIViewController) {
        presentingViewController = viewController
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            delegate?.googleSignIn(self, didSignInWith: .failure(GoogleSignInError.configurationError))
            return
        }
        let serverClientId = plist["SERVER_CLIENT_ID"] as? String
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: clientId,
            serverClientID: serverClientId
        )
        performSignInWithTimeout(viewController: viewController)
    }
    
    private func performSignInWithTimeout(viewController: UIViewController) {
        isAwaitingSignIn = true
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard let self, self.isAwaitingSignIn else { return }
            self.delegate?.googleSignIn(self, didSignInWith: .failure(GoogleSignInError.serviceUnavailable))
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { [weak self] result, error in
            let outcome = Self.outcome(of: result, error: error)
            Task { @MainActor in
                guard let self else { return }
                self.isAwaitingSignIn = false
                self.delegate?.googleSignIn(self, didSignInWith: outcome)
            }
        }
    }

    /// What the Google SDK's completion means for the delegate: the codes the server needs, a cancellation, or the
    /// reason there are none. Reads only the SDK's result, so it can run on whatever thread the SDK calls back on.
    private nonisolated static func outcome(
        of result: GIDSignInResult?,
        error: Error?
    ) -> Result<(serverAuthCode: String, idToken: String), Error> {
        if let error {
            let canceled = (error as NSError).code == GIDSignInError.canceled.rawValue
            return .failure(canceled ? CancellationError() : error)
        }
        guard let result,
              let serverAuthCode = result.serverAuthCode,
              let idToken = result.user.idToken?.tokenString else {
            return .failure(GoogleSignInError.noServerAuthCode)
        }
        return .success((serverAuthCode: serverAuthCode, idToken: idToken))
    }
    
    func disconnect() {
        GIDSignIn.sharedInstance.disconnect { error in
            if let error = error {
                print("Error disconnecting Google Sign-In: \(error)")
            }
        }
    }
}

struct CancellationError: Error {}