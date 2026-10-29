import SwiftUI
import Combine
import Foundation

/// 应用状态管理器
/// 管理应用全局状态，包括相机状态、用户设置、应用生命周期等
final class AppStateManager: ObservableObject {
    
    // MARK: - 应用状态枚举
    
    /// 应用生命周期状态
    enum AppLifecycleState {
        case launching      // 启动中
        case active         // 活跃
        case background     // 后台
        case inactive       // 非活跃
        case terminating    // 终止中
    }
    
    /// 相机状态
    enum CameraState {
        case notInitialized // 未初始化
        case initializing   // 初始化中
        case ready          // 准备就绪
        case active         // 活跃状态
        case error(Error)   // 错误状态
        case unavailable    // 不可用
    }
    
    // MARK: - 发布的状态属性
    
    /// 当前应用生命周期状态
    @Published var lifecycleState: AppLifecycleState = .launching
    
    /// 当前相机状态
    @Published var cameraState: CameraState = .notInitialized
    
    /// 权限管理器引用
    @Published var permissionManager = PermissionManager.shared
    
    /// 是否首次启动应用
    @Published var isFirstLaunch: Bool = false
    
    /// 用户设置
    @Published var userSettings = UserSettings()
    
    /// 错误状态
    @Published var currentError: AppError?
    
    /// 是否显示错误弹窗
    @Published var showingError: Bool = false
    
    // MARK: - 私有属性
    
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 用户设置数据模型
    
    struct UserSettings: Codable {
        // 相机设置
        var preferredFlashMode: Bool = false
        var preferredCameraPosition: CameraPosition = .back
        var preferredZoomLevel: Float = 1.0
        
        // 文件设置
        var saveToAlbum: Bool = true
        var dngQuality: DNGQuality = .standard
        
        // 界面设置
        var showGrid: Bool = false
        var showLevelIndicator: Bool = true
        var autoHideControls: Bool = false
        
        // 性能设置
        var highPerformanceMode: Bool = false
        var batteryOptimization: Bool = true
        
        enum CameraPosition: String, Codable, CaseIterable {
            case front = "front"
            case back = "back"
            
            var displayName: String {
                switch self {
                case .front:
                    return "前置"
                case .back:
                    return "后置"
                }
            }
        }
        
        enum DNGQuality: String, Codable, CaseIterable {
            case standard = "standard"
            case high = "high"
            case maximum = "maximum"
            
            var displayName: String {
                switch self {
                case .standard:
                    return "标准"
                case .high:
                    return "高质量"
                case .maximum:
                    return "最高质量"
                }
            }
        }
    }
    
    // MARK: - 应用错误类型
    
    enum AppError: LocalizedError, Identifiable {
        case cameraInitializationFailed(String)
        case permissionsDenied(String)
        case fileSystemError(String)
        case networkError(String)
        case unknownError(String)
        
        var id: String {
            switch self {
            case .cameraInitializationFailed(let message):
                return "camera_init_\(message.hashValue)"
            case .permissionsDenied(let message):
                return "permissions_\(message.hashValue)"
            case .fileSystemError(let message):
                return "filesystem_\(message.hashValue)"
            case .networkError(let message):
                return "network_\(message.hashValue)"
            case .unknownError(let message):
                return "unknown_\(message.hashValue)"
            }
        }
        
        var errorDescription: String? {
            switch self {
            case .cameraInitializationFailed(let message):
                return "相机初始化失败: \(message)"
            case .permissionsDenied(let message):
                return "权限被拒绝: \(message)"
            case .fileSystemError(let message):
                return "文件系统错误: \(message)"
            case .networkError(let message):
                return "网络错误: \(message)"
            case .unknownError(let message):
                return "未知错误: \(message)"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .cameraInitializationFailed:
                return "请重启应用或检查设备相机功能。"
            case .permissionsDenied:
                return "请在系统设置中授予 JustRaw 相关权限。"
            case .fileSystemError:
                return "请检查设备存储空间并重试。"
            case .networkError:
                return "请检查网络连接并重试。"
            case .unknownError:
                return "请重启应用，如果问题持续存在请联系支持。"
            }
        }
    }
    
    // MARK: - 单例
    static let shared = AppStateManager()
    
