import UIKit
import Photos

/// Save a UIImage to the user's photo library.
/// From-scratch implementation.
enum PhotoLibrary {
    static func save(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                if !success {
                    print("PhotoLibrary save failed: \(error?.localizedDescription ?? "unknown")")
                }
            }
        }
    }
}
