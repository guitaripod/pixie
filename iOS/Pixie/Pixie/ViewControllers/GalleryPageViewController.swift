import UIKit
import UniformTypeIdentifiers

final class GalleryPageViewController: UIViewController {
    
    weak var delegate: GalleryPageViewControllerDelegate?
    
    private var images: [ImageMetadata] = []
    private var isLoading = false
    private var isRefreshing = false
    private var hasMore = true
    private var currentPage = 1
    private let pageSize = 20
    private var totalPagesLoaded = 0
    private var hiddenIDs: Set<String> = []
    private var selectedIDs: Set<String> = []
    private(set) var isSelecting = false
    
    private let collectionView: UICollectionView
    private let refreshControl = UIRefreshControl()
    private let emptyRefreshControl = UIRefreshControl()
    private let emptyScrollView = UIScrollView()
    private var showsSkeleton = false
    private var serverTotal: Int?
    private var isTitleHidden = true
    private var skeletonSize = CGSize.zero
    
    private var dataSource: UICollectionViewDiffableDataSource<Int, ImageMetadata>!
    
    /// What the grid shows: everything loaded except the images waiting out their undo window,
    /// each id once even if two pages overlap after the gallery changed between requests.
    private var displayedImages: [ImageMetadata] {
        var seen = Set<String>()
        return images.filter { !hiddenIDs.contains($0.id) && seen.insert($0.id).inserted }
    }
    
    var selectedImages: [ImageMetadata] {
        displayedImages.filter { selectedIDs.contains($0.id) }
    }
    
    init() {
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: Self.createLayout())
        
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
        setupDragAndDrop()
        loadInitialData()

        NotificationCenter.default.addObserver(self, selector: #selector(galleryNeedsRefresh), name: .galleryNeedsRefresh, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard showsSkeleton, view.bounds.size != skeletonSize else { return }
        updateSnapshot()
    }


