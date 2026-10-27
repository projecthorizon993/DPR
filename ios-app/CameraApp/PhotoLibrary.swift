//
//  PhotoLibrary.swift
//  CameraApp
//
//  Save photos/videos to system Photo Library.
//

import Foundation
import Photos
import UIKit

final class PhotoLibrary {
    static let shared = PhotoLibrary()
    private init() {}

    func save(image: UIImage, completion: ((Bool, Error?) -> Void)? = nil) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    completion?(false, PhotoLibraryError.notAuthorized)
                }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: image.jpegData(compressionQuality: 0.9) ?? Data(), options: nil)
            }, completionHandler: { success, error in
                DispatchQueue.main.async {
                    completion?(success, error)
                }
            })
        }
    }

    func save(videoURL: URL, completion: ((Bool, Error?) -> Void)? = nil) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    completion?(false, PhotoLibraryError.notAuthorized)
                }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .video, fileURL: videoURL, options: nil)
            }, completionHandler: { success, error in
                DispatchQueue.main.async {
                    completion?(success, error)
                }
            })
        }
    }

    func lastThumbnail() -> UIImage? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        guard let asset = result.firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        var thumbnail: UIImage?
        let semaphore = DispatchSemaphore(value: 0)
        PHCachingImageManager().requestImage(
            for: asset,
            targetSize: CGSize(width: 120, height: 120),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            thumbnail = image
            semaphore.signal()
        }
        semaphore.wait()
        return thumbnail
    }
}

enum PhotoLibraryError: LocalizedError {
    case notAuthorized
    var errorDescription: String? { return "Photo library access not authorized" }
}
