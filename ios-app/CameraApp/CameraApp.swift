import SwiftUI

/// App entry point. From-scratch implementation.
@main
struct CameraApp: App {
    @StateObject private var viewModel = CameraViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onAppear {
                    viewModel.requestCameraPermission()
                }
        }
    }
}
