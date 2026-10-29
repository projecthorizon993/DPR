import AppIntents

/// 启动JustRaw应用的Intent
/// 设置openAppWhenRun = true让系统自动打开应用
/// 
/// 注意：此文件需要同时设置为主应用和Widget Extension的Target Membership
@available(iOS 18.0, *)
struct LaunchJustRawIntent: AppIntent {
    static let title: LocalizedStringResource = "启动JustRaw"
    static var openAppWhenRun = true  // 关键设置：点击控件时自动打开应用
    static var isDiscoverable = true  // 让Intent可以被系统发现
    
    func perform() async throws -> some IntentResult {
        // 简单返回，系统会自动打开主应用
        // 由于JustRaw打开就是相机界面，不需要额外的深链接处理
        Logger.shared.info(
            module: .camera,
            operation: "WidgetLaunch",
            details: "JustRaw launched from lock screen control widget"
        )
        
        return .result()
    }
}