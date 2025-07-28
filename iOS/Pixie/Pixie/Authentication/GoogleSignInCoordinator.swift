import UIKit
import GoogleSignIn

protocol GoogleSignInCoordinatorDelegate: AnyObject {
    func googleSignIn(_ coordinator: GoogleSignInCoordinator, didSignInWith result: Result<(serverAuthCode: String, idToken: String), Error>)
}

class GoogleSignInCoordinator: NSObject {
    
    weak var delegate: GoogleSignInCoordinatorDelegate?
    private weak var presentingViewController: UIViewController?
    
    enum GoogleSignInError: LocalizedError {
        case noServerAuthCode
        case noIdToken
        case configurationError
        case serviceUnavailable
        
        var errorDescription: String? {
            switch self {
            case .noServerAuthCode:
                return "No server authorization code received"
            case .noIdToken:
                return "No ID token received"
            case .configurationError:
                return "Google Sign-In configuration error"
            case .serviceUnavailable:
                return "Google Sign-In service is currently unavailable"
            }
        }
    }
    
    func signIn(from viewController: UIViewController) {
        presentingViewController = viewController
        
        // Check if Google Sign-In is properly configured
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            // Fallback: Google Sign-In not configured, fail gracefully
            delegate?.googleSignIn(self, didSignInWith: .failure(GoogleSignInError.configurationError))
            return
        }
        
        // Create configuration with server client ID for backend authentication
        let serverClientId = plist["SERVER_CLIENT_ID"] as? String
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: clientId,
            serverClientID: serverClientId
        )
        
        // Attempt sign in with timeout handling
        performSignInWithTimeout(viewController: viewController)
    }
    
    private func performSignInWithTimeout(viewController: UIViewController) {
        var didComplete = false
        
        // Set a timeout for Google Sign-In to prevent hanging
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self = self, !didComplete else { return }
            self.delegate?.googleSignIn(self, didSignInWith: .failure(GoogleSignInError.serviceUnavailable))
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { [weak self] result, error in
            didComplete = true
            guard let self = self else { return }
            
            if let error = error {
                // Check if it's a cancellation
                if (error as NSError).code == GIDSignInError.canceled.rawValue {
                    self.delegate?.googleSignIn(self, didSignInWith: .failure(CancellationError()))
                } else {
                    self.delegate?.googleSignIn(self, didSignInWith: .failure(error))
                }
                return
            }
            
            guard let result = result,
                  let serverAuthCode = result.serverAuthCode,
                  let idToken = result.user.idToken?.tokenString else {
                self.delegate?.googleSignIn(self, didSignInWith: .failure(GoogleSignInError.noServerAuthCode))
                return
            }
            
            self.delegate?.googleSignIn(self, didSignInWith: .success((serverAuthCode: serverAuthCode, idToken: idToken)))
        }
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