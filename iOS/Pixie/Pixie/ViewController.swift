import UIKit

class ViewController: UIViewController {
    
    private let titleLabel = UILabel()
    private let userInfoLabel = UILabel()
    private let logoutButton = UIButton()
    private let authenticationManager = AuthenticationManager.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateUserInfo()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Welcome to Pixie"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)
        
        userInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        userInfoLabel.font = .systemFont(ofSize: 16)
        userInfoLabel.textAlignment = .center
        userInfoLabel.numberOfLines = 0
        userInfoLabel.textColor = .secondaryLabel
        view.addSubview(userInfoLabel)
        
        logoutButton.translatesAutoresizingMaskIntoConstraints = false
        
        var config = UIButton.Configuration.filled()
        config.title = "Logout"
        config.baseForegroundColor = .white
        config.baseBackgroundColor = .systemRed
        config.cornerStyle = .medium
        config.buttonSize = .large
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 18, weight: .medium)
            return outgoing
        }
        
        logoutButton.configuration = config
        logoutButton.configurationUpdateHandler = { button in
            var config = button.configuration
            switch button.state {
            case .highlighted:
                config?.baseBackgroundColor = .systemRed.withAlphaComponent(0.8)
            default:
                config?.baseBackgroundColor = .systemRed
            }
            button.configuration = config
        }
        
        logoutButton.addAction(UIAction { [weak self] _ in
            self?.handleLogoutTapped()
        }, for: .touchUpInside)
        
        view.addSubview(logoutButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            userInfoLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            userInfoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            userInfoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            logoutButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoutButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            logoutButton.widthAnchor.constraint(equalToConstant: 200),
            logoutButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func updateUserInfo() {
        if let user = authenticationManager.currentUser {
            userInfoLabel.text = "Logged in as: \(user.email ?? user.id)"
        } else {
            userInfoLabel.text = "Not logged in"
        }
    }
    
    private func handleLogoutTapped() {
        HapticManager.shared.impact(.click)
        
        let alert = UIAlertController(
            title: "Logout",
            message: "Are you sure you want to logout?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Logout", style: .destructive) { _ in
            Task {
                do {
                    try await self.authenticationManager.logout()
                    
                    await MainActor.run {
                        if let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate {
                            sceneDelegate.showAuthenticationInterface()
                        }
                    }
                } catch {
                    await MainActor.run {
                        let errorAlert = UIAlertController(
                            title: "Error",
                            message: error.localizedDescription,
                            preferredStyle: .alert
                        )
                        errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(errorAlert, animated: true)
                    }
                }
            }
        })
        
        present(alert, animated: true)
    }
}
