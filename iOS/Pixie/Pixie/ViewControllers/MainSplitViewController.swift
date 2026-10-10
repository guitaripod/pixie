import UIKit

class MainSplitViewController: UISplitViewController {
    
    private var sidebarViewController: SidebarViewController!
    private var chatViewController: ChatGenerationViewController!
    private var detailNavigationController: UINavigationController!
    private var galleryViewController: GalleryViewController?
    private var creditsViewController: CreditsMainViewController?
    private var settingsViewController: SettingsViewController?
    private var adminViewController: AdminDashboardViewController?
    private var selectedSection: SidebarSection = .chat {
        didSet { Self.persist(selectedSection) }
    }
    private static let selectedSectionKey = "pixie.selectedSection"
    #if DEBUG
    var demoLaunch: DemoLaunch?
    private var demoLaunched = false
    #endif
    
    init() {
        super.init(style: .doubleColumn)
    }
    
    required init?(coder: NSCoder) {
        super.init(style: .doubleColumn)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Theme.Color.canvas
        preferredDisplayMode = .oneBesideSecondary
        preferredSplitBehavior = .tile
        presentsWithGesture = true
        preferredPrimaryColumnWidth = Self.regularPrimaryColumnWidth
        minimumPrimaryColumnWidth = 280
        maximumPrimaryColumnWidth = Self.regularMaximumPrimaryColumnWidth
        
        setupViewControllers()
        setupDelegate()
        
        displayModeButtonVisibility = .automatic
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        alignColumnsToFold()
    }

    /// With the device folded like a book the sidebar fills the page left of the fold and the
    /// detail column the page right of it, so no column straddles the fold. Otherwise the
    /// columns keep their usual widths.
    private func alignColumnsToFold() {
        guard !isCollapsed else { return }
        let fold = FoldGeometry.activeFold(in: view)
        let verticalFold = fold?.orientation == .vertical ? fold : nil
        let primaryWidth = verticalFold?.frame.minX ?? Self.regularPrimaryColumnWidth
        let detailInset = verticalFold.map { $0.frame.width } ?? 0
        if abs(preferredPrimaryColumnWidth - primaryWidth) > 0.5 {
            maximumPrimaryColumnWidth = max(Self.regularMaximumPrimaryColumnWidth, primaryWidth)
            preferredPrimaryColumnWidth = primaryWidth
        }
        if abs(detailNavigationController.additionalSafeAreaInsets.left - detailInset) > 0.5 {
            detailNavigationController.additionalSafeAreaInsets.left = detailInset
        }
    }

    private static let regularPrimaryColumnWidth: CGFloat = 320
    private static let regularMaximumPrimaryColumnWidth: CGFloat = 400

    private func setupViewControllers() {
        sidebarViewController = SidebarViewController()
        sidebarViewController.delegate = self
        sidebarViewController.initialSection = restoredSection()
        
        chatViewController = ChatGenerationViewController()
        #if DEBUG
        chatViewController.demoMode = demoLaunch?.scenario
        #endif
        detailNavigationController = UINavigationController(rootViewController: chatViewController)
        
        setViewController(sidebarViewController, for: .primary)
        setViewController(detailNavigationController, for: .secondary)

        setViewController(detailNavigationController, for: .compact)
    }
    
    /// The section saved by the last session, used only when the window is wide enough for the
    /// sidebar and never during a demo launch, so compact phones keep opening on the chat.
    private func restoredSection() -> SidebarSection {
        #if DEBUG
        if demoLaunch != nil { return .chat }
        #endif
        guard traitCollection.horizontalSizeClass == .regular,
              let raw = UserDefaults.standard.object(forKey: Self.selectedSectionKey) as? Int,
              let section = SidebarSection(rawValue: raw) else { return .chat }
        return section
    }

    private static func persist(_ section: SidebarSection) {
        UserDefaults.standard.set(section.rawValue, forKey: selectedSectionKey)
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
    
    func showViewController(_ viewController: UIViewController, animated: Bool = true) {
        if isCollapsed {
            if !detailNavigationController.viewControllers.contains(where: { $0 === viewController }) {
                detailNavigationController.pushViewController(viewController, animated: animated)
            } else {
                detailNavigationController.popToViewController(viewController, animated: animated)
            }
        } else {
            if detailNavigationController.viewControllers.first !== viewController {
                detailNavigationController.setViewControllers([viewController], animated: false)
            }
        }
    }
    
    func navigateToSection(_ section: SidebarSection, animated: Bool = true) {
        selectedSection = section
        sidebarViewController.select(section)
        showViewController(viewController(for: section), animated: animated)
    }

    private func viewController(for section: SidebarSection) -> UIViewController {
        switch section {
        case .chat:
            return chatViewController
            
        case .gallery:
            if galleryViewController == nil {
                galleryViewController = GalleryViewController()
            }
            return galleryViewController!
            
        case .credits:
            if creditsViewController == nil {
                creditsViewController = CreditsMainViewController()
            }
            return creditsViewController!
            
        case .settings:
            if settingsViewController == nil {
                settingsViewController = SettingsViewController()
            }
            return settingsViewController!
            
        case .admin:
            if adminViewController == nil {
                adminViewController = AdminDashboardViewController()
            }
            return adminViewController!
        }
    }

    private func section(of viewController: UIViewController) -> SidebarSection {
        switch viewController {
        case is GalleryViewController: return .gallery
        case is CreditsMainViewController: return .credits
        case is SettingsViewController: return .settings
        case is AdminDashboardViewController: return .admin
        default: return .chat
        }
    }

    /// Folding to a single column keeps the person where they were: the chat becomes the root
    /// again with the section they were viewing pushed on top, so Back leads to the chat.
    private func restoreCollapsedStack() {
        let stack = detailNavigationController.viewControllers
        guard let first = stack.first, first !== chatViewController else { return }
        detailNavigationController.setViewControllers([chatViewController] + stack, animated: false)
    }

    /// Unfolding to two columns keeps the person where they were: the section on top of the
    /// chat becomes the detail column and the sidebar selects it.
    private func restoreExpandedStack() {
        let stack = detailNavigationController.viewControllers
        guard stack.first === chatViewController, stack.count > 1 else { return }
        let remaining = Array(stack.dropFirst())
        selectedSection = section(of: remaining[0])
        detailNavigationController.setViewControllers(remaining, animated: false)
        sidebarViewController.select(selectedSection)
    }
}

extension MainSplitViewController: UISplitViewControllerDelegate {
    
    func splitViewController(_ svc: UISplitViewController,
                             topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column {
        return .secondary
    }

    func splitViewControllerDidCollapse(_ svc: UISplitViewController) {
        restoreCollapsedStack()
    }

    func splitViewControllerDidExpand(_ svc: UISplitViewController) {
        restoreExpandedStack()
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

#if DEBUG
extension MainSplitViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let demoLaunch, !demoLaunched else { return }
        demoLaunched = true
        if demoLaunch.section != .chat {
            navigateToSection(demoLaunch.section, animated: false)
        }
        demoLaunch.afterLaunch?(self, detailNavigationController)
    }
}
#endif