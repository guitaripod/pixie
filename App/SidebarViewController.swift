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
        UIImage(systemName: symbolName)
    }

    var symbolName: String {
        switch self {
        case .chat: return "sparkles"
        case .gallery: return "photo.stack"
        case .credits: return "dollarsign.circle"
        case .settings: return "gearshape.fill"
        case .admin: return "person.badge.shield.checkmark"
        }
    }
}

/// Draws the 28-point gradient tile with a white glyph that stands in front of a sidebar row.
private enum SidebarBadge {
    static let size = CGSize(width: 28, height: 28)

    static func image(symbol: String, traits: UITraitCollection) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(roundedRect: rect, cornerRadius: size.width * 0.3).addClip()
            let colors = Theme.Color.gradient.map { $0.resolvedColor(with: traits).cgColor } as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: nil) {
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }
            let configuration = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            guard let glyph = UIImage(systemName: symbol, withConfiguration: configuration)?.withTintColor(.white, renderingMode: .alwaysOriginal) else { return }
            glyph.draw(in: CGRect(
                x: (size.width - glyph.size.width) / 2,
                y: (size.height - glyph.size.height) / 2,
                width: glyph.size.width,
                height: glyph.size.height
            ))
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
        configuration.backgroundColor = Theme.Color.canvas
        configuration.showsSeparators = false
        configuration.headerMode = .none
        
        let layout = UICollectionViewCompositionalLayout.list(using: configuration)
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = Theme.Color.canvas
        collectionView.delegate = self
        
        view.addSubview(collectionView)
    }
    
    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, SidebarSection> { cell, indexPath, section in
            cell.isAccessibilityElement = true
            cell.accessibilityLabel = section.title
            cell.configurationUpdateHandler = { cell, state in
                var content = UIListContentConfiguration.sidebarCell()
                content.text = section.title
                content.textProperties.font = Theme.TextStyle.headline.font
                content.textProperties.color = state.isSelected ? Theme.Color.accentText : Theme.Color.ink
                content.image = SidebarBadge.image(symbol: section.symbolName, traits: state.traitCollection)
                content.imageProperties.reservedLayoutSize = SidebarBadge.size
                content.imageProperties.maximumSize = SidebarBadge.size
                content.imageToTextPadding = Theme.Space.md
                cell.contentConfiguration = content

                var background = UIBackgroundConfiguration.clear()
                background.backgroundColor = state.isSelected ? Theme.Color.accentSoft : .clear
                background.cornerRadius = Theme.Radius.md
                background.backgroundInsets = NSDirectionalEdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0)
                cell.backgroundConfiguration = background

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