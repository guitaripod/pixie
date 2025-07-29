import UIKit
import Photos

enum PhotoSavingError: LocalizedError {
    case permissionDenied
    case saveFailed(String)
    case albumCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Photo library access denied. Please enable access in Settings."
        case .saveFailed(let reason):
            return "Failed to save image: \(reason)"
        case .albumCreationFailed:
            return "Failed to create Pixie album"
        }
    }
}

class PhotoSavingService {
    
    static let shared = PhotoSavingService()
    
    private let albumName = "Pixie"
    private var pixieAlbum: PHAssetCollection?
    
    private init() {}
    
    func saveImage(
        _ image: UIImage,
        completion: @escaping (Result<PHAsset, PhotoSavingError>) -> Void
    ) {
        checkPhotoLibraryPermission { [weak self] granted in
            guard granted else {
                completion(.failure(.permissionDenied))
                return
            }
            
            self?.performSave(image: image, completion: completion)
        }
    }
    
    func saveImages(
        _ images: [UIImage],
        progress: ((Float) -> Void)? = nil,
        completion: @escaping (Result<[PHAsset], PhotoSavingError>) -> Void
    ) {
        checkPhotoLibraryPermission { [weak self] granted in
            guard granted else {
                completion(.failure(.permissionDenied))
                return
            }
            
            self?.performBatchSave(images: images, progress: progress, completion: completion)
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
    
    private func performSave(
        image: UIImage,
        completion: @escaping (Result<PHAsset, PhotoSavingError>) -> Void
    ) {
        ensureAlbumExists { [weak self] result in
            switch result {
            case .success(let album):
                self?.saveImageToAlbum(image, album: album, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func performBatchSave(
        images: [UIImage],
        progress: ((Float) -> Void)?,
        completion: @escaping (Result<[PHAsset], PhotoSavingError>) -> Void
    ) {
        ensureAlbumExists { [weak self] result in
            switch result {
            case .success(let album):
                self?.saveImagesToAlbum(images, album: album, progress: progress, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
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
    
    private func saveImageToAlbum(
        _ image: UIImage,
        album: PHAssetCollection,
        completion: @escaping (Result<PHAsset, PhotoSavingError>) -> Void
    ) {
        var assetPlaceholder: PHObjectPlaceholder?
        
        PHPhotoLibrary.shared().performChanges({
            let assetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
            assetPlaceholder = assetRequest.placeholderForCreatedAsset
            
            if let albumChangeRequest = PHAssetCollectionChangeRequest(for: album),
               let placeholder = assetPlaceholder {
                albumChangeRequest.addAssets([placeholder] as NSArray)
            }
        }) { success, error in
            DispatchQueue.main.async {
                if success, let placeholder = assetPlaceholder {
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                    if let asset = fetchResult.firstObject {
                        completion(.success(asset))
                    } else {
                        completion(.failure(.saveFailed("Could not fetch saved asset")))
                    }
                } else {
                    completion(.failure(.saveFailed(error?.localizedDescription ?? "Unknown error")))
                }
            }
        }
    }
    
    private func saveImagesToAlbum(
        _ images: [UIImage],
        album: PHAssetCollection,
        progress: ((Float) -> Void)?,
        completion: @escaping (Result<[PHAsset], PhotoSavingError>) -> Void
    ) {
        var assetPlaceholders: [PHObjectPlaceholder] = []
        
        PHPhotoLibrary.shared().performChanges({
            let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
            
            for (index, image) in images.enumerated() {
                let assetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                if let placeholder = assetRequest.placeholderForCreatedAsset {
                    assetPlaceholders.append(placeholder)
                    albumChangeRequest?.addAssets([placeholder] as NSArray)
                }
                
                let currentProgress = Float(index + 1) / Float(images.count)
                DispatchQueue.main.async {
                    progress?(currentProgress)
                }
            }
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    let identifiers = assetPlaceholders.map { $0.localIdentifier }
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
                    
                    var assets: [PHAsset] = []
                    fetchResult.enumerateObjects { asset, _, _ in
                        assets.append(asset)
                    }
                    
                    completion(.success(assets))
                } else {
                    completion(.failure(.saveFailed(error?.localizedDescription ?? "Unknown error")))
                }
            }
        }
    }
}