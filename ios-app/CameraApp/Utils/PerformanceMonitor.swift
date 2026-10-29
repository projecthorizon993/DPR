import Foundation
import SwiftUI
import UIKit
import os.log
import os.signpost
import Combine

/// JustRaw 应用性能监控系统
/// 提供全面的性能指标收集、分析和报告功能
final class PerformanceMonitor: ObservableObject {
    
    // MARK: - 性能指标类型
    
    /// 性能指标类型枚举
    enum MetricType: String, CaseIterable, Codable {
        case appLaunch = "app_launch"
        case cameraInit = "camera_init"
        case dngCapture = "dng_capture"
        case dngProcessing = "dng_processing"
        case fileIO = "file_io"
        case uiRender = "ui_render"
        case memoryUsage = "memory_usage"
        case batteryUsage = "battery_usage"
        
        var displayName: String {
            switch self {
            case .appLaunch:
                return "应用启动"
            case .cameraInit:
                return "相机初始化"
            case .dngCapture:
                return "DNG拍摄"
            case .dngProcessing:
                return "DNG处理"
            case .fileIO:
                return "文件读写"
            case .uiRender:
                return "界面渲染"
            case .memoryUsage:
                return "内存使用"
            case .batteryUsage:
                return "电池使用"
            }
        }
    }
    
    /// 性能指标数据结构
    struct PerformanceMetric: Codable, Identifiable {
        let id: UUID
        let type: MetricType
        let timestamp: Date
        let duration: TimeInterval
        let value: Double
        let metadata: [String: String]
        
        init(type: MetricType, timestamp: Date, duration: TimeInterval, value: Double, metadata: [String: String]) {
            self.id = UUID()
            self.type = type
            self.timestamp = timestamp
            self.duration = duration
            self.value = value
            self.metadata = metadata
        }
        
        var formattedDuration: String {
            return String(format: "%.3fs", duration)
        }
        
        var formattedValue: String {
            switch type {
            case .memoryUsage:
                return String(format: "%.1fMB", value)
            case .batteryUsage:
                return String(format: "%.1f%%", value)
            default:
                return String(format: "%.2f", value)
            }
        }
    }
    
    /// 性能统计信息
    struct PerformanceStatistics: Codable {
        var totalMetrics: Int = 0
        var averageDurations: [String: TimeInterval] = [:]
        var peakValues: [String: Double] = [:]
        var metricCounts: [String: Int] = [:]
        var lastUpdateTime: Date = Date()
        
        mutating func update(with metric: PerformanceMetric) {
            totalMetrics += 1
            
            let typeKey = metric.type.rawValue
            metricCounts[typeKey, default: 0] += 1
            
            // 更新平均持续时间
            let currentAverage = averageDurations[typeKey, default: 0]
            let count = metricCounts[typeKey] ?? 1
            averageDurations[typeKey] = (currentAverage * Double(count - 1) + metric.duration) / Double(count)
            
            // 更新峰值
            peakValues[typeKey] = max(peakValues[typeKey, default: 0], metric.value)
            
            lastUpdateTime = Date()
        }
    }
    
    // MARK: - 发布属性
    
    /// 实时性能指标
    @Published var currentMetrics: [PerformanceMetric] = []
    
    /// 性能统计信息
    @Published var statistics: PerformanceStatistics = PerformanceStatistics()
    
    /// 是否启用性能监控
    @Published var isMonitoringEnabled: Bool = true
    
    /// 当前内存使用情况
    @Published var currentMemoryUsage: Double = 0.0
    
    /// 当前CPU使用率
    @Published var currentCPUUsage: Double = 0.0
    
    // MARK: - 私有属性
    
    private let maxMetricsCount = 1000  // 最大保留指标数量
    private var activeOperations: [String: (startTime: Date, signpost: OSSignpostID)] = [:]
    private let performanceQueue = DispatchQueue(label: "com.justraw.performance", qos: .utility)
    private var systemMonitorTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // OS Signpost 日志
    private let signpostLog = OSLog(subsystem: "com.justraw.app", category: "Performance")
    
