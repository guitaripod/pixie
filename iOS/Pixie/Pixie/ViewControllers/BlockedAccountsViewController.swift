import UIKit

final class BlockedAccountsViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var blocked: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Blocked Accounts"
        view.backgroundColor = .systemGroupedBackground

        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        reload()
    }

    private func reload() {
        blocked = BlockedUsers.all.sorted()
        tableView.reloadData()
    }
}

extension BlockedAccountsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(blocked.count, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        if blocked.isEmpty {
            cell.textLabel?.text = "You haven't blocked anyone."
            cell.textLabel?.textColor = .secondaryLabel
            cell.selectionStyle = .none
        } else {
            cell.textLabel?.text = blocked[indexPath.row]
            cell.textLabel?.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
            cell.textLabel?.lineBreakMode = .byTruncatingMiddle
            cell.selectionStyle = .none
        }
        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        !blocked.isEmpty
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard !blocked.isEmpty else { return nil }
        let unblock = UIContextualAction(style: .destructive, title: "Unblock") { [weak self] _, _, completion in
            guard let self = self, indexPath.row < self.blocked.count else { completion(false); return }
            BlockedUsers.unblock(self.blocked[indexPath.row])
            self.reload()
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [unblock])
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "Swipe a row to unblock. Unblocked accounts will reappear in Explore."
    }
}
