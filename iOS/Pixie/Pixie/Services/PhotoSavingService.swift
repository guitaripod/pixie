import UIKit
@preconcurrency import Photos

nonisolated enum PhotoSavingError: LocalizedError {
    case permissionDenied
    case saveFailed(String)
    case albumCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return String(localized: "Photo library access denied. Please enable access in Settings.")
        case .saveFailed(let reason):
            return String(localized: "Failed to save image: \(reason)")
        case .albumCreationFailed:
            return String(localized: "Failed to create Pixie album")
        }
    }
}

class PhotoSavingService {
    
    static let shared = PhotoSavingService()
    
    private let albumName = "Pixie"
    private var pixieAlbum: PHAssetCollection?
    
    private init() {}
    
    /// Saves images with whatever access the user granted. Add-only access, the usual
    /// answer to the save prompt and the only one requested here, can neither create the
    /// Pixie album nor read the new asset back, so the album is used only when the user
    /// already granted full access and success comes from the write itself. If the album
    /// cannot be created or written to, the images still go to the library.
    func saveToLibrary(_ images: [UIImage], completion: @escaping @MainActor (Result<Void, PhotoSavingError>) -> Void) {
        Task {
            completion(await saveToLibrary(images))
        }
    }

    func saveToLibrary(_ images: [UIImage]) async -> Result<Void, PhotoSavingError> {
        guard await hasAddPermission() else { return .failure(.permissionDenied) }
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else {
            return await writeAssets(images, into: nil)
        }
        let album = try? await ensureAlbumExists().get()
        return await writeAssets(images, into: album)
    }

    /// Writes the images, adding them to the album when one is given. A write that fails
    /// with an album, for instance because the user deleted it, is retried once without it
    /// so the images are never lost to an album problem.
    private func writeAssets(_ images: [UIImage], into album: PHAssetCollection?) async -> Result<Void, PhotoSavingError> {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let placeholders = images.compactMap { PHAssetChangeRequest.creationRequestForAsset(from: $0).placeholderForCreatedAsset }
                if let album, let albumRequest = PHAssetCollectionChangeRequest(for: album) {
                    albumRequest.addAssets(placeholders as NSArray)
                }
            }
            return .success(())
        } catch {
            guard album != nil else {
                return .failure(.saveFailed(error.localizedDescription))
            }
            pixieAlbum = nil
            return await writeAssets(images, into: nil)
        }
    }

    private func hasAddPermission() async -> Bool {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized, .limited:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return status == .authorized || status == .limited
        @unknown default:
            return false
        }
    }
    
    private func ensureAlbumExists() async -> Result<PHAssetCollection, PhotoSavingError> {
        if let album = pixieAlbum {
            return .success(album)
        }
        if let existingAlbum = fetchAlbum() {
            pixieAlbum = existingAlbum
            return .success(existingAlbum)
        }
        return await createAlbum()
    }

    private func fetchAlbum() -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        return PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions).firstObject
    }
    
    private func createAlbum() async -> Result<PHAssetCollection, PhotoSavingError> {
        let name = albumName
        do {
            try await PHPhotoLibrary.shared().performChanges {
                _ = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            }
        } catch {
            return .failure(.albumCreationFailed)
        }
        guard let album = fetchAlbum() else { return .failure(.albumCreationFailed) }
        pixieAlbum = album
        return .success(album)
    }
}