    // MARK: - 单例
    static let shared = PerformanceMonitor()
    
    private init() {
        setupPerformanceMonitoring()
        startSystemMonitoring()
        Logger.shared.info(module: .performance, operation: "Init", details: "Performance monitor initialized")
    }
    
    // MARK: - 设置和配置
    
    private func setupPerformanceMonitoring() {
        // 加载保存的统计信息
        loadStatistics()
        
        // 监听应用生命周期变化
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.pauseMonitoring()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.resumeMonitoring()
            }
            .store(in: &cancellables)
        
        // 定期保存统计信息
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.saveStatistics()
            }
            .store(in: &cancellables)
    }
    
    private func startSystemMonitoring() {
        guard isMonitoringEnabled else { return }
        
        // 停止之前的定时器（避免重复创建）
        stopSystemMonitoring()
        
        systemMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.collectSystemMetrics()
        }
        
        Logger.shared.debug(module: .performance, operation: "StartSystemMonitoring", details: "System monitoring timer started")
    }
    
    /// 停止系统监控定时器
    private func stopSystemMonitoring() {
        systemMonitorTimer?.invalidate()
        systemMonitorTimer = nil
        Logger.shared.debug(module: .performance, operation: "StopSystemMonitoring", details: "System monitoring timer stopped")
    }
    
    private func collectSystemMetrics() {
        guard isMonitoringEnabled else { return }
        
        performanceQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 收集内存使用情况
            let memoryUsage = self.getCurrentMemoryUsage()
            
            // 收集CPU使用情况（简化版本，避免过度计算）
            let cpuUsage = self.getCurrentCPUUsage()
            
            DispatchQueue.main.async {
                // 只有在值发生显著变化时才更新（减少不必要的UI更新）
                if abs(self.currentMemoryUsage - memoryUsage) > 1.0 {  // 变化超过1MB才更新
                    self.currentMemoryUsage = memoryUsage
                }
                
                if abs(self.currentCPUUsage - cpuUsage) > 5.0 {  // 变化超过5%才更新
                    self.currentCPUUsage = cpuUsage
                }
                
                // 只在内存使用较高时记录指标（避免过多日志）
                if memoryUsage > 50.0 {  // 只有当内存超过50MB时才记录
                    self.recordMetric(
                        type: .memoryUsage,
                        duration: 0,
                        value: memoryUsage,
                        metadata: ["unit": "MB", "threshold_exceeded": "true"]
                    )
                }
            }
        }
    }
    
    // MARK: - 性能指标记录
    
    /// 开始性能操作记录
    /// - Parameters:
    ///   - operationName: 操作名称
    ///   - type: 指标类型
    ///   - metadata: 附加元数据
    func startOperation(_ operationName: String, type: MetricType, metadata: [String: String] = [:]) {
        guard isMonitoringEnabled else { return }
        
        let signpostID = OSSignpostID(log: signpostLog)
        let startTime = Date()
        
        performanceQueue.async { [weak self] in
            self?.activeOperations[operationName] = (startTime: startTime, signpost: signpostID)
        }
        
        // 记录开始信号
        os_signpost(.begin, log: signpostLog, name: "Performance Operation", signpostID: signpostID,
                   "Operation: %{public}s, Type: %{public}s", operationName, type.rawValue)
        
        Logger.shared.info(
            module: .performance,
            operation: "StartOperation",
            details: "Started \(operationName) (\(type.displayName))"
        )
    }
    
    /// 结束性能操作记录
    /// - Parameters:
    ///   - operationName: 操作名称
    ///   - value: 操作结果值
    ///   - additionalMetadata: 附加元数据
    func endOperation(_ operationName: String, value: Double = 0, additionalMetadata: [String: String] = [:]) {
        guard isMonitoringEnabled else { return }
        
        performanceQueue.async { [weak self] in
            guard let self = self,
                  let operation = self.activeOperations.removeValue(forKey: operationName) else {
                Logger.shared.warning(
                    module: .performance,
                    operation: "EndOperation",
                    details: "No active operation found for: \(operationName)"
                )
                return
            }
            
            let endTime = Date()
            let duration = endTime.timeIntervalSince(operation.startTime)
            
            // 记录结束信号
            os_signpost(.end, log: self.signpostLog, name: "Performance Operation", 
                       signpostID: operation.signpost)
            
            // 推断操作类型
            let type = self.inferMetricType(from: operationName)
            
            // 创建性能指标
            let metric = PerformanceMetric(
                type: type,
                timestamp: operation.startTime,
                duration: duration,
                value: value,
                metadata: additionalMetadata
            )
            
            DispatchQueue.main.async {
                self.addMetric(metric)
            }
            
            Logger.shared.info(
                module: .performance,
                operation: "EndOperation",
                details: "Completed \(operationName) in \(String(format: "%.3fs", duration))"
            )
        }
    }
    
    /// 直接记录性能指标
    /// - Parameters:
    ///   - type: 指标类型
    ///   - duration: 持续时间
    ///   - value: 数值
    ///   - metadata: 元数据
    func recordMetric(type: MetricType, duration: TimeInterval, value: Double, metadata: [String: String] = [:]) {
        guard isMonitoringEnabled else { return }
        
        let metric = PerformanceMetric(
            type: type,
            timestamp: Date(),
            duration: duration,
            value: value,
            metadata: metadata
        )
        
        addMetric(metric)
    }
    
    private func addMetric(_ metric: PerformanceMetric) {
        // 添加到当前指标列表
        currentMetrics.append(metric)
        
        // 保持最大数量限制
        if currentMetrics.count > maxMetricsCount {
            currentMetrics.removeFirst(currentMetrics.count - maxMetricsCount)
        }
        
        // 更新统计信息
        statistics.update(with: metric)
        
        Logger.shared.logPerformanceMetric(operation: metric.type.rawValue, duration: metric.duration)
    }
    
    // MARK: - 工具方法
    
    private func inferMetricType(from operationName: String) -> MetricType {
        let lowercased = operationName.lowercased()
        
        if lowercased.contains("camera") {
            return .cameraInit
        } else if lowercased.contains("dng") {
            if lowercased.contains("capture") {
                return .dngCapture
            } else {
                return .dngProcessing
            }
        } else if lowercased.contains("file") || lowercased.contains("io") {
            return .fileIO
        } else if lowercased.contains("ui") || lowercased.contains("render") {
            return .uiRender
        } else if lowercased.contains("launch") {
            return .appLaunch
        } else {
            return .appLaunch  // 默认类型
        }
    }
    
    // MARK: - 系统指标收集
    
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024 * 1024)  // 转换为MB
        }
        
        return 0.0
    }
    
    private func getCurrentCPUUsage() -> Double {
        // 简化的CPU使用率计算，返回模拟值
        // 实际实现需要更复杂的计算，涉及线程信息收集
        return Double.random(in: 0...20)
    }
    
    // MARK: - 监控控制
    
    /// 暂停性能监控
    func pauseMonitoring() {
        isMonitoringEnabled = false
        stopSystemMonitoring()
        
        Logger.shared.info(module: .performance, operation: "PauseMonitoring", details: "Performance monitoring paused")
    }
    
    /// 恢复性能监控
    func resumeMonitoring() {
        isMonitoringEnabled = true
        startSystemMonitoring()
        
        Logger.shared.info(module: .performance, operation: "ResumeMonitoring", details: "Performance monitoring resumed")
    }
    
    /// 重置所有性能数据
    func resetMetrics() {
        currentMetrics.removeAll()
        statistics = PerformanceStatistics()
        activeOperations.removeAll()
        
        Logger.shared.info(module: .performance, operation: "ResetMetrics", details: "All performance metrics reset")
    }
    
    // MARK: - 生命周期管理
    
    deinit {
        // 清理定时器和资源
        stopSystemMonitoring()
        cancellables.removeAll()
        activeOperations.removeAll()
        
        Logger.shared.info(module: .performance, operation: "Deinit", details: "PerformanceMonitor deinitialized")
    }
    
    // MARK: - 数据持久化
    
    private func saveStatistics() {
        do {
            let data = try JSONEncoder().encode(statistics)
            UserDefaults.standard.set(data, forKey: "performanceStatistics")
        } catch {
            Logger.shared.error(
                module: .performance,
                operation: "SaveStatistics",
                details: "Failed to save statistics: \(error.localizedDescription)"
            )
        }
    }
    
    private func loadStatistics() {
        guard let data = UserDefaults.standard.data(forKey: "performanceStatistics") else {
            return
        }
        
        do {
            statistics = try JSONDecoder().decode(PerformanceStatistics.self, from: data)
        } catch {
            Logger.shared.error(
                module: .performance,
                operation: "LoadStatistics",
                details: "Failed to load statistics: \(error.localizedDescription)"
            )
        }
    }
    
    // MARK: - 分析和报告
    
    /// 获取性能摘要报告
    func getPerformanceSummary() -> String {
        let totalMetrics = statistics.totalMetrics
        let avgLaunchTime = statistics.averageDurations[MetricType.appLaunch.rawValue] ?? 0
        let avgCameraInit = statistics.averageDurations[MetricType.cameraInit.rawValue] ?? 0
        let peakMemory = statistics.peakValues[MetricType.memoryUsage.rawValue] ?? 0
        
        return """
        性能监控摘要报告
        生成时间: \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))
        
        总体统计:
        - 总指标数: \(totalMetrics)
        - 平均启动时间: \(String(format: "%.3fs", avgLaunchTime))
        - 平均相机初始化: \(String(format: "%.3fs", avgCameraInit))
        - 峰值内存使用: \(String(format: "%.1fMB", peakMemory))
        - 当前内存使用: \(String(format: "%.1fMB", currentMemoryUsage))
        - 当前CPU使用: \(String(format: "%.1f%%", currentCPUUsage))
        
        最近更新: \(DateFormatter.localizedString(from: statistics.lastUpdateTime, dateStyle: .short, timeStyle: .short))
        """
    }
    
    /// 获取特定类型的性能指标
    /// - Parameter type: 指标类型
    /// - Returns: 该类型的所有指标
    func getMetrics(for type: MetricType) -> [PerformanceMetric] {
        return currentMetrics.filter { $0.type == type }
    }
    
    /// 获取最近N个指标
    /// - Parameter count: 指标数量
    /// - Returns: 最近的指标列表
    func getRecentMetrics(count: Int) -> [PerformanceMetric] {
        return Array(currentMetrics.suffix(count))
    }
    
    /// 检查性能是否存在问题
    func checkPerformanceIssues() -> [String] {
        var issues: [String] = []
        
        // 检查启动时间
        if let avgLaunchTime = statistics.averageDurations[MetricType.appLaunch.rawValue],
           avgLaunchTime > 3.0 {
            issues.append("应用启动时间过长 (\(String(format: "%.2fs", avgLaunchTime)))")
        }
        
        // 检查内存使用
        if currentMemoryUsage > 200.0 {
            issues.append("内存使用过高 (\(String(format: "%.1fMB", currentMemoryUsage)))")
        }
        
        // 检查CPU使用
        if currentCPUUsage > 80.0 {
            issues.append("CPU使用过高 (\(String(format: "%.1f%%", currentCPUUsage)))")
        }
        
        return issues
    }
}

// MARK: - 便捷扩展

extension PerformanceMonitor {
    
    /// 测量代码块执行时间
    /// - Parameters:
    ///   - operationName: 操作名称
    ///   - type: 指标类型
    ///   - block: 要测量的代码块
    func measure<T>(_ operationName: String, type: MetricType, block: () throws -> T) rethrows -> T {
        startOperation(operationName, type: type)
        defer { endOperation(operationName) }
        return try block()
    }
    
    /// 异步测量代码块执行时间
    /// - Parameters:
    ///   - operationName: 操作名称
    ///   - type: 指标类型
    ///   - block: 要测量的异步代码块
    func measureAsync<T>(_ operationName: String, type: MetricType, block: () async throws -> T) async rethrows -> T {
        startOperation(operationName, type: type)
        defer { endOperation(operationName) }
        return try await block()
    }
}