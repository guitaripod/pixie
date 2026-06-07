import AuthenticationServices
import UIKit

enum AppleLinkError: LocalizedError {
    case missingToken
    var errorDescription: String? { "Could not read the Apple identity token." }
}

@MainActor
final class AppleLinkCoordinator: NSObject {
    static let shared = AppleLinkCoordinator()

    private var anchor: ASPresentationAnchor?
    private var completion: ((Result<User, Error>) -> Void)?

    func start(from viewController: UIViewController, completion: @escaping (Result<User, Error>) -> Void) {
        anchor = viewController.view.window
        self.completion = completion

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    private func finish(_ result: Result<User, Error>) {
        let completion = completion
        self.completion = nil
        anchor = nil
        completion?(result)
    }
}

extension AppleLinkCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let token = String(data: tokenData, encoding: .utf8)
        else {
            finish(.failure(AppleLinkError.missingToken))
            return
        }
        Task {
            do {
                let user = try await AuthenticationManager.shared.linkApple(identityToken: token)
                finish(.success(user))
            } catch {
                finish(.failure(error))
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        finish(.failure(error))
    }
}

extension AppleLinkCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        anchor ?? ASPresentationAnchor()
    }
}
