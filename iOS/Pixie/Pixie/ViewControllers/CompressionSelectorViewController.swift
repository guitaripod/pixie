import UIKit

class CompressionSelectorViewController: UIViewController {
    
    private let currentLevel: Int
    private let onLevelChanged: (Int) -> Void
    
    private let slider = UISlider()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let containerView = UIView()
    
    private var lastHapticValue: Int
    
    init(currentLevel: Int, onLevelChanged: @escaping (Int) -> Void) {
        self.currentLevel = currentLevel
        self.onLevelChanged = onLevelChanged
        self.lastHapticValue = currentLevel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        title = "Compression Level"
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
        )
        
        setupViews()
        setupConstraints()
        
        slider.value = Float(currentLevel)
        updateLabels()
    }
    
    private func setupViews() {
        // Container
        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.cornerRadius = 12
        view.addSubview(containerView)
        
        // Title
        titleLabel.text = "Compression Level"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        containerView.addSubview(titleLabel)
        
        // Value
        valueLabel.font = .systemFont(ofSize: 17, weight: .regular)
        valueLabel.textColor = .secondaryLabel
        containerView.addSubview(valueLabel)
        
        // Slider
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = Float(currentLevel)
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        containerView.addSubview(slider)
        
        // Description
        descriptionLabel.text = "Higher compression reduces file size but may lower image quality"
        descriptionLabel.font = .systemFont(ofSize: 13)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .center
        view.addSubview(descriptionLabel)
        
        // Make views layout-ready
        [containerView, titleLabel, valueLabel, slider, descriptionLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Title and Value in same row
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            valueLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Slider
            slider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            slider.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            slider.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            slider.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            // Description
            descriptionLabel.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }
    
    @objc private func sliderValueChanged() {
        let value = Int(slider.value)
        
        // Haptic feedback every 5%
        if value % 5 == 0 && value != lastHapticValue {
            HapticManager.shared.impact(.sliderTick)
            lastHapticValue = value
        }
        
        onLevelChanged(value)
        updateLabels()
    }
    
    @objc private func doneTapped() {
        HapticManager.shared.impact(.click)
        dismiss(animated: true)
    }
    
    private func updateLabels() {
        let value = Int(slider.value)
        valueLabel.text = "\(value)%"
    }
}