    @objc private func galleryNeedsRefresh() {
        refresh()
    }

    
    private static func createLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { _, environment in
            let metrics = GalleryGrid.metrics(containerWidth: environment.container.effectiveContentSize.width, traits: environment.traitCollection)
            let fraction = 1.0 / CGFloat(metrics.columns)

            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(fraction),
                heightDimension: .fractionalWidth(fraction)
            ))
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalWidth(fraction)),
                subitem: item,
                count: metrics.columns
            )
            group.interItemSpacing = .fixed(metrics.spacing)

            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(96)),
                elementKind: GalleryHeaderView.kind,
                alignment: .top
            )

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = metrics.spacing
            section.boundarySupplementaryItems = [header]
            section.contentInsets = NSDirectionalEdgeInsets(
                top: 0,
                leading: metrics.insets.left,
                bottom: GalleryGrid.bottomInset,
                trailing: metrics.insets.right
            )
            return section
        }
    }
    
    private func setupUI() {
        view.backgroundColor = Theme.Color.canvas
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.accessibilityLabel = String(localized: "My Images")
        view.addSubview(collectionView)
        
        setupEmptyState()
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    /// The empty state sits in its own scroll view so a large text size scrolls instead of
    /// clipping, and the scroll view carries its own refresh control because it covers the grid.
    private func setupEmptyState() {
        emptyScrollView.translatesAutoresizingMaskIntoConstraints = false
        emptyScrollView.backgroundColor = Theme.Color.canvas
        emptyScrollView.alwaysBounceVertical = true
        emptyScrollView.isHidden = true
        emptyScrollView.refreshControl = emptyRefreshControl
        emptyRefreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        view.addSubview(emptyScrollView)
        
        let holder = UIView()
        holder.translatesAutoresizingMaskIntoConstraints = false
        emptyScrollView.addSubview(holder)
        
        let emptyStateView = StateView(
            symbol: "photo.on.rectangle.angled",
            title: String(localized: "No images yet"),
            message: String(localized: "Your generated images will appear here"),
            actionTitle: String(localized: "Create an image")
        ) { [weak self] in
            guard let self else { return }
            self.delegate?.galleryPageDidRequestCreate(self)
        }
        holder.addSubview(emptyStateView)
        
        let holderHeight = holder.heightAnchor.constraint(equalTo: emptyScrollView.frameLayoutGuide.heightAnchor)
        holderHeight.priority = .defaultLow
        
        NSLayoutConstraint.activate([
            emptyScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            emptyScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            holder.topAnchor.constraint(equalTo: emptyScrollView.contentLayoutGuide.topAnchor),
            holder.bottomAnchor.constraint(equalTo: emptyScrollView.contentLayoutGuide.bottomAnchor),
            holder.leadingAnchor.constraint(equalTo: emptyScrollView.contentLayoutGuide.leadingAnchor),
            holder.trailingAnchor.constraint(equalTo: emptyScrollView.contentLayoutGuide.trailingAnchor),
            holder.widthAnchor.constraint(equalTo: emptyScrollView.frameLayoutGuide.widthAnchor),
            holder.heightAnchor.constraint(greaterThanOrEqualTo: emptyScrollView.frameLayoutGuide.heightAnchor),
            holderHeight,
            
            emptyStateView.centerYAnchor.constraint(equalTo: holder.centerYAnchor),
            emptyStateView.topAnchor.constraint(greaterThanOrEqualTo: holder.topAnchor, constant: Theme.Space.xxl),
            emptyStateView.bottomAnchor.constraint(lessThanOrEqualTo: holder.bottomAnchor, constant: -Theme.Space.xxl),
            emptyStateView.leadingAnchor.constraint(equalTo: holder.safeAreaLayoutGuide.leadingAnchor, constant: Theme.Space.xxxl),
            emptyStateView.trailingAnchor.constraint(equalTo: holder.safeAreaLayoutGuide.trailingAnchor, constant: -Theme.Space.xxxl)
        ])
    }
    
    private func setupCollectionView() {
        collectionView.backgroundColor = Theme.Color.canvas
        collectionView.delegate = self
        collectionView.prefetchDataSource = self
        collectionView.register(GalleryImageCell.self, forCellWithReuseIdentifier: GalleryImageCell.identifier)
        collectionView.register(
            GalleryHeaderView.self,
            forSupplementaryViewOfKind: GalleryHeaderView.kind,
            withReuseIdentifier: GalleryHeaderView.identifier
        )
    }
    
    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Int, ImageMetadata>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, image in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: GalleryImageCell.identifier,
                for: indexPath
            ) as! GalleryImageCell
            if image.isSkeleton {
                cell.configurePlaceholder()
                return cell
            }
            cell.configure(with: image)
            cell.setSelection(mode: self?.isSelecting ?? false, marked: self?.selectedIDs.contains(image.id) ?? false)
            cell.onAction = { [weak self] action in
                guard let self else { return }
                self.delegate?.galleryPageDidPerformAction(self, action: action, on: image)
            }
            return cell
        }
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard kind == GalleryHeaderView.kind else { return nil }
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: GalleryHeaderView.identifier,
                for: indexPath
            ) as! GalleryHeaderView
            self?.configure(header: header)
            return header
        }
    }
    
    private func configure(header: GalleryHeaderView) {
        let metrics = GalleryGrid.metrics(containerWidth: collectionView.bounds.width, traits: traitCollection)
        let padding = metrics.insets.left == 0 ? Theme.screenMargin(for: traitCollection) : 0
        header.configure(count: showsSkeleton ? nil : headerCount, horizontalPadding: padding)
    }
    
    /// The number in the "N images" line: the server's total when it is known, less the images
    /// waiting out their undo window, and never fewer than the grid is showing.
    private var headerCount: Int {
        let shown = displayedImages.count
        guard let serverTotal else { return shown }
        return max(shown, serverTotal - hiddenIDs.count)
    }
    
    private func refreshHeader() {
        let header = collectionView.supplementaryView(forElementKind: GalleryHeaderView.kind, at: IndexPath(item: 0, section: 0))
        guard let header = header as? GalleryHeaderView else { return }
        configure(header: header)
        collectionView.collectionViewLayout.invalidateLayout()
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
        showsSkeleton = true
        collectionView.isScrollEnabled = false
        emptyScrollView.isHidden = true
        updateSnapshot()
        
        Task {
            do {
                let response = try await fetchImages(page: 1)
                await MainActor.run {
                    self.images = response.images
                    self.serverTotal = response.total
                    self.currentPage = 1
                    self.totalPagesLoaded = 1
                    self.hasMore = response.images.count == self.pageSize
                    self.isLoading = false
                    self.endSkeleton()
                    self.updateSnapshot()
                    self.updateEmptyState()
                    self.announceLoaded()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.endSkeleton()
                    self.updateSnapshot()
                    self.showError(error) { self.loadInitialData() }
                    self.updateEmptyState()
                }
            }
        }
    }
    
    func refresh() {
        guard !isLoading else {
            endRefreshing()
            return
        }
        
        isRefreshing = true
        currentPage = 1
        totalPagesLoaded = 0
        hasMore = true
        
        Task {
            do {
                let response = try await fetchImages(page: 1)
                await MainActor.run {
                    self.images = response.images
                    self.serverTotal = response.total
                    self.totalPagesLoaded = 1
                    self.hasMore = response.images.count == self.pageSize
                    self.isRefreshing = false
                    self.endRefreshing()
                    self.updateSnapshot()
                    self.updateEmptyState()
                    self.announceLoaded()
                }
            } catch {
                await MainActor.run {
                    self.isRefreshing = false
                    self.endRefreshing()
                    self.showError(error) { self.refresh() }
                }
            }
        }
    }
    
    private func endSkeleton() {
        showsSkeleton = false
        collectionView.isScrollEnabled = true
    }
    
    private func endRefreshing() {
        refreshControl.endRefreshing()
        emptyRefreshControl.endRefreshing()
    }
    
    private func loadMore() {
        guard !isLoading, hasMore else { return }
        
        isLoading = true
        let nextPage = currentPage + 1
        announce(String(localized: "Loading more images"))
        
        Task {
            do {
                let response = try await fetchImages(page: nextPage)
                await MainActor.run {
                    self.images.append(contentsOf: response.images)
                    self.serverTotal = response.total
                    self.currentPage = nextPage
                    self.totalPagesLoaded += 1
                    self.hasMore = response.images.count == self.pageSize
                    self.isLoading = false
                    self.updateSnapshot()
                    if !response.images.isEmpty {
                        self.announce(String(localized: "\(response.images.count) more images"))
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.showError(error) { self.loadMore() }
                }
            }
        }
    }
    
    private func announceLoaded() {
        let count = displayedImages.count
        if count > 0 {
            announce(String(localized: "\(count) images"))
        }
    }
    
    private func announce(_ text: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        Announce.say(text)
    }
    
    private func fetchImages(page: Int) async throws -> GalleryResponse {
        #if DEBUG
        if DemoMode.isActive {
            let images = page == 1 ? DemoContent.mockMetadata() : []
            return GalleryResponse(images: images, total: images.count, page: page, perPage: pageSize)
        }
        #endif

        guard let apiKey = ConfigurationManager.shared.apiKey, !apiKey.isEmpty else {
            print("No API key available")
            throw URLError(.userAuthenticationRequired)
        }
        
        guard let userId = AuthenticationManager.shared.currentUser?.id else {
            throw URLError(.userAuthenticationRequired)
        }
        let urlString = "\(APIService.shared.baseURL)/v1/images/user/\(userId)?page=\(page)&per_page=\(pageSize)"
        let cacheKey = "personal_\(userId)_page_\(page)"
        
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
        
        let decoder = JSONDecoder()
        do {
            let response = try decoder.decode(GalleryResponse.self, from: data)
            GalleryCache.shared.setResponse(response, for: cacheKey)
            return response
        } catch {
            throw error
        }
    }
    
    /// Takes images off the grid at once while keeping them in the list, so putting them
    /// back lands each one exactly where it was.
    func hide(ids: Set<String>) {
        hiddenIDs.formUnion(ids)
        selectedIDs.subtract(ids)
        updateSnapshot()
        updateEmptyState()
        notifySelectionChanged()
    }
    
    func unhide(ids: Set<String>) {
        hiddenIDs.subtract(ids)
        updateSnapshot()
        updateEmptyState()
    }
    
    /// Forgets images the server has deleted for good.
    func purge(ids: Set<String>) {
        let removed = images.filter { ids.contains($0.id) }.count
        images.removeAll { ids.contains($0.id) }
        serverTotal = serverTotal.map { max(0, $0 - removed) }
        hiddenIDs.subtract(ids)
        selectedIDs.subtract(ids)
        updateSnapshot()
        updateEmptyState()
    }
    
    func setSelecting(_ selecting: Bool) {
        guard selecting != isSelecting else { return }
        isSelecting = selecting
        selectedIDs.removeAll()
        collectionView.dragInteractionEnabled = !selecting
        refreshVisibleSelectionState()
        notifySelectionChanged()
    }
    
    private func refreshVisibleSelectionState() {
        for case let cell as GalleryImageCell in collectionView.visibleCells {
            guard let indexPath = collectionView.indexPath(for: cell),
                  let image = dataSource.itemIdentifier(for: indexPath) else { continue }
            cell.setSelection(mode: isSelecting, marked: selectedIDs.contains(image.id))
        }
    }
    
    private func notifySelectionChanged() {
        delegate?.galleryPageDidChangeSelection(self, count: selectedIDs.count)
    }

    private func updateSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Int, ImageMetadata>()
        snapshot.appendSections([0])
        snapshot.appendItems(showsSkeleton ? skeletonItems : displayedImages, toSection: 0)
        dataSource.apply(snapshot, animatingDifferences: !Motion.isReduced && !showsSkeleton) { [weak self] in
            self?.refreshHeader()
        }
        refreshHeader()
    }
    
    /// Enough loading squares to fill the screen, in the same grid the real thumbnails will use.
    private var skeletonItems: [ImageMetadata] {
        skeletonSize = view.bounds.size
        let width = max(collectionView.bounds.width, 1)
        let metrics = GalleryGrid.metrics(containerWidth: width, traits: traitCollection)
        let side = (width - metrics.insets.left - metrics.insets.right) / CGFloat(metrics.columns)
        let rows = Int(ceil(max(collectionView.bounds.height, view.bounds.height, 1) / max(side, 1)))
        return (0..<(rows * metrics.columns)).map { ImageMetadata.skeleton(index: $0) }
    }
    
    private func updateEmptyState() {
        let isEmpty = displayedImages.isEmpty
        emptyScrollView.isHidden = !isEmpty || isLoading
        if !emptyScrollView.isHidden {
            view.bringSubviewToFront(emptyScrollView)
        }
        notifyHeaderVisibility()
        delegate?.galleryPageDidChangeContent(self, hasImages: !isEmpty)
    }
    
    /// The navigation bar shows its own "Gallery" once the big title has scrolled away, and
    /// always when the empty state has replaced the grid and its title.
    private func notifyHeaderVisibility() {
        let scrolled = showsSkeleton ? 0 : collectionView.contentOffset.y + collectionView.adjustedContentInset.top
        let hidden = emptyScrollView.isHidden && scrolled < GalleryGrid.titleScrollThreshold
        guard hidden != isTitleHidden else { return }
        isTitleHidden = hidden
        delegate?.galleryPageDidChangeHeaderVisibility(self, isTitleHidden: hidden)
    }
    
    private func showError(_ error: Error, retry: @escaping () -> Void) {
        let alert = UIAlertController(
            title: String(localized: "Error"),
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "Retry"), style: .default) { _ in retry() })
        alert.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel))
        present(alert, animated: true)
    }
}

