import UIKit

class CollectionViewDataSource<Section: Hashable, Item: Hashable> {
    typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    typealias SupplementaryViewProvider = (UICollectionView, String, IndexPath) -> UICollectionReusableView?
    
    private(set) var dataSource: DataSource!
    private weak var collectionView: UICollectionView?
    
    init(collectionView: UICollectionView) {
        self.collectionView = collectionView
    }
    
    func configure<Cell: UICollectionViewCell>(
        cellType: Cell.Type,
        cellProvider: @escaping (Cell, IndexPath, Item) -> Void
    ) {
        guard let collectionView = collectionView else { return }
        
        dataSource = DataSource(collectionView: collectionView) { collectionView, indexPath, item in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: String(describing: Cell.self),
                for: indexPath
            ) as! Cell
            cellProvider(cell, indexPath, item)
            return cell
        }
    }
    
    func configureWithRegistration<Cell: UICollectionViewCell>(
        cellType: Cell.Type,
        cellProvider: @escaping (Cell, IndexPath, Item) -> Void
    ) {
        guard let collectionView = collectionView else { return }
        
        let cellRegistration = UICollectionView.CellRegistration<Cell, Item> { cell, indexPath, item in
            cellProvider(cell, indexPath, item)
        }
        
        dataSource = DataSource(collectionView: collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
    }
    
    func configureSupplementaryViews(provider: @escaping SupplementaryViewProvider) {
        dataSource.supplementaryViewProvider = provider
    }
    
    func configureSupplementaryViewWithRegistration<View: UICollectionReusableView>(
        viewType: View.Type,
        elementKind: String,
        viewProvider: @escaping (View, String, IndexPath) -> Void
    ) {
        guard collectionView != nil else { return }
        
        let registration = UICollectionView.SupplementaryRegistration<View>(
            elementKind: elementKind
        ) { view, elementKind, indexPath in
            viewProvider(view, elementKind, indexPath)
        }
        
        dataSource.supplementaryViewProvider = { collectionView, elementKind, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: registration, for: indexPath)
        }
    }
    
    func apply(_ snapshot: Snapshot, animatingDifferences: Bool = true) {
        dataSource?.apply(snapshot, animatingDifferences: animatingDifferences)
    }
    
    func apply(sections: [Section], items: [(Section, [Item])], animatingDifferences: Bool = true) {
        var snapshot = Snapshot()
        snapshot.appendSections(sections)
        
        for (section, sectionItems) in items {
            snapshot.appendItems(sectionItems, toSection: section)
        }
        
        apply(snapshot, animatingDifferences: animatingDifferences)
    }
    
    func currentSnapshot() -> Snapshot {
        dataSource.snapshot()
    }
    
    func item(at indexPath: IndexPath) -> Item? {
        dataSource.itemIdentifier(for: indexPath)
    }
    
    func indexPath(for item: Item) -> IndexPath? {
        dataSource.indexPath(for: item)
    }
    
    func reconfigureItems(_ items: [Item]) {
        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems(items)
        apply(snapshot)
    }
}