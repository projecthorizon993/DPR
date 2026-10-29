//
//  PermissionManager.swift
//  CameraApp
//

import Foundation
import AVFoundation
import Photos

final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    @Published var areAllPermissionsGranted = false

    private init() {}

    func requestAllPermissions() async {
        await requestCameraPermission()
        await requestPhotoPermission()
        await MainActor.run {
            self.areAllPermissionsGranted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized &&
                PHPhotoLibrary.authorizationStatus() == .authorized
        }
    }

    private func requestCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            Logger.shared.info("Camera permission: \(granted ? "granted" : "denied")")
        }
    }

    private func requestPhotoPermission() async {
        let status = PHPhotoLibrary.authorizationStatus()
        if status == .notDetermined {
            let granted = await PHPhotoLibrary.requestAuthorization()
            Logger.shared.info("Photo permission: \(granted == .authorized ? "granted" : "denied")")
        }
    }
}
