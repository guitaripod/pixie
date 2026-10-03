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

        #if DEBUG
        if let demoMode = DemoMode.current {
            window?.rootViewController = DemoRootBuilder.makeRootViewController(for: demoMode)
            return
        }
        #endif

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
        if PresetLink.handle(url) { return }
        if url.scheme == "pixie", url.host == "chat" {
            NotificationCenter.default.post(
                name: .openChatFromNotification, object: nil,
                userInfo: ["chatId": url.lastPathComponent])
            return
        }
        _ = AuthenticationManager.shared.handleUniversalLink(url)
    }
    
    @MainActor
    private func checkAuthenticationState() async {
        #if DEBUG
        if DebugUtils.isRunningInSimulator && !Self.simulatesBootstrapFailure {
            adoptSimulatorAPIKey()
            showMainInterface()
            return
        }
        if CommandLine.arguments.contains("--aicredits-reset") {
            await AuthenticationManager.shared.signOutForTesting()
        }
        #endif

        if !isSimulatingBootstrapFailure, (try? await AuthenticationManager.shared.restoreSession()) != nil {
            showMainInterface()
            return
        }

        if await bootstrapAnonymousUser() {
            showMainInterface()
            return
        }

        showLaunchFailureInterface()
    }

    @MainActor
    private func bootstrapAnonymousUser() async -> Bool {
        #if DEBUG
        if Self.simulatesBootstrapFailure {
            guard Self.debugBootstrapFailuresRemaining == 0 else {
                Self.debugBootstrapFailuresRemaining -= 1
                AppLogger.warning("Simulated anonymous bootstrap failure", category: .auth)
                return false
            }
            return true
        }
        #endif
        do {
            try await AuthenticationManager.shared.bootstrapAnonymous()
            return true
        } catch {
            AppLogger.warning("Anonymous bootstrap failed: \(error.localizedDescription)", category: .auth)
            return false
        }
    }

    #if DEBUG
    private static var debugBootstrapFailuresRemaining = Int(ProcessInfo.processInfo.environment["PX_FAIL_BOOTSTRAP"] ?? "") ?? 0
    private static let simulatesBootstrapFailure = ProcessInfo.processInfo.environment["PX_FAIL_BOOTSTRAP"] != nil
    private var isSimulatingBootstrapFailure: Bool { Self.simulatesBootstrapFailure }
    #else
    private var isSimulatingBootstrapFailure: Bool { false }
    #endif

    #if DEBUG
    /// Lets a simulator run talk to the live backend as a real account: launch with
    /// `SIMCTL_CHILD_PX_API_KEY=<key>` and every request uses that key.
    private func adoptSimulatorAPIKey() {
        guard let key = ProcessInfo.processInfo.environment["PX_API_KEY"], !key.isEmpty else { return }
        ConfigurationManager.shared.apiKey = key
        AppContainer.shared.updateNetworkServiceAPIKey()
    }
    #endif

    func showAuthenticationInterface() {
        let authViewController = AuthenticationViewController()
        let navigationController = UINavigationController(rootViewController: authViewController)
        navigationController.navigationBar.isHidden = true
        replaceRoot(with: navigationController)
    }

    /// First launch with no way to create the anonymous identity: offers Try Again (also
    /// fired when connectivity returns) and keeps sign-in as the secondary path.
    private func showLaunchFailureInterface() {
        let failure = LaunchFailureViewController(
            onRetry: { [weak self] in
                guard let self else { return false }
                let succeeded = await self.bootstrapAnonymousUser()
                if succeeded { self.showMainInterface() }
                return succeeded
            },
            onSignIn: { [weak self] in
                self?.showAuthenticationInterface()
            }
        )
        replaceRoot(with: failure)
    }

    private func replaceRoot(with viewController: UIViewController) {
        if let splashView = window?.rootViewController?.view as? SplashView {
            window?.rootViewController = viewController
            window?.addSubview(splashView)
            splashView.frame = window!.bounds
            splashView.animateOut {
                splashView.removeFromSuperview()
            }
        } else {
            UIView.transition(with: window!, duration: 0.3, options: .transitionCrossDissolve) {
                self.window?.rootViewController = viewController
            }
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
