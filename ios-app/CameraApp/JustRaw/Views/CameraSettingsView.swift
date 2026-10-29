import SwiftUI
import AVFoundation

/// 相机设置界面
struct CameraSettingsView: View {
    
    @EnvironmentObject var appStateManager: AppStateManager
    @EnvironmentObject var cameraService: CameraService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var tempSettings: AppStateManager.UserSettings
    
    init() {
        // 使用当前设置初始化临时设置
        _tempSettings = State(initialValue: AppStateManager.shared.userSettings)
    }
    
    var body: some View {
        NavigationView {
            List {
                // 拍摄设置
                Section("拍摄设置") {
                    // 默认相机位置
                    Picker("默认相机", selection: $tempSettings.preferredCameraPosition) {
                        Text("后置摄像头").tag(AppStateManager.UserSettings.CameraPosition.back)
                        Text("前置摄像头").tag(AppStateManager.UserSettings.CameraPosition.front)
                    }
                    
                    // 默认闪光灯状态
                    Toggle("默认开启闪光灯", isOn: $tempSettings.preferredFlashMode)
                    
                    // 默认缩放级别
                    VStack(alignment: .leading) {
                        HStack {
                            Text("默认缩放级别")
                            Spacer()
                            Text(String(format: "%.1fx", tempSettings.preferredZoomLevel))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: $tempSettings.preferredZoomLevel,
                            in: 1.0...5.0,
                            step: 0.1
                        )
                    }
                }
                
                // 界面设置
                Section("界面设置") {
                    Toggle("显示网格线", isOn: $tempSettings.showGrid)
                    Toggle("显示水平仪", isOn: $tempSettings.showLevelIndicator)
                    Toggle("自动隐藏控制栏", isOn: $tempSettings.autoHideControls)
                }
                
                // 性能设置
                Section("性能设置") {
                    Toggle("高性能模式", isOn: $tempSettings.highPerformanceMode)
                    Toggle("电池优化", isOn: $tempSettings.batteryOptimization)
                }
                
                // 设备信息
                Section("设备信息") {
                    InfoRow(title: "当前设备", value: cameraService.deviceInfo)
                    InfoRow(title: "RAW支持", value: cameraService.supportsRAWCapture ? "支持" : "不支持")
                    InfoRow(title: "闪光灯支持", value: cameraService.supportsFlash ? "支持" : "不支持")
                    InfoRow(title: "最大缩放", value: String(format: "%.1fx", cameraService.maxZoomFactor))
                    InfoRow(title: "相机状态", value: cameraService.sessionState.description)
                }
                
                // 关于信息
                Section("关于") {
                    InfoRow(title: "应用版本", value: "1.0.0")
                    InfoRow(title: "构建版本", value: "1")
                    InfoRow(title: "iOS版本", value: UIDevice.current.systemVersion)
                    InfoRow(title: "设备型号", value: UIDevice.current.model)
                }
                
                // 重置设置
                Section {
                    Button("重置为默认设置") {
                        resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("相机设置")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("保存") {
                    saveSettings()
                }
                .fontWeight(.semibold)
            )
        }
    }
    
    private func saveSettings() {
        // 应用设置到AppStateManager
        appStateManager.updateFlashPreference(tempSettings.preferredFlashMode)
        appStateManager.updateCameraPositionPreference(tempSettings.preferredCameraPosition)
        appStateManager.updateZoomLevelPreference(tempSettings.preferredZoomLevel)
        appStateManager.updateGridPreference(tempSettings.showGrid)
        appStateManager.updateLevelIndicatorPreference(tempSettings.showLevelIndicator)
        appStateManager.updateAutoHideControlsPreference(tempSettings.autoHideControls)
        appStateManager.updateHighPerformanceModePreference(tempSettings.highPerformanceMode)
        appStateManager.updateBatteryOptimizationPreference(tempSettings.batteryOptimization)
        
        presentationMode.wrappedValue.dismiss()
        
        Logger.shared.info(
            module: .app,
            operation: "SettingsUpdated",
            details: "Camera settings updated successfully"
        )
    }
    
    private func resetToDefaults() {
        tempSettings = AppStateManager.UserSettings()
        
        Logger.shared.info(
            module: .app,
            operation: "SettingsReset",
            details: "Settings reset to defaults"
        )
    }
}

/// 信息行视图组件
struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    CameraSettingsView()
        .environmentObject(AppStateManager.shared)
        .environmentObject(CameraService.shared)
}