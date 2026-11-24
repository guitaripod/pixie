import UIKit

protocol ImageCacheProtocol {
    func image(for key: String) -> UIImage?
    func setImage(_ image: UIImage, for key: String)
    func removeImage(for key: String)
    func removeAllImages()
    func prefetchImages(for urls: [String])
}

class ImageCache: ImageCacheProtocol {
    static let shared = ImageCache(networkService: AppContainer.shared.networkService)
    
    private let cache = NSCache<NSString, UIImage>()
    private let ioQueue = DispatchQueue(label: "com.guitaripod.pixie.imagecache", attributes: .concurrent)
    private let networkService: NetworkServiceProtocol
    
    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
        setupCache()
    }
    
    private func setupCache() {
        cache.countLimit = 1000
        cache.totalCostLimit = 1024 * 1024 * 1024
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }
    
    func setImage(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    func removeImage(for key: String) {
        cache.removeObject(forKey: key as NSString)
    }
    
    func removeAllImages() {
        cache.removeAllObjects()
    }
    
    @objc private func clearCache() {
        cache.removeAllObjects()
    }
    
    func prefetchImages(for urls: [String]) {
        for urlString in urls {
            Task {
                await loadImage(from: urlString)
            }
        }
    }

    /// Warms the grid-sized copies the gallery cells ask for, so a page of thumbnails arrives
    /// already decoded at cell size.
    func prefetchThumbnails(for urls: [String], maxPixelSize: Int) {
        for urlString in urls {
            Task {
                await thumbnail(for: urlString, maxPixelSize: maxPixelSize)
            }
        }
    }

    /// A copy decoded straight to `maxPixelSize`, so a multi-megapixel image never becomes a
    /// bitmap for a 120pt cell; the full-resolution image stays for the detail screen.
    func thumbnail(for urlString: String, maxPixelSize: Int) async -> UIImage? {
        let key = "\(urlString)#\(maxPixelSize)"
        if let cached = image(for: key) {
            return cached
        }
        if let full = image(for: urlString) {
            let side = CGFloat(maxPixelSize)
            guard let scaled = await full.byPreparingThumbnail(ofSize: CGSize(width: side, height: side)) else {
                return full
            }
            setImage(scaled, for: key)
            return scaled
        }

        guard let url = URL(string: urlString) else { return nil }

        do {
            let data = try await networkService.downloadData(from: url)
            guard let image = await Self.gridSized(data, maxPixelSize: maxPixelSize) else { return nil }
            setImage(image, for: key)
            return image
        } catch {
            return nil
        }
    }

    /// Decodes away from the main thread, so the first draw of a cell is a blit of a bitmap that
    /// is already the size of the cell.
    private static func gridSized(_ data: Data, maxPixelSize: Int) async -> UIImage? {
        await Task.detached(priority: .utility) {
            guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
            ]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            return UIImage(cgImage: image)
        }.value
    }
    
    @discardableResult
    func loadImage(from urlString: String) async -> UIImage? {
        if let cachedImage = image(for: urlString) {
            return cachedImage
        }
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let data = try await networkService.downloadData(from: url)
            guard let image = UIImage(data: data) else { return nil }
            
            setImage(image, for: urlString)
            return image
        } catch {
            return nil
        }
    }
}

extension UIImageView {
    func setImage(from urlString: String, placeholder: UIImage? = nil) {
        self.image = placeholder
        
        Task { @MainActor in
            if let image = await ImageCache.shared.loadImage(from: urlString) {
                self.image = image
            }
        }
    }
}