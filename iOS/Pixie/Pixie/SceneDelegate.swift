import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene, willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        window = UIWindow(windowScene: windowScene)
        
        applyTheme()
        
        window?.makeKeyAndVisible()
        let loadingVC = UIViewController()
        loadingVC.view.backgroundColor = .systemBackground
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.center = loadingVC.view.center
        spinner.startAnimating()
        loadingVC.view.addSubview(spinner)
        window?.rootViewController = loadingVC
        
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
        #if DEBUG
        if DebugUtils.isRunningInSimulator {
            showMainInterface()
            return
        }
        #endif
        
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
        print("DEBUG: Showing main interface")
        let chatViewController = ChatGenerationViewController()
        let navigationController = UINavigationController(rootViewController: chatViewController)
        
        UIView.transition(with: window!, duration: 0.3, options: .transitionCrossDissolve) {
            self.window?.rootViewController = navigationController
        }
        print("DEBUG: Main interface shown")
    }
    
    private func applyTheme() {
        let theme = ConfigurationManager.shared.theme
        let style: UIUserInterfaceStyle
        
        switch theme {
        case .light:
            style = .light
        case .dark:
            style = .dark
        case .system:
            style = .unspecified
        }
        
        window?.overrideUserInterfaceStyle = style
    }
}
