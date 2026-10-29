import Foundation
import SwiftUI
import os.log

/// JustRaw 统一错误处理系统
/// 提供全应用错误处理、错误恢复、用户友好提示和错误分析
final class ErrorHandler: ObservableObject {
    
    // MARK: - 错误类型定义
    
    /// 应用错误严重等级
    enum ErrorSeverity: String, CaseIterable {
        case low = "low"           // 低等级 - 不影响核心功能
        case medium = "medium"     // 中等级 - 影响部分功能
        case high = "high"         // 高等级 - 影响核心功能
        case critical = "critical" // 严重等级 - 应用无法继续运行
        
        var description: String {
            switch self {
            case .low:
                return "轻微"
            case .medium:
                return "中等"
            case .high:
                return "严重"
            case .critical:
                return "致命"
            }
        }
    }
    
    /// 错误分类
    enum ErrorCategory: String, CaseIterable {
        case camera = "camera"             // 相机相关错误
        case permissions = "permissions"   // 权限相关错误
        case fileSystem = "fileSystem"     // 文件系统错误
        case dng = "dng"                  // DNG处理错误
        case network = "network"          // 网络相关错误
        case ui = "ui"                    // 用户界面错误
        case system = "system"            // 系统级错误
        case unknown = "unknown"          // 未知错误
        
        var description: String {
            switch self {
            case .camera:
                return "相机"
            case .permissions:
                return "权限"
            case .fileSystem:
                return "文件系统"
            case .dng:
                return "DNG处理"
            case .network:
                return "网络"
            case .ui:
                return "界面"
            case .system:
                return "系统"
            case .unknown:
                return "未知"
            }
        }
    }
    
    /// 统一错误数据结构
    struct AppError: LocalizedError, Identifiable {
        let id = UUID()
        let category: ErrorCategory
        let severity: ErrorSeverity
        let code: String
        let message: String
        let underlyingError: Error?
        let timestamp: Date
        let context: [String: Any]?
        let recoveryActions: [RecoveryAction]
        
        var errorDescription: String? {
            return message
        }
        
        var recoverySuggestion: String? {
            guard !recoveryActions.isEmpty else {
                return getDefaultRecoverySuggestion()
            }
            
            let suggestions = recoveryActions.map { $0.description }.joined(separator: " 或 ")
            return suggestions
        }
        
        private func getDefaultRecoverySuggestion() -> String {
            switch category {
            case .camera:
                return "请检查相机权限并重新启动相机功能。"
            case .permissions:
                return "请在系统设置中授予相关权限。"
            case .fileSystem:
                return "请检查设备存储空间并重试。"
            case .dng:
                return "请重新尝试拍摄或检查设备兼容性。"
            case .network:
                return "请检查网络连接并重试。"
            case .ui:
                return "请重新启动应用。"
            case .system:
                return "请重启设备或联系技术支持。"
            case .unknown:
                return "请重新启动应用，如问题持续请联系支持。"
            }
        }
    }
    
    /// 错误恢复行为
    struct RecoveryAction {
        let title: String
        let description: String
        let action: () async -> Bool
        
        init(title: String, description: String, action: @escaping () async -> Bool) {
            self.title = title
            self.description = description
            self.action = action
        }
    }
    
    // MARK: - 发布属性
    
    /// 当前错误队列
    @Published var currentErrors: [AppError] = []
    
    /// 是否显示错误弹窗
    @Published var showingErrorAlert: Bool = false
    
    /// 错误统计
    @Published var errorStatistics: ErrorStatistics = ErrorStatistics()
    
    // MARK: - 错误统计
    
    struct ErrorStatistics: Codable {
        var totalErrors: Int = 0
        var errorsByCategory: [String: Int] = [:]
        var errorsBySeverity: [String: Int] = [:]
        var lastResetDate: Date = Date()
        
        mutating func recordError(_ error: AppError) {
            totalErrors += 1
            errorsByCategory[error.category.rawValue, default: 0] += 1
            errorsBySeverity[error.severity.rawValue, default: 0] += 1
        }
        
        mutating func reset() {
            totalErrors = 0
            errorsByCategory.removeAll()
            errorsBySeverity.removeAll()
            lastResetDate = Date()
        }
    }
    
    // MARK: - 单例
    static let shared = ErrorHandler()
    
    private init() {
        loadErrorStatistics()
        Logger.shared.info(module: .app, operation: "ErrorHandlerInit", details: "Unified error handler initialized")
    }
    
    // MARK: - 错误处理核心方法
    
