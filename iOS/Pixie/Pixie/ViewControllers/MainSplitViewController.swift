import UIKit

class MainSplitViewController: UISplitViewController {
    
    private var sidebarViewController: SidebarViewController!
    private var chatViewController: ChatGenerationViewController!
    private var detailNavigationController: UINavigationController!
    
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
        
        if UIDevice.isPad {
            setViewController(nil, for: .compact)
        }
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
            detailNavigationController.pushViewController(viewController, animated: true)
        } else {
            detailNavigationController.setViewControllers([viewController], animated: false)
        }
    }
    
    func navigateToSection(_ section: SidebarSection) {
        switch section {
        case .chat:
            showViewController(chatViewController)
        case .gallery:
            let galleryVC = GalleryViewController()
            showViewController(galleryVC)
        case .credits:
            let creditsVC = CreditsMainViewController()
            showViewController(creditsVC)
        case .settings:
            let settingsVC = SettingsViewController()
            showViewController(settingsVC)
        case .admin:
            let adminVC = AdminDashboardViewController()
            showViewController(adminVC)
        }
    }
}

extension MainSplitViewController: UISplitViewControllerDelegate {
    
    func splitViewController(_ splitViewController: UISplitViewController,
                             collapseSecondary secondaryViewController: UIViewController,
                             onto primaryViewController: UIViewController) -> Bool {
        return false
    }
    
    func splitViewController(_ svc: UISplitViewController,
                             topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column {
        if UIDevice.isPad {
            return .primary
        }
        return proposedTopColumn
    }
}

extension MainSplitViewController: SidebarViewControllerDelegate {
    func sidebarViewController(_ controller: SidebarViewController, didSelectSection section: SidebarSection) {
        navigateToSection(section)
    }
}