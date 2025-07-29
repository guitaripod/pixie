import UIKit
import AuthenticationServices

protocol OAuthCoordinatorDelegate: AnyObject {
    func oauthCoordinator(_ coordinator: OAuthCoordinator, didCompleteWith result: AuthResult)
}

class OAuthCoordinator: NSObject {
    private weak var presentingViewController: UIViewController?
    private var authSession: ASWebAuthenticationSession?
    private var pendingAuthState: OAuthState?
    private let apiService: APIServiceProtocol
    private let configurationManager: ConfigurationManagerProtocol
    private let googleSignInCoordinator = GoogleSignInCoordinator()
    weak var delegate: OAuthCoordinatorDelegate?
    init(apiService: APIServiceProtocol, configurationManager: ConfigurationManagerProtocol) {
        self.apiService = apiService
        self.configurationManager = configurationManager
        super.init()
        googleSignInCoordinator.delegate = self
    }
    func authenticate(provider: AuthProvider, from viewController: UIViewController) {
        presentingViewController = viewController
        switch provider {
        case .apple:
            authenticateWithApple()
        case .github:
            authenticateWithOAuth(provider: provider)
        case .google:
            authenticateWithGoogle()
        }
    }
    private func authenticateWithOAuth(provider: AuthProvider) {
        let state = OAuthState(provider: provider)
        pendingAuthState = state
        let baseURL = configurationManager.baseURL
        let authPath: String
        let redirectURI: String
        switch provider {
        case .github:
            authPath = "/v1/auth/github"
            redirectURI = "pixie:
        case .apple:
            authPath = "/v1/auth/apple"
            redirectURI = "\(baseURL)/v1/auth/apple/callback"
        case .google:

            delegate?.oauthCoordinator(self, didCompleteWith: .error("Google authentication requires SDK"))
            return
        }
        var components = URLComponents(string: "\(baseURL)\(authPath)")!
        components.queryItems = [
            URLQueryItem(name: "state", value: state.state),
            URLQueryItem(name: "redirect_uri", value: redirectURI)
        ]
        guard let authURL = components.url else {
            delegate?.oauthCoordinator(self, didCompleteWith: .error("Invalid authentication URL"))
            return
        }
        authSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "pixie"
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }
            if let error = error {
                if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                    self.delegate?.oauthCoordinator(self, didCompleteWith: .cancelled)
                } else {
                    self.delegate?.oauthCoordinator(self, didCompleteWith: .error(error.localizedDescription))
                }
                return
            }
            guard let callbackURL = callbackURL else {
                self.delegate?.oauthCoordinator(self, didCompleteWith: .error("No callback URL received"))
                return
            }
            Task {
                await self.handleOAuthCallback(url: callbackURL)
            }
        }
        authSession?.presentationContextProvider = self
        authSession?.prefersEphemeralWebBrowserSession = true
        authSession?.start()
    }
    private func authenticateWithGoogle() {
        guard let viewController = presentingViewController else {
            delegate?.oauthCoordinator(self, didCompleteWith: .error("No presenting view controller"))
            return
        }
        let state = OAuthState(provider: .google)
        pendingAuthState = state
        googleSignInCoordinator.signIn(from: viewController)
    }
    private func authenticateWithApple() {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    func handleOAuthCallback(url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let state = components.queryItems?.first(where: { $0.name == "state" })?.value else {
            delegate?.oauthCoordinator(self, didCompleteWith: .error("Missing required parameters in callback"))
            return
        }
        if let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
            delegate?.oauthCoordinator(self, didCompleteWith: .error(error))
            return
        }
        guard let savedState = pendingAuthState,
              savedState.state == state,
              savedState.isValid() else {
            delegate?.oauthCoordinator(self, didCompleteWith: .error("Invalid OAuth state"))
            return
        }
        let callbackRequest = OAuthCallbackRequest(
            code: code,
            state: state,
            redirectUri: "pixie:
        )
        do {
            let authResponse: AuthResponse
            switch savedState.provider {
            case .github:
                authResponse = try await apiService.authenticateGitHub(callbackRequest)
            case .google:
                authResponse = try await apiService.authenticateGoogle(callbackRequest)
            case .apple:
                authResponse = try await apiService.authenticateApple(callbackRequest)
            }
            pendingAuthState = nil
            delegate?.oauthCoordinator(self, didCompleteWith: .success(
                apiKey: authResponse.apiKey,
                userId: authResponse.userId,
                provider: savedState.provider
            ))
        } catch {
            pendingAuthState = nil
            delegate?.oauthCoordinator(self, didCompleteWith: .error(error.localizedDescription))
        }
    }
}

extension OAuthCoordinator: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return presentingViewController?.view.window ?? UIWindow()
    }
}

extension OAuthCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            delegate?.oauthCoordinator(self, didCompleteWith: .error("Invalid Apple ID credential"))
            return
        }
        guard let authorizationCode = appleIDCredential.authorizationCode,
              let identityToken = appleIDCredential.identityToken else {
            delegate?.oauthCoordinator(self, didCompleteWith: .error("Missing authorization data"))
            return
        }
        let state = OAuthState(provider: .apple)
        pendingAuthState = state
        Task {
            await handleAppleSignIn(
                authorizationCode: authorizationCode,
                identityToken: identityToken,
                state: state
            )
        }
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
            delegate?.oauthCoordinator(self, didCompleteWith: .cancelled)
        } else {
            delegate?.oauthCoordinator(self, didCompleteWith: .error(error.localizedDescription))
        }
    }
    private func handleAppleSignIn(authorizationCode: Data, identityToken: Data, state: OAuthState) async {
        guard let tokenString = String(data: identityToken, encoding: .utf8) else {
            delegate?.oauthCoordinator(self, didCompleteWith: .error("Invalid identity token"))
            return
        }
        let tokenRequest = AppleTokenRequest(identityToken: tokenString)
        do {
            let authResponse = try await apiService.authenticateAppleToken(tokenRequest)
            pendingAuthState = nil
            delegate?.oauthCoordinator(self, didCompleteWith: .success(
                apiKey: authResponse.apiKey,
                userId: authResponse.userId,
                provider: .apple
            ))
        } catch {
            pendingAuthState = nil
            delegate?.oauthCoordinator(self, didCompleteWith: .error(error.localizedDescription))
        }
    }
}

extension OAuthCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return presentingViewController?.view.window ?? UIWindow()
    }
}

extension OAuthCoordinator: GoogleSignInCoordinatorDelegate {
    func googleSignIn(_ coordinator: GoogleSignInCoordinator, didSignInWith result: Result<(serverAuthCode: String, idToken: String), Error>) {
        switch result {
        case .success(let (_, idToken)):

            let tokenRequest = GoogleTokenRequest(idToken: idToken)
            Task {
                do {
                    let authResponse = try await apiService.authenticateGoogleToken(tokenRequest)
                    pendingAuthState = nil
                    delegate?.oauthCoordinator(self, didCompleteWith: .success(
                        apiKey: authResponse.apiKey,
                        userId: authResponse.userId,
                        provider: .google
                    ))
                } catch {
                    pendingAuthState = nil
                    delegate?.oauthCoordinator(self, didCompleteWith: .error(error.localizedDescription))
                }
            }
        case .failure(let error):
            pendingAuthState = nil
            if error is CancellationError {
                delegate?.oauthCoordinator(self, didCompleteWith: .cancelled)
            } else {
                delegate?.oauthCoordinator(self, didCompleteWith: .error(error.localizedDescription))
            }
        }
    }
}