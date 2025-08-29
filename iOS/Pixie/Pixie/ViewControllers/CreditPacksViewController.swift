import UIKit
import Combine
import RevenueCat

class CreditPacksViewController: UIViewController {
    private let viewModel: CreditsViewModel
    private var cancellables = Set<AnyCancellable>()
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let loadingView = UIActivityIndicatorView(style: .large)
    
    private let headerView = UIView()
    private let balanceLabel = UILabel()
    private let balanceAmountLabel = UILabel()
    
    private var creditPacks: [CreditPack] = []
    private var creditPacksWithPricing: [CreditPackWithPrice] = []
    private let purchaseManager = CreditPurchaseManager.shared
    
    init(viewModel: CreditsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        viewModel.refresh()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.refresh()
    }
    
    private func setupUI() {
        title = "Credit Packs"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never
        
        // Add restore button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Restore",
            style: .plain,
            target: self,
            action: #selector(restoreTapped)
        )
        
        setupHeaderView()
        setupTableView()
        setupLoadingView()
    }
    
    private func setupHeaderView() {
        headerView.backgroundColor = .secondarySystemGroupedBackground
        headerView.layer.cornerRadius = 16
        
        balanceLabel.text = "Current Balance"
        balanceLabel.font = .systemFont(ofSize: 14, weight: .medium)
        balanceLabel.textColor = .secondaryLabel
        balanceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        balanceAmountLabel.font = .systemFont(ofSize: 28, weight: .bold)
        balanceAmountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(balanceLabel)
        headerView.addSubview(balanceAmountLabel)
        
        NSLayoutConstraint.activate([
            balanceLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            balanceLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            
            balanceAmountLabel.topAnchor.constraint(equalTo: balanceLabel.bottomAnchor, constant: 4),
            balanceAmountLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            balanceAmountLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16)
        ])
        
        headerView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 100)
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(CreditPackCell.self, forCellReuseIdentifier: "CreditPackCell")
        tableView.tableHeaderView = headerView
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupLoadingView() {
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.hidesWhenStopped = true
        view.addSubview(loadingView)
        
        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func bindViewModel() {
        viewModel.$balance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] balance in
                self?.updateBalance(balance)
            }
            .store(in: &cancellables)
        
        purchaseManager.getCreditPacksWithPricing()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] packsWithPricing in
                self?.creditPacksWithPricing = packsWithPricing
                self?.creditPacks = packsWithPricing.map { $0.creditPack }
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
        
        viewModel.$isLoadingPacks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                if isLoading {
                    self?.loadingView.startAnimating()
                } else {
                    self?.loadingView.stopAnimating()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateBalance(_ balance: CreditBalance?) {
        guard let balance = balance else { return }
        balanceAmountLabel.text = "\(balance.balance) credits"
        balanceAmountLabel.textColor = balance.getBalanceColor()
    }
    
    @objc private func restoreTapped() {
        HapticsManager.shared.impact(.light)
        showRestoreDialog()
    }
    
    private func showRestoreDialog() {
        let alert = UIAlertController(
            title: "Restore Purchases",
            message: "This will restore any previous credit pack purchases made with your Apple ID.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Restore", style: .default) { [weak self] _ in
            self?.restorePurchases()
        })
        
        present(alert, animated: true)
    }
    
    private func restorePurchases() {
        let loadingAlert = UIAlertController(
            title: "Restoring Purchases",
            message: "Please wait...",
            preferredStyle: .alert
        )
        present(loadingAlert, animated: true)
        
        Task {
            let result = await purchaseManager.restorePurchases()
            
            await MainActor.run {
                loadingAlert.dismiss(animated: true) {
                    switch result {
                    case .success(let restoredPurchases):
                        HapticsManager.shared.notification(.success)
                        let message = restoredPurchases.isEmpty 
                            ? "No purchases found to restore."
                            : "Successfully restored \(restoredPurchases.count) purchase(s)."
                        
                        let successAlert = UIAlertController(
                            title: "Restore Complete",
                            message: message,
                            preferredStyle: .alert
                        )
                        successAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(successAlert, animated: true)
                        
                    case .failure(let error):
                        HapticsManager.shared.notification(.error)
                        let errorAlert = UIAlertController(
                            title: "Restore Failed",
                            message: error.localizedDescription,
                            preferredStyle: .alert
                        )
                        errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(errorAlert, animated: true)
                    }
                }
            }
        }
    }
    
    private func purchasePack(_ pack: CreditPack) {
        HapticsManager.shared.impact(.medium)
        
        guard let creditPackWithPrice = creditPacksWithPricing.first(where: { $0.creditPack.id == pack.id }) else {
            return
        }
        
        let loadingAlert = UIAlertController(
            title: "Processing Purchase",
            message: "Please wait...",
            preferredStyle: .alert
        )
        present(loadingAlert, animated: true)
        
        Task {
            let result = await purchaseManager.purchaseCreditPack(package: creditPackWithPrice.rcPackage)
            
            await MainActor.run {
                loadingAlert.dismiss(animated: true) {
                    switch result {
                    case .success(let purchaseResult):
                        HapticsManager.shared.notification(.success)
                        
                        Task {
                            await self.viewModel.loadBalance()
                        }
                        
                        let successAlert = UIAlertController(
                            title: "Purchase Successful",
                            message: "Added \(purchaseResult.credits) credits to your account.\nNew balance: \(purchaseResult.newBalance) credits",
                            preferredStyle: .alert
                        )
                        successAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(successAlert, animated: true)
                        
                    case .failure(let error):
                        if error is PurchaseCancelledException {
                            return
                        }
                        
                        HapticsManager.shared.notification(.error)
                        let errorAlert = UIAlertController(
                            title: "Purchase Failed",
                            message: error.localizedDescription,
                            preferredStyle: .alert
                        )
                        errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(errorAlert, animated: true)
                    }
                }
            }
        }
    }
}