extension GalleryPageViewController: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === collectionView else { return }
        notifyHeaderVisibility()
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.section == 0, let image = dataSource.itemIdentifier(for: indexPath), !image.isSkeleton else { return }
        collectionView.deselectItem(at: indexPath, animated: false)
        
        if isSelecting {
            toggleSelection(of: image, at: indexPath)
            return
        }
        
        HapticsManager.shared.impact(.light)
        delegate?.galleryPageDidSelectImage(self, image: image)
    }
    
    private func toggleSelection(of image: ImageMetadata, at indexPath: IndexPath) {
        if selectedIDs.contains(image.id) {
            selectedIDs.remove(image.id)
        } else {
            selectedIDs.insert(image.id)
        }
        HapticsManager.shared.selection()
        if let cell = collectionView.cellForItem(at: indexPath) as? GalleryImageCell {
            cell.setSelection(mode: true, marked: selectedIDs.contains(image.id))
            Announce.layoutChanged(cell)
        }
        notifySelectionChanged()
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard indexPath.section == 0, !showsSkeleton else { return }
        
        if indexPath.item >= displayedImages.count - 5 && !isLoading && hasMore {
            loadMore()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPath.section == 0, !isSelecting, let image = dataSource.itemIdentifier(for: indexPath), !image.isSkeleton else { return nil }
        
        return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: {
            return self.makePreviewViewController(for: image)
        }) { _ in
            return self.makeContextMenu(for: image)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let indexPath = configuration.identifier as? IndexPath,
              let image = dataSource.itemIdentifier(for: indexPath) else { return }
        
        animator.addCompletion {
            self.delegate?.galleryPageDidSelectImage(self, image: image)
        }
    }
    
    private func makePreviewViewController(for image: ImageMetadata) -> UIViewController? {
        let previewVC = UIViewController()
        previewVC.view.backgroundColor = Theme.Color.canvas
        
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
        
        let maxWidth: CGFloat = view.bounds.width - 40
        let maxHeight: CGFloat = view.bounds.height * 0.7
        
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
        let viewDetails = UIAction(title: String(localized: "View Details"), image: UIImage(systemName: "info.circle")) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.galleryPageDidSelectImage(self, image: image)
        }
        
        let useForEdit = UIAction(title: String(localized: "Use for Edit"), image: UIImage(systemName: "pencil")) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.galleryPageDidPerformAction(self, action: .useForEdit, on: image)
        }
        
        let copyPrompt = UIAction(title: String(localized: "Copy Prompt"), image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.galleryPageDidPerformAction(self, action: .copyPrompt, on: image)
        }
        
        let save = UIAction(title: String(localized: "Save to Photos"), image: UIImage(systemName: "square.and.arrow.down")) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.galleryPageDidPerformAction(self, action: .download, on: image)
        }
        
        let share = UIAction(title: String(localized: "Share"), image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.galleryPageDidPerformAction(self, action: .share, on: image)
        }

        let delete = UIAction(title: String(localized: "Delete"), image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.galleryPageDidPerformAction(self, action: .delete, on: image)
        }

        return UIMenu(title: "", children: [viewDetails, useForEdit, copyPrompt, save, share, UIMenu(options: .displayInline, children: [delete])])
    }

}

