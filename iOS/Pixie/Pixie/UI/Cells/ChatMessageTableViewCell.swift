import UIKit

class ChatMessageTableViewCell: UITableViewCell {
    
    enum MessageType {
        case user(String)
        case imageResponse(url: String, prompt: String)
        case error(String)
        case loading
    }
    
    struct Configuration: Hashable {
        let id: String
        let messageType: MessageType
        let timestamp: Date
        
        static func == (lhs: Configuration, rhs: Configuration) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    
    private let bubbleView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let messageImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 12
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let loadingIndicator: AnimatedLoadingIndicator = {
        let indicator = AnimatedLoadingIndicator()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .caption2)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        messageLabel.text = nil
        messageImageView.image = nil
        messageImageView.isHidden = true
        loadingIndicator.stopAnimating()
        loadingIndicator.isHidden = true
        timestampLabel.text = nil
    }
    
    private func setupViews() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(messageLabel)
        bubbleView.addSubview(messageImageView)
        bubbleView.addSubview(loadingIndicator)
        contentView.addSubview(timestampLabel)
        
        leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            bubbleView.bottomAnchor.constraint(equalTo: timestampLabel.topAnchor, constant: -4),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75),
            
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12),
            
            messageImageView.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
            messageImageView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            messageImageView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            messageImageView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12),
            messageImageView.heightAnchor.constraint(equalTo: messageImageView.widthAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: bubbleView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: bubbleView.centerYAnchor),
            
            timestampLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            timestampLabel.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    func configure(with configuration: Configuration) {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        timestampLabel.text = formatter.localizedString(for: configuration.timestamp, relativeTo: Date())
        
        switch configuration.messageType {
        case .user(let text):
            configureUserMessage(text: text)
            
        case .imageResponse(let url, let prompt):
            configureImageResponse(url: url, prompt: prompt)
            
        case .error(let message):
            configureError(message: message)
            
        case .loading:
            configureLoading()
        }
    }
    
    private func configureUserMessage(text: String) {
        bubbleView.backgroundColor = UIColor(red: 103/255, green: 80/255, blue: 164/255, alpha: 1)
        messageLabel.textColor = .white
        messageLabel.text = text
        
        leadingConstraint.isActive = false
        trailingConstraint.isActive = true
        timestampLabel.textAlignment = .right
        timestampLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor).isActive = true
    }
    
    private func configureImageResponse(url: String, prompt: String) {
        bubbleView.backgroundColor = .clear
        messageLabel.text = nil
        
        messageImageView.isHidden = false
        messageImageView.setImage(from: url)
        
        leadingConstraint.isActive = true
        trailingConstraint.isActive = false
        timestampLabel.textAlignment = .left
        timestampLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor).isActive = true
    }
    
    private func configureError(message: String) {
        bubbleView.backgroundColor = .systemRed.withAlphaComponent(0.1)
        messageLabel.textColor = .systemRed
        messageLabel.text = message
        
        leadingConstraint.isActive = true
        trailingConstraint.isActive = false
        timestampLabel.textAlignment = .left
        timestampLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor).isActive = true
    }
    
    private func configureLoading() {
        bubbleView.backgroundColor = .systemGray6
        messageLabel.text = nil
        loadingIndicator.isHidden = false
        loadingIndicator.startAnimating()
        
        leadingConstraint.isActive = true
        trailingConstraint.isActive = false
        timestampLabel.textAlignment = .left
        timestampLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor).isActive = true
    }
    
    static func registration() -> String {
        return String(describing: ChatMessageTableViewCell.self)
    }
}