    private init() {
        setupInitialState()
        setupObservers()
        Logger.shared.info(module: .app, operation: "StateManagerInit", details: "AppStateManager initialized")
    }
    
    // MARK: - 初始化设置
    
    private func setupInitialState() {
        // 检查是否首次启动
        isFirstLaunch = !userDefaults.bool(forKey: "hasLaunchedBefore")
        if isFirstLaunch {
            userDefaults.set(true, forKey: "hasLaunchedBefore")
            Logger.shared.info(module: .app, operation: "FirstLaunch", details: "First time launching the app")
        }
        
        // 加载用户设置
        loadUserSettings()
        
        // 设置初始生命周期状态
        lifecycleState = .launching
    }
    
    private func setupObservers() {
        // 监听权限变化
        permissionManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        
        // 监听用户设置变化并自动保存
        $userSettings
            .dropFirst() // 跳过初始值
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.saveUserSettings()
            }
            .store(in: &cancellables)
        
        // 监听错误状态变化
        $currentError
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.showingError = true
                Logger.shared.error(
                    module: .app,
                    operation: "AppError",
                    details: error.localizedDescription
                )
            }
            .store(in: &cancellables)
        
        Logger.shared.debug(module: .app, operation: "ObserversSetup", details: "State observers configured")
    }
    
    // MARK: - 生命周期管理
    
    /// 应用变为活跃状态
    func applicationDidBecomeActive() {
        lifecycleState = .active
        Logger.shared.logAppForeground()
        
        // 重新检查权限状态
        Task {
            await permissionManager.requestAllPermissions()
        }
    }
    
    /// 应用进入后台
    func applicationDidEnterBackground() {
        lifecycleState = .background
        Logger.shared.logAppBackground()
        
        // 保存当前状态
        saveUserSettings()
    }
    
    /// 应用变为非活跃状态
    func applicationWillResignActive() {
        lifecycleState = .inactive
        Logger.shared.info(module: .app, operation: "AppInactive", details: "Application will resign active")
    }
    
    /// 应用即将终止
    func applicationWillTerminate() {
        lifecycleState = .terminating
        Logger.shared.logAppTerminate()
        
        // 保存最终状态
        saveUserSettings()
    }
    
    // MARK: - 相机状态管理
    
    /// 更新相机状态
    func updateCameraState(_ newState: CameraState) {
        DispatchQueue.main.async {
            self.cameraState = newState
        }
        
        let stateDescription = self.getCameraStateDescription(newState)
        Logger.shared.info(
            module: .app,
            operation: "CameraStateUpdate",
            details: "Camera state updated to: \(stateDescription)"
        )
        
        // 如果相机状态是错误，设置应用错误
        if case .error(let error) = newState {
            handleError(.cameraInitializationFailed(error.localizedDescription))
        }
    }
    
    private func getCameraStateDescription(_ state: CameraState) -> String {
        switch state {
        case .notInitialized:
            return "未初始化"
        case .initializing:
            return "初始化中"
        case .ready:
            return "准备就绪"
        case .active:
            return "活跃状态"
        case .error(let error):
            return "错误: \(error.localizedDescription)"
        case .unavailable:
            return "不可用"
        }
    }
    
    // MARK: - 错误处理
    
    /// 处理应用错误
    func handleError(_ error: AppError) {
        DispatchQueue.main.async {
            self.currentError = error
        }
    }
    
    /// 清除当前错误
    func clearError() {
        DispatchQueue.main.async {
            self.currentError = nil
            self.showingError = false
        }
    }
    
    // MARK: - 用户设置持久化
    
    /// 保存用户设置
    func saveUserSettings() {
        do {
            let data = try JSONEncoder().encode(userSettings)
            userDefaults.set(data, forKey: "userSettings")
            Logger.shared.debug(module: .app, operation: "SaveSettings", details: "User settings saved successfully")
        } catch {
            Logger.shared.error(module: .app, operation: "SaveSettings", details: "Failed to save settings: \(error.localizedDescription)")
            handleError(.fileSystemError("设置保存失败"))
        }
    }
    
    /// 加载用户设置
    func loadUserSettings() {
        guard let data = userDefaults.data(forKey: "userSettings") else {
            Logger.shared.debug(module: .app, operation: "LoadSettings", details: "No saved settings found, using defaults")
            return
        }
        
        do {
            userSettings = try JSONDecoder().decode(UserSettings.self, from: data)
            Logger.shared.debug(module: .app, operation: "LoadSettings", details: "User settings loaded successfully")
        } catch {
            Logger.shared.error(module: .app, operation: "LoadSettings", details: "Failed to load settings: \(error.localizedDescription)")
            // 使用默认设置
            userSettings = UserSettings()
        }
    }
    
    /// 重置用户设置到默认值
    func resetUserSettings() {
        userSettings = UserSettings()
        saveUserSettings()
        Logger.shared.info(module: .app, operation: "ResetSettings", details: "User settings reset to defaults")
    }
    
    // MARK: - 便捷属性
    
    /// 应用是否处于前台活跃状态
    var isAppActive: Bool {
        return lifecycleState == .active
    }
    
    /// 应用是否处于后台状态
    var isAppInBackground: Bool {
        return lifecycleState == .background
    }
    
    /// 相机是否可用
    var isCameraReady: Bool {
        switch cameraState {
        case .ready, .active:
            return true
        default:
            return false
        }
    }
    
    /// 是否有未处理的错误
    var hasError: Bool {
        return currentError != nil
    }
    
    /// 应用状态描述
    var stateDescription: String {
        let lifecycle = getLifecycleDescription()
        let camera = getCameraStateDescription(cameraState)
        let permissions = permissionManager.permissionStatusDescription
        return "应用: \(lifecycle), 相机: \(camera), \(permissions)"
    }
    
    private func getLifecycleDescription() -> String {
        switch lifecycleState {
        case .launching:
            return "启动中"
        case .active:
            return "活跃"
        case .background:
            return "后台"
        case .inactive:
            return "非活跃"
        case .terminating:
            return "终止中"
        }
    }
}