extension GalleryPageViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let urls = indexPaths.compactMap { indexPath -> String? in
            guard let image = dataSource.itemIdentifier(for: indexPath), !image.isSkeleton else { return nil }
            return image.thumbnailUrl ?? image.url
        }
        
        ImageCache.shared.prefetchImages(for: urls)
        
        if let lastIndexPath = indexPaths.last,
           lastIndexPath.item >= displayedImages.count - 5,
           !isLoading && hasMore {
            loadMore()
        }
    }
    
    private func setupDragAndDrop() {
        collectionView.dragDelegate = self
        collectionView.dragInteractionEnabled = true
    }
}

extension GalleryPageViewController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard !isSelecting, let image = dataSource.itemIdentifier(for: indexPath), !image.isSkeleton else { return [] }
        
        let itemProvider = NSItemProvider()
        
        itemProvider.registerDataRepresentation(forTypeIdentifier: UTType.plainText.identifier, visibility: .all) { completion in
            let data = image.prompt.data(using: .utf8) ?? Data()
            completion(data, nil)
            return nil
        }
        
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = image
        return [dragItem]
    }
}


enum GalleryGrid {
    struct Metrics {
        let columns: Int
        let spacing: CGFloat
        let insets: UIEdgeInsets
    }

    static let narrowWidth: CGFloat = 480
    static let bottomInset: CGFloat = 96
    static let titleScrollThreshold: CGFloat = 40

    static func metrics(containerWidth: CGFloat, traits: UITraitCollection) -> Metrics {
        let layout = AdaptiveLayout(traitCollection: traits)
        let insets = containerWidth < narrowWidth ? UIEdgeInsets.zero : layout.contentInsets
        let columns = layout.galleryColumns(containerWidth: containerWidth - insets.left - insets.right)
        return Metrics(columns: columns, spacing: 1, insets: insets)
    }
}

private extension ImageMetadata {
    static let skeletonPrefix = "skeleton-"

    var isSkeleton: Bool { id.hasPrefix(Self.skeletonPrefix) }

    static func skeleton(index: Int) -> ImageMetadata {
        ImageMetadata(id: "\(skeletonPrefix)\(index)", url: "", prompt: "", createdAt: "", userId: "", thumbnailUrl: nil, metadata: nil, tags: nil)
    }
}
