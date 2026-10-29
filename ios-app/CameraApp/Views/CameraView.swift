import SwiftUI
import AVFoundation

/// 主相机界面
/// 集成相机预览、控制按钮和拍摄功能
struct CameraView: View {
    
    @EnvironmentObject var cameraService: CameraService
    @EnvironmentObject var appStateManager: AppStateManager
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var errorHandler: ErrorHandler
    @StateObject private var photoSaveService = PhotoSaveService.shared
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.openURL) var openURL
    
    // 相机预览状态
    @State private var previewLayer: AVCaptureVideoPreviewLayer?
    
    // UI状态
    @State private var showingControls = true
    @State private var isCapturing = false
    @State private var isProcessingRAW = false
    
    // 对焦和曝光
    @State private var focusPoint: CGPoint?
    @State private var exposurePoint: CGPoint?
    @State private var showingFocusIndicator = false
    @State private var showingExposureIndicator = false
    
    // 移除水平仪相关状态
    
    // 设备方向状态
    @State private var deviceOrientation: UIDeviceOrientation = .portrait
    @State private var isLandscape: Bool = false
    
    // 自动隐藏控制栏的计时器
    @State private var hideControlsTimer: Timer?
    
    // 变焦状态管理
    @State private var currentZoomFactor: CGFloat = 1.0       // 当前实际变焦倍数
    @State private var lastScaleValue: CGFloat = 1.0          // 上次手势缩放值
    @State private var showingZoomIndicator = false           // 显示变焦指示器
    @State private var showingZoomSlider = true               // 默认显示变焦滑块
    @State private var targetCropRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1) // 拍摄时的裁剪区域（保留给RAW处理用）
    
    // RAW处理服务
    @StateObject private var rawProcessor = RAWProcessorService.shared
    
    // 色彩风格选择器
    @State private var selectedStyle: CameraStyle = .natural
    @State private var showingStylePicker = false
    
    // 错误反馈状态
    @State private var showingEnhancedError = false
    @State private var currentErrorInfo: CaptureErrorInfo?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 相机预览 - 固定3:4宽高比容器
            GeometryReader { geometry in
                VStack {
                    Spacer() // 上方留空间给控制栏
                    
                    // 固定比例的预览容器
                    ZStack {
                        // 预览层
                        if cameraService.sessionState == .running {
                            CameraPreviewView(
                                session: cameraService.cameraSession,
                                previewLayer: $previewLayer
                            )
                            .onTapGesture(coordinateSpace: .local) { location in
                                handleTapInPreview(at: location, containerSize: geometry.size)
                            }
                            .onTapGesture(count: 2) {
                                // 双击切换连续变焦控制
                                toggleZoomSlider()
                            }
                            .simultaneousGesture(
                                // 使用simultaneousGesture解决iOS 18手势冲突问题
                                MagnificationGesture(minimumScaleDelta: 0.1)
                                    .onChanged { value in
                                        handleZoomGesture(value)
                                    }
                                    .onEnded { value in
                                        handleZoomGestureEnded(value)
                                    }
                            )
                        } else {
                            // 预览未就绪时显示占位符
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    VStack {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        Text("初始化相机...")
                                            .foregroundColor(.white)
                                            .padding(.top, 8)
                                    }
                                )
                        }
                        
                        // 网格线
                        GridLinesView(isVisible: appStateManager.userSettings.showGrid)
                        
                        // 对焦指示器
                        if showingFocusIndicator, let focusPoint = focusPoint {
                            FocusIndicatorView(position: focusPoint)
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        showingFocusIndicator = false
                                    }
                                }
                        }
                        
                        // 曝光指示器
                        if showingExposureIndicator, let exposurePoint = exposurePoint {
                            ExposureIndicatorView(position: exposurePoint)
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        showingExposureIndicator = false
                                    }
                                }
                        }
                        
                        // 简洁的变焦指示器 - 纯数字显示
                        if showingZoomIndicator && currentZoomFactor != 1.0 {
                            VStack {
                                HStack {
                                    Spacer()
                                    
                                    Text("\(String(format: "%.1f", currentZoomFactor))×")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 1)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.black.opacity(0.7))
                                        )
                                        .padding(.top, 20)
                                        .padding(.trailing, 20)
                                }
                                
                                Spacer()
                            }
                        }
                        
                    }
                    .aspectRatio(getCurrentAspectRatio(), contentMode: .fit) // 动态比例
                    .background(Color.black) // 黑色背景
                    .clipped() // 裁剪超出的内容
                    
                    Spacer() // 下方留空间给控制栏
                }
            }
            
            // 控制栏覆盖层
            VStack {
                // 顶部控制栏（固定在顶部）
                if showingControls {
                    topControlBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 50) // 给状态栏留空间
                }
                
                Spacer()
                
                // 变焦滑块控制（位于底部控制栏上方）
                if showingZoomSlider {
                    ZoomSliderControl(
                        currentZoomFactor: $currentZoomFactor,
                        isVisible: $showingZoomSlider,
                        minZoom: 0.5,
                        maxZoom: min(10.0, cameraService.maxZoomFactor)
                    ) { newZoom in
                        handleContinuousZoomChange(newZoom)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 8)
                }
                
                // 底部控制栏（固定在底部）
                if showingControls {
                    bottomControlBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 40) // 给家庭指示器留空间
                }
            }
            .padding(.horizontal, 16) // 只添加水平边距
            
            // 拍摄、处理和保存状态覆盖层
            if isCapturing || isProcessingRAW || photoSaveService.isSaving {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay(
                        VStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            if isCapturing && !isProcessingRAW && !photoSaveService.isSaving {
                                Text("正在拍摄RAW...")
                                    .foregroundColor(.white)
                                    .font(.headline)
                                    .padding(.top, 16)
                            } else if isProcessingRAW && !photoSaveService.isSaving {
                                VStack(spacing: 8) {
                                    Text("正在处理RAW数据...")
                                        .foregroundColor(.white)
                                        .font(.headline)
                                    
                                    if currentZoomFactor > 1.0 {
                                        Text("创建裁剪JPEG（\(String(format: "%.1f", currentZoomFactor))x变焦）")
                                            .foregroundColor(.white.opacity(0.8))
                                            .font(.subheadline)
                                            .padding(.top, 4)
                                    } else {
                                        Text("准备保存原始RAW文件")
                                            .foregroundColor(.white.opacity(0.8))
                                            .font(.subheadline)
                                            .padding(.top, 4)
                                    }
                                }
                                .padding(.top, 16)
                            } else if photoSaveService.isSaving {
                                VStack(spacing: 8) {
                                    Text("保存到相册...")
                                        .foregroundColor(.white)
                                        .font(.headline)
                                    
                                    Text(photoSaveService.statusDescription)
                                        .foregroundColor(.white.opacity(0.8))
                                        .font(.subheadline)
                                        .padding(.top, 4)
                                    
                                    // 保存进度条
                                    ProgressView(value: photoSaveService.saveProgress)
                                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                                        .frame(width: 200)
                                        .padding(.top, 8)
                                }
                                .padding(.top, 16)
                            }
                        }
                    )
            }
            
            // 保存成功提示
            if photoSaveService.isCompleted {
                VStack {
                    Spacer()
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        if currentZoomFactor > 1.0 {
                            Text("双照片已保存：原始RAW + 裁剪JPEG")
                                .foregroundColor(.white)
                                .font(.headline)
                        } else {
                            Text("RAW照片已保存到相册")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // ── Style Applied badge (top-right, Xiaomi style) ──
            if selectedStyle != .natural {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(selectedStyle.accentColor)
                                .frame(width: 6, height: 6)
                            Text("STYLE APPLIED")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(selectedStyle.accentColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.black.opacity(0.7)))
                    }
                    .padding(.top, 12)
                    .padding(.trailing, 16)
                    Spacer()
                }
                .ignoresSafeArea()
            }
            
            // 保存失败提示
            if photoSaveService.hasFailed, let error = photoSaveService.lastError {
                VStack {
                    Spacer()
                    
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                        
                        VStack(alignment: .leading) {
                            Text("照片保存失败")
                                .foregroundColor(.white)
                                .font(.headline)
                            
                            Text(error.localizedDescription)
                                .foregroundColor(.white.opacity(0.8))
                                .font(.caption)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 增强的错误反馈覆盖层
            if showingEnhancedError, let errorInfo = currentErrorInfo {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            // 错误图标
                            Image(systemName: errorInfo.iconName)
                                .foregroundColor(errorInfo.iconColor)
                                .font(.system(size: 48))
                            
                            // 错误标题
                            Text(errorInfo.title)
                                .foregroundColor(.white)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.center)
                            
                            // 错误描述
                            Text(errorInfo.userMessage)
                                .foregroundColor(.white.opacity(0.9))
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            
                            // 操作按钮
                            HStack(spacing: 16) {
                                // 重试按钮（如果支持重试）
                                if errorInfo.canRetry {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            showingEnhancedError = false
                                        }
                                        // 等待动画完成后重试拍摄
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            capturePhoto()
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "arrow.clockwise")
                                            Text("重试")
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.blue)
                                        .cornerRadius(8)
                                    }
                                }
                                
                                // 关闭按钮
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showingEnhancedError = false
                                        currentErrorInfo = nil
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "xmark")
                                        Text("关闭")
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.gray.opacity(0.7))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.9))
                        )
                        .padding(.horizontal, 32)
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden()
        .onAppear {
            setupCamera()
            updateDeviceOrientation() // 初始化方向状态
        }
        .onDisappear {
            hideControlsTimer?.invalidate()
            NotificationCenter.default.removeObserver(self)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            updateDeviceOrientation()
        }
        // 移除设置页面
    }
    
    // MARK: - 顶部控制栏
    
    private var topControlBar: some View {
        HStack {
            // 连续变焦控制切换按钮（左上角）
            Button(action: toggleZoomSlider) {
                Image(systemName: showingZoomSlider ? "hand.tap.fill" : "hand.point.up.left.fill")
                    .foregroundColor(showingZoomSlider ? .blue : .white)
                    .font(.title2)
                    .padding(10)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .disabled(isCapturing)
            
            Spacer()
            
            // RAW模式固定显示
            Text("RAW照片")
                .foregroundColor(.white)
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.5))
                .cornerRadius(20)
            
            Spacer()
            
            // 切换相机按钮（右上角）
            Button(action: switchCamera) {
                Image(systemName: "camera.rotate.fill")
                    .foregroundColor(.white)
                    .font(.title2)
                    .padding(10)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .disabled(isCapturing)
        }
        .background(Color.clear) // 透明背景
    }
    
    // MARK: - 底部控制栏
    
    private var bottomControlBar: some View {
        HStack(spacing: 30) {
            // 相册访问按钮（跳转到系统相册应用）
            Button(action: openPhotosApp) {
                Image(systemName: "photo.on.rectangle")
                    .foregroundColor(.white)
                    .font(.title2)
                    .padding(16)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // 拍摄按钮（放大以突出重要性）
            Button(action: capturePhoto) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 5)
                        .frame(width: 90, height: 90)
                    
                    Circle()
                        .fill(isCapturing ? Color.gray : Color.white)
                        .frame(width: 70, height: 70)
                }
            }
            .disabled(isCapturing || isProcessingRAW || photoSaveService.isSaving || !cameraService.canCapture)
            .scaleEffect(isCapturing ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isCapturing)
            
            Spacer()
            
            // 闪光灯按钮
            Button(action: toggleFlash) {
                Image(systemName: cameraService.isFlashEnabled ? "bolt.fill" : "bolt.slash.fill")
                    .foregroundColor(cameraService.isFlashEnabled ? .yellow : .white)
                    .font(.title2)
                    .padding(16)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .disabled(!cameraService.supportsFlash)
            .opacity(cameraService.supportsFlash ? 1.0 : 0.5)
            
            Spacer()
            
            // 样式选择按钮（Xiaomi风格，右下角）
            Button(action: { showingStylePicker = true }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 70, height: 70)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(selectedStyle.accentColor)
                            .frame(width: 11, height: 11)
                        Text(selectedStyle.shortName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingStylePicker) {
                StylePickerView(selectedStyle: $selectedStyle)
            }
        }
        .background(Color.clear) // 透明背景
    }
    
    // MARK: - 相机控制方法
    
    private func setupCamera() {
        Task {
            do {
                try await cameraService.configureSession()
                await cameraService.startSession()
                
                // 延迟显示控制界面，确保相机启动完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    resetHideControlsTimer()
                }
                
            } catch {
                errorHandler.handleError(
                    error,
                    category: .camera,
                    severity: .high,
                    context: ["action": "setup"]
                )
            }
        }
    }
    
    private func capturePhoto() {
        guard !isCapturing else { return }
        guard !isProcessingRAW else { return }
        guard !photoSaveService.isSaving else {
            // 如果正在保存照片，显示提示
            Logger.shared.warning(module: .camera, operation: "CapturePhoto", details: "Previous photo still saving")
            return
        }
        
        withAnimation(.easeInOut(duration: 0.1)) {
            isCapturing = true
        }
        
        Task {
            do {
                // 步骤1：使用变焦重置RAW拍摄（避免Apple约束）
                Logger.shared.info(
                    module: .camera,
                    operation: "RAWCaptureStart",
                    details: "Starting RAW capture with current zoom: \(String(format: "%.2f", currentZoomFactor))x, crop rect: \(targetCropRect)"
                )
                
                let result = try await cameraService.captureRAWWithZoomReset(originalZoomFactor: currentZoomFactor)
                
                Logger.shared.info(
                    module: .camera, 
                    operation: "RAWCaptureComplete", 
                    details: "RAW photo captured: \(result.formattedFileSize), starting processing"
                )
                
                // 步骤2：检验RAW数据
                guard let rawData = result.rawPhotoData else {
                    throw CameraService.CameraError.captureError("没有RAW数据")
                }
                
                // 步骤3：RAW处理 - 生成裁剪的JPEG（只有在用户变焦时才处理）
                var croppedJPEGData: Data?
                
                // 在主线程更新UI状态
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isCapturing = false
                        isProcessingRAW = true
                    }
                }
                
                if currentZoomFactor > 1.0 {
                    Logger.shared.info(
                        module: .camera,
                        operation: "RAWProcessStart",
                        details: "Processing RAW for zoom \(String(format: "%.2f", currentZoomFactor))x with crop rect: \(targetCropRect)"
                    )
                    
                    croppedJPEGData = try await rawProcessor.processRAWToJPEG(
                        rawData,
                        cropRect: targetCropRect,
                        style: selectedStyle
                    )
                    
                    Logger.shared.info(
                        module: .camera,
                        operation: "RAWProcessComplete",
                        details: "RAW processing completed, JPEG size: \(croppedJPEGData?.count ?? 0 / 1024)KB"
                    )
                } else {
                    Logger.shared.info(
                        module: .camera,
                        operation: "RAWProcessSkip",
                        details: "No zoom applied, skipping RAW processing"
                    )
                }
                
                // 在主线程停止RAW处理状态
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isProcessingRAW = false
                    }
                }
                
                // 步骤4：保存照片到相册
                let assetID: String
                
                if let jpegData = croppedJPEGData {
                    // 保存双照片：原始RAW + 裁剪JPEG
                    assetID = try await photoSaveService.saveDualPhotos(
                        originalRAW: rawData, 
                        croppedJPEG: jpegData, 
                        metadata: result.metadata
                    )
                    
                    Logger.shared.info(
                        module: .camera,
                        operation: "DualPhotosSaved",
                        details: "Saved dual photos: original RAW + cropped JPEG, Asset ID: \(assetID)"
                    )
                } else {
                    // 只保存原始RAW
                    assetID = try await photoSaveService.saveRAWPhoto(
                        rawData: rawData, 
                        metadata: result.metadata
                    )
                    
                    Logger.shared.info(
                        module: .camera,
                        operation: "RAWPhotoSaved",
                        details: "Saved original RAW only, Asset ID: \(assetID)"
                    )
                }
                
                // 步骤5：在主线程更新UI
                await MainActor.run {
                    showCaptureAndSaveSuccess(result: result, assetID: assetID)
                    
                    // 确保所有状态都已重置
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isCapturing = false
                        isProcessingRAW = false
                    }
                }
                
            } catch {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isCapturing = false
                        isProcessingRAW = false
                    }
                }
                
                // 增强的错误处理（拍摄、处理或保存）
                let errorInfo = analyzeError(error, userZoom: currentZoomFactor)
                
                errorHandler.handleError(
                    error,
                    category: errorInfo.category,
                    severity: errorInfo.severity,
                    context: [
                        "action": "captureRAWAndProcess",
                        "stage": errorInfo.stage,
                        "currentZoom": String(format: "%.2f", currentZoomFactor),
                        "cropRect": "\(targetCropRect)",
                        "errorType": errorInfo.type,
                        "canRetry": "\(errorInfo.canRetry)"
                    ]
                )
                
                Logger.shared.error(
                    module: .camera,
                    operation: "CaptureError",
                    details: "RAW capture failed: \(errorInfo.userMessage) (Stage: \(errorInfo.stage), Type: \(errorInfo.type))"
                )
                
                // 显示用户友好的错误信息
                await MainActor.run {
                    showEnhancedErrorFeedback(errorInfo)
                }
            }
        }
    }
    
    private func switchCamera() {
        Task {
            do {
                try await cameraService.switchCamera()
            } catch {
                errorHandler.handleError(
                    error,
                    category: .camera,
                    severity: .medium,
                    context: ["action": "switch"]
                )
            }
        }
    }
    
    private func toggleFlash() {
        cameraService.toggleFlash()
    }
    
    private func openPhotosApp() {
        guard let url = URL(string: "photos-navigation://") else {
            Logger.shared.error(
                module: .app,
                operation: "OpenPhotosApp",
                details: "Invalid Photos URL scheme"
            )
            return
        }
        
        openURL(url) { success in
            if success {
                Logger.shared.info(
                    module: .app,
                    operation: "OpenPhotosApp",
                    details: "Successfully opened Photos app"
                )
            } else {
                Logger.shared.warning(
                    module: .app,
                    operation: "OpenPhotosApp",
                    details: "Failed to open Photos app with photos-navigation:// scheme"
                )
            }
        }
    }
    
    /// 处理预览区域内的点击事件
    /// - Parameters:
    ///   - location: 点击位置（相对于预览容器）
    ///   - containerSize: 整个容器尺寸
    private func handleTapInPreview(at location: CGPoint, containerSize: CGSize) {
        let previewSize = getPreviewSize(for: containerSize)
        
        // 计算预览区域在容器中的位置（居中）
        let previewOriginX = (containerSize.width - previewSize.width) / 2
        let previewOriginY = (containerSize.height - previewSize.height) / 2
        
        // 检查点击是否在预览区域内
        let adjustedLocation = CGPoint(
            x: location.x - previewOriginX,
            y: location.y - previewOriginY
        )
        
        // 验证点击是否在预览区域边界内
        guard adjustedLocation.x >= 0 && adjustedLocation.x <= previewSize.width &&
              adjustedLocation.y >= 0 && adjustedLocation.y <= previewSize.height else {
            return // 点击在预览区域外，忽略
        }
        
        // 转换到相机设备坐标系 (0.0-1.0)
        let devicePoint = CGPoint(
            x: adjustedLocation.x / previewSize.width,
            y: adjustedLocation.y / previewSize.height
        )
        
        // 只设置对焦点，保持全局测光模式
        Task {
            do {
                try await cameraService.setFocusPoint(devicePoint)
                // 注释掉曝光点设置以保持全局测光
                // try await cameraService.setExposurePoint(devicePoint)
                
                DispatchQueue.main.async {
                    // 指示器位置使用原始点击位置（相对于整个容器）
                    self.focusPoint = location
                    // 不设置曝光点UI，因为使用全局测光
                    // self.exposurePoint = location
                    self.showingFocusIndicator = true
                    // 不显示曝光指示器，因为使用全局测光
                    // self.showingExposureIndicator = true
                }
            } catch {
                // 忽略对焦错误（可能是不支持的设备）
                Logger.shared.warning(
                    module: .camera,
                    operation: "HandleTapFocus",
                    details: "Focus setting failed (全局测光模式): \(error.localizedDescription)"
                )
            }
        }
        
        resetHideControlsTimer()
    }
    
    private func handleTap(at location: CGPoint, in size: CGSize) {
        // 旧版本兼容性方法，保留以防其他地方调用
        let devicePoint = CGPoint(
            x: location.x / size.width,
            y: location.y / size.height
        )
        
        Task {
            do {
                try await cameraService.setFocusPoint(devicePoint)
                // 注释掉曝光点设置以保持全局测光
                // try await cameraService.setExposurePoint(devicePoint)
                
                DispatchQueue.main.async {
                    focusPoint = location
                    // 不设置曝光点UI，因为使用全局测光
                    // exposurePoint = location
                    showingFocusIndicator = true
                    // 不显示曝光指示器，因为使用全局测光
                    // showingExposureIndicator = true
                }
            } catch {
                // 忽略对焦错误（全局测光模式）
                Logger.shared.warning(
                    module: .camera,
                    operation: "HandleDoubleTapFocus",
                    details: "Focus setting failed (全局测光模式): \(error.localizedDescription)"
                )
            }
        }
        
        resetHideControlsTimer()
    }
    
    /// 计算预览容器尺寸
    /// - Parameter containerSize: 容器尺寸
    /// - Returns: 预览区域尺寸
    private func getPreviewSize(for containerSize: CGSize) -> CGSize {
        let aspectRatio = getCurrentAspectRatio()
        
        let previewWidth = containerSize.width
        let previewHeight = previewWidth / aspectRatio
        
        // 如果高度超出容器，按高度限制
        if previewHeight > containerSize.height {
            let adjustedHeight = containerSize.height
            let adjustedWidth = adjustedHeight * aspectRatio
            return CGSize(width: adjustedWidth, height: adjustedHeight)
        }
        
        return CGSize(width: previewWidth, height: previewHeight)
    }
    
    /// 获取当前设备方向对应的预览比例
    /// - Returns: 竖屏3:4，横屏4:3
    private func getCurrentAspectRatio() -> CGFloat {
        return isLandscape ? (4.0 / 3.0) : (3.0 / 4.0)
    }
    
    /// 更新设备方向状态
    private func updateDeviceOrientation() {
        let newOrientation = UIDevice.current.orientation
        let wasLandscape = isLandscape
        
        // 更新方向状态
        switch newOrientation {
        case .landscapeLeft, .landscapeRight:
            isLandscape = true
        case .portrait, .portraitUpsideDown:
            isLandscape = false
        default:
            // 保持当前状态不变
            return
        }
        
        deviceOrientation = newOrientation
        
        // 如果方向发生变化，记录日志
        if wasLandscape != isLandscape {
            Logger.shared.info(
                module: .camera,
                operation: "OrientationChange",
                details: "Device orientation changed to \(isLandscape ? "landscape" : "portrait"), aspect ratio: \(getCurrentAspectRatio())"
            )
        }
    }
    
    /// 处理变焦手势变化 - 使用真实硬件变焦预览
    private func handleZoomGesture(_ value: CGFloat) {
        // 计算增量变化（delta-based scaling）
        let delta = value / lastScaleValue
        
        // 应用阻尼系数，减少敏感度
        let dampingFactor: CGFloat = 0.3
        let adjustedDelta = 1.0 + (delta - 1.0) * dampingFactor
        
        // 计算新的变焦倍数
        let newZoomFactor = currentZoomFactor * adjustedDelta
        
        // 约束到相机支持的范围
        let minZoom: CGFloat = 0.5
        let maxZoom = min(10.0, cameraService.maxZoomFactor) // 使用相机实际支持的最大变焦
        let clampedZoomFactor = max(minZoom, min(maxZoom, newZoomFactor))
        
        // 更新当前变焦倍数
        currentZoomFactor = clampedZoomFactor
        lastScaleValue = value
        
        // 立即应用真实硬件变焦到相机（这会让预览层自动显示变焦效果）
        Task {
            do {
                try await cameraService.setZoomFactor(clampedZoomFactor)
                
                // 计算拍摄时需要的裁剪区域（用于RAW处理）
                await MainActor.run {
                    targetCropRect = rawProcessor.calculateCropRect(
                        for: clampedZoomFactor,
                        imageSize: CGSize(width: 4032, height: 3024) // iPhone 13 mini 主摄分辨率
                    )
                }
                
            } catch {
                Logger.shared.warning(
                    module: .camera,
                    operation: "ZoomGesture", 
                    details: "Failed to apply zoom factor \(String(format: "%.2f", clampedZoomFactor))x: \(error.localizedDescription)"
                )
            }
        }
        
        // 显示变焦指示器
        withAnimation(.easeOut(duration: 0.1)) {
            showingZoomIndicator = true
        }
        
        Logger.shared.info(
            module: .camera,
            operation: "RealZoomGesture",
            details: "Applied real zoom: \(String(format: "%.2f", clampedZoomFactor))x, crop rect: \(targetCropRect)"
        )
        
        resetHideControlsTimer()
    }
    
    /// 处理变焦手势结束
    private func handleZoomGestureEnded(_ value: CGFloat) {
        // 重置手势状态
        lastScaleValue = 1.0
        
        // 延迟隐藏变焦指示器
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.showingZoomIndicator = false
            }
        }
        
        Logger.shared.info(
            module: .camera,
            operation: "RealZoomGestureEnd",
            details: "Final real zoom factor: \(String(format: "%.2f", currentZoomFactor))x"
        )
    }
    
    /// 重置变焦到1.0x
    private func resetZoom() {
        currentZoomFactor = 1.0
        lastScaleValue = 1.0
        targetCropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        
        // 重置硬件变焦
        Task {
            do {
                try await cameraService.setZoomFactor(1.0)
            } catch {
                Logger.shared.warning(
                    module: .camera,
                    operation: "ZoomReset",
                    details: "Failed to reset zoom: \(error.localizedDescription)"
                )
            }
        }
        
        withAnimation(.easeOut(duration: 0.3)) {
            showingZoomIndicator = false
        }
        
        Logger.shared.info(
            module: .camera,
            operation: "RealZoomReset",
            details: "Real zoom reset to 1.0x"
        )
    }
    
    // MARK: - 滑块变焦控制
    
    /// 处理滑块变焦变化
    /// - Parameter newZoom: 新的变焦倍数
    private func handleSliderZoomChange(_ newZoom: CGFloat) {
        // 更新变焦倍数
        currentZoomFactor = newZoom
        
        // 立即应用真实硬件变焦
        Task {
            do {
                try await cameraService.setZoomFactor(newZoom)
                
                // 计算拍摄时需要的裁剪区域（用于RAW处理）
                await MainActor.run {
                    targetCropRect = rawProcessor.calculateCropRect(
                        for: newZoom,
                        imageSize: CGSize(width: 4032, height: 3024) // iPhone 13 mini 主摄分辨率
                    )
                }
                
            } catch {
                Logger.shared.warning(
                    module: .camera,
                    operation: "SliderZoom", 
                    details: "Failed to apply slider zoom factor \(String(format: "%.2f", newZoom))x: \(error.localizedDescription)"
                )
            }
        }
        
        Logger.shared.info(
            module: .camera,
            operation: "SliderZoomChange",
            details: "Applied slider zoom: \(String(format: "%.2f", newZoom))x, crop rect: \(targetCropRect)"
        )
        
        // 重置控制界面隐藏计时器
        resetHideControlsTimer()
    }
    
    /// 处理连续变焦变化（iPhone 16风格）
    /// - Parameter newZoom: 新的变焦倍数
    private func handleContinuousZoomChange(_ newZoom: CGFloat) {
        // 更新变焦倍数
        currentZoomFactor = newZoom
        
        // 立即应用真实硬件变焦
        Task {
            do {
                try await cameraService.setZoomFactor(newZoom)
                
                // 计算拍摄时需要的裁剪区域（用于RAW处理）
                await MainActor.run {
                    targetCropRect = rawProcessor.calculateCropRect(
                        for: newZoom,
                        imageSize: CGSize(width: 4032, height: 3024) // iPhone 13 mini 主摄分辨率
                    )
                }
                
            } catch {
                Logger.shared.warning(
                    module: .camera,
                    operation: "ContinuousZoom", 
                    details: "Failed to apply continuous zoom factor \(String(format: "%.2f", newZoom))x: \(error.localizedDescription)"
                )
            }
        }
        
        Logger.shared.debug(
            module: .camera,
            operation: "ContinuousZoomChange",
            details: "Applied continuous zoom: \(String(format: "%.2f", newZoom))x"
        )
        
        // 重置控制界面隐藏计时器
        resetHideControlsTimer()
    }
    
    /// 切换变焦滑块显示状态
    private func toggleZoomSlider() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showingZoomSlider.toggle()
        }
        
        // 如果显示滑块，隐藏变焦指示器避免重复
        if showingZoomSlider {
            withAnimation(.easeOut(duration: 0.2)) {
                showingZoomIndicator = false
            }
        }
        
        Logger.shared.info(
            module: .camera,
            operation: "ToggleZoomSlider",
            details: "Zoom slider visibility: \(showingZoomSlider)"
        )
        
        resetHideControlsTimer()
    }
    
    private func showCaptureAndSaveSuccess(result: CapturedPhotoResult, assetID: String) {
        // 成功反馈 - 短暂的闪屏效果
        withAnimation(.easeIn(duration: 0.1)) {
            // 可以添加成功反馈UI
        }
        
        Logger.shared.info(
            module: .camera,
            operation: "CaptureAndSaveSuccess",
            details: "RAW photo captured and saved: \(result.formattedFileSize), Asset ID: \(assetID), hasRAW: \(result.hasRawData)"
        )
    }
    
    // MARK: - 控制界面显示/隐藏
    
    private func resetHideControlsTimer() {
        hideControlsTimer?.invalidate()
        
        if !showingControls {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingControls = true
            }
        }
        
        if appStateManager.userSettings.autoHideControls {
            hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingControls = false
                }
            }
        }
    }
    
    // MARK: - 增强的错误处理系统
    
    /// 错误信息结构体
    struct CaptureErrorInfo {
        let title: String
        let userMessage: String
        let stage: String
        let type: String
        let category: ErrorHandler.ErrorCategory
        let severity: ErrorHandler.ErrorSeverity
        let canRetry: Bool
        let iconName: String
        let iconColor: Color
    }
    
    /// 分析错误并生成用户友好的错误信息
    /// - Parameters:
    ///   - error: 原始错误
    ///   - userZoom: 当前用户变焦倍数
    /// - Returns: 结构化的错误信息
    private func analyzeError(_ error: Error, userZoom: CGFloat) -> CaptureErrorInfo {
        
        // 1. RAW处理错误
        if let rawError = error as? RAWProcessorError {
            switch rawError {
            case .invalidRAWData:
                return CaptureErrorInfo(
                    title: "RAW数据处理失败",
                    userMessage: "相机捕获的RAW数据无效，请检查设备状态后重试",
                    stage: "rawProcessing",
                    type: "invalidData",
                    category: .camera,
                    severity: .high,
                    canRetry: true,
                    iconName: "exclamationmark.triangle.fill",
                    iconColor: .orange
                )
            case .processingFailed(let message):
                return CaptureErrorInfo(
                    title: "RAW处理失败",
                    userMessage: userZoom > 1.0 ? 
                        "无法创建\(String(format: "%.1f", userZoom))x变焦的JPEG图片，请降低变焦倍数后重试" :
                        "RAW文件处理过程中发生错误：\(message)",
                    stage: "rawProcessing",
                    type: "processingFailed",
                    category: .camera,
                    severity: .high,
                    canRetry: true,
                    iconName: "gearshape.fill",
                    iconColor: .orange
                )
            case .unsupportedFormat:
                return CaptureErrorInfo(
                    title: "格式不支持",
                    userMessage: "当前设备或iOS版本不支持此RAW格式，请联系开发者",
                    stage: "rawProcessing",
                    type: "unsupportedFormat",
                    category: .camera,
                    severity: .critical,
                    canRetry: false,
                    iconName: "xmark.octagon.fill",
                    iconColor: .red
                )
            }
        }
        
        // 2. 相册保存错误
        if let saveError = photoSaveService.lastError {
            switch saveError {
            case .permissionDenied:
                return CaptureErrorInfo(
                    title: "相册权限被拒绝",
                    userMessage: "请前往设置 > 隐私与安全性 > 照片，为JustRaw开启相册访问权限",
                    stage: "save",
                    type: "permissionDenied",
                    category: .permissions,
                    severity: .critical,
                    canRetry: false,
                    iconName: "lock.fill",
                    iconColor: .red
                )
            case .invalidData:
                return CaptureErrorInfo(
                    title: "照片数据无效",
                    userMessage: "生成的照片数据损坏，请重新拍摄",
                    stage: "save",
                    type: "invalidData",
                    category: .fileSystem,
                    severity: .high,
                    canRetry: true,
                    iconName: "doc.badge.exclamationmark",
                    iconColor: .orange
                )
            case .fileCreationFailed(let message):
                return CaptureErrorInfo(
                    title: "文件创建失败",
                    userMessage: "无法创建临时文件，可能是存储空间不足：\(message)",
                    stage: "save",
                    type: "fileCreationFailed",
                    category: .fileSystem,
                    severity: .high,
                    canRetry: true,
                    iconName: "externaldrive.badge.exclamationmark",
                    iconColor: .orange
                )
            case .photoLibraryError(let message):
                return CaptureErrorInfo(
                    title: "相册保存失败",
                    userMessage: "无法保存到相册，请检查存储空间：\(message)",
                    stage: "save",
                    type: "photoLibraryError",
                    category: .fileSystem,
                    severity: .high,
                    canRetry: true,
                    iconName: "photo.badge.exclamationmark",
                    iconColor: .orange
                )
            case .tempDirectoryError:
                return CaptureErrorInfo(
                    title: "临时目录错误",
                    userMessage: "无法访问临时目录，请重启应用",
                    stage: "save",
                    type: "tempDirectoryError",
                    category: .fileSystem,
                    severity: .high,
                    canRetry: false,
                    iconName: "folder.badge.exclamationmark",
                    iconColor: .red
                )
            }
        }
        
        // 3. 相机捕获错误
        if let cameraError = error as? CameraService.CameraError {
            switch cameraError {
            case .configurationFailed(let message):
                return CaptureErrorInfo(
                    title: "相机配置失败",
                    userMessage: "相机初始化失败：\(message)",
                    stage: "capture",
                    type: "configurationFailed",
                    category: .camera,
                    severity: .critical,
                    canRetry: false,
                    iconName: "camera.badge.exclamationmark",
                    iconColor: .red
                )
            case .deviceNotFound:
                return CaptureErrorInfo(
                    title: "相机设备未找到",
                    userMessage: "无法访问相机硬件，请检查设备权限",
                    stage: "capture",
                    type: "deviceNotFound",
                    category: .camera,
                    severity: .critical,
                    canRetry: false,
                    iconName: "camera.fill",
                    iconColor: .red
                )
            case .sessionNotRunning:
                return CaptureErrorInfo(
                    title: "相机会话未运行",
                    userMessage: "相机会话异常停止，请重启应用",
                    stage: "capture",
                    type: "sessionNotRunning",
                    category: .camera,
                    severity: .high,
                    canRetry: false,
                    iconName: "pause.circle.fill",
                    iconColor: .orange
                )
            case .captureError(let message):
                return CaptureErrorInfo(
                    title: "拍摄失败",
                    userMessage: "无法捕获照片：\(message)",
                    stage: "capture",
                    type: "captureError",
                    category: .camera,
                    severity: .high,
                    canRetry: true,
                    iconName: "camera.badge.exclamationmark",
                    iconColor: .orange
                )
            case .permissionDenied:
                return CaptureErrorInfo(
                    title: "相机权限被拒绝",
                    userMessage: "请前往设置 > 隐私与安全性 > 相机，为JustRaw开启相机权限",
                    stage: "capture",
                    type: "permissionDenied",
                    category: .permissions,
                    severity: .critical,
                    canRetry: false,
                    iconName: "lock.fill",
                    iconColor: .red
                )
            case .rawNotSupported:
                return CaptureErrorInfo(
                    title: "RAW格式不支持",
                    userMessage: "当前设备不支持RAW照片拍摄",
                    stage: "capture",
                    type: "rawNotSupported",
                    category: .camera,
                    severity: .critical,
                    canRetry: false,
                    iconName: "camera.badge.exclamationmark",
                    iconColor: .red
                )
            case .deviceChangeFailed(let message):
                return CaptureErrorInfo(
                    title: "切换相机失败",
                    userMessage: "无法切换到指定相机：\(message)",
                    stage: "capture",
                    type: "deviceChangeFailed",
                    category: .camera,
                    severity: .medium,
                    canRetry: true,
                    iconName: "camera.rotate.fill",
                    iconColor: .orange
                )
            }
        }
        
        // 4. 默认通用错误
        return CaptureErrorInfo(
            title: "拍摄过程发生错误",
            userMessage: "发生未知错误：\(error.localizedDescription)，请重试",
            stage: "unknown",
            type: "unknown",
            category: .camera,
            severity: .medium,
            canRetry: true,
            iconName: "exclamationmark.circle.fill",
            iconColor: .yellow
        )
    }
    
    /// 显示增强的错误反馈
    /// - Parameter errorInfo: 错误信息
    private func showEnhancedErrorFeedback(_ errorInfo: CaptureErrorInfo) {
        currentErrorInfo = errorInfo
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showingEnhancedError = true
        }
        
        // 对于非关键错误，5秒后自动隐藏
        if errorInfo.severity != .critical {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if showingEnhancedError && currentErrorInfo?.type == errorInfo.type {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingEnhancedError = false
                        currentErrorInfo = nil
                    }
                }
            }
        }
    }
    
    // MARK: - 设备运动监测已移除
    
}


#Preview {
    NavigationView {
        CameraView()
            .environmentObject(CameraService.shared)
            .environmentObject(AppStateManager.shared)
            .environmentObject(PermissionManager.shared)
            .environmentObject(ErrorHandler.shared)
    }
}