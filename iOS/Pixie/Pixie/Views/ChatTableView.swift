import UIKit
import Photos

class ChatTableView: UIView {
    enum Section: Int, CaseIterable {
        case messages
    }
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
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupDataSource()
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
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
    func setMessages(_ messages: [ChatMessage], animated: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, ChatMessage>()
        snapshot.appendSections([.messages])
        snapshot.appendItems(messages, toSection: .messages)
        dataSource.apply(snapshot, animatingDifferences: animated) { [weak self] in
            if !messages.isEmpty {
                self?.scrollToBottom(animated: animated)
            }
        }
    }
    func addMessage(_ message: ChatMessage, animated: Bool = true) {
        var snapshot = dataSource.snapshot()
        if !snapshot.sectionIdentifiers.contains(.messages) {
            snapshot.appendSections([.messages])
        }
        snapshot.appendItems([message], toSection: .messages)
        dataSource.apply(snapshot, animatingDifferences: animated) { [weak self] in
            self?.scrollToBottom(animated: animated)
        }
    }
    func scrollToBottom(animated: Bool = true) {
        guard let lastSection = dataSource.snapshot().sectionIdentifiers.last,
              let lastItem = dataSource.snapshot().itemIdentifiers(inSection: lastSection).last,
              let indexPath = dataSource.indexPath(for: lastItem) else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let contentHeight = self.tableView.contentSize.height
            let frameHeight = self.tableView.frame.height
            let contentInsetBottom = self.tableView.contentInset.bottom
            
            if contentHeight > frameHeight - contentInsetBottom {
                self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
            }
        }
    }
    func adjustForKeyboard(height: CGFloat, duration: TimeInterval) {
        let adjustedHeight = height > 0 ? height - 20 : 0
        tableView.contentInset.bottom = adjustedHeight + 100
        tableView.verticalScrollIndicatorInsets.bottom = adjustedHeight + 80
        if height > 0 {
            scrollToBottom(animated: true)
        }
    }
    
    func setHorizontalContentInsets(left: CGFloat, right: CGFloat) {
        // Apply padding to content but keep scroll indicators at edges
        tableView.contentInset.left = left
        tableView.contentInset.right = right
        // Don't indent scroll indicators
        tableView.scrollIndicatorInsets.left = 0
        tableView.scrollIndicatorInsets.right = 0
    }
    
    var contentInset: UIEdgeInsets {
        get { tableView.contentInset }
        set { 
            tableView.contentInset = newValue
            // Keep vertical scroll indicator insets but reset horizontal
            tableView.scrollIndicatorInsets = UIEdgeInsets(top: tableView.scrollIndicatorInsets.top,
                                                           left: 0,
                                                           bottom: tableView.scrollIndicatorInsets.bottom,
                                                           right: 0)
        }
    }
    
    var scrollIndicatorInsets: UIEdgeInsets {
        get { tableView.scrollIndicatorInsets }
        set { tableView.scrollIndicatorInsets = newValue }
    }
}



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
    func assistantMessageCell(_ cell: AssistantMessageCell, didSelectImageForEdit index: Int) {
        guard let indexPath = tableView.indexPath(for: cell),
              let message = dataSource.itemIdentifier(for: indexPath) else { return }
        delegate?.chatTableView(self, didSelectImageForEdit: index, in: message)
    }
}



protocol ChatTableViewDelegate: AnyObject {
    func chatTableView(_ chatTableView: ChatTableView, didTapImageAt index: Int, in message: ChatMessage)
    func chatTableView(_ chatTableView: ChatTableView, didLongPressImageAt index: Int, in message: ChatMessage)
    func chatTableView(_ chatTableView: ChatTableView, didSelectImageForEdit index: Int, in message: ChatMessage)
}



