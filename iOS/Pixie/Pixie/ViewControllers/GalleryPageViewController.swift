import UIKit

final class GalleryPageViewController: UIViewController {
    
    weak var delegate: GalleryPageViewControllerDelegate?
    
    private let type: GalleryType
    private var images: [ImageMetadata] = []
    private var isLoading = false
    private var isRefreshing = false
    private var hasMore = true
    private var currentPage = 1
    private let pageSize = 20
    private var totalPagesLoaded = 0
    private let maxImagesLimit = 100
    
    private let collectionView: UICollectionView
    private let refreshControl = UIRefreshControl()
    private let emptyStateView = EmptyStateView()
    private let loadingView = UIActivityIndicatorView(style: .large)
    
    private var dataSource: UICollectionViewDiffableDataSource<Int, ImageMetadata>!
    
    init(type: GalleryType) {
        self.type = type
        
        let layout = Self.createLayout()
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
        setupDataSource()
        setupRefreshControl()
        loadInitialData()
    }
    
    private static func createLayout() -> UICollectionViewLayout {
        let spacing: CGFloat = 0.5
        let columns: CGFloat = 3
        
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: spacing, leading: spacing, bottom: spacing, trailing: spacing)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(1.0 / columns)
        )
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitem: item,
            count: Int(columns)
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 80, trailing: 0)
        
        let layout = UICollectionViewCompositionalLayout(section: section)
        
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = 0
        layout.configuration = config
        
        return layout
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.hidesWhenStopped = true
        view.addSubview(loadingView)
        
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
        
        emptyStateView.configure(for: type) { [weak self] in
            self?.delegate?.galleryPageDidTapGenerate(self!)
        }
    }
    
    private func setupCollectionView() {
        collectionView.backgroundColor = .white
        collectionView.delegate = self
        collectionView.prefetchDataSource = self
        collectionView.register(GalleryImageCell.self, forCellWithReuseIdentifier: GalleryImageCell.identifier)
    }
    
    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Int, ImageMetadata>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, image in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: GalleryImageCell.identifier,
                for: indexPath
            ) as! GalleryImageCell
            cell.configure(with: image)
            return cell
        }
    }
    
    private func setupRefreshControl() {
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }
    
    @objc private func handleRefresh() {
        HapticsManager.shared.impact(.medium)
        refresh()
    }
    
    private func loadInitialData() {
        guard !isLoading else { return }
        isLoading = true
        loadingView.startAnimating()
        emptyStateView.isHidden = true
        
        Task {
            do {
                let response = try await fetchImages(page: 1)
                await MainActor.run {
                    self.images = response.images
                    self.currentPage = 1
                    self.totalPagesLoaded = 1
                    self.hasMore = response.images.count == self.pageSize
                    self.isLoading = false
                    self.loadingView.stopAnimating()
                    self.updateSnapshot()
                    self.updateEmptyState()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.loadingView.stopAnimating()
                    self.showError(error)
                    self.updateEmptyState()
                }
            }
        }
    }
    
    func refresh() {
        guard !isLoading else { return }
        
        isRefreshing = true
        currentPage = 1
        totalPagesLoaded = 0
        hasMore = true
        
        Task {
            do {
                let response = try await fetchImages(page: 1)
                await MainActor.run {
                    self.images = response.images
                    self.totalPagesLoaded = 1
                    self.hasMore = response.images.count == self.pageSize
                    self.isRefreshing = false
                    self.refreshControl.endRefreshing()
                    self.updateSnapshot()
                    self.updateEmptyState()
                }
            } catch {
                await MainActor.run {
                    self.isRefreshing = false
                    self.refreshControl.endRefreshing()
                    self.showError(error)
                }
            }
        }
    }
    
    private func loadMore() {
        guard !isLoading, hasMore else { return }
        
        if type == .explore && images.count >= maxImagesLimit {
            hasMore = false
            updateSnapshot()
            return
        }
        
        isLoading = true
        let nextPage = currentPage + 1
        
        Task {
            do {
                let response = try await fetchImages(page: nextPage)
                await MainActor.run {
                    self.images.append(contentsOf: response.images)
                    self.currentPage = nextPage
                    self.totalPagesLoaded += 1
                    self.hasMore = response.images.count == self.pageSize
                    self.isLoading = false
                    self.updateSnapshot()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.showError(error)
                }
            }
        }
    }
    
    private func fetchImages(page: Int) async throws -> GalleryResponse {
        guard let apiKey = ConfigurationManager.shared.apiKey, !apiKey.isEmpty else {
            print("No API key available")
            throw URLError(.userAuthenticationRequired)
        }
        
        let urlString: String
        let cacheKey: String
        if type == .personal {
            guard let userId = AuthenticationManager.shared.currentUser?.id else {
                throw URLError(.userAuthenticationRequired)
            }
            urlString = "\(APIService.shared.baseURL)/v1/images/user/\(userId)?page=\(page)&per_page=\(pageSize)"
            cacheKey = "personal_\(userId)_page_\(page)"
        } else {
            urlString = "\(APIService.shared.baseURL)/v1/images?page=\(page)&per_page=\(pageSize)"
            cacheKey = "public_page_\(page)"
        }
        
        if !isRefreshing, let cachedResponse = GalleryCache.shared.getResponse(for: cacheKey) {
            return cachedResponse
        }
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("API Error [\(httpResponse.statusCode)]: \(errorMessage)")
            
            if httpResponse.statusCode == 401 {
                throw URLError(.userAuthenticationRequired)
            } else if httpResponse.statusCode == 404 {
                return GalleryResponse(images: [], total: 0, page: page, perPage: pageSize)
            } else {
                throw URLError(.badServerResponse)
            }
        }
        
        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Gallery API Response: \(jsonString)")
        }
        #endif
        
        let decoder = JSONDecoder()
        do {
            let response = try decoder.decode(GalleryResponse.self, from: data)
            GalleryCache.shared.setResponse(response, for: cacheKey)
            return response
        } catch {
            print("Decoding error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .dataCorrupted(let context):
                    print("Data corrupted: \(context)")
                case .keyNotFound(let key, let context):
                    print("Key '\(key)' not found: \(context)")
                case .typeMismatch(let type, let context):
                    print("Type mismatch for type \(type): \(context)")
                case .valueNotFound(let type, let context):
                    print("Value not found for type \(type): \(context)")
                @unknown default:
                    print("Unknown decoding error")
                }
            }
            throw error
        }
    }
    
    private func updateSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Int, ImageMetadata>()
        snapshot.appendSections([0])
        snapshot.appendItems(images, toSection: 0)
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    private func updateEmptyState() {
        emptyStateView.isHidden = !images.isEmpty || isLoading
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Retry", style: .default) { [weak self] _ in
            self?.loadInitialData()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

extension GalleryPageViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.section == 0 else { return }
        HapticsManager.shared.impact(.light)
        let image = images[indexPath.item]
        delegate?.galleryPageDidSelectImage(self, image: image)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard indexPath.section == 0 else { return }
        
        if indexPath.item >= images.count - 5 && !isLoading && hasMore {
            loadMore()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPath.section == 0 else { return nil }
        let image = images[indexPath.item]
        
        return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: {
            return self.makePreviewViewController(for: image)
        }) { _ in
            return self.makeContextMenu(for: image)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let indexPath = configuration.identifier as? IndexPath else { return }
        let image = images[indexPath.item]
        
        animator.addCompletion {
            self.delegate?.galleryPageDidSelectImage(self, image: image)
        }
    }
    
    private func makePreviewViewController(for image: ImageMetadata) -> UIViewController? {
        let previewVC = UIViewController()
        previewVC.view.backgroundColor = .systemBackground
        
        let containerView = UIView()
        containerView.backgroundColor = .black
        containerView.translatesAutoresizingMaskIntoConstraints = false
        previewVC.view.addSubview(containerView)
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black
        imageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: previewVC.view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: previewVC.view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: previewVC.view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: previewVC.view.bottomAnchor),
            
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        let maxWidth: CGFloat = UIScreen.main.bounds.width - 40
        let maxHeight: CGFloat = UIScreen.main.bounds.height * 0.7
        
        if let cachedImage = ImageCache.shared.image(for: image.url) {
            imageView.image = cachedImage
            let aspectRatio = cachedImage.size.width / cachedImage.size.height
            var width = min(maxWidth, cachedImage.size.width)
            var height = width / aspectRatio
            
            if height > maxHeight {
                height = maxHeight
                width = height * aspectRatio
            }
            
            previewVC.preferredContentSize = CGSize(width: width, height: height)
        } else {
            previewVC.preferredContentSize = CGSize(width: 300, height: 400)
            
            if let url = URL(string: image.url) {
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    if let data = data, let loadedImage = UIImage(data: data) {
                        ImageCache.shared.setImage(loadedImage, for: image.url)
                        
                        DispatchQueue.main.async {
                            imageView.image = loadedImage
                            let aspectRatio = loadedImage.size.width / loadedImage.size.height
                            var width = min(maxWidth, loadedImage.size.width)
                            var height = width / aspectRatio
                            
                            if height > maxHeight {
                                height = maxHeight
                                width = height * aspectRatio
                            }
                            
                            previewVC.preferredContentSize = CGSize(width: width, height: height)
                        }
                    }
                }.resume()
            }
        }
        
        return previewVC
    }
    
    private func makeContextMenu(for image: ImageMetadata) -> UIMenu {
        let viewDetails = UIAction(title: "View Details", image: UIImage(systemName: "info.circle")) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.galleryPageDidSelectImage(self, image: image)
        }
        
        let useForEdit = UIAction(title: "Use for Edit", image: UIImage(systemName: "pencil")) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.galleryPageDidPerformAction(self, action: .useForEdit, on: image)
        }
        
        let copyPrompt = UIAction(title: "Copy Prompt", image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.galleryPageDidPerformAction(self, action: .copyPrompt, on: image)
        }
        
        let save = UIAction(title: "Save to Photos", image: UIImage(systemName: "square.and.arrow.down")) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.galleryPageDidPerformAction(self, action: .download, on: image)
        }
        
        let share = UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.galleryPageDidPerformAction(self, action: .share, on: image)
        }
        
        return UIMenu(title: "", children: [viewDetails, useForEdit, copyPrompt, save, share])
    }
}

extension GalleryPageViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let urls = indexPaths.compactMap { indexPath -> String? in
            guard indexPath.item < images.count else { return nil }
            let image = images[indexPath.item]
            return image.thumbnailUrl ?? image.url
        }
        
        ImageCache.shared.prefetchImages(for: urls)
        
        if let lastIndexPath = indexPaths.last,
           lastIndexPath.item >= images.count - 5,
           !isLoading && hasMore {
            loadMore()
        }
    }
}

