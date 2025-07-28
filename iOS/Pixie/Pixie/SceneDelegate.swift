import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene, willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        window = UIWindow(windowScene: windowScene)
        window?.makeKeyAndVisible()
        
        Task {
            await checkAuthenticationState()
        }
        
        if let urlContext = connectionOptions.urlContexts.first {
            handleUniversalLink(urlContext.url)
        }
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleUniversalLink(url)
    }
    
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            handleUniversalLink(url)
        }
    }
    
    private func handleUniversalLink(_ url: URL) {
        _ = AuthenticationManager.shared.handleUniversalLink(url)
    }
    
    @MainActor
    private func checkAuthenticationState() async {
        do {
            if try await AuthenticationManager.shared.restoreSession() != nil {
                showMainInterface()
            } else {
                showAuthenticationInterface()
            }
        } catch {
            showAuthenticationInterface()
        }
    }
    
    func showAuthenticationInterface() {
        let authViewController = AuthenticationViewController()
        let navigationController = UINavigationController(rootViewController: authViewController)
        navigationController.navigationBar.isHidden = true
        window?.rootViewController = navigationController
    }
    
    func showMainInterface() {
        let mainViewController = ViewController()
        let navigationController = UINavigationController(rootViewController: mainViewController)
        window?.rootViewController = navigationController
    }
}
