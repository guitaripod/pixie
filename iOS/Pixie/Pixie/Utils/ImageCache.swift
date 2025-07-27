import UIKit

protocol ImageCacheProtocol {
    func image(for key: String) -> UIImage?
    func setImage(_ image: UIImage, for key: String)
    func removeImage(for key: String)
    func removeAllImages()
    func prefetchImages(for urls: [String])
}

class ImageCache: ImageCacheProtocol {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    private let ioQueue = DispatchQueue(label: "com.guitaripod.pixie.imagecache", attributes: .concurrent)
    private let networkService: NetworkServiceProtocol
    
    init(networkService: NetworkServiceProtocol = NetworkService()) {
        self.networkService = networkService
        setupCache()
    }
    
    private func setupCache() {
        cache.countLimit = 100
        cache.totalCostLimit = 100 * 1024 * 1024
        
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
            print("Failed to load image from \(urlString): \(error)")
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