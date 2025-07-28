import UIKit

class ChatTableView: UIView {
    
    // MARK: - Types
    
    enum Section: Int, CaseIterable {
        case messages
    }
    
    // MARK: - Properties
    
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.backgroundColor = .systemBackground
        tv.separatorStyle = .none
        tv.keyboardDismissMode = .interactive
        tv.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 100, right: 0)
        tv.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 80, right: 0)
        return tv
    }()
    
    private var dataSource: UITableViewDiffableDataSource<Section, ChatMessage>!
    
    weak var delegate: ChatTableViewDelegate?
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupDataSource()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        backgroundColor = .systemBackground
        
        addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        registerCells()
    }
    
    private func registerCells() {
        tableView.register(UserMessageCell.self, forCellReuseIdentifier: UserMessageCell.identifier)
        tableView.register(AssistantMessageCell.self, forCellReuseIdentifier: AssistantMessageCell.identifier)
        tableView.register(LoadingMessageCell.self, forCellReuseIdentifier: LoadingMessageCell.identifier)
    }
    
    private func setupDataSource() {
        dataSource = UITableViewDiffableDataSource<Section, ChatMessage>(
            tableView: tableView
        ) { [weak self] tableView, indexPath, message in
            switch message.role {
            case .user:
                let cell = tableView.dequeueReusableCell(withIdentifier: UserMessageCell.identifier, for: indexPath) as! UserMessageCell
                cell.configure(with: message)
                return cell
            case .assistant:
                let cell = tableView.dequeueReusableCell(withIdentifier: AssistantMessageCell.identifier, for: indexPath) as! AssistantMessageCell
                cell.configure(with: message)
                cell.delegate = self
                return cell
            case .loading:
                let cell = tableView.dequeueReusableCell(withIdentifier: LoadingMessageCell.identifier, for: indexPath) as! LoadingMessageCell
                cell.startAnimating()
                return cell
            }
        }
        
        dataSource.defaultRowAnimation = .fade
    }
    
    // MARK: - Public Methods
    
    func setMessages(_ messages: [ChatMessage], animated: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, ChatMessage>()
        snapshot.appendSections([.messages])
        snapshot.appendItems(messages, toSection: .messages)
        dataSource.apply(snapshot, animatingDifferences: animated)
        
        if !messages.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.scrollToBottom(animated: animated)
            }
        }
    }
    
    func scrollToBottom(animated: Bool = true) {
        guard let lastSection = dataSource.snapshot().sectionIdentifiers.last,
              let lastItem = dataSource.snapshot().itemIdentifiers(inSection: lastSection).last,
              let indexPath = dataSource.indexPath(for: lastItem) else { return }
        
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
    }
    
    func adjustForKeyboard(height: CGFloat, duration: TimeInterval) {
        let adjustedHeight = height > 0 ? height - 20 : 0
        tableView.contentInset.bottom = adjustedHeight + 100
        tableView.verticalScrollIndicatorInsets.bottom = adjustedHeight + 80
        
        if height > 0 {
            scrollToBottom(animated: true)
        }
    }
}

// MARK: - AssistantMessageCellDelegate

extension ChatTableView: AssistantMessageCellDelegate {
    func assistantMessageCell(_ cell: AssistantMessageCell, didTapImageAt index: Int) {
        guard let indexPath = tableView.indexPath(for: cell),
              let message = dataSource.itemIdentifier(for: indexPath) else { return }
        
        delegate?.chatTableView(self, didTapImageAt: index, in: message)
    }
    
    func assistantMessageCell(_ cell: AssistantMessageCell, didLongPressImageAt index: Int) {
        guard let indexPath = tableView.indexPath(for: cell),
              let message = dataSource.itemIdentifier(for: indexPath) else { return }
        
        delegate?.chatTableView(self, didLongPressImageAt: index, in: message)
    }
}

// MARK: - Delegate Protocol

protocol ChatTableViewDelegate: AnyObject {
    func chatTableView(_ chatTableView: ChatTableView, didTapImageAt index: Int, in message: ChatMessage)
    func chatTableView(_ chatTableView: ChatTableView, didLongPressImageAt index: Int, in message: ChatMessage)
}

// MARK: - Message Cells

class UserMessageCell: UITableViewCell {
    static let identifier = "UserMessageCell"
    
    private let bubbleView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBlue
        view.layer.cornerRadius = 18
        return view
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16)
        label.textColor = .white
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 60),
            
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with message: ChatMessage) {
        messageLabel.text = message.content
    }
}

class AssistantMessageCell: UITableViewCell {
    static let identifier = "AssistantMessageCell"
    
    weak var delegate: AssistantMessageCellDelegate?
    
    private let bubbleView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 18
        return view
    }()
    
    private let contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        return stack
    }()
    
    private var imageViews: [UIImageView] = []
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(contentStackView)
        
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -60),
            
            contentStackView.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
            contentStackView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            contentStackView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            contentStackView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with message: ChatMessage) {
        contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        imageViews.removeAll()
        
        if let images = message.images, !images.isEmpty {
            let imageContainer = UIStackView()
            imageContainer.axis = .horizontal
            imageContainer.spacing = 8
            imageContainer.distribution = .fillEqually
            
            for (index, image) in images.enumerated() {
                let imageView = UIImageView()
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
                imageView.layer.cornerRadius = 12
                imageView.backgroundColor = .tertiarySystemBackground
                imageView.isUserInteractionEnabled = true
                imageView.tag = index
                
                imageView.widthAnchor.constraint(equalToConstant: 120).isActive = true
                imageView.heightAnchor.constraint(equalToConstant: 120).isActive = true
                
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageTapped(_:)))
                imageView.addGestureRecognizer(tapGesture)
                
                let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(imageLongPressed(_:)))
                imageView.addGestureRecognizer(longPressGesture)
                
                imageView.image = image
                imageContainer.addArrangedSubview(imageView)
                imageViews.append(imageView)
            }
            
            contentStackView.addArrangedSubview(imageContainer)
        }
        
        if let text = message.content, !text.isEmpty {
            let label = UILabel()
            label.numberOfLines = 0
            label.font = .systemFont(ofSize: 16)
            label.textColor = .label
            label.text = text
            contentStackView.addArrangedSubview(label)
        }
    }
    
    @objc private func imageTapped(_ gesture: UITapGestureRecognizer) {
        guard let imageView = gesture.view else { return }
        delegate?.assistantMessageCell(self, didTapImageAt: imageView.tag)
    }
    
    @objc private func imageLongPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let imageView = gesture.view else { return }
        delegate?.assistantMessageCell(self, didLongPressImageAt: imageView.tag)
    }
}

class LoadingMessageCell: UITableViewCell {
    static let identifier = "LoadingMessageCell"
    
    private let bubbleView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 18
        return view
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = false
        return indicator
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubbleView.widthAnchor.constraint(equalToConstant: 60),
            bubbleView.heightAnchor.constraint(equalToConstant: 36),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: bubbleView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: bubbleView.centerYAnchor)
        ])
    }
    
    func startAnimating() {
        loadingIndicator.startAnimating()
    }
}

// MARK: - Delegate Protocol

protocol AssistantMessageCellDelegate: AnyObject {
    func assistantMessageCell(_ cell: AssistantMessageCell, didTapImageAt index: Int)
    func assistantMessageCell(_ cell: AssistantMessageCell, didLongPressImageAt index: Int)
}