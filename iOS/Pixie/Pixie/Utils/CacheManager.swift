import Foundation
import UIKit

protocol CacheManagerProtocol {
    /// Calculates the total size of the cache directory including URLCache
    /// - Returns: Total cache size in bytes
    func getCacheSize() async -> Int64
    
    /// Clears all cache data including URLCache, image cache, and temporary files
    func clearCache() async
    
    /// Clears only the in-memory image cache
    func clearImageCache()
}

class CacheManager: CacheManagerProtocol {
    static let shared = CacheManager()

    private init() {}

    func getCacheSize() async -> Int64 {
        guard let cacheDirectory = Self.cacheDirectory else { return 0 }

        return await Task.detached(priority: .background) {
            Self.calculateDirectorySize(at: cacheDirectory)
        }.value
    }

    func clearCache() async {
        await clearURLCaches()
        clearImageCache()
        await Task.detached(priority: .background) {
            Self.removeCachedFiles()
        }.value
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

    /// Empties the shared URL cache and the networking layer's own, pausing between shrinking and restoring the
    /// shared cache's capacity so the disk store lets go of its files.
    private func clearURLCaches() async {
        URLCache.shared.removeAllCachedResponses()

        if let networkService = AppContainer.shared.networkService as? NetworkService {
            await networkService.clearCache()
        }

        URLCache.shared.diskCapacity = 0
        URLCache.shared.memoryCapacity = 0
        try? await Task.sleep(for: .milliseconds(100))
        URLCache.shared.diskCapacity = 500 * 1024 * 1024
        URLCache.shared.memoryCapacity = 100 * 1024 * 1024
    }

    private nonisolated static var cacheDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    }

    private nonisolated static func calculateDirectorySize(at url: URL) -> Int64 {
        var totalSize: Int64 = 0

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                if let isRegularFile = resourceValues.isRegularFile, isRegularFile,
                   let fileSize = resourceValues.fileSize {
                    let filename = fileURL.lastPathComponent
                    if !isDatabaseFile(filename) {
                        totalSize += Int64(fileSize)
                    }
                }
            } catch { }
        }

        return totalSize + Int64(URLCache.shared.currentDiskUsage)
    }

    private nonisolated static func removeCachedFiles() {
        if let cacheDirectory {
            clearAppCacheDirectory(at: cacheDirectory)
            clearMainCacheDirectory(at: cacheDirectory)
        }

        clearDocumentsDirectory()
        clearTemporaryDirectory()
    }

    private nonisolated static func clearAppCacheDirectory(at cacheDirectory: URL) {
        let fileManager = FileManager.default
        let appCacheDirectory = cacheDirectory.appendingPathComponent("com.guitaripod.Pixie")
        guard fileManager.fileExists(atPath: appCacheDirectory.path) else { return }

        if let contents = try? fileManager.contentsOfDirectory(at: appCacheDirectory, includingPropertiesForKeys: nil) {
            for file in contents {
                let filename = file.lastPathComponent
                if shouldDeleteCacheFile(filename) {
                    try? fileManager.removeItem(at: file)
                }
            }
        }
    }

    private nonisolated static func clearMainCacheDirectory(at cacheDirectory: URL) {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else { return }

        for file in contents {
            let filename = file.lastPathComponent
            if shouldDeleteMainCacheFile(filename) {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    private nonisolated static func clearDocumentsDirectory() {
        let fileManager = FileManager.default
        guard let documentsDirectory = try? fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else { return }

        let imagesDirectory = documentsDirectory.appendingPathComponent("PixieImages")
        if fileManager.fileExists(atPath: imagesDirectory.path) {
            try? fileManager.removeItem(at: imagesDirectory)
        }
    }

    private nonisolated static func clearTemporaryDirectory() {
        let fileManager = FileManager.default
        let tmpDirectory = fileManager.temporaryDirectory
        guard let tmpContents = try? fileManager.contentsOfDirectory(at: tmpDirectory, includingPropertiesForKeys: nil) else { return }

        for file in tmpContents {
            try? fileManager.removeItem(at: file)
        }
    }

    private nonisolated static func isDatabaseFile(_ filename: String) -> Bool {
        return filename.hasSuffix(".db") ||
               filename.hasSuffix(".db-wal") ||
               filename.hasSuffix(".db-shm")
    }

    private nonisolated static func shouldDeleteCacheFile(_ filename: String) -> Bool {
        return !filename.hasPrefix(".") && !isDatabaseFile(filename)
    }

    private nonisolated static func shouldDeleteMainCacheFile(_ filename: String) -> Bool {
        let systemFiles = ["Snapshots", "com.guitaripod.Pixie"]
        return shouldDeleteCacheFile(filename) && !systemFiles.contains(filename)
    }
}
