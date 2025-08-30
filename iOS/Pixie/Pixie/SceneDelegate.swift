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
        
        let splashViewController = UIViewController()
        splashViewController.modalPresentationStyle = .fullScreen
        let splashView = SplashView(frame: UIScreen.main.bounds)
        splashViewController.view = splashView
        window?.rootViewController = splashViewController
        
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
        
        if let splashView = window?.rootViewController?.view as? SplashView {
            // Set the navigation controller as root first
            window?.rootViewController = navigationController
            
            // Add splash view on top for animation
            window?.addSubview(splashView)
            splashView.frame = window!.bounds
            
            splashView.animateOut {
                splashView.removeFromSuperview()
            }
        } else {
            window?.rootViewController = navigationController
        }
    }
    
    func showMainInterface() {
        print("DEBUG: Showing main interface")
        
        let rootViewController: UIViewController
        
        if UIDevice.isPad {
            rootViewController = MainSplitViewController()
        } else {
            let chatViewController = ChatGenerationViewController()
            rootViewController = UINavigationController(rootViewController: chatViewController)
        }
        
        if let splashView = window?.rootViewController?.view as? SplashView {
            window?.rootViewController = rootViewController
            
            window?.addSubview(splashView)
            splashView.frame = window!.bounds
            
            splashView.animateOut {
                splashView.removeFromSuperview()
            }
        } else {
            UIView.transition(with: window!, duration: 0.3, options: .transitionCrossDissolve) {
                self.window?.rootViewController = rootViewController
            }
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
