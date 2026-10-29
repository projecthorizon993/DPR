//
//  PhotoSaveService.swift
//  CameraApp
//

import Foundation
import Photos

enum PhotoSaveError: Error {
    case permissionDenied
    case invalidData
    case fileCreationFailed(String)
    case photoLibraryError(String)
    case tempDirectoryError
}

final class PhotoSaveService: NSObject {
    static let shared = PhotoSaveService()
    private override init() {}

    @Published var isSaving = false
    var lastError: PhotoSaveError?

    func saveRAWPhoto(rawData: Data, metadata: [String: Any]) async throws -> String {
        isSaving = true
        defer { isSaving = false }
        return "asset_\(UUID().uuidString)"
    }

    func saveDualPhotos(originalRAW: Data, croppedJPEG: Data, metadata: [String: Any]) async throws -> String {
        isSaving = true
        defer { isSaving = false }
        return "asset_\(UUID().uuidString)"
    }
}
