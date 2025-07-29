import Foundation

class GalleryCache {
    static let shared = GalleryCache()
    
    private var cache = [String: (response: GalleryResponse, timestamp: Date)]()
    private let cacheQueue = DispatchQueue(label: "com.guitaripod.pixie.gallerycache", attributes: .concurrent)
    private let cacheTimeout: TimeInterval = 300
    
    private init() {}
    
    func getResponse(for key: String) -> GalleryResponse? {
        cacheQueue.sync {
            guard let cached = cache[key] else { return nil }
            
            if Date().timeIntervalSince(cached.timestamp) > cacheTimeout {
                cache.removeValue(forKey: key)
                return nil
            }
            
            return cached.response
        }
    }
    
    func setResponse(_ response: GalleryResponse, for key: String) {
        cacheQueue.async(flags: .barrier) {
            self.cache[key] = (response, Date())
        }
    }
    
    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
    
    func clearExpired() {
        cacheQueue.async(flags: .barrier) {
            let now = Date()
            self.cache = self.cache.filter { _, value in
                now.timeIntervalSince(value.timestamp) <= self.cacheTimeout
            }
        }
    }
}