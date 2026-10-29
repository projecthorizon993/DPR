import SwiftUI

struct ContentView: View {
    
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var appStateManager: AppStateManager
    @EnvironmentObject var cameraService: CameraService
    
    @State private var showingCamera = false
    @State private var isCheckingPermissions = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // 应用标题
                    VStack(spacing: 12) {
                        Text("JustRaw")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("专业 RAW 相机")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    
                    // 功能介绍
                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(icon: "camera.aperture", text: "绕过 Apple 计算摄影算法")
                        FeatureRow(icon: "doc.badge.camera", text: "直接拍摄 DNG 格式照片")
                        FeatureRow(icon: "iphone", text: "专为 iPhone 13 mini 优化")
                        FeatureRow(icon: "hand.tap", text: "手动对焦与全局测光")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                    
                    // 开始拍照按钮
                    Button(action: startCamera) {
                        HStack {
                            if isCheckingPermissions {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                            }
                            
                            Text(isCheckingPermissions ? "检查权限中..." : "开始拍照")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isCheckingPermissions ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isCheckingPermissions)
                    
                    // 权限状态指示
                    if !permissionManager.areAllPermissionsGranted {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("需要相机和相册权限")
                                    .foregroundColor(.orange)
                                    .font(.subheadline)
                            }
                            
                            Button("前往设置") {
                                openAppSettings()
                            }
                            .foregroundColor(.blue)
                            .font(.subheadline)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    // 版本信息
                    Text("v1.0.0 - 开发中")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView()
        }
        .onAppear {
            // 应用启动时自动检查权限
            Task {
                await checkAndRequestPermissions()
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func startCamera() {
        isCheckingPermissions = true
        
        Task {
            await checkAndRequestPermissions()
            
            DispatchQueue.main.async {
                isCheckingPermissions = false
                
                if permissionManager.areAllPermissionsGranted {
                    showingCamera = true
                } else {
                    // 权限被拒绝，显示提示
                }
            }
        }
    }
    
    private func checkAndRequestPermissions() async {
        await permissionManager.requestAllPermissions()
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

/// 功能特性行组件
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 20)
            
            Text(text)
                .foregroundColor(.white)
                .font(.body)
            
            Spacer()
        }
    }
}

#Preview {
    ContentView()
}