// MARK: - 扩展 - 设置更新方法

extension AppStateManager {
    
    /// 更新闪光灯偏好
    func updateFlashPreference(_ enabled: Bool) {
        userSettings.preferredFlashMode = enabled
        Logger.shared.debug(module: .app, operation: "UpdateSetting", details: "Flash preference: \(enabled)")
    }
    
    /// 更新相机位置偏好
    func updateCameraPositionPreference(_ position: UserSettings.CameraPosition) {
        userSettings.preferredCameraPosition = position
        Logger.shared.debug(module: .app, operation: "UpdateSetting", details: "Camera position: \(position.displayName)")
    }
    
    /// 更新变焦级别偏好
    func updateZoomLevelPreference(_ level: Float) {
        userSettings.preferredZoomLevel = level
        Logger.shared.debug(module: .app, operation: "UpdateSetting", details: "Zoom level: \(level)x")
    }
    
    /// 更新DNG质量偏好
    func updateDNGQualityPreference(_ quality: UserSettings.DNGQuality) {
        userSettings.dngQuality = quality
        Logger.shared.debug(module: .app, operation: "UpdateSetting", details: "DNG quality: \(quality.displayName)")
    }
    
    /// 更新网格线显示偏好
    func updateGridPreference(_ show: Bool) {
        userSettings.showGrid = show
        Logger.shared.debug(module: .app, operation: "UpdateSetting", details: "Show grid: \(show)")
    }
    
    /// 更新水平仪显示偏好
    func updateLevelIndicatorPreference(_ show: Bool) {
        userSettings.showLevelIndicator = show
        Logger.shared.debug(module: .app, operation: "UpdateSetting", details: "Show level indicator: \(show)")
    }
    
    /// 更新自动隐藏控制栏偏好
    func updateAutoHideControlsPreference(_ enabled: Bool) {
        userSettings.autoHideControls = enabled
        Logger.shared.debug(module: .app, operation: "UpdateSetting", details: "Auto hide controls: \(enabled)")
    }
    
    /// 更新高性能模式偏好
    func updateHighPerformanceModePreference(_ enabled: Bool) {
        userSettings.highPerformanceMode = enabled
        Logger.shared.debug(module: .app, operation: "UpdateSetting", details: "High performance mode: \(enabled)")
    }
    
    /// 更新电池优化偏好
    func updateBatteryOptimizationPreference(_ enabled: Bool) {
        userSettings.batteryOptimization = enabled
        Logger.shared.debug(module: .app, operation: "UpdateSetting", details: "Battery optimization: \(enabled)")
    }
}