import UIKit

class MainSplitViewController: UISplitViewController {
    
    private var sidebarViewController: SidebarViewController!
    private var chatViewController: ChatGenerationViewController!
    private var detailNavigationController: UINavigationController!
    private var galleryViewController: GalleryViewController?
    private var creditsViewController: CreditsMainViewController?
    private var settingsViewController: SettingsViewController?
    private var adminViewController: AdminDashboardViewController?
    
    init() {
        super.init(style: .doubleColumn)
    }
    
    required init?(coder: NSCoder) {
        super.init(style: .doubleColumn)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        preferredDisplayMode = .oneBesideSecondary
        preferredSplitBehavior = .tile
        presentsWithGesture = true
        preferredPrimaryColumnWidth = 320
        minimumPrimaryColumnWidth = 280
        maximumPrimaryColumnWidth = 400
        
        setupViewControllers()
        setupDelegate()
        
        displayModeButtonVisibility = .automatic
    }
    
    private func setupViewControllers() {
        sidebarViewController = SidebarViewController()
        sidebarViewController.delegate = self
        
        chatViewController = ChatGenerationViewController()
        detailNavigationController = UINavigationController(rootViewController: chatViewController)
        
        setViewController(sidebarViewController, for: .primary)
        setViewController(detailNavigationController, for: .secondary)

        setViewController(detailNavigationController, for: .compact)
    }
    
    private func setupDelegate() {
        delegate = self
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass {
            adaptToSizeClass()
        }
    }
    
    private func adaptToSizeClass() {
        if traitCollection.horizontalSizeClass == .compact {
            preferredDisplayMode = .secondaryOnly
        } else {
            preferredDisplayMode = .oneBesideSecondary
        }
    }
    
    func showViewController(_ viewController: UIViewController) {
        if isCollapsed {
            if !detailNavigationController.viewControllers.contains(where: { $0 === viewController }) {
                detailNavigationController.pushViewController(viewController, animated: true)
            } else {
                detailNavigationController.popToViewController(viewController, animated: true)
            }
        } else {
            if detailNavigationController.viewControllers.first !== viewController {
                detailNavigationController.setViewControllers([viewController], animated: false)
            }
        }
    }
    
    func navigateToSection(_ section: SidebarSection) {
        let viewController: UIViewController
        
        switch section {
        case .chat:
            viewController = chatViewController
            
        case .gallery:
            if galleryViewController == nil {
                galleryViewController = GalleryViewController()
            }
            viewController = galleryViewController!
            
        case .credits:
            if creditsViewController == nil {
                creditsViewController = CreditsMainViewController()
            }
            viewController = creditsViewController!
            
        case .settings:
            if settingsViewController == nil {
                settingsViewController = SettingsViewController()
            }
            viewController = settingsViewController!
            
        case .admin:
            if adminViewController == nil {
                adminViewController = AdminDashboardViewController()
            }
            viewController = adminViewController!
        }
        
        showViewController(viewController)
    }
}

extension MainSplitViewController: UISplitViewControllerDelegate {
    
    func splitViewController(_ svc: UISplitViewController,
                             topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column {
        return .secondary
    }

    func splitViewController(_ splitViewController: UISplitViewController,
                             displayModeForExpandingToProposedDisplayMode proposedDisplayMode: UISplitViewController.DisplayMode) -> UISplitViewController.DisplayMode {
        return .oneBesideSecondary
    }
}

extension MainSplitViewController: SidebarViewControllerDelegate {
    func sidebarViewController(_ controller: SidebarViewController, didSelectSection section: SidebarSection) {
        navigateToSection(section)
    }
}