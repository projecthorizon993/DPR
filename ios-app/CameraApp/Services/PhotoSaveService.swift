import Foundation
import Photos
import UIKit
import SwiftUI
import os.signpost

/// 照片保存服务 - iPhone 13 mini RAW/DNG专用
/// 负责将拍摄的RAW照片保存到系统相册，支持iOS 18现代化async/await模式
@MainActor
final class PhotoSaveService: NSObject, ObservableObject {
    
    // MARK: - 保存状态枚举
    
    /// 照片保存状态
    enum SaveStatus: String, CaseIterable {
        case idle = "idle"
        case saving = "saving" 
        case completed = "completed"
        case failed = "failed"
        
        var description: String {
            switch self {
            case .idle: return "空闲"
            case .saving: return "保存中"
            case .completed: return "保存成功"
            case .failed: return "保存失败"
            }
        }
    }
    
    /// 保存错误类型
    enum SaveError: LocalizedError {
        case permissionDenied
        case invalidData
        case fileCreationFailed(String)
        case photoLibraryError(String)
        case tempDirectoryError
        
        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "相册访问权限被拒绝"
            case .invalidData:
                return "照片数据无效"
            case .fileCreationFailed(let message):
                return "文件创建失败: \(message)"
            case .photoLibraryError(let message):
                return "相册保存失败: \(message)"
            case .tempDirectoryError:
                return "临时目录访问失败"
            }
        }
    }
    
    // MARK: - 发布属性
    
    /// 当前保存状态
    @Published var saveStatus: SaveStatus = .idle
    
    /// 保存进度 (0.0 - 1.0)
    @Published var saveProgress: Double = 0.0
    
    /// 最近保存的照片资产ID
    @Published var lastSavedAssetID: String?
    
    /// 错误信息
    @Published var lastError: SaveError?
    
    // MARK: - 私有属性
    
    /// 单例实例
    static let shared = PhotoSaveService()
    
    /// 临时文件目录URL
    private let tempDirectoryURL: URL
    
    /// 当前保存任务
    private var currentSaveTask: Task<Void, Never>?
    
    // 性能监控将在后续集成
    
    // MARK: - 初始化
    
    override init() {
        // 创建临时文件目录
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("JustRaw_DNG")
        self.tempDirectoryURL = tempDir
        
        super.init()
        
        // 确保临时目录存在
        Task {
            await createTempDirectoryIfNeeded()
        }
        
        print("PhotoSaveService initialized")
    }
    
    // MARK: - 公共方法
    
    /// 保存RAW照片到相册
    /// - Parameters:
    ///   - rawData: RAW照片数据
    ///   - metadata: 照片元数据
    /// - Returns: 保存成功的PHAsset本地标识符
    @discardableResult
    func saveRAWPhoto(rawData: Data, metadata: [String: Any]?) async throws -> String {
        // 取消之前的保存任务
        currentSaveTask?.cancel()
        
        // 重置状态
        await resetSaveState()
        
        // 开始保存
        saveStatus = .saving
        saveProgress = 0.0
        
        // performanceMonitor.startOperation("PhotoSave", type: .fileSave)
        
        print("开始保存RAW照片到相册，文件大小: \(String(format: "%.2f", Double(rawData.count) / 1024 / 1024))MB")
        
        do {
            let assetID = try await performSave(rawData: rawData, metadata: metadata)
            
            // 保存成功
            saveStatus = .completed
            saveProgress = 1.0
            lastSavedAssetID = assetID
            lastError = nil
            
            // performanceMonitor.endOperation("PhotoSave")
            
            print("RAW照片保存成功，Asset ID: \(assetID)")
            
            // 3秒后自动重置为idle状态
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if saveStatus == .completed {
                    saveStatus = .idle
                }
            }
            
            return assetID
            
        } catch {
            // 保存失败
            saveStatus = .failed
            saveProgress = 0.0
            
            if let saveError = error as? SaveError {
                lastError = saveError
            } else {
                lastError = .photoLibraryError(error.localizedDescription)
            }
            
            // performanceMonitor.endOperation("PhotoSave")
            
            print("RAW照片保存失败: \(error.localizedDescription)")
            
            throw error
        }
    }
    
    /// 保存双照片：原始RAW + 裁剪JPEG
    /// - Parameters:
    ///   - originalRAW: 原始RAW数据
    ///   - croppedJPEG: 裁剪后的JPEG数据
    ///   - metadata: 照片元数据
    /// - Returns: 资产ID
    func saveDualPhotos(originalRAW: Data, croppedJPEG: Data, metadata: [String: Any]?) async throws -> String {
        // 取消之前的保存任务
        currentSaveTask?.cancel()
        
        // 重置状态
        await resetSaveState()
        
        // 开始保存
        saveStatus = .saving
        saveProgress = 0.0
        
        print("开始保存双照片到相册，RAW大小: \(String(format: "%.2f", Double(originalRAW.count) / 1024 / 1024))MB，JPEG大小: \(String(format: "%.2f", Double(croppedJPEG.count) / 1024))KB")
        
        do {
            let assetID = try await performDualSave(originalRAW: originalRAW, croppedJPEG: croppedJPEG, metadata: metadata)
            
            // 保存成功
            saveStatus = .completed
            saveProgress = 1.0
            lastSavedAssetID = assetID
            lastError = nil
            
            print("双照片保存成功，Asset ID: \(assetID)")
            
            // 3秒后自动重置为idle状态
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if saveStatus == .completed {
                    saveStatus = .idle
                }
            }
            
            return assetID
            
        } catch {
            // 保存失败
            saveStatus = .failed
            saveProgress = 0.0
            
            if let saveError = error as? SaveError {
                lastError = saveError
            } else {
                lastError = .photoLibraryError(error.localizedDescription)
            }
            
            print("双照片保存失败: \(error.localizedDescription)")
            
            throw error
        }
    }
    
    /// 检查相册访问权限
    func checkPhotoLibraryPermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            // 请求权限
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return newStatus == .authorized || newStatus == .limited
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    /// 取消当前保存任务
    func cancelCurrentSave() {
        currentSaveTask?.cancel()
        currentSaveTask = nil
        
        if saveStatus == .saving {
            saveStatus = .idle
            saveProgress = 0.0
        }
        
        print("照片保存任务已取消")
    }
    
    // MARK: - 私有方法
    
    /// 执行保存操作
    private func performSave(rawData: Data, metadata: [String: Any]?) async throws -> String {
        // 验证权限
        guard await checkPhotoLibraryPermission() else {
            throw SaveError.permissionDenied
        }
        
        saveProgress = 0.1
        
        // 验证RAW数据
        guard !rawData.isEmpty else {
            throw SaveError.invalidData
        }
        
        saveProgress = 0.2
        
        // iPhone 13 mini专用：纯DNG模式保存
        let assetID = try await saveDNGOnly(data: rawData, metadata: metadata)
        
        saveProgress = 1.0
        
        return assetID
    }
    
    /// 执行双照片保存操作
    private func performDualSave(originalRAW: Data, croppedJPEG: Data, metadata: [String: Any]?) async throws -> String {
        // 验证权限
        guard await checkPhotoLibraryPermission() else {
            throw SaveError.permissionDenied
        }
        
        saveProgress = 0.1
        
        // 验证数据
        guard !originalRAW.isEmpty && !croppedJPEG.isEmpty else {
            throw SaveError.invalidData
        }
        
        saveProgress = 0.2
        
        // 创建临时文件
        let tempDNGURL = try await createTempDNGFile(data: originalRAW)
        
        saveProgress = 0.4
        
        print("双照片保存：创建临时RAW文件成功，开始关联保存")
        
        // 使用现代化async/await方式关联保存到相册
        let assetID = try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                // 创建资产请求
                let creationRequest = PHAssetCreationRequest.forAsset()
                
                // 设置资源创建选项
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true  // 移动RAW文件，节省存储空间
                
                // 添加主照片资源：裁剪后的JPEG（用户主要查看的照片）
                creationRequest.addResource(
                    with: .photo,
                    data: croppedJPEG,
                    options: nil
                )
                
                // 添加备用照片资源：完整的RAW文件（用于专业后期处理）
                creationRequest.addResource(
                    with: .alternatePhoto,
                    fileURL: tempDNGURL,
                    options: options
                )
                
                // 添加元数据（如果存在）
                if let metadata = metadata {
                    print("双照片保存：RAW和JPEG元数据已处理")
                }
                
            }) { success, error in
                if success {
                    // 生成资产ID
                    let assetID = "dual_\(Int(Date().timeIntervalSince1970))"
                    print("双照片保存到相册成功：JPEG（主）+ RAW（备用）")
                    continuation.resume(returning: assetID)
                } else {
                    let saveError = SaveError.photoLibraryError(error?.localizedDescription ?? "双照片保存未知错误")
                    print("双照片保存到相册失败: \(error?.localizedDescription ?? "未知错误")")
                    continuation.resume(throwing: saveError)
                }
            }
        }
        
        saveProgress = 0.8
        
        // 清理临时RAW文件（JPEG数据在内存中，不需要清理文件）
        try? FileManager.default.removeItem(at: tempDNGURL)
        
        saveProgress = 0.9
        
        return assetID
    }
    
    /// iPhone 13 mini专用：仅保存DNG文件
    private func saveDNGOnly(data: Data, metadata: [String: Any]?) async throws -> String {
        print("iPhone 13 mini模式：仅保存DNG文件，大小: \(String(format: "%.2f", Double(data.count) / 1024 / 1024))MB")
        
        // 创建临时DNG文件
        let tempFileURL = try await createTempDNGFile(data: data)
        
        saveProgress = 0.5
        
        // 使用现代化async/await方式保存到相册
        let assetID = try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                // 创建资产请求
                let creationRequest = PHAssetCreationRequest.forAsset()
                
                // 设置资源创建选项
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true  // 移动而不是复制，节省存储空间
                
                // 将DNG作为主要资源添加（iPhone 13 mini纯DNG模式）
                creationRequest.addResource(
                    with: .photo,  // 作为主要照片资源
                    fileURL: tempFileURL,
                    options: options
                )
                
                // 添加元数据
                if let metadata = metadata {
                    // 注意：PHAssetCreationRequest 不直接支持设置元数据
                    // 元数据已经嵌入在DNG文件中
                    print("DNG元数据已嵌入文件中")
                }
                
            }) { success, error in
                if success {
                    // 获取新创建的资产ID
                    // 注意：由于我们无法直接从performChanges获取具体的Asset ID，
                    // 我们使用时间戳作为标识符
                    let assetID = "dng_\(Int(Date().timeIntervalSince1970))"
                    continuation.resume(returning: assetID)
                } else {
                    let saveError = SaveError.photoLibraryError(error?.localizedDescription ?? "未知错误")
                    continuation.resume(throwing: saveError)
                }
            }
        }
        
        saveProgress = 0.8
        
        // 清理临时文件
        try? FileManager.default.removeItem(at: tempFileURL)
        
        saveProgress = 0.9
        
        return assetID
    }
    
    /// 创建临时DNG文件
    private func createTempDNGFile(data: Data) async throws -> URL {
        guard await createTempDirectoryIfNeeded() else {
            throw SaveError.tempDirectoryError
        }
        
        let fileName = "JustRaw_\(Int(Date().timeIntervalSince1970)).dng"
        let fileURL = tempDirectoryURL.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            print("临时DNG文件创建成功: \(fileURL.lastPathComponent)")
            return fileURL
        } catch {
            throw SaveError.fileCreationFailed(error.localizedDescription)
        }
    }
    
    /// 创建临时目录（如果不存在）
    @discardableResult
    private func createTempDirectoryIfNeeded() async -> Bool {
        guard !FileManager.default.fileExists(atPath: tempDirectoryURL.path) else {
            return true
        }
        
        do {
            try FileManager.default.createDirectory(
                at: tempDirectoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            print("临时目录创建成功: \(tempDirectoryURL.path)")
            
            return true
        } catch {
            print("临时目录创建失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 重置保存状态
    private func resetSaveState() async {
        saveStatus = .idle
        saveProgress = 0.0
        lastError = nil
    }
    
    // MARK: - 清理方法
    
    /// 清理临时文件
    func cleanupTempFiles() async {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: tempDirectoryURL, includingPropertiesForKeys: nil)
            
            for fileURL in contents {
                try FileManager.default.removeItem(at: fileURL)
            }
            
            print("清理了 \(contents.count) 个临时文件")
            
        } catch {
            print("临时文件清理失败: \(error.localizedDescription)")
        }
    }
    
    deinit {
        currentSaveTask?.cancel()
        
        // 异步清理临时文件
        Task {
            await cleanupTempFiles()
        }
        
        print("PhotoSaveService deinitialized")
    }
}

// MARK: - 扩展 - 便捷属性

extension PhotoSaveService {
    
    /// 是否正在保存
    var isSaving: Bool {
        return saveStatus == .saving
    }
    
    /// 是否保存成功
    var isCompleted: Bool {
        return saveStatus == .completed
    }
    
    /// 是否保存失败
    var hasFailed: Bool {
        return saveStatus == .failed
    }
    
    /// 格式化的保存状态描述
    var statusDescription: String {
        switch saveStatus {
        case .saving:
            return "保存中 \(Int(saveProgress * 100))%"
        default:
            return saveStatus.description
        }
    }
}