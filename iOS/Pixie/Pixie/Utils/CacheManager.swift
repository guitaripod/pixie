import Foundation
import UIKit

protocol CacheManagerProtocol {
    func getCacheSize() async -> Int64
    func clearCache() async
    func clearImageCache()
}

class CacheManager: CacheManagerProtocol {
    static let shared = CacheManager()
    
    private let fileManager = FileManager.default
    
    private init() {}
    
    private var cacheDirectory: URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
    }
    
    func getCacheSize() async -> Int64 {
        guard let cacheDirectory = cacheDirectory else { return 0 }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                let size = self.calculateDirectorySize(at: cacheDirectory)
                continuation.resume(returning: size)
            }
        }
    }
    
    private func calculateDirectorySize(at url: URL) -> Int64 {
        var totalSize: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                if let isRegularFile = resourceValues.isRegularFile, isRegularFile,
                   let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            } catch {
                print("Error calculating file size for \(fileURL): \(error)")
            }
        }
        
        // Add URLCache size
        let urlCacheSize = URLCache.shared.currentDiskUsage
        totalSize += Int64(urlCacheSize)
        
        return totalSize
    }
    
    func clearCache() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                self.performCacheClear()
                continuation.resume()
            }
        }
    }
    
    private func performCacheClear() {
        // Clear URLCache
        URLCache.shared.removeAllCachedResponses()
        
        // Clear image cache
        clearImageCache()
        
        // Clear temporary directory
        if let tmpDirectory = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            do {
                let tmpContents = try fileManager.contentsOfDirectory(at: tmpDirectory, includingPropertiesForKeys: nil)
                for file in tmpContents {
                    try? fileManager.removeItem(at: file)
                }
            } catch {
                print("Error clearing cache directory: \(error)")
            }
        }
        
        // Clear downloaded images directory if exists
        if let documentsDirectory = try? fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            let imagesDirectory = documentsDirectory.appendingPathComponent("PixieImages")
            if fileManager.fileExists(atPath: imagesDirectory.path) {
                try? fileManager.removeItem(at: imagesDirectory)
            }
        }
    }
    
    func clearImageCache() {
        ImageCache.shared.removeAllImages()
    }
    
    func formatCacheSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}