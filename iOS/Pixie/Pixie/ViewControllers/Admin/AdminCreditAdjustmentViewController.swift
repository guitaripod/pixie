import UIKit

class AdminCreditAdjustmentViewController: UIViewController {
    
    private let haptics = HapticManager.shared
    
    private let searchBar = UISearchBar()
    private let tableView = UITableView()
    private let loadingView = UIActivityIndicatorView(style: .large)
    private let promptStateView = StateView(
        symbol: "magnifyingglass",
        title: String(localized: "Search for users to adjust their credits")
    )
    private let noResultsStateView = StateView(
        symbol: "person.crop.circle.badge.questionmark",
        title: String(localized: "No users found")
    )
    private let errorView = AdminInlineMessageView()
    private let searchSpinner = UIActivityIndicatorView(style: .medium)
    private var searchMagnifier: UIView?
    
    private let adminRepository: AdminRepositoryProtocol
    private var searchResults: [UserSearchResult] = []
    private var selectedUser: UserSearchResult?
    private var searchTimer: Timer?
    private var searchGeneration = 0
    
    init() {
        self.adminRepository = AdminRepository(networkService: AppContainer.shared.networkService)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupConstraints()
    }
    
    private func setupUI() {
        title = String(localized: "Credit Adjustments")
        view.backgroundColor = Theme.Color.canvas
        
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = String(localized: "Search users by email or ID")
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        searchBar.accessibilityLabel = String(localized: "Search users")
        searchBar.searchTextField.accessibilityLabel = String(localized: "Search users")
        searchMagnifier = searchBar.searchTextField.leftView
        searchBar.tintColor = Theme.Color.accentText
        searchSpinner.hidesWhenStopped = true
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        tableView.keyboardDismissMode = .onDrag
        tableView.register(UserSearchResultCell.self, forCellReuseIdentifier: "UserCell")
        
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.hidesWhenStopped = true
        loadingView.color = Theme.Color.accentText
        
        noResultsStateView.isHidden = true
        
        view.addSubview(searchBar)
        view.addSubview(tableView)
        view.addSubview(loadingView)
        view.addSubview(promptStateView)
        view.addSubview(noResultsStateView)
        errorView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            promptStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            promptStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            promptStateView.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 32),
            promptStateView.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -32),

            noResultsStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            noResultsStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            noResultsStateView.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 32),
            noResultsStateView.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -32),
            
            errorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 32),
            errorView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -32)
        ])
    }
    
    private func searchUsers(query: String) {
        searchGeneration += 1
        let generation = searchGeneration
        errorView.hide()
        
        guard !query.isEmpty else {
            searchResults = []
            tableView.reloadData()
            setSearching(false)
            updateEmptyState()
            return
        }
        
        setSearching(true)
        hideEmptyStates()
        
        Task {
            do {
                let results = try await adminRepository.searchUsers(query: query)
                await MainActor.run {
                    guard generation == self.searchGeneration else { return }
                    self.searchResults = results
                    self.tableView.reloadData()
                    self.setSearching(false)
                    self.updateEmptyState()
                    self.announceResultCount()
                }
            } catch {
                await MainActor.run {
                    guard generation == self.searchGeneration else { return }
                    self.searchResults = []
                    self.tableView.reloadData()
                    self.setSearching(false)
                    self.showSearchError(error.localizedDescription, query: query)
                }
            }
        }
    }
    
    /// Swaps the search field's magnifier for a spinner while the debounce or the request is pending.
    private func setSearching(_ searching: Bool) {
        let field = searchBar.searchTextField
        if searching {
            field.leftView = searchSpinner
            searchSpinner.startAnimating()
        } else {
            searchSpinner.stopAnimating()
            field.leftView = searchMagnifier
        }
    }
    
    private func announceResultCount() {
        guard !searchResults.isEmpty else { return }
        Announce.say(String(localized: "\(searchResults.count) users found"))
    }
    
    private func showSearchError(_ message: String, query: String) {
        hideEmptyStates()
        haptics.notification(.error)
        errorView.show(message) { [weak self] in
            self?.searchUsers(query: query)
        }
    }
    
    private func hideEmptyStates() {
        promptStateView.isHidden = true
        noResultsStateView.isHidden = true
    }
    
    private func updateEmptyState() {
        let isSearching = !(searchBar.text ?? "").isEmpty
        promptStateView.isHidden = !(searchResults.isEmpty && !isSearching)
        noResultsStateView.isHidden = !(searchResults.isEmpty && isSearching)
    }
    
    private func showAdjustmentDialog(for user: UserSearchResult) {
        let form = AdminAdjustmentFormViewController(user: user, repository: adminRepository)
        form.onAdjusted = { [weak self] newBalance in
            self?.presentAdjustmentSuccess(newBalance: newBalance)
        }
        let navigation = UINavigationController(rootViewController: form)
        navigation.modalPresentationStyle = .pageSheet
        navigation.sheetPresentationController?.detents = [.medium(), .large()]
        haptics.impact(.click)
        present(navigation, animated: true)
    }
    
    private func presentAdjustmentSuccess(newBalance: Int) {
        let successAlert = UIAlertController(
            title: String(localized: "Success"),
            message: String(localized: "Credits adjusted successfully. New balance: \(newBalance)"),
            preferredStyle: .alert
        )
        successAlert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default) { [weak self] _ in
            guard let self else { return }
            self.searchBar.text = ""
            self.searchUsers(query: "")
        })
        present(successAlert, animated: true)
    }
}

extension AdminCreditAdjustmentViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchTimer?.invalidate()
        
        guard !searchText.isEmpty else {
            searchUsers(query: "")
            return
        }
        
        errorView.hide()
        setSearching(true)
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.searchUsers(query: searchText)
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

extension AdminCreditAdjustmentViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath) as! UserSearchResultCell
        let user = searchResults[indexPath.row]
        cell.configure(with: user)
        return cell
    }
}

extension AdminCreditAdjustmentViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let user = searchResults[indexPath.row]
        showAdjustmentDialog(for: user)
    }
}

final class AdminBadgeLabel: UILabel {

    private let insets = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let fitted = super.sizeThatFits(CGSize(width: size.width - insets.left - insets.right, height: size.height))
        return CGSize(width: fitted.width + insets.left + insets.right, height: fitted.height + insets.top + insets.bottom)
    }
}

class UserSearchResultCell: UITableViewCell {
    
    private let card = SurfaceView(style: .card)
    private let emailLabel = UILabel()
    private let idLabel = UILabel()
    private let creditsLabel = UILabel()
    private let adminBadge = AdminBadgeLabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        emailLabel.apply(.headline)
        
        idLabel.apply(.footnote)
        
        creditsLabel.apply(.numeral(17), color: Theme.Color.accentText)
        creditsLabel.numberOfLines = 1
        creditsLabel.textAlignment = .right
        creditsLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        adminBadge.text = String(localized: "ADMIN")
        adminBadge.font = Theme.TextStyle.caption.font
        adminBadge.adjustsFontForContentSizeCategory = true
        adminBadge.textColor = Theme.Color.accentText
        adminBadge.backgroundColor = Theme.Color.accentSoft
        adminBadge.layer.cornerRadius = 9
        adminBadge.layer.cornerCurve = .continuous
        adminBadge.layer.masksToBounds = true
        adminBadge.textAlignment = .center
        adminBadge.isHidden = true
        
        let textStack = UIStackView(arrangedSubviews: [emailLabel, idLabel])
        textStack.axis = .vertical
        textStack.spacing = Theme.Space.xs
        
        let trailingStack = UIStackView(arrangedSubviews: [creditsLabel, adminBadge])
        trailingStack.axis = .vertical
        trailingStack.alignment = .trailing
        trailingStack.spacing = Theme.Space.xs
        trailingStack.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        let rowStack = UIStackView(arrangedSubviews: [textStack, trailingStack])
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = Theme.Space.md
        
        contentView.addSubview(card)
        card.contentView.addSubview(rowStack)
        rowStack.pinEdges(to: card.contentView, insets: UIEdgeInsets(top: Theme.Space.lg, left: Theme.Space.lg, bottom: Theme.Space.lg, right: Theme.Space.lg))
        
        let width = card.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -2 * Theme.Space.lg)
        width.priority = .defaultHigh
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Theme.Space.sm),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Theme.Space.sm),
            card.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: Theme.Width.form),
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            width
        ])
    }
    
    func configure(with user: UserSearchResult) {
        let email = user.email ?? String(localized: "No email")
        emailLabel.text = email
        idLabel.text = String(localized: "ID: \(user.id)")
        creditsLabel.text = "\(user.credits)"
        adminBadge.isHidden = !user.isAdmin
        
        let role = user.isAdmin ? String(localized: "Admin") + ", " : ""
        describe(
            "\(email), \(role)" + String(localized: "\(user.credits) credits"),
            hint: String(localized: "Adjusts this user's credits"),
            value: String(localized: "ID: \(user.id)"),
            traits: .button
        )
    }
}

final class AdminAdjustmentFormViewController: UIViewController {

    var onAdjusted: ((Int) -> Void)?

    private let user: UserSearchResult
    private let repository: AdminRepositoryProtocol
    private let haptics = HapticManager.shared

    private let summaryLabel = UILabel()
    private let directionControl = UISegmentedControl(items: [String(localized: "Add"), String(localized: "Remove")])
    private let amountField = UITextField()
    private let reasonField = UITextField()
    private let errorLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var adjustButton: UIBarButtonItem!
    private var isSubmitting = false