// MARK: - UITableViewDataSource
extension CreditPacksViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return creditPacks.isEmpty ? 0 : 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return creditPacks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CreditPackCell", for: indexPath) as! CreditPackCell
        let pack = creditPacks[indexPath.row]
        let localizedPrice = creditPacksWithPricing.first(where: { $0.creditPack.id == pack.id })?.localizedPrice
        cell.configure(with: pack, localizedPrice: localizedPrice)
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Available Packs"
    }
}

// MARK: - UITableViewDelegate
extension CreditPacksViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let pack = creditPacks[indexPath.row]
        purchasePack(pack)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
}

// MARK: - CreditPackCell
class CreditPackCell: UITableViewCell {
    private let packNameLabel = UILabel()
    private let creditsLabel = UILabel()
    private let priceLabel = UILabel()
    private let bonusLabel = UILabel()
    private let popularBadge = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .secondarySystemGroupedBackground
        
        packNameLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        packNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        creditsLabel.font = .systemFont(ofSize: 14)
        creditsLabel.textColor = .secondaryLabel
        creditsLabel.translatesAutoresizingMaskIntoConstraints = false
        
        priceLabel.font = .systemFont(ofSize: 20, weight: .bold)
        priceLabel.textColor = .systemPurple
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        bonusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        bonusLabel.textColor = .systemGreen
        bonusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        popularBadge.text = "POPULAR"
        popularBadge.font = .systemFont(ofSize: 10, weight: .bold)
        popularBadge.textColor = .white
        popularBadge.backgroundColor = .systemOrange
        popularBadge.textAlignment = .center
        popularBadge.layer.cornerRadius = 4
        popularBadge.layer.masksToBounds = true
        popularBadge.isHidden = true
        popularBadge.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(packNameLabel)
        contentView.addSubview(creditsLabel)
        contentView.addSubview(priceLabel)
        contentView.addSubview(bonusLabel)
        contentView.addSubview(popularBadge)
        
        NSLayoutConstraint.activate([
            packNameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            packNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            creditsLabel.topAnchor.constraint(equalTo: packNameLabel.bottomAnchor, constant: 4),
            creditsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            bonusLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            bonusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            priceLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            priceLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            popularBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            popularBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            popularBadge.widthAnchor.constraint(equalToConstant: 60),
            popularBadge.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func configure(with pack: CreditPack, localizedPrice: String? = nil) {
        packNameLabel.text = pack.name
        creditsLabel.text = "\(pack.credits) credits"
        priceLabel.text = localizedPrice ?? "$\(String(format: "%.2f", Double(pack.priceUsdCents) / 100.0))"
        
        if pack.bonusCredits > 0 {
            bonusLabel.text = "+\(pack.bonusCredits) bonus credits"
            bonusLabel.isHidden = false
        } else {
            bonusLabel.isHidden = true
        }
        
        popularBadge.isHidden = pack.id != "popular"
    }
}