import UIKit

class HelpViewController: UIViewController {
    
    private let segmentedControl = UISegmentedControl(items: ["Getting Started", "Features", "FAQ"])
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    
    private var currentTab = 0
    private let haptics = HapticManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Help"
        view.backgroundColor = .systemBackground
        
        setupViews()
        setupConstraints()
        
        // Select first tab
        segmentedControl.selectedSegmentIndex = 0
        updateContent()
    }
    
    private func setupViews() {
        // Configure segmented control
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)
        
        // Configure scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        
        // Configure content view
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Configure stack view
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Segmented control
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Stack view
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
    
    @objc private func segmentChanged() {
        haptics.impact(.click)
        currentTab = segmentedControl.selectedSegmentIndex
        updateContent()
    }
    
    private func updateContent() {
        // Clear existing content
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        switch currentTab {
        case 0:
            showGettingStartedContent()
        case 1:
            showFeaturesContent()
        case 2:
            showFAQContent()
        default:
            break
        }
        
        // Scroll to top
        scrollView.setContentOffset(.zero, animated: false)
    }
    
    // MARK: - Getting Started Content
    
    private func showGettingStartedContent() {
        stackView.addArrangedSubview(createSection(
            title: "Welcome to Pixie",
            content: "Pixie is a powerful AI image generation app powered by gpt-image-1. Create stunning images from text descriptions, edit existing images, and browse galleries of amazing creations."
        ))
        
        stackView.addArrangedSubview(createSection(
            title: "Quick Start",
            content: """
                1. **Generate Images**: Tap the bottom toolbar and enter a description
                2. **Edit Images**: Select an image from gallery or your device
                3. **Browse Gallery**: Explore public images or view your creations
                4. **Manage Credits**: Check your balance and purchase more credits
                """
        ))
        
        stackView.addArrangedSubview(createSection(
            title: "Authentication",
            content: """
                Sign in with your preferred provider:
                • GitHub (recommended)
                • Google
                • Apple
                
                Your account syncs across all devices and with the CLI tool.
                """
        ))
    }
    
    // MARK: - Features Content
    
    private func showFeaturesContent() {
        stackView.addArrangedSubview(createSection(
            title: "Image Generation",
            content: """
                **Quality Options:**
                • Low: ~4-6 credits per image
                • Medium: ~16-24 credits per image
                • High: ~62-94 credits per image
                • Auto: ~50-75 credits (AI selects)
                
                **Size Options:**
                • Square (1024×1024)
                • Landscape (1536×1024)
                • Portrait (1024×1536)
                • Auto (AI selects optimal)
                
                **Advanced Options:**
                • Background: Auto, transparent, white, black
                • Format: PNG, JPEG, WebP
                • Compression: 0-100 (JPEG/WebP only)
                • Moderation: Auto (default), Low (less restrictive)
                """
        ))
        
        stackView.addArrangedSubview(createSection(
            title: "Image Editing",
            content: """
                Transform existing images with AI:
                
                **Edit Options:**
                • Change styles (cyberpunk, oil painting, etc.)
                • Add or remove elements
                • Enhance details
                • Create variations
                
                **Quality & Fidelity:**
                • Low fidelity: More creative freedom
                • High fidelity: Preserves faces/logos better
                
                **Credit Costs:**
                Base edit cost + quality cost:
                • Low: ~7 credits
                • Medium: ~16 credits
                • High: ~72-110 credits
                """
        ))
        
        stackView.addArrangedSubview(createSection(
            title: "Gallery Features",
            content: """
                **Public Gallery:**
                • Browse all public images
                • View image details and prompts
                • Copy prompts for inspiration
                • Download or share images
                
                **My Images:**
                • View your generated images
                • Edit from gallery
                • Manage your creations
                • Track image metadata
                """
        ))
        
        stackView.addArrangedSubview(createSection(
            title: "Credits System",
            content: """
                **Understanding Credits:**
                • Credits never expire
                • Shared across all platforms
                • Used for image generation and editing
                
                **Usage Tracking:**
                • View daily/weekly/monthly usage
                • Export usage data as CSV
                • Monitor credit consumption
                • Set up low balance alerts
                """
        ))
    }
    
    // MARK: - FAQ Content
    
    private func showFAQContent() {
        let faqs = [
            ("How do credits work?", 
             "Credits are the currency used to generate and edit images. Each operation costs a different amount based on quality and size."),
            
            ("Can I use my own OpenAI API key?", 
             "Yes! The backend supports using your own OpenAI API key. Contact support to set this up for your account."),
            
            ("What's the difference between quality levels?", 
             "Higher quality produces more detailed images but costs more credits. Low quality is great for drafts and experiments, while high quality is best for final artwork."),
            
            ("How do I get transparent backgrounds?", 
             "Select 'Transparent' in the background options when generating images. This works best with isolated subjects like logos or products."),
            
            ("Can I edit images from my gallery?", 
             "Yes! Long-press any image in the gallery and select 'Edit' to modify it with AI."),
            
            ("Is my data private?", 
             "Your API keys are stored securely on your device. All images you generate are automatically shared to the public gallery. You can save images locally or share them to other apps."),
            
            ("How do I report issues?", 
             "Report issues at github.com/anthropics/claude-code/issues or contact support through the app."),
            
            ("Can I use Pixie offline?", 
             "No, Pixie requires an internet connection to communicate with the AI servers for image generation.")
        ]
        
        for (question, answer) in faqs {
            stackView.addArrangedSubview(createFAQItem(question: question, answer: answer))
        }
    }
    
    // MARK: - Helper Methods
    
    private func createSection(title: String, content: String) -> UIView {
        let container = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .systemBlue
        titleLabel.numberOfLines = 0
        
        let contentLabel = UILabel()
        contentLabel.attributedText = parseMarkdown(content)
        contentLabel.numberOfLines = 0
        
        let stack = UIStackView(arrangedSubviews: [titleLabel, contentLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func createFAQItem(question: String, answer: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 12
        
        let questionLabel = UILabel()
        questionLabel.text = question
        questionLabel.font = .systemFont(ofSize: 17, weight: .medium)
        questionLabel.textColor = .systemBlue
        questionLabel.numberOfLines = 0
        
        let answerLabel = UILabel()
        answerLabel.text = answer
        answerLabel.font = .systemFont(ofSize: 15)
        answerLabel.textColor = .secondaryLabel
        answerLabel.numberOfLines = 0
        answerLabel.isHidden = true
        
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        
        let topStack = UIStackView(arrangedSubviews: [questionLabel, chevron])
        topStack.axis = .horizontal
        topStack.alignment = .center
        topStack.spacing = 8
        
        let mainStack = UIStackView(arrangedSubviews: [topStack, answerLabel])
        mainStack.axis = .vertical
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            
            chevron.widthAnchor.constraint(equalToConstant: 12),
            chevron.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(faqTapped(_:)))
        container.addGestureRecognizer(tapGesture)
        container.isUserInteractionEnabled = true
        
        // Store references for animation
        container.tag = stackView.arrangedSubviews.count
        answerLabel.tag = 1000 // Marker for answer label
        chevron.tag = 2000 // Marker for chevron
        
        return container
    }
    
    @objc private func faqTapped(_ gesture: UITapGestureRecognizer) {
        guard let container = gesture.view else { return }
        haptics.impact(.click)
        
        // Find answer label and chevron
        var answerLabel: UILabel?
        var chevron: UIImageView?
        
        container.subviews.forEach { subview in
            if let stack = subview as? UIStackView {
                stack.arrangedSubviews.forEach { view in
                    if view.tag == 1000, let label = view as? UILabel {
                        answerLabel = label
                    } else if let topStack = view as? UIStackView {
                        topStack.arrangedSubviews.forEach { innerView in
                            if innerView.tag == 2000, let imageView = innerView as? UIImageView {
                                chevron = imageView
                            }
                        }
                    }
                }
            }
        }
        
        guard let answer = answerLabel, let arrow = chevron else { return }
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            answer.isHidden.toggle()
            arrow.transform = answer.isHidden ? .identity : CGAffineTransform(rotationAngle: .pi / 2)
        }
    }
    
    private func parseMarkdown(_ text: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        
        let lines = text.components(separatedBy: "\n")
        
        for (index, line) in lines.enumerated() {
            var processedLine = line
            var attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle
            ]
            
            // Handle bold text
            let boldPattern = #"\*\*(.*?)\*\*"#
            if let regex = try? NSRegularExpression(pattern: boldPattern, options: []) {
                let matches = regex.matches(in: processedLine, options: [], range: NSRange(location: 0, length: processedLine.count))
                
                for match in matches.reversed() {
                    if let range = Range(match.range, in: processedLine) {
                        let boldText = String(processedLine[range]).replacingOccurrences(of: "**", with: "")
                        processedLine.replaceSubrange(range, with: boldText)
                    }
                }
                
                if !matches.isEmpty {
                    attributes[.font] = UIFont.systemFont(ofSize: 15, weight: .semibold)
                }
            }
            
            // Handle bullet points
            if processedLine.trimmingCharacters(in: .whitespaces).hasPrefix("•") {
                processedLine = "  " + processedLine
            }
            
            attributedString.append(NSAttributedString(string: processedLine, attributes: attributes))
            
            if index < lines.count - 1 {
                attributedString.append(NSAttributedString(string: "\n", attributes: attributes))
            }
        }
        
        return attributedString
    }
}