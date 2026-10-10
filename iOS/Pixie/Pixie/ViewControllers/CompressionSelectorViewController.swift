import UIKit

class CompressionSelectorViewController: UIViewController {

    private let currentLevel: Int
    private let onLevelChanged: (Int) -> Void

    private let scrollView = UIScrollView()
    private let slider = PercentSlider()
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
        title = String(localized: "Compression Level")

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
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.cornerRadius = 12
        scrollView.addSubview(containerView)

        titleLabel.text = String(localized: "Compression Level")
        titleLabel.useScaledFont(.body, size: 17, weight: .semibold)
        titleLabel.numberOfLines = 0
        titleLabel.hideFromAccessibility()
        containerView.addSubview(titleLabel)

        valueLabel.useScaledFont(.body, size: 17)
        valueLabel.textColor = .secondaryLabel
        valueLabel.hideFromAccessibility()
        containerView.addSubview(valueLabel)

        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = Float(currentLevel)
        slider.accessibilityLabel = String(localized: "Compression Level")
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        containerView.addSubview(slider)

        descriptionLabel.text = String(localized: "Higher compression reduces file size but may lower image quality")
        descriptionLabel.useScaledFont(.footnote, size: 13)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .center
        scrollView.addSubview(descriptionLabel)

        [containerView, titleLabel, valueLabel, slider, descriptionLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            containerView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            containerView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            containerView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: valueLabel.leadingAnchor, constant: -8),

            valueLabel.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            slider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            slider.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            slider.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            slider.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            slider.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            descriptionLabel.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 32),
            descriptionLabel.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -32),
            descriptionLabel.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20)
        ])
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    @objc private func sliderValueChanged() {
        let value = Int(slider.value)

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
        valueLabel.text = String(localized: "\(value)%")
    }
}