    /// 处理错误
    /// - Parameters:
    ///   - error: 原始错误
    ///   - category: 错误分类
    ///   - severity: 错误严重程度
    ///   - context: 错误上下文
    ///   - recoveryActions: 恢复行为
    func handleError(
        _ error: Error,
        category: ErrorCategory = .unknown,
        severity: ErrorSeverity = .medium,
        context: [String: Any]? = nil,
        recoveryActions: [RecoveryAction] = []
    ) {
        let appError = createAppError(
            from: error,
            category: category,
            severity: severity,
            context: context,
            recoveryActions: recoveryActions
        )
        
        processError(appError)
    }
    
    /// 处理自定义错误消息
    /// - Parameters:
    ///   - message: 错误消息
    ///   - code: 错误代码
    ///   - category: 错误分类
    ///   - severity: 错误严重程度
    ///   - context: 错误上下文
    ///   - recoveryActions: 恢复行为
    func handleError(
        message: String,
        code: String = "CUSTOM_ERROR",
        category: ErrorCategory = .unknown,
        severity: ErrorSeverity = .medium,
        context: [String: Any]? = nil,
        recoveryActions: [RecoveryAction] = []
    ) {
        let appError = AppError(
            category: category,
            severity: severity,
            code: code,
            message: message,
            underlyingError: nil,
            timestamp: Date(),
            context: context,
            recoveryActions: recoveryActions
        )
        
        processError(appError)
    }
    
    /// 创建应用错误对象
    private func createAppError(
        from error: Error,
        category: ErrorCategory,
        severity: ErrorSeverity,
        context: [String: Any]?,
        recoveryActions: [RecoveryAction]
    ) -> AppError {
        
        // 尝试从现有错误中提取信息
        let code: String
        let message: String
        
        if let appStateError = error as? AppStateManager.AppError {
            // AppStateManager 错误
            code = "APP_STATE_\(appStateError.id)"
            message = appStateError.localizedDescription
        } else if let permissionError = error as? PermissionManager.PermissionError {
            // 权限管理器错误
            code = "PERMISSION_ERROR"
            message = permissionError.localizedDescription
        } else if let nsError = error as? NSError {
            // NSError
            code = "NS_ERROR_\(nsError.code)"
            message = nsError.localizedDescription
        } else {
            // 通用错误
            code = "GENERIC_ERROR"
            message = error.localizedDescription
        }
        
        return AppError(
            category: category,
            severity: severity,
            code: code,
            message: message,
            underlyingError: error,
            timestamp: Date(),
            context: context,
            recoveryActions: recoveryActions
        )
    }
    
    /// 处理错误
    private func processError(_ error: AppError) {
        DispatchQueue.main.async {
            // 添加到错误队列
            self.currentErrors.append(error)
            
            // 更新统计信息
            self.errorStatistics.recordError(error)
            self.saveErrorStatistics()
            
            // 记录日志
            self.logError(error)
            
            // 根据严重程度决定处理方式
            switch error.severity {
            case .low:
                // 低等级错误只记录，不显示UI
                break
            case .medium, .high:
                // 中高等级错误显示用户提示
                self.showingErrorAlert = true
            case .critical:
                // 严重错误立即显示并可能需要特殊处理
                self.showingErrorAlert = true
                self.handleCriticalError(error)
            }
        }
    }
    
    /// 处理严重错误
    private func handleCriticalError(_ error: AppError) {
        Logger.shared.error(
            module: .app,
            operation: "CriticalError",
            details: "Critical error occurred: \(error.message)"
        )
        
        // 严重错误可能需要额外的处理，比如：
        // - 保存当前状态
        // - 清理资源
        // - 发送崩溃报告
        // - 引导用户重启应用
    }
    
    /// 记录错误日志
    private func logError(_ error: AppError) {
        let contextInfo = error.context?.map { "\($0.key): \($0.value)" }.joined(separator: ", ") ?? "No context"
        let details = """
        Category: \(error.category.description), 
        Severity: \(error.severity.description), 
        Code: \(error.code), 
        Message: \(error.message), 
        Context: \(contextInfo)
        """
        
        switch error.severity {
        case .low:
            Logger.shared.debug(module: .app, operation: "ErrorHandled", details: details)
        case .medium:
            Logger.shared.warning(module: .app, operation: "ErrorHandled", details: details)
        case .high, .critical:
            Logger.shared.error(module: .app, operation: "ErrorHandled", details: details)
        }
    }
    
    // MARK: - 错误恢复
    
