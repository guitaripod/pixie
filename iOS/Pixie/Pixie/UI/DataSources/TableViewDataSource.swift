import UIKit

class TableViewDataSource<Section: Hashable, Item: Hashable> {
    typealias DataSource = UITableViewDiffableDataSource<Section, Item>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    
    private(set) var dataSource: DataSource!
    private weak var tableView: UITableView?
    
    init(tableView: UITableView) {
        self.tableView = tableView
    }
    
    func configure<Cell: UITableViewCell>(
        cellType: Cell.Type,
        cellProvider: @escaping (Cell, IndexPath, Item) -> Void
    ) {
        guard let tableView = tableView else { return }
        
        dataSource = DataSource(tableView: tableView) { tableView, indexPath, item in
            let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: Cell.self), for: indexPath) as! Cell
            cellProvider(cell, indexPath, item)
            return cell
        }
        
        dataSource.defaultRowAnimation = .fade
    }
    
    func configureWithRegistration<Cell: UITableViewCell>(
        cellType: Cell.Type,
        cellProvider: @escaping (Cell, IndexPath, Item) -> Void
    ) {
        guard let tableView = tableView else { return }
        
        tableView.register(Cell.self, forCellReuseIdentifier: String(describing: Cell.self))
        
        dataSource = DataSource(tableView: tableView) { tableView, indexPath, item in
            let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: Cell.self), for: indexPath) as! Cell
            cellProvider(cell, indexPath, item)
            return cell
        }
        
        dataSource.defaultRowAnimation = .fade
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
}