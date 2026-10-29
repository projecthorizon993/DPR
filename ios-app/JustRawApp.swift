import SwiftUI

@main
struct JustRawApp: App {

    @StateObject private var appStateManager = AppStateManager.shared
    @StateObject private var permissionManager = PermissionManager.shared
    @StateObject private var cameraService = CameraService.shared
    @StateObject private var errorHandler = ErrorHandler.shared

    init() {
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
                    appStateManager.applicationDidBecomeActive()
                    Logger.shared.info("App appeared")
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
                .alert("Camera Error", isPresented: $errorHandler.showingErrorAlert) {
                    Button("OK") {
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