    /// 执行错误恢复行为
    /// - Parameters:
    ///   - error: 需要恢复的错误
    ///   - actionIndex: 恢复行为索引
    @MainActor
    func executeRecoveryAction(for error: AppError, actionIndex: Int) async -> Bool {
        guard actionIndex < error.recoveryActions.count else {
            Logger.shared.error(
                module: .app,
                operation: "RecoveryAction",
                details: "Invalid recovery action index: \(actionIndex)"
            )
            return false
        }
        
        let action = error.recoveryActions[actionIndex]
        
        Logger.shared.info(
            module: .app,
            operation: "RecoveryAction",
            details: "Executing recovery action: \(action.title)"
        )
        
        let success = await action.action()
        
        if success {
            // 恢复成功，移除错误
            removeError(error)
            Logger.shared.info(
                module: .app,
                operation: "RecoverySuccess",
                details: "Recovery action succeeded: \(action.title)"
            )
        } else {
            Logger.shared.warning(
                module: .app,
                operation: "RecoveryFailed",
                details: "Recovery action failed: \(action.title)"
            )
        }
        
        return success
    }
    
    /// 移除错误
    func removeError(_ error: AppError) {
        DispatchQueue.main.async {
            self.currentErrors.removeAll { $0.id == error.id }
            
            // 如果没有更多错误，隐藏提示
            if self.currentErrors.isEmpty {
                self.showingErrorAlert = false
            }
        }
    }
    
    /// 清除所有错误
    func clearAllErrors() {
        DispatchQueue.main.async {
            self.currentErrors.removeAll()
            self.showingErrorAlert = false
        }
    }
    
    // MARK: - 便捷属性
    
    /// 当前是否有错误
    var hasErrors: Bool {
        return !currentErrors.isEmpty
    }
    
    /// 当前最高优先级错误
    var currentHighestPriorityError: AppError? {
        return currentErrors.max { lhs, rhs in
            let lhsPriority = getSeverityPriority(lhs.severity)
            let rhsPriority = getSeverityPriority(rhs.severity)
            return lhsPriority < rhsPriority
        }
    }
    
    private func getSeverityPriority(_ severity: ErrorSeverity) -> Int {
        switch severity {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
    
    // MARK: - 统计数据持久化
    
    /// 保存错误统计
    private func saveErrorStatistics() {
        do {
            let data = try JSONEncoder().encode(errorStatistics)
            UserDefaults.standard.set(data, forKey: "errorStatistics")
        } catch {
            Logger.shared.error(
                module: .app,
                operation: "SaveErrorStats",
                details: "Failed to save error statistics: \(error.localizedDescription)"
            )
        }
    }
    
    /// 加载错误统计
    private func loadErrorStatistics() {
        guard let data = UserDefaults.standard.data(forKey: "errorStatistics") else {
            return
        }
        
        do {
            errorStatistics = try JSONDecoder().decode(ErrorStatistics.self, from: data)
        } catch {
            Logger.shared.error(
                module: .app,
                operation: "LoadErrorStats",
                details: "Failed to load error statistics: \(error.localizedDescription)"
            )
            errorStatistics = ErrorStatistics()
        }
    }
    
    /// 重置错误统计
    func resetErrorStatistics() {
        errorStatistics.reset()
        saveErrorStatistics()
        Logger.shared.info(module: .app, operation: "ResetErrorStats", details: "Error statistics reset")
    }
}

// MARK: - 预定义恢复行为

extension ErrorHandler {
    
    /// 创建重试恢复行为
    /// - Parameters:
    ///   - title: 行为标题
    ///   - retryAction: 重试的异步操作
    /// - Returns: 恢复行为
    static func createRetryAction(
        title: String = "重试",
        retryAction: @escaping () async throws -> Void
    ) -> RecoveryAction {
        return RecoveryAction(
            title: title,
            description: "重新尝试刚才的操作"
        ) {
            do {
                try await retryAction()
                return true
            } catch {
                return false
            }
        }
    }
    
    /// 创建权限设置恢复行为
    /// - Returns: 权限设置恢复行为
    static func createPermissionSettingsAction() -> RecoveryAction {
        return RecoveryAction(
            title: "前往设置",
            description: "在系统设置中授予权限"
        ) {
            PermissionManager.shared.openSystemSettings()
            return true
        }
    }
    
    /// 创建重启相机恢复行为
    /// - Returns: 重启相机恢复行为
    static func createRestartCameraAction() -> RecoveryAction {
        return RecoveryAction(
            title: "重启相机",
            description: "重新初始化相机系统"
        ) {
            // 这里将来会调用相机管理器的重启方法
            Logger.shared.info(module: .camera, operation: "RestartAction", details: "Camera restart requested")
            return true
        }
    }
    
    /// 创建清理缓存恢复行为
    /// - Returns: 清理缓存恢复行为
    static func createClearCacheAction() -> RecoveryAction {
        return RecoveryAction(
            title: "清理缓存",
            description: "清理应用缓存数据"
        ) {
            // 这里将来会实现缓存清理逻辑
            Logger.shared.info(module: .fileIO, operation: "ClearCache", details: "Cache clearing requested")
            return true
        }
    }
}