import AVFoundation
import Photos
import Foundation
import UIKit

/// 权限管理器
/// 处理相机和相册权限的请求、检查和状态监听
final class PermissionManager: ObservableObject {
    
    // MARK: - 权限状态
    enum PermissionStatus {
        case notDetermined  // 未确定
        case denied        // 拒绝
        case granted       // 授权
        case restricted    // 受限制
        
        var description: String {
            switch self {
            case .notDetermined:
                return "未确定"
            case .denied:
                return "拒绝"
            case .granted:
                return "授权"
            case .restricted:
                return "受限制"
            }
        }
    }
    
    // MARK: - 发布的状态属性
    @Published var cameraPermissionStatus: PermissionStatus = .notDetermined
    @Published var photoLibraryPermissionStatus: PermissionStatus = .notDetermined
    
    // MARK: - 单例
    static let shared = PermissionManager()
    
    private init() {
        // 初始化时检查当前权限状态
        checkCurrentPermissions()
        Logger.shared.info(module: .permissions, operation: "Init", details: "PermissionManager initialized")
    }
    
    // MARK: - 权限状态检查
    
    /// 检查当前所有权限状态
    private func checkCurrentPermissions() {
        checkCameraPermissionStatus()
        checkPhotoLibraryPermissionStatus()
    }
    
    /// 检查相机权限状态
    private func checkCameraPermissionStatus() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async {
            self.cameraPermissionStatus = self.convertAVAuthorizationStatus(status)
        }
        
        Logger.shared.debug(
            module: .permissions,
            operation: "CheckCamera",
            details: "Camera permission status: \(cameraPermissionStatus.description)"
        )
    }
    
    /// 检查相册权限状态
    private func checkPhotoLibraryPermissionStatus() {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        DispatchQueue.main.async {
            self.photoLibraryPermissionStatus = self.convertPHAuthorizationStatus(status)
        }
        
        Logger.shared.debug(
            module: .permissions,
            operation: "CheckPhoto",
            details: "Photo library permission status: \(photoLibraryPermissionStatus.description)"
        )
    }
    
    // MARK: - 权限请求
    
    /// 请求相机权限
    /// - Returns: 异步返回权限授予结果
    @MainActor
    func requestCameraPermission() async -> Bool {
        Logger.shared.logPermissionRequest(type: "Camera")
        
        let status = await AVCaptureDevice.requestAccess(for: .video)
        
        // 更新状态
        checkCameraPermissionStatus()
        
        Logger.shared.logPermissionResult(type: "Camera", granted: status)
        
        return status
    }
    
    /// 请求相册权限
    /// - Returns: 异步返回权限授予结果
    @MainActor
    func requestPhotoLibraryPermission() async -> Bool {
        Logger.shared.logPermissionRequest(type: "PhotoLibrary")
        
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        let granted = (status == .authorized)
        
        // 更新状态
        checkPhotoLibraryPermissionStatus()
        
        Logger.shared.logPermissionResult(type: "PhotoLibrary", granted: granted)
        
        return granted
    }
    
    /// 请求所有必要权限
    /// - Returns: 异步返回所有权限是否都授予
    @MainActor
    func requestAllPermissions() async -> Bool {
        Logger.shared.info(module: .permissions, operation: "RequestAll", details: "Requesting all permissions")
        
        let cameraGranted = await requestCameraPermission()
        let photoGranted = await requestPhotoLibraryPermission()
        
        let allGranted = cameraGranted && photoGranted
        
        Logger.shared.info(
            module: .permissions,
            operation: "RequestAllComplete",
            details: "All permissions granted: \(allGranted)"
        )
        
        return allGranted
    }
    
    // MARK: - 权限检查便捷方法
    
    /// 检查相机权限是否已授权
    var isCameraPermissionGranted: Bool {
        return cameraPermissionStatus == .granted
    }
    
    /// 检查相册权限是否已授权
    var isPhotoLibraryPermissionGranted: Bool {
        return photoLibraryPermissionStatus == .granted
    }
    
    /// 检查所有权限是否都已授权
    var areAllPermissionsGranted: Bool {
        return isCameraPermissionGranted && isPhotoLibraryPermissionGranted
    }
    
    /// 检查是否有权限被拒绝
    var hasAnyPermissionDenied: Bool {
        return cameraPermissionStatus == .denied || photoLibraryPermissionStatus == .denied
    }
    
    // MARK: - 权限状态转换
    
    /// 转换 AVAuthorizationStatus 到内部 PermissionStatus
    /// - Parameter status: AVFoundation 权限状态
    /// - Returns: 内部权限状态枚举
    private func convertAVAuthorizationStatus(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return .granted
        case .restricted:
            return .restricted
        @unknown default:
            return .notDetermined
        }
    }
    
    /// 转换 PHAuthorizationStatus 到内部 PermissionStatus
    /// - Parameter status: Photos 框架权限状态
    /// - Returns: 内部权限状态枚举
    private func convertPHAuthorizationStatus(_ status: PHAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized, .limited:
            return .granted
        case .restricted:
            return .restricted
        @unknown default:
            return .notDetermined
        }
    }
    
    // MARK: - 系统设置跳转
    
    /// 引导用户到系统设置页面修改权限
    func openSystemSettings() {
        Logger.shared.info(module: .permissions, operation: "OpenSettings", details: "Opening system settings")
        
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            Logger.shared.error(module: .permissions, operation: "OpenSettings", details: "Failed to create settings URL")
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl) { success in
                Logger.shared.info(
                    module: .permissions,
                    operation: "OpenSettings",
                    details: "System settings opened: \(success)"
                )
            }
        }
    }
    
    // MARK: - 错误处理
    
    /// 权限相关错误类型
    enum PermissionError: LocalizedError {
        case cameraPermissionDenied
        case photoLibraryPermissionDenied
        case allPermissionsDenied
        
        var errorDescription: String? {
            switch self {
            case .cameraPermissionDenied:
                return "相机权限被拒绝。JustRaw 需要相机权限来拍摄 RAW 照片。"
            case .photoLibraryPermissionDenied:
                return "相册权限被拒绝。JustRaw 需要相册权限来保存拍摄的照片。"
            case .allPermissionsDenied:
                return "所有权限都被拒绝。JustRaw 需要相机和相册权限才能正常工作。"
            }
        }
        
        var recoverySuggestion: String? {
            return "请在系统设置中授予 JustRaw 相关权限。"
        }
    }
    
    /// 获取权限被拒绝时的错误信息
    /// - Returns: 权限错误，如果没有权限被拒绝则返回 nil
    func getPermissionError() -> PermissionError? {
        if !isCameraPermissionGranted && !isPhotoLibraryPermissionGranted {
            return .allPermissionsDenied
        } else if !isCameraPermissionGranted {
            return .cameraPermissionDenied
        } else if !isPhotoLibraryPermissionGranted {
            return .photoLibraryPermissionDenied
        }
        return nil
    }
}

// MARK: - 权限管理器扩展 - 便捷方法

extension PermissionManager {
    
    /// 检查并请求权限（如果需要）
    /// - Returns: 权限是否最终获得授权
    @MainActor
    func ensurePermissions() async -> Bool {
        // 首先检查当前状态
        checkCurrentPermissions()
        
        // 如果所有权限都已授权，直接返回
        if areAllPermissionsGranted {
            Logger.shared.info(module: .permissions, operation: "EnsurePermissions", details: "All permissions already granted")
            return true
        }
        
        // 请求缺失的权限
        let success = await requestAllPermissions()
        
        if !success {
            Logger.shared.warning(
                module: .permissions,
                operation: "EnsurePermissions",
                details: "Some permissions not granted. Camera: \(isCameraPermissionGranted), Photo: \(isPhotoLibraryPermissionGranted)"
            )
        }
        
        return success
    }
    
    /// 获取权限状态描述文本
    var permissionStatusDescription: String {
        let cameraDesc = "相机权限: \(cameraPermissionStatus.description)"
        let photoDesc = "相册权限: \(photoLibraryPermissionStatus.description)"
        return "\(cameraDesc), \(photoDesc)"
    }
}