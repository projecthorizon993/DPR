import Foundation
import AVFoundation
import UIKit
import SwiftUI
import os.signpost

/// JustRaw 相机服务核心类
/// 管理相机会话、设备控制和RAW数据捕获
final class CameraService: NSObject, ObservableObject {
    
    // MARK: - 相机状态枚举
    
    /// 相机会话状态
    enum SessionState: String, CaseIterable {
        case notConfigured = "notConfigured"
        case configuring = "configuring"
        case configured = "configured"
        case running = "running"
        case stopped = "stopped"
        case error = "error"
        
        var description: String {
            switch self {
            case .notConfigured: return "未配置"
            case .configuring: return "配置中"
            case .configured: return "已配置"
            case .running: return "运行中"
            case .stopped: return "已停止"
            case .error: return "错误"
            }
        }
    }
    
    /// 相机配置模式
    enum CameraMode: String, CaseIterable {
        case rawPhoto = "rawPhoto"
        
        var description: String {
            switch self {
            case .rawPhoto: return "RAW照片"
            }
        }
    }
    
    /// 相机错误类型
    enum CameraError: LocalizedError {
        case configurationFailed(String)
        case deviceNotFound
        case permissionDenied
        case sessionNotRunning
        case captureError(String)
        case rawNotSupported
        case deviceChangeFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .configurationFailed(let message):
                return "相机配置失败: \(message)"
            case .deviceNotFound:
                return "找不到可用的相机设备"
            case .permissionDenied:
                return "相机权限被拒绝"
            case .sessionNotRunning:
                return "相机会话未运行"
            case .captureError(let message):
                return "拍摄错误: \(message)"
            case .rawNotSupported:
                return "设备不支持RAW拍摄"
            case .deviceChangeFailed(let message):
                return "切换相机失败: \(message)"
            }
        }
    }
    
    // MARK: - 发布属性
    
    /// 当前会话状态
    @Published var sessionState: SessionState = .notConfigured
    
    /// 当前相机模式
    @Published var currentMode: CameraMode = .rawPhoto
    
    /// 当前相机位置
    @Published var currentCameraPosition: AVCaptureDevice.Position = .back
    
    /// 是否正在配置
    @Published var isConfiguring: Bool = false
    
    /// 是否支持RAW捕获
    @Published var supportsRAWCapture: Bool = false
    
    /// 当前缩放因子
    @Published var zoomFactor: CGFloat = 1.0
    
    /// 最大缩放因子
    @Published var maxZoomFactor: CGFloat = 1.0
    
    /// 是否启用闪光灯
    @Published var isFlashEnabled: Bool = false
    
    /// 是否支持闪光灯
    @Published var supportsFlash: Bool = false
    
    /// 当前对焦点
    @Published var focusPoint: CGPoint?
    
    /// 当前曝光点
    @Published var exposurePoint: CGPoint?
    
    // MARK: - 私有属性
    
    private let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var photoOutput: AVCapturePhotoOutput?
    private var currentDevice: AVCaptureDevice?
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue", qos: .userInitiated)
    private let captureQueue = DispatchQueue(label: "camera.capture.queue", qos: .userInitiated)
    
    // 当前捕获代理引用（防止过早释放 - iOS 18 兼容性）
    private var currentCaptureDelegate: PhotoCaptureDelegate?
    
    // 性能和调试
    private let performanceMonitor = PerformanceMonitor.shared
    private let errorHandler = ErrorHandler.shared
    private let appStateManager = AppStateManager.shared
    
    // MARK: - 单例
    static let shared = CameraService()
    
    override init() {
        super.init()
        Logger.shared.info(module: .camera, operation: "Init", details: "CameraService initialized")
    }
    
    // MARK: - 会话管理
    
    /// 配置相机会话
    func configureSession() async throws {
        guard sessionState == .notConfigured else {
            Logger.shared.debug(module: .camera, operation: "ConfigureSession", details: "Session already configured")
            return
        }
        
        performanceMonitor.startOperation("CameraConfiguration", type: .cameraInit)
        isConfiguring = true
        sessionState = .configuring
        appStateManager.updateCameraState(.initializing)
        
        do {
            try await withCheckedThrowingContinuation { continuation in
                sessionQueue.async {
                    do {
                        try self.configureSessionInternal()
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            sessionState = .configured
            appStateManager.updateCameraState(.ready)
            
            Logger.shared.logCameraSessionStart()
            performanceMonitor.endOperation("CameraConfiguration")
            
        } catch {
            sessionState = .error
            appStateManager.updateCameraState(.error(error))
            errorHandler.handleError(error, category: .camera, severity: .high)
            
            Logger.shared.logCameraSessionError(error)
            performanceMonitor.endOperation("CameraConfiguration")
            
            throw error
        }
        isConfiguring = false
    }
    
    /// 内部配置方法
    private func configureSessionInternal() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        // 设置会话预设
        if captureSession.canSetSessionPreset(.photo) {
            captureSession.sessionPreset = .photo
        } else {
            throw CameraError.configurationFailed("无法设置照片预设")
        }
        
        // 配置视频输入
        try configureVideoInput()
        
        // 配置照片输出
        try configurePhotoOutput()
        
        // 检查设备能力
        updateDeviceCapabilities()
        
        Logger.shared.info(module: .camera, operation: "ConfigureSession", details: "Camera session configured successfully")
    }
    
    /// 配置视频输入
    private func configureVideoInput() throws {
        // 移除现有输入
        if let existingInput = videoDeviceInput {
            captureSession.removeInput(existingInput)
        }
        
        // 获取默认相机设备
        guard let device = getDefaultDevice() else {
            throw CameraError.deviceNotFound
        }
        
        // 创建输入
        let deviceInput = try AVCaptureDeviceInput(device: device)
        
        // 添加输入到会话
        guard captureSession.canAddInput(deviceInput) else {
            throw CameraError.configurationFailed("无法添加相机输入")
        }
        
        captureSession.addInput(deviceInput)
        videoDeviceInput = deviceInput
        currentDevice = device
        currentCameraPosition = device.position
        
        // 配置默认曝光模式为全局测光
        try configureDefaultExposureMode(for: device)
        
        Logger.shared.info(module: .camera, operation: "ConfigureInput", details: "Video input configured for \(device.position == .back ? "back" : "front") camera")
    }
    
    /// 配置照片输出
    private func configurePhotoOutput() throws {
        // 移除现有输出
        if let existingOutput = photoOutput {
            captureSession.removeOutput(existingOutput)
        }
        
        // 创建照片输出
        let output = AVCapturePhotoOutput()
        
        // iOS 18 兼容性设置
        if #available(iOS 18.0, *) {
            // 设置最大照片质量优先级为速度，避免 sessionNotRunning 错误
            output.maxPhotoQualityPrioritization = .speed
            Logger.shared.info(module: .camera, operation: "ConfigureOutput", details: "iOS 18: Set maxPhotoQualityPrioritization to speed")
        }
        
        // 添加输出到会话
        guard captureSession.canAddOutput(output) else {
            throw CameraError.configurationFailed("无法添加照片输出")
        }
        
        captureSession.addOutput(output)
        photoOutput = output
        
        Logger.shared.info(module: .camera, operation: "ConfigureOutput", details: "Photo output configured")
    }
    
    /// 获取默认相机设备
    private func getDefaultDevice() -> AVCaptureDevice? {
        // 优先使用后置三摄系统
        if let device = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back) {
            return device
        }
        
        // 其次使用后置双摄系统
        if let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
            return device
        }
        
        // 使用后置广角摄像头
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            return device
        }
        
        // 最后使用默认设备
        return AVCaptureDevice.default(for: .video)
    }
    
    /// 更新设备能力
    private func updateDeviceCapabilities() {
        guard let device = currentDevice else { return }
        
        // 检查RAW支持
        if let photoOutput = photoOutput {
            supportsRAWCapture = photoOutput.availableRawPhotoPixelFormatTypes.count > 0
            
        }
        
        // 检查闪光灯支持
        supportsFlash = device.hasFlash
        
        // 设置缩放范围
        maxZoomFactor = device.activeFormat.videoMaxZoomFactor
        
        Logger.shared.info(
            module: .camera,
            operation: "UpdateCapabilities",
            details: "RAW: \(supportsRAWCapture), Flash: \(supportsFlash), MaxZoom: \(maxZoomFactor)"
        )
    }
    
    /// 启动相机会话
    func startSession() async {
        guard sessionState == .configured else {
            Logger.shared.warning(module: .camera, operation: "StartSession", details: "Session not configured")
            return
        }
        
        sessionQueue.async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                
                Task { @MainActor in
                    self.sessionState = .running
                    self.appStateManager.updateCameraState(.active)
                    Logger.shared.info(module: .camera, operation: "StartSession", details: "Camera session started")
                }
            }
        }
    }
    
    /// 停止相机会话
    func stopSession() {
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                
                // 清理当前捕获代理引用
                self.currentCaptureDelegate = nil
                
                Task { @MainActor in
                    self.sessionState = .stopped
                    self.appStateManager.updateCameraState(.ready)
                    Logger.shared.logCameraSessionStop()
                }
            }
        }
    }
    
    // MARK: - 相机控制
    
    /// 切换相机位置
    func switchCamera() async throws {
        guard sessionState == .running else {
            throw CameraError.sessionNotRunning
        }
        
        performanceMonitor.startOperation("SwitchCamera", type: .cameraInit)
        
        do {
            try await withCheckedThrowingContinuation { continuation in
                sessionQueue.async {
                    do {
                        try self.switchCameraInternal()
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            let newPosition = currentCameraPosition == .back ? "front" : "back"
            Logger.shared.logCameraSwitch(to: newPosition)
            performanceMonitor.endOperation("SwitchCamera")
            
        } catch {
            errorHandler.handleError(error, category: .camera, severity: .medium)
            performanceMonitor.endOperation("SwitchCamera")
            throw error
        }
    }
    
    /// 内部切换相机方法
    private func switchCameraInternal() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        // 确定新的位置
        let newPosition: AVCaptureDevice.Position = currentCameraPosition == .back ? .front : .back
        
        // 查找新设备
        let newDevice: AVCaptureDevice?
        if newPosition == .back {
            newDevice = getDefaultDevice()
        } else {
            newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        }
        
        guard let device = newDevice else {
            throw CameraError.deviceChangeFailed("找不到\(newPosition == .back ? "后置" : "前置")摄像头")
        }
        
        // 移除当前输入
        if let currentInput = videoDeviceInput {
            captureSession.removeInput(currentInput)
        }
        
        // 创建新输入
        let newInput = try AVCaptureDeviceInput(device: device)
        
        guard captureSession.canAddInput(newInput) else {
            throw CameraError.deviceChangeFailed("无法添加新的相机输入")
        }
        
        // 添加新输入
        captureSession.addInput(newInput)
        videoDeviceInput = newInput
        currentDevice = device
        currentCameraPosition = device.position
        
        // 更新设备能力
        updateDeviceCapabilities()
    }
    
    /// 设置缩放因子
    func setZoomFactor(_ factor: CGFloat) async throws {
        guard let device = currentDevice else {
            throw CameraError.deviceNotFound
        }
        
        let clampedFactor = min(max(factor, 1.0), maxZoomFactor)
        
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                do {
                    try device.lockForConfiguration()
                    device.videoZoomFactor = clampedFactor
                    device.unlockForConfiguration()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        
        zoomFactor = clampedFactor
        Logger.shared.logZoomSet(level: Float(clampedFactor), success: true)
    }
    
    /// 设置对焦点
    func setFocusPoint(_ point: CGPoint) async throws {
        guard let device = currentDevice,
              device.isFocusPointOfInterestSupported else {
            Logger.shared.warning(module: .camera, operation: "SetFocus", details: "Focus point not supported")
            return
        }
        
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                do {
                    try device.lockForConfiguration()
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                    device.unlockForConfiguration()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        
        focusPoint = point
        Logger.shared.logFocusSet(point: point, success: true)
    }
    
    /// 设置曝光点
    func setExposurePoint(_ point: CGPoint) async throws {
        guard let device = currentDevice,
              device.isExposurePointOfInterestSupported else {
            Logger.shared.warning(module: .camera, operation: "SetExposure", details: "Exposure point not supported")
            return
        }
        
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                do {
                    try device.lockForConfiguration()
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                    device.unlockForConfiguration()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        
        exposurePoint = point
        Logger.shared.info(module: .camera, operation: "SetExposure", details: "Exposure point set to (\(point.x), \(point.y))")
    }
    
    /// 配置默认曝光模式为全局测光
    private func configureDefaultExposureMode(for device: AVCaptureDevice) throws {
        do {
            try device.lockForConfiguration()
            
            // 设置为连续自动曝光（全局测光模式）
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
                Logger.shared.info(module: .camera, operation: "ConfigureExposure", details: "设置全局测光模式 (.continuousAutoExposure)")
            } else {
                Logger.shared.warning(module: .camera, operation: "ConfigureExposure", details: "设备不支持连续自动曝光模式")
            }
            
            device.unlockForConfiguration()
        } catch {
            Logger.shared.error(module: .camera, operation: "ConfigureExposure", details: "配置曝光模式失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 切换闪光灯
    func toggleFlash() {
        isFlashEnabled.toggle()
        Logger.shared.logFlashToggle(enabled: isFlashEnabled)
    }
    
    // MARK: - 相机模式管理
    
    /// 设置相机模式
    func setCameraMode(_ mode: CameraMode) async throws {
        // iPhone 13 mini RAW专用模式，仅支持.rawPhoto
        guard mode == .rawPhoto else {
            throw CameraError.configurationFailed("仅支持RAW拍摄模式")
        }
        
        guard sessionState == .running else {
            throw CameraError.sessionNotRunning
        }
        
        guard supportsRAWCapture else {
            throw CameraError.rawNotSupported
        }
        
        currentMode = mode
        Logger.shared.info(module: .camera, operation: "SetMode", details: "Camera mode set to RAW photo")
    }
    
    // MARK: - 照片捕获
    
    /// 捕获照片
    /// - Parameter completion: 完成回调，返回捕获的照片数据或错误
    func capturePhoto() async throws -> CapturedPhotoResult {
        guard canCapture else {
            throw CameraError.sessionNotRunning
        }
        
        guard photoOutput != nil else {
            throw CameraError.configurationFailed("照片输出未配置")
        }
        
        performanceMonitor.startOperation("PhotoCapture", type: .dngCapture)
        
        do {
            let result = try await capturePhotoInternal()
            Logger.shared.logPhotoCapture(mode: currentMode.description, success: true)
            performanceMonitor.endOperation("PhotoCapture")
            return result
        } catch {
            Logger.shared.logPhotoCapture(mode: currentMode.description, success: false)
            errorHandler.handleError(error, category: .camera, severity: .high)
            performanceMonitor.endOperation("PhotoCapture")
            throw error
        }
    }
    
    /// RAW拍摄（带变焦重置） - 避免Apple的videoZoomFactor = 1.0约束
    func captureRAWWithZoomReset(originalZoomFactor: CGFloat) async throws -> CapturedPhotoResult {
        guard canCapture else {
            throw CameraError.sessionNotRunning
        }
        
        guard photoOutput != nil else {
            throw CameraError.configurationFailed("照片输出未配置")
        }
        
        Logger.shared.info(
            module: .camera,
            operation: "RAWCaptureStart",
            details: "Starting RAW capture, original zoom: \(String(format: "%.2f", originalZoomFactor))x, will reset to 1.0x"
        )
        
        performanceMonitor.startOperation("RAWCaptureWithZoomReset", type: .dngCapture)
        
        do {
            // 步骤1：保存当前变焦值并重置到1.0x（满足Apple约束）
            let currentZoom = zoomFactor
            
            if abs(currentZoom - 1.0) > 0.001 {
                Logger.shared.debug(
                    module: .camera,
                    operation: "ZoomReset",
                    details: "Resetting zoom from \(String(format: "%.2f", currentZoom))x to 1.0x for RAW capture"
                )
                
                try await setZoomFactor(1.0)
                
                // 等待变焦稳定
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            }
            
            // 步骤2：拍摄RAW照片
            let result = try await capturePhotoInternal()
            
            // 步骤3：恢复原变焦值（如果需要）
            if abs(originalZoomFactor - 1.0) > 0.001 {
                Logger.shared.debug(
                    module: .camera,
                    operation: "ZoomRestore",
                    details: "Restoring zoom to \(String(format: "%.2f", originalZoomFactor))x after RAW capture"
                )
                
                try await setZoomFactor(originalZoomFactor)
            }
            
            Logger.shared.info(
                module: .camera,
                operation: "RAWCaptureComplete",
                details: "RAW capture completed successfully, zoom restored to \(String(format: "%.2f", originalZoomFactor))x"
            )
            
            Logger.shared.logPhotoCapture(mode: "RAW", success: true)
            performanceMonitor.endOperation("RAWCaptureWithZoomReset")
            return result
            
        } catch {
            // 发生错误时也尝试恢复变焦值
            if abs(originalZoomFactor - 1.0) > 0.001 {
                do {
                    try await setZoomFactor(originalZoomFactor)
                } catch {
                    Logger.shared.warning(
                        module: .camera,
                        operation: "ZoomRestoreError",
                        details: "Failed to restore zoom after capture error: \(error.localizedDescription)"
                    )
                }
            }
            
            Logger.shared.logPhotoCapture(mode: "RAW", success: false)
            errorHandler.handleError(error, category: .camera, severity: .high)
            performanceMonitor.endOperation("RAWCaptureWithZoomReset")
            throw error
        }
    }
    
    /// 内部照片捕获实现
    private func capturePhotoInternal() async throws -> CapturedPhotoResult {
        return try await captureWithDelegate()
    }
    
    /// 正常的delegate-based捕获方法（带iOS 18 fallback保护）
    private func captureWithDelegate() async throws -> CapturedPhotoResult {
        return try await withTimeout(seconds: 8) { [self] in
            try await withCheckedThrowingContinuation { continuation in
                self.captureQueue.async {
                    guard let photoOutput = self.photoOutput else {
                        continuation.resume(throwing: CameraError.configurationFailed("照片输出未配置"))
                        return
                    }
                    
                    // iOS 18 兼容性处理：修复delegate回调不被调用的问题
                    if #available(iOS 18.0, *) {
                        guard self.captureSession.isRunning else {
                            Logger.shared.error(module: .camera, operation: "CaptureStart", details: "iOS 18: Session not running before capture")
                            continuation.resume(throwing: CameraError.sessionNotRunning)
                            return
                        }
                        
                        // 设置最大照片质量优先级（iOS 18 必需修复）
                        photoOutput.maxPhotoQualityPrioritization = .speed
                        
                        // 在捕获前重新配置会话（iOS 18 delegate callback修复）
                        self.captureSession.beginConfiguration()
                        self.captureSession.commitConfiguration()
                        
                        Logger.shared.debug(module: .camera, operation: "CaptureStart", details: "iOS 18: Applied delegate callback fixes - maxPhotoQualityPrioritization: .speed, session reconfiguration")
                    }
                    
                    // 创建照片设置
                    let photoSettings = self.createPhotoSettings()
                    
                    Logger.shared.debug(
                        module: .camera,
                        operation: "CaptureStart",
                        details: "开始执行照片捕获，像素格式: \(photoSettings.rawPhotoPixelFormatType)"
                    )
                    
                    // 创建照片捕获代理
                    let captureDelegate = PhotoCaptureDelegate(
                        mode: self.currentMode,
                        continuation: continuation
                    )
                    
                    // 将代理存储为实例变量，防止过早释放（iOS 18 兼容性）
                    self.currentCaptureDelegate = captureDelegate
                    
                    // iOS 18 监控：检查delegate是否在3秒内响应
                    if #available(iOS 18.0, *) {
                        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 3.0) {
                            if !captureDelegate.hasAnyCallbackBeenCalled() {
                                Logger.shared.warning(module: .camera, operation: "iOS18Check", details: "Delegate callbacks not received after 3 seconds - iOS 18 delegate issue confirmed")
                            }
                        }
                    }
                    
                    // 执行捕获
                    photoOutput.capturePhoto(with: photoSettings, delegate: captureDelegate)
                }
            }
        }
    }
    
    
    /// 超时包装器
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // 添加实际操作任务
            group.addTask {
                try await operation()
            }
            
            // 添加超时任务
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw CameraError.captureError("照片捕获超时（\(seconds)秒）")
            }
            
            // 返回第一个完成的任务结果
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    /// 创建照片设置
    private func createPhotoSettings() -> AVCapturePhotoSettings {
        // iPhone 13 mini专用RAW/DNG拍摄配置
        guard let photoOutput = photoOutput else {
            Logger.shared.error(
                module: .camera,
                operation: "CreateSettings",
                details: "PhotoOutput未初始化"
            )
            // 如果photoOutput不可用，创建基础设置作为备用
            let basicSettings = AVCapturePhotoSettings()
            basicSettings.photoQualityPrioritization = .speed
            return basicSettings
        }
        
        // 获取可用的RAW格式
        guard let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first else {
            Logger.shared.error(
                module: .camera,
                operation: "CreateSettings", 
                details: "设备不支持RAW格式，iPhone 13 mini应该支持RAW拍摄"
            )
            // 如果RAW不可用，创建基础设置作为备用
            let basicSettings = AVCapturePhotoSettings()
            basicSettings.photoQualityPrioritization = .speed
            return basicSettings
        }
        
        // 创建RAW照片设置
        let photoSettings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
        
        // RAW格式必须使用speed优先级（Apple强制要求）
        photoSettings.photoQualityPrioritization = .speed
        
        // 设置闪光灯模式
        if supportsFlash {
            photoSettings.flashMode = isFlashEnabled ? .on : .off
        }
        
        // 注意：RAW模式不支持深度数据，因为RAW是未处理的传感器数据
        // 不设置isDepthDataDeliveryEnabled以避免兼容性问题
        
        Logger.shared.info(
            module: .camera,
            operation: "CreateSettings",
            details: "已创建RAW拍摄设置，像素格式: \(rawFormat), 质量优先级: speed"
        )
        
        return photoSettings
    }
    
    // MARK: - 便捷属性
    
    /// 相机会话（用于预览）
    var cameraSession: AVCaptureSession {
        return captureSession
    }
    
    /// 相机是否可用
    var isCameraAvailable: Bool {
        return sessionState == .running && currentDevice != nil
    }
    
    /// 是否可以拍摄
    var canCapture: Bool {
        return isCameraAvailable && !isConfiguring
    }
    
    /// 当前设备信息
    var deviceInfo: String {
        guard let device = currentDevice else { return "无设备" }
        return "\(device.localizedName) - \(device.position == .back ? "后置" : "前置")"
    }
    
    /// 会话描述
    var sessionDescription: String {
        return "状态: \(sessionState.description), 模式: \(currentMode.description), 设备: \(deviceInfo)"
    }
}

// MARK: - 照片捕获结果

/// 捕获的照片结果
struct CapturedPhotoResult {
    /// 照片数据
    let photoData: Data?
    /// RAW照片数据
    let rawPhotoData: Data?
    /// 深度数据
    let depthData: Data?
    /// 照片元数据
    let metadata: [String: Any]?
    /// 捕获模式
    let captureMode: CameraService.CameraMode
    /// 捕获时间
    let timestamp: Date
    /// 文件大小（字节）
    let fileSize: Int64
    
    /// 是否包含RAW数据
    var hasRawData: Bool {
        return rawPhotoData != nil
    }
    
    /// 格式化文件大小
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

// MARK: - 照片捕获代理

private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let mode: CameraService.CameraMode
    private let continuation: CheckedContinuation<CapturedPhotoResult, Error>
    private let captureTime = Date()
    
    // 防止continuation被多次恢复
    private var hasResumed = false
    private let resumeLock = NSLock()
    
    // 回调状态监控（iOS 18 兼容性）
    private var didFinishProcessingPhotoCalled = false
    private var didFinishCaptureForCalled = false
    
    /// 检查是否有任何delegate回调被调用（iOS 18 监控用）
    func hasAnyCallbackBeenCalled() -> Bool {
        return didFinishProcessingPhotoCalled || didFinishCaptureForCalled
    }
    
    private var photoData: Data?
    private var rawPhotoData: Data?
    private var depthData: Data?
    private var metadata: [String: Any]?
    
    // 错误信息收集
    private var captureError: Error?
    
    init(mode: CameraService.CameraMode, continuation: CheckedContinuation<CapturedPhotoResult, Error>) {
        self.mode = mode
        self.continuation = continuation
        super.init()
        
        Logger.shared.debug(
            module: .camera,
            operation: "DelegateInit",
            details: "PhotoCaptureDelegate initialized for mode: \(mode.description)"
        )
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        didFinishProcessingPhotoCalled = true
        
        Logger.shared.debug(
            module: .camera,
            operation: "PhotoProcessing",
            details: "开始处理照片，是RAW: \(photo.isRawPhoto), 有错误: \(error != nil)"
        )
        
        if let error = error {
            Logger.shared.error(
                module: .camera,
                operation: "PhotoProcessing",
                details: "照片处理出错: \(error.localizedDescription)"
            )
            captureError = error  // 收集错误，将在最终处理时使用
            return
        }
        
        // 获取照片数据 - 现代iOS API中，RAW和标准照片都在这里处理
        if let data = photo.fileDataRepresentation() {
            if photo.isRawPhoto {
                // 这是RAW/DNG数据（纯RAW模式下的主要数据）
                rawPhotoData = data
                
                // 验证DNG数据的完整性
                let isDNG = data.count > 8 && data.prefix(4).starts(with: [0x49, 0x49]) // II for little-endian TIFF
                
                Logger.shared.info(
                    module: .camera,
                    operation: "PhotoProcessing",
                    details: "RAW/DNG数据已获取，大小: \(String(format: "%.2f", Double(data.count) / 1024 / 1024))MB, 格式验证: \(isDNG ? "DNG" : "未知")"
                )
            } else {
                // 这是标准照片数据（JPEG/HEIF）
                photoData = data
                Logger.shared.info(
                    module: .camera,
                    operation: "PhotoProcessing",
                    details: "标准照片数据已获取，大小: \(data.count) 字节"
                )
            }
        } else {
            Logger.shared.error(
                module: .camera,
                operation: "PhotoProcessing",
                details: "无法获取照片数据表示，是RAW: \(photo.isRawPhoto)"
            )
        }
        
        // 获取元数据
        metadata = photo.metadata
        
        Logger.shared.debug(
            module: .camera,
            operation: "PhotoProcessing",
            details: "照片数据收集完成，模式: \(mode.description), 是RAW: \(photo.isRawPhoto)"
        )
    }
    
    // 注意：didFinishProcessingRawPhoto 方法在 iOS 11+ 已被废弃
    // 现代 iOS 应用应使用 didFinishProcessingPhoto 中的 photo.isRawPhoto 判断
    
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        didFinishCaptureForCalled = true
        
        Logger.shared.debug(
            module: .camera,
            operation: "CaptureComplete",
            details: "捕获完成回调，有错误: \(error != nil), didFinishProcessingPhoto: \(didFinishProcessingPhotoCalled)"
        )
        
        // 使用线程安全的方式检查和设置恢复状态
        resumeLock.lock()
        defer { resumeLock.unlock() }
        
        if hasResumed {
            Logger.shared.warning(
                module: .camera,
                operation: "CaptureComplete",
                details: "Continuation已经恢复，忽略重复调用"
            )
            return
        }
        hasResumed = true
        
        // iOS 18 兼容性：检查之前收集的错误
        let finalError = error ?? captureError
        
        if let finalError = finalError {
            Logger.shared.error(
                module: .camera,
                operation: "CaptureComplete",
                details: "捕获失败: \(finalError.localizedDescription)"
            )
            continuation.resume(throwing: CameraService.CameraError.captureError(finalError.localizedDescription))
            return
        }
        
        // RAW模式下，必须有RAW数据
        if mode == .rawPhoto && rawPhotoData == nil {
            let errorMessage = "RAW模式下未获取到RAW数据 - didFinishProcessingPhoto: \(didFinishProcessingPhotoCalled)"
            Logger.shared.error(
                module: .camera,
                operation: "CaptureComplete",
                details: errorMessage
            )
            continuation.resume(throwing: CameraService.CameraError.captureError(errorMessage))
            return
        }
        
        // 计算总文件大小
        var totalSize: Int64 = 0
        if let photoData = photoData {
            totalSize += Int64(photoData.count)
        }
        if let rawPhotoData = rawPhotoData {
            totalSize += Int64(rawPhotoData.count)
        }
        if let depthData = depthData {
            totalSize += Int64(depthData.count)
        }
        
        // 创建结果
        let result = CapturedPhotoResult(
            photoData: photoData,
            rawPhotoData: rawPhotoData,
            depthData: depthData,
            metadata: metadata,
            captureMode: mode,
            timestamp: captureTime,
            fileSize: totalSize
        )
        
        // 立即清理内存中的大数据，减少内存占用
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.1) {
            self.photoData = nil
            self.rawPhotoData = nil
            self.depthData = nil
        }
        
        Logger.shared.info(
            module: .camera,
            operation: "CaptureComplete",
            details: "照片捕获完成，总大小: \(result.formattedFileSize), 包含RAW: \(result.hasRawData), 回调状态: Processing(\(didFinishProcessingPhotoCalled))"
        )
        
        continuation.resume(returning: result)
    }
    
    deinit {
        // 清理大内存数据
        photoData = nil
        rawPhotoData = nil
        depthData = nil
        metadata = nil
        
        Logger.shared.debug(
            module: .camera,
            operation: "DelegateDestroy",
            details: "PhotoCaptureDelegate deallocated - hasResumed: \(hasResumed), callbacks: Processing(\(didFinishProcessingPhotoCalled)), CaptureFor(\(didFinishCaptureForCalled))"
        )
    }
}


// MARK: - 扩展 - 生命周期管理

extension CameraService {
    
    /// 应用进入前台
    func applicationDidBecomeActive() {
        Task {
            if sessionState == .stopped {
                await startSession()
            }
        }
    }
    
    /// 应用进入后台
    func applicationDidEnterBackground() {
        if sessionState == .running {
            stopSession()
        }
    }
    
    /// 应用即将终止
    func applicationWillTerminate() {
        stopSession()
        Logger.shared.info(module: .camera, operation: "Terminate", details: "Camera service terminated")
    }
}