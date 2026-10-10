import UIKit

enum SidebarSection: Int, CaseIterable {
    case chat
    case gallery
    case credits
    case settings
    case admin
    
    var title: String {
        switch self {
        case .chat: return String(localized: "Generate")
        case .gallery: return String(localized: "Gallery")
        case .credits: return String(localized: "Credits")
        case .settings: return String(localized: "Settings")
        case .admin: return String(localized: "Admin")
        }
    }
    
    var icon: UIImage? {
        switch self {
        case .chat: return UIImage(systemName: "sparkles")
        case .gallery: return UIImage(systemName: "photo.stack")
        case .credits: return UIImage(systemName: "dollarsign.circle")
        case .settings: return UIImage(systemName: "gear")
        case .admin: return UIImage(systemName: "person.badge.shield.checkmark")
        }
    }
}

protocol SidebarViewControllerDelegate: AnyObject {
    func sidebarViewController(_ controller: SidebarViewController, didSelectSection section: SidebarSection)
}

class SidebarViewController: UIViewController {
    
    weak var delegate: SidebarViewControllerDelegate?
    var initialSection: SidebarSection = .chat
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, SidebarSection>!
    private var sections: [SidebarSection] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Pixie"
        
        setupSections()
        setupCollectionView()
        configureDataSource()
        applyInitialSnapshot()
        selectInitialItem()
    }
    
    private func setupSections() {
        sections = [.chat, .gallery, .credits, .settings]
        
        if AuthenticationManager.shared.currentUser?.isAdmin == true {
            sections.append(.admin)
        }
    }
    
    private func setupCollectionView() {
        var configuration = UICollectionLayoutListConfiguration(appearance: .sidebar)
        configuration.backgroundColor = .systemGroupedBackground
        configuration.headerMode = .none
        
        let layout = UICollectionViewCompositionalLayout.list(using: configuration)
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.delegate = self
        
        view.addSubview(collectionView)
    }
    
    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, SidebarSection> { cell, indexPath, section in
            
            var configuration = UIListContentConfiguration.sidebarCell()
            configuration.text = section.title
            configuration.image = section.icon
            configuration.imageProperties.tintColor = .brandText
            
            cell.contentConfiguration = configuration
            cell.backgroundConfiguration = UIBackgroundConfiguration.listSidebarCell()
            cell.isAccessibilityElement = true
            cell.accessibilityLabel = section.title
            cell.configurationUpdateHandler = { cell, state in
                cell.accessibilityTraits = state.isSelected ? [.button, .selected] : .button
            }
        }
        
        dataSource = UICollectionViewDiffableDataSource<Int, SidebarSection>(collectionView: collectionView) { collectionView, indexPath, section in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: section)
        }
    }
    
    private func applyInitialSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Int, SidebarSection>()
        snapshot.appendSections([0])
        snapshot.appendItems(sections, toSection: 0)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    private func selectInitialItem() {
        let isExpanded = splitViewController.map { !$0.isCollapsed } ?? false
        let section = isExpanded && sections.contains(initialSection) ? initialSection : .chat
        let item = sections.firstIndex(of: section) ?? 0
        collectionView.selectItem(at: IndexPath(item: item, section: 0), animated: false, scrollPosition: .top)

        if isExpanded {
            delegate?.sidebarViewController(self, didSelectSection: section)
        }
    }
    
    func select(_ section: SidebarSection) {
        guard isViewLoaded, let item = sections.firstIndex(of: section) else { return }
        collectionView.selectItem(at: IndexPath(item: item, section: 0), animated: false, scrollPosition: [])
    }

    func refreshSections() {
        setupSections()
        applyInitialSnapshot()
    }
}

extension SidebarViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < sections.count else { return }
        
        let section = sections[indexPath.item]
        delegate?.sidebarViewController(self, didSelectSection: section)
        
        HapticManager.shared.impact(.click)
    }
}