import SwiftUI

@main
struct JustRawApp: App {
    
    // 应用状态管理
    @StateObject private var appStateManager = AppStateManager.shared
    @StateObject private var permissionManager = PermissionManager.shared
    @StateObject private var cameraService = CameraService.shared
    @StateObject private var errorHandler = ErrorHandler.shared
    
    init() {
        // 记录应用启动日志
        Logger.shared.logAppLaunch()
    }
    
    var body: some Scene {
        WindowGroup {
            CameraView()
                .preferredColorScheme(.dark)
                .environmentObject(appStateManager)
                .environmentObject(permissionManager)  
                .environmentObject(cameraService)
                .environmentObject(errorHandler)
                .onAppear {
                    // 应用启动完成
                    appStateManager.applicationDidBecomeActive()
                    Logger.shared.info(
                        module: .app,
                        operation: "AppAppear",
                        details: "Main content view appeared"
                    )
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    appStateManager.applicationDidBecomeActive()
                    cameraService.applicationDidBecomeActive()
                    Logger.shared.logAppForeground()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    appStateManager.applicationDidEnterBackground()
                    cameraService.applicationDidEnterBackground()
                    Logger.shared.logAppBackground()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    appStateManager.applicationWillResignActive()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    cameraService.applicationWillTerminate()
                    Logger.shared.logAppTerminate()
                }
                .alert("错误", isPresented: $errorHandler.showingErrorAlert) {
                    Button("确定") {
                        errorHandler.clearAllErrors()
                    }
                } message: {
                    if let currentError = errorHandler.currentErrors.first {
                        Text(currentError.message)
                    }
                }
        }
    }
}