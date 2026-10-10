import UIKit
import Photos

enum PhotoSavingError: LocalizedError {
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
    func saveToLibrary(_ images: [UIImage], completion: @escaping (Result<Void, PhotoSavingError>) -> Void) {
        checkPhotoLibraryPermission { [weak self] granted in
            guard let self, granted else {
                completion(.failure(.permissionDenied))
                return
            }
            guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else {
                self.writeAssets(images, into: nil, completion: completion)
                return
            }
            self.ensureAlbumExists { result in
                self.writeAssets(images, into: try? result.get(), completion: completion)
            }
        }
    }

    /// Writes the images, adding them to the album when one is given. A write that fails
    /// with an album, for instance because the user deleted it, is retried once without it
    /// so the images are never lost to an album problem.
    private func writeAssets(
        _ images: [UIImage],
        into album: PHAssetCollection?,
        completion: @escaping (Result<Void, PhotoSavingError>) -> Void
    ) {
        PHPhotoLibrary.shared().performChanges({
            let placeholders = images.compactMap { PHAssetChangeRequest.creationRequestForAsset(from: $0).placeholderForCreatedAsset }
            if let album, let albumRequest = PHAssetCollectionChangeRequest(for: album) {
                albumRequest.addAssets(placeholders as NSArray)
            }
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success(()))
                } else if album != nil {
                    self?.pixieAlbum = nil
                    self?.writeAssets(images, into: nil, completion: completion)
                } else {
                    completion(.failure(.saveFailed(error?.localizedDescription ?? String(localized: "Unknown error"))))
                }
            }
        }
    }

    private func checkPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            completion(true)
        case .denied, .restricted:
            completion(false)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                DispatchQueue.main.async {
                    completion(status == .authorized || status == .limited)
                }
            }
        @unknown default:
            completion(false)
        }
    }
    
    private func ensureAlbumExists(completion: @escaping (Result<PHAssetCollection, PhotoSavingError>) -> Void) {
        if let album = pixieAlbum {
            completion(.success(album))
            return
        }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        
        if let existingAlbum = collections.firstObject {
            pixieAlbum = existingAlbum
            completion(.success(existingAlbum))
        } else {
            createAlbum(completion: completion)
        }
    }
    
    private func createAlbum(completion: @escaping (Result<PHAssetCollection, PhotoSavingError>) -> Void) {
        var albumPlaceholder: PHObjectPlaceholder?
        
        PHPhotoLibrary.shared().performChanges({
            let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: self.albumName)
            albumPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success, let placeholder = albumPlaceholder {
                    let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                    if let album = fetchResult.firstObject {
                        self?.pixieAlbum = album
                        completion(.success(album))
                    } else {
                        completion(.failure(.albumCreationFailed))
                    }
                } else {
                    completion(.failure(.albumCreationFailed))
                }
            }
        }
    }
}