class UserMessageCell: UITableViewCell {
    static let identifier = "UserMessageCell"
    private let bubbleView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 103/255, green: 80/255, blue: 164/255, alpha: 1)
        view.layer.cornerRadius = 18
        return view
    }()
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .white
        return label
    }()
    private let metadataStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 3
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    private let editImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true
        return imageView
    }()
    private var editImageBottomConstraint: NSLayoutConstraint!
    private var metadataBottomConstraint: NSLayoutConstraint!
    
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
        bubbleView.addSubview(metadataStackView)
        bubbleView.addSubview(editImageView)
        
        metadataBottomConstraint = metadataStackView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12)
        editImageBottomConstraint = editImageView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12)
        
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 60),
            
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            
            metadataStackView.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 8),
            metadataStackView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            metadataStackView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -16),
            
            editImageView.topAnchor.constraint(equalTo: metadataStackView.bottomAnchor, constant: 8),
            editImageView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 16),
            editImageView.widthAnchor.constraint(equalToConstant: 60),
            editImageView.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        messageLabel.text = nil
        metadataStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        editImageView.image = nil
        editImageView.isHidden = true
    }
    
    func configure(with message: ChatMessage) {
        messageLabel.text = message.content
        
        metadataStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        metadataBottomConstraint.isActive = false
        editImageBottomConstraint.isActive = false
        
        if let metadata = message.metadata {
            let titleLabel = createMetadataLabel(text: metadata.isEditMode ? "✏️ Edit Request" : "🎨 Generation Request", isBold: true)
            metadataStackView.addArrangedSubview(titleLabel)
            
            let divider = UIView()
            divider.backgroundColor = UIColor.white.withAlphaComponent(0.3)
            divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
            metadataStackView.addArrangedSubview(divider)
            
            addMetadataRow("Quality", value: metadata.quality?.uppercased() ?? "")
            
            if let sizeDisplay = metadata.sizeDisplay {
                addMetadataRow("Size", value: sizeDisplay)
            }
            
            if let background = metadata.background {
                addMetadataRow("Background", value: background)
            }
            
            if let format = metadata.format {
                addMetadataRow("Format", value: format)
                if let compression = metadata.compression {
                    addMetadataRow("Compress", value: "\(compression)%")
                }
            }
            
            if let moderation = metadata.moderation {
                addMetadataRow("Moderation", value: moderation)
            }
        }
        
        if let editImage = message.editingImage {
            editImageView.image = editImage
            editImageView.isHidden = false
            editImageBottomConstraint.isActive = true
        } else {
            editImageView.isHidden = true
            metadataBottomConstraint.isActive = true
        }
    }
    
    private func createMetadataLabel(text: String, isBold: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = .systemFont(ofSize: 11, weight: isBold ? .semibold : .regular)
        return label
    }
    
    private func addMetadataRow(_ label: String, value: String) {
        let rowStack = UIStackView()
        rowStack.axis = .horizontal
        rowStack.distribution = .equalSpacing
        
        let labelView = createMetadataLabel(text: label)
        labelView.textColor = UIColor.white.withAlphaComponent(0.7)
        labelView.font = .systemFont(ofSize: 10, weight: .regular)
        
        let valueView = createMetadataLabel(text: value)
        valueView.textColor = .white
        valueView.font = .systemFont(ofSize: 10, weight: .medium)
        
        rowStack.addArrangedSubview(labelView)
        rowStack.addArrangedSubview(valueView)
        
        metadataStackView.addArrangedSubview(rowStack)
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
            bubbleView.backgroundColor = .clear
            let imageContainer = UIStackView()
            imageContainer.axis = .horizontal
            imageContainer.spacing = 8
            imageContainer.distribution = .fill
            imageContainer.alignment = .center
            for (index, image) in images.enumerated() {
                let imageView = UIImageView()
                imageView.contentMode = .scaleAspectFit
                imageView.clipsToBounds = true
                imageView.layer.cornerRadius = 12
                imageView.backgroundColor = .tertiarySystemBackground
                imageView.isUserInteractionEnabled = true
                imageView.tag = index
                let widthConstraint = imageView.widthAnchor.constraint(equalToConstant: 240)
                widthConstraint.isActive = true
                let aspectRatio = image.size.height / image.size.width
                let heightConstraint = imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: aspectRatio)
                heightConstraint.isActive = true
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageTapped(_:)))
                imageView.addGestureRecognizer(tapGesture)
                if #available(iOS 13.0, *) {
                    let interaction = UIContextMenuInteraction(delegate: self)
                    imageView.addInteraction(interaction)
                }
                imageView.image = image
                imageContainer.addArrangedSubview(imageView)
                imageViews.append(imageView)
            }
            contentStackView.addArrangedSubview(imageContainer)
        } else if let text = message.content, !text.isEmpty {
            bubbleView.backgroundColor = .secondarySystemBackground
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

@available(iOS 13.0, *)
extension AssistantMessageCell: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        guard let imageView = interaction.view as? UIImageView,
              let image = imageView.image else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: {
            let previewController = UIViewController()
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            previewController.view.addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: previewController.view.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: previewController.view.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: previewController.view.trailingAnchor),
                imageView.bottomAnchor.constraint(equalTo: previewController.view.bottomAnchor)
            ])
            previewController.preferredContentSize = image.size
            return previewController
        }) { _ in
            let save = UIAction(title: "Save to Photos", image: UIImage(systemName: "square.and.arrow.down")) { _ in
                PhotoSavingService.shared.saveImage(image) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            HapticManager.shared.impact(.success)
                        case .failure:
                            HapticManager.shared.impact(.error)
                        }
                    }
                }
            }
            let share = UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                guard let self = self,
                      let viewController = self.window?.rootViewController else { return }
                ImageSharingService.shared.shareImage(
                    image,
                    from: viewController,
                    sourceView: imageView
                )
            }
            let copy = UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.image = image
                HapticManager.shared.impact(.success)
            }
            let edit = UIAction(title: "Edit Image", image: UIImage(systemName: "wand.and.stars")) { [weak self] _ in
                guard let self = self else { return }
                self.delegate?.assistantMessageCell(self, didSelectImageForEdit: imageView.tag)
            }
            return UIMenu(title: "", children: [edit, save, share, copy])
        }
    }
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let imageView = interaction.view as? UIImageView else { return }
        animator.addCompletion {
            self.delegate?.assistantMessageCell(self, didTapImageAt: imageView.tag)
        }
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



protocol AssistantMessageCellDelegate: AnyObject {
    func assistantMessageCell(_ cell: AssistantMessageCell, didTapImageAt index: Int)
    func assistantMessageCell(_ cell: AssistantMessageCell, didLongPressImageAt index: Int)
    func assistantMessageCell(_ cell: AssistantMessageCell, didSelectImageForEdit index: Int)
}