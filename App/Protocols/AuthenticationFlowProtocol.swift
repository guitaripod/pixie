import UIKit

protocol AuthenticationFlowProtocol: AnyObject {
    var delegate: AuthenticationFlowDelegate? { get set }
    var provider: AuthProvider { get }
    var isAuthenticating: Bool { get }
    
    func startAuthentication(from viewController: UIViewController)
    func cancelAuthentication()
    func handleCallback(url: URL) async -> Bool
}

protocol AuthenticationFlowDelegate: AnyObject {
    func authenticationFlow(_ flow: AuthenticationFlowProtocol, didUpdateState state: AuthFlowState)
    func authenticationFlow(_ flow: AuthenticationFlowProtocol, didCompleteWith result: AuthResult)
}

enum AuthFlowState {
    case idle
    case authenticating
    case waitingForCallback
    case processingCallback
    case completed
    case failed(Error)
}

extension AuthenticationFlowProtocol {
    func notifyStateChange(_ state: AuthFlowState) {
        delegate?.authenticationFlow(self, didUpdateState: state)
    }
    
    func notifyCompletion(_ result: AuthResult) {
        delegate?.authenticationFlow(self, didCompleteWith: result)
    }
}

protocol AuthenticationProviderButtonProtocol: UIView {
    var provider: AuthProvider { get }
    var isEnabled: Bool { get set }
    var action: (() -> Void)? { get set }
    
    func setLoading(_ loading: Bool)
    func updateAppearance(for state: UIControl.State)
}