    init(user: UserSearchResult, repository: AdminRepositoryProtocol) {
        self.user = user
        self.repository = repository
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String(localized: "Adjust Credits")
        view.backgroundColor = Theme.Color.canvas
        setupNavigation()
        setupFields()
        setupLayout()
        updateAdjustEnabled()
    }

    private func setupNavigation() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        adjustButton = UIBarButtonItem(title: String(localized: "Adjust"), primaryAction: UIAction { [weak self] _ in
            self?.submit()
        })
        if #available(iOS 26.0, *) {
            adjustButton.style = .prominent
        }
        navigationItem.rightBarButtonItem = adjustButton
    }

    private func setupFields() {
        summaryLabel.apply(.callout)
        summaryLabel.text = String(localized: "Current balance: \(user.credits) credits\nUser: \(user.email ?? user.id)")

        directionControl.selectedSegmentIndex = 0
        directionControl.accessibilityLabel = String(localized: "Adjustment type")
        directionControl.addAction(UIAction { [weak self] _ in self?.directionChanged() }, for: .valueChanged)
        directionChanged()

        configure(amountField, placeholder: String(localized: "Amount"), keyboard: .numberPad)
        configure(reasonField, placeholder: String(localized: "Reason for adjustment"), keyboard: .default)
        reasonField.returnKeyType = .done
        reasonField.delegate = self

        errorLabel.apply(.footnote, color: Theme.Color.danger)
        errorLabel.isHidden = true
    }

    private func configure(_ field: UITextField, placeholder: String, keyboard: UIKeyboardType) {
        field.placeholder = placeholder
        field.accessibilityLabel = placeholder
        field.keyboardType = keyboard
        field.borderStyle = .none
        field.backgroundColor = Theme.Color.fill
        field.layer.cornerRadius = Theme.Radius.md
        field.layer.cornerCurve = .continuous
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: Theme.Space.lg, height: 1))
        field.leftViewMode = .always
        field.font = Theme.TextStyle.body.font
        field.textColor = Theme.Color.ink
        field.tintColor = Theme.Color.accentText
        field.adjustsFontForContentSizeCategory = true
        field.addAction(UIAction { [weak self] _ in self?.fieldsChanged() }, for: .editingChanged)
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
    }

    private func setupLayout() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        let stack = UIStackView(arrangedSubviews: [summaryLabel, directionControl, amountField, reasonField, errorLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = Theme.Space.lg
        stack.layoutMargins = UIEdgeInsets(top: Theme.Space.lg, left: Theme.Space.xl, bottom: Theme.Space.lg, right: Theme.Space.xl)
        stack.isLayoutMarginsRelativeArrangement = true
        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private var signedAmount: Int? {
        guard let text = amountField.text, let magnitude = Int(text), magnitude > 0 else { return nil }
        return directionControl.selectedSegmentIndex == 0 ? magnitude : -magnitude
    }

    private var trimmedReason: String {
        reasonField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func directionChanged() {
        let removing = directionControl.selectedSegmentIndex == 1
        directionControl.accessibilityValue = removing ? String(localized: "Remove") : String(localized: "Add")
        haptics.selectionChanged()
        fieldsChanged()
    }

    private func fieldsChanged() {
        errorLabel.isHidden = true
        updateAdjustEnabled()
    }

    private func updateAdjustEnabled() {
        adjustButton?.isEnabled = !isSubmitting && signedAmount != nil && !trimmedReason.isEmpty
    }

    private func setSubmitting(_ submitting: Bool) {
        isSubmitting = submitting
        directionControl.isEnabled = !submitting
        amountField.isEnabled = !submitting
        reasonField.isEnabled = !submitting
        isModalInPresentation = submitting
        navigationItem.leftBarButtonItem?.isEnabled = !submitting
        if submitting {
            spinner.startAnimating()
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: spinner)
        } else {
            spinner.stopAnimating()
            navigationItem.rightBarButtonItem = adjustButton
        }
        updateAdjustEnabled()
    }

    private func submit() {
        guard let amount = signedAmount, !trimmedReason.isEmpty, !isSubmitting else {
            showError(String(localized: "Please enter a valid amount and reason"))
            return
        }
        view.endEditing(true)
        setSubmitting(true)
        let request = AdminCreditAdjustmentRequest(userId: user.id, amount: amount, reason: trimmedReason)
        Task {
            do {
                let response = try await repository.adjustCredits(request: request)
                await MainActor.run {
                    self.haptics.notification(.success)
                    self.dismiss(animated: true) {
                        self.onAdjusted?(response.newBalance)
                    }
                }
            } catch {
                await MainActor.run {
                    self.setSubmitting(false)
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
        haptics.notification(.error)
        Announce.say(message)
    }
}

extension AdminAdjustmentFormViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
