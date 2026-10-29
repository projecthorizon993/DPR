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
                            Text("Dual photos saved: Original RAW + Cropped JPEG")
                                .foregroundColor(.white)
                                .font(.headline)
                        } else {
                            Text("RAW photo saved to album")
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
                            Text("Photo save failed")
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
                            // Error icon
                            Image(systemName: errorInfo.iconName)
                                .foregroundColor(errorInfo.iconColor)
                                .font(.system(size: 48))
                            
                            // Error title
                            Text(errorInfo.title)
                                .foregroundColor(.white)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.center)
                            
                            // Error description
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
            updateDeviceOrientation() // Initialize orientation state
        }
        .onDisappear {
            hideControlsTimer?.invalidate()
            NotificationCenter.default.removeObserver(self)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            updateDeviceOrientation()
        }
        // Remove settings page
    }
    
    // MARK: - Top control bar (Xiaomi MIUI: Flash | Mode pills | Settings)
    
    private var topControlBar: some View {
        HStack(spacing: 0) {
            // Flash toggle (top-left)
            Button(action: toggleFlash) {
                Image(systemName: cameraService.isFlashEnabled ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(cameraService.isFlashEnabled ? Color(hex: "FFFFCE16") : .white)
                    .frame(width: 56, height: 56)
                    .contentShape(Rectangle())
            }
            
            Spacer()
            
            // Mode pills: PHOTO / VIDEO (top center)
            HStack(spacing: 0) {
                ModePill(
                    title: "PHOTO",
                    isSelected: !viewModel.isVideoMode
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.isVideoMode = false
                    }
                }
                ModePill(
                    title: "VIDEO",
                    isSelected: viewModel.isVideoMode
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.isVideoMode = true
                    }
                }
            }
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.24), lineWidth: 1)
                    )
            )
            .frame(height: 30)
            
            Spacer()
            
            // Settings (top-right) - ellipsis like Xiaomi
            Button(action: { viewModel.showSettings = true }) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    // MARK: - Bottom control bar
    
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
                        .fill(isCapturing ? Color.gray : Color(hex: "FFFFCE16"))
                        .frame(width: 70, height: 70)
                }
            }
            .disabled(isCapturing || isProcessingRAW || photoSaveService.isSaving || !cameraService.canCapture)
            .scaleEffect(isCapturing ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isCapturing)
            
            Spacer()
            
            // Flash button
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
            
            // Style selector button (Xiaomi style, bottom-right)
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
        .background(Color.clear) // Transparent background
    }
    
    // MARK: - Camera control methods
    
    private func setupCamera() {
        Task {
            do {
                try await cameraService.configureSession()
                await cameraService.startSession()
                
                // Delay showing control UI, ensure camera startup completes
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
            // If saving photo, show prompt
            Logger.shared.warning(module: .camera, operation: "CapturePhoto", details: "Previous photo still saving")
            return
        }
        
        withAnimation(.easeInOut(duration: 0.1)) {
            isCapturing = true
        }
        
        Task {
            do {
                // Step 1: Use zoom-reset RAW capture (avoid Apple constraint)
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
                
                // Step 2: Verify RAW data
                guard let rawData = result.rawPhotoData else {
                    throw CameraService.CameraError.captureError("No RAW data")
                }
                
                // Step 3: RAW processing - generate cropped JPEG (only process when user zooms)
                var croppedJPEGData: Data?
                
                // Update UI state on main thread
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
                
                // Stop RAW processing status on main thread
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isProcessingRAW = false
                    }
                }
                
                // Step 4: Save photo to album
                let assetID: String
                
                if let jpegData = croppedJPEGData {
                    // Save dual photos: Original RAW + Cropped JPEG
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
                    // Only save original RAW
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
                
                // Step 5: Update UI on main thread
                await MainActor.run {
                    showCaptureAndSaveSuccess(result: result, assetID: assetID)
                    
                    // Ensure all states have been reset
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
                
                // Enhanced error handling (capture, process, or save)
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
                
                // Display user-friendly error feedback
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
    
    /// Handle tap events in preview area
    /// - Parameters:
    ///   - location: Tap location (relative to preview container)
    ///   - containerSize: Entire container size
    private func handleTapInPreview(at location: CGPoint, containerSize: CGSize) {
        let previewSize = getPreviewSize(for: containerSize)
        
        // Calculate preview area position in container (centered)
        let previewOriginX = (containerSize.width - previewSize.width) / 2
        let previewOriginY = (containerSize.height - previewSize.height) / 2
        
        // Check if tap is within preview area
        let adjustedLocation = CGPoint(
            x: location.x - previewOriginX,
            y: location.y - previewOriginY
        )
        
        // Validate tap is within preview area bounds
        guard adjustedLocation.x >= 0 && adjustedLocation.x <= previewSize.width &&
              adjustedLocation.y >= 0 && adjustedLocation.y <= previewSize.height else {
            return // Tap is outside preview area, ignore
        }
        
        // Convert to camera device coordinate system (0.0-1.0)
        let devicePoint = CGPoint(
            x: adjustedLocation.x / previewSize.width,
            y: adjustedLocation.y / previewSize.height
        )
        
        // Only set focus point, keep global metering mode
        Task {
            do {
                try await cameraService.setFocusPoint(devicePoint)
                // Commented out exposure point setting to keep global metering
                // try await cameraService.setExposurePoint(devicePoint)
                
                DispatchQueue.main.async {
                    // Indicator position uses original tap position (relative to entire container)
                    self.focusPoint = location
                    // Do not set exposure point UI, using global metering
                    // self.exposurePoint = location
                    self.showingFocusIndicator = true
                    // Do not show exposure indicator, using global metering
                    // self.showingExposureIndicator = true
                }
            } catch {
                // Ignore focus error (may be unsupported device)
                Logger.shared.warning(
                    module: .camera,
                    operation: "HandleTapFocus",
                    details: "Focus setting failed (global metering mode): \(error.localizedDescription)"
                )
            }
        }
        
        resetHideControlsTimer()
    }
    
    private func handleTap(at location: CGPoint, in size: CGSize) {
        // Legacy compatibility method, kept in case called from elsewhere
        let devicePoint = CGPoint(
            x: location.x / size.width,
            y: location.y / size.height
        )
        
        Task {
            do {
                try await cameraService.setFocusPoint(devicePoint)
                // Commented out exposure point setting to keep global metering
                // try await cameraService.setExposurePoint(devicePoint)
                
                DispatchQueue.main.async {
                    focusPoint = location
                    // Do not set exposure point UI, using global metering
                    // exposurePoint = location
                    showingFocusIndicator = true
                    // Do not show exposure indicator, using global metering
                    // showingExposureIndicator = true
                }
            } catch {
                // Ignore focus error (global metering mode)
                Logger.shared.warning(
                    module: .camera,
                    operation: "HandleDoubleTapFocus",
                    details: "Focus setting failed (global metering mode): \(error.localizedDescription)"
                )
            }
        }
        
        resetHideControlsTimer()
    }
    
    /// Calculate preview container size
    /// - Parameter containerSize: Container size
    /// - Returns: Preview area size
    private func getPreviewSize(for containerSize: CGSize) -> CGSize {
        let aspectRatio = getCurrentAspectRatio()
        
        let previewWidth = containerSize.width
        let previewHeight = previewWidth / aspectRatio
        
        // If height exceeds container, limit by height
        if previewHeight > containerSize.height {
            let adjustedHeight = containerSize.height
            let adjustedWidth = adjustedHeight * aspectRatio
            return CGSize(width: adjustedWidth, height: adjustedHeight)
        }
        
        return CGSize(width: previewWidth, height: previewHeight)
    }
    
    /// Get preview ratio corresponding to current device orientation
    /// - Returns: Portrait 3:4, landscape 4:3
    private func getCurrentAspectRatio() -> CGFloat {
        return isLandscape ? (4.0 / 3.0) : (3.0 / 4.0)
    }
    
    /// Update device orientation state
    private func updateDeviceOrientation() {
        let newOrientation = UIDevice.current.orientation
        let wasLandscape = isLandscape
        
        // Update orientation state
        switch newOrientation {
        case .landscapeLeft, .landscapeRight:
            isLandscape = true
        case .portrait, .portraitUpsideDown:
            isLandscape = false
        default:
            // Keep current state unchanged
            return
        }
        
        deviceOrientation = newOrientation
        
        // If orientation changes, log it
        if wasLandscape != isLandscape {
            Logger.shared.info(
                module: .camera,
                operation: "OrientationChange",
                details: "Device orientation changed to \(isLandscape ? "landscape" : "portrait"), aspect ratio: \(getCurrentAspectRatio())"
            )
        }
    }
    
    /// Handle zoom gesture change - use real hardware zoom preview
    private func handleZoomGesture(_ value: CGFloat) {
        // Calculate incremental change (delta-based scaling)
        let delta = value / lastScaleValue
        
        // Apply damping factor to reduce sensitivity
        let dampingFactor: CGFloat = 0.3
        let adjustedDelta = 1.0 + (delta - 1.0) * dampingFactor
        
        // Calculate new zoom multiplier
        let newZoomFactor = currentZoomFactor * adjustedDelta
        
        // Constrain to camera supported range
        let minZoom: CGFloat = 0.5
        let maxZoom = min(10.0, cameraService.maxZoomFactor) // Use camera's actual max zoom
        let clampedZoomFactor = max(minZoom, min(maxZoom, newZoomFactor))
        
        // Update current zoom multiplier
        currentZoomFactor = clampedZoomFactor
        lastScaleValue = value
        
        // Immediately apply real hardware zoom to camera (this lets preview layer show zoom effect)
        Task {
            do {
                try await cameraService.setZoomFactor(clampedZoomFactor)
                
                // Calculate crop area needed for capture (for RAW processing)
                await MainActor.run {
                    targetCropRect = rawProcessor.calculateCropRect(
                        for: clampedZoomFactor,
                        imageSize: CGSize(width: CGFloat(cameraService.activeSensorResolution.width), height: CGFloat(cameraService.activeSensorResolution.height)) // Dynamic sensor resolution
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

        // Show zoom indicator
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

    /// Handle zoom gesture end
    private func handleZoomGestureEnded(_ value: CGFloat) {
        // Reset gesture state
        lastScaleValue = 1.0

        // Delay hiding zoom indicator
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

    /// Reset zoom to 1.0x
    private func resetZoom() {
        currentZoomFactor = 1.0
        lastScaleValue = 1.0
        targetCropRect = CGRect(x: 0, y: 0, width: 1, height: 1)

        // Reset hardware zoom
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
    
    // MARK: - Slider zoom control
    
    /// Handle slider zoom change
    /// - Parameter newZoom: New zoom multiplier
    private func handleSliderZoomChange(_ newZoom: CGFloat) {
        // Update zoom multiplier
        currentZoomFactor = newZoom
        
        // Immediately apply real hardware zoom
        Task {
            do {
                try await cameraService.setZoomFactor(newZoom)
                
                // Calculate crop area needed for capture (for RAW processing)
                await MainActor.run {
                    targetCropRect = rawProcessor.calculateCropRect(
                        for: newZoom,
                        imageSize: CGSize(width: CGFloat(cameraService.activeSensorResolution.width), height: CGFloat(cameraService.activeSensorResolution.height)) // Dynamic sensor resolution
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
        
        // Reset control UI hide timer
        resetHideControlsTimer()
    }

    /// Handle continuous zoom change (iPhone 16 style)
    /// - Parameter newZoom: New zoom multiplier
    private func handleContinuousZoomChange(_ newZoom: CGFloat) {
        // Update zoom multiplier
        currentZoomFactor = newZoom
        
        // Immediately apply real hardware zoom
        Task {
            do {
                try await cameraService.setZoomFactor(newZoom)
                
                // Calculate crop area needed for capture (for RAW processing)
                await MainActor.run {
                    targetCropRect = rawProcessor.calculateCropRect(
                        for: newZoom,
                        imageSize: CGSize(width: CGFloat(cameraService.activeSensorResolution.width), height: CGFloat(cameraService.activeSensorResolution.height)) // Dynamic sensor resolution
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
        
        // Reset control UI hide timer
        resetHideControlsTimer()
    }
    
    /// Toggle zoom slider display state
    private func toggleZoomSlider() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showingZoomSlider.toggle()
        }
        
        // If showing slider, hide zoom indicator to avoid duplication
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
        // Success feedback - brief flash effect
        withAnimation(.easeIn(duration: 0.1)) {
            // Can add success feedback UI
        }
        
        Logger.shared.info(
            module: .camera,
            operation: "CaptureAndSaveSuccess",
            details: "RAW photo captured and saved: \(result.formattedFileSize), Asset ID: \(assetID), hasRAW: \(result.hasRawData)"
        )
    }
    
    // MARK: - Control UI show/hide
    
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
    
    // MARK: - Enhanced error handling system
    
    /// Error information structure
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
    
    /// Analyze error and generate user-friendly error info
    /// - Parameters:
    ///   - error: Original error
    ///   - userZoom: Current user zoom multiplier
    /// - Returns: Structured error info
    private func analyzeError(_ error: Error, userZoom: CGFloat) -> CaptureErrorInfo {
        
        // 1. RAW processing error
        if let rawError = error as? RAWProcessorError {
            switch rawError {
            case .invalidRAWData:
                return CaptureErrorInfo(
                    title: "RAW data processing failed",
                    userMessage: "RAW data captured by camera is invalid, please check device status and retry",
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
                    title: "RAW processing failed",
                    userMessage: userZoom > 1.0 ? 
                        "Unable to create \(String(format: "%.1f", userZoom))x zoom JPEG image, please reduce zoom multiplier and retry" :
                        "Error occurred during RAW file processing: \(message)",
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
                    title: "Format not supported",
                    userMessage: "Current device or iOS version does not support this RAW format, please contact developer",
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
        
        // 2. Photo save error
        if let saveError = photoSaveService.lastError {
            switch saveError {
            case .permissionDenied:
                return CaptureErrorInfo(
                    title: "Album permission denied",
                    userMessage: "Please go to Settings > Privacy & Security > Photos, enable album access permission for JustRaw",
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
                    title: "Photo data invalid",
                    userMessage: "Generated photo data is corrupted, please retake photo",
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
                    title: "File creation failed",
                    userMessage: "Unable to create temporary file, may be insufficient storage space: \(message)",
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
                    title: "Album save failed",
                    userMessage: "Unable to save to album, please check storage space: \(message)",
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
                    title: "Temp directory error",
                    userMessage: "Unable to access temp directory, please restart app",
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
        
        // 3. Camera capture error
        if let cameraError = error as? CameraService.CameraError {
            switch cameraError {
            case .configurationFailed(let message):
                return CaptureErrorInfo(
                    title: "Camera configuration failed",
                    userMessage: "Camera initialization failed: \(message)",
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
                    title: "Camera device not found",
                    userMessage: "Unable to access camera hardware, please check device permissions",
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
                    title: "Camera session not running",
                    userMessage: "Camera session unexpectedly stopped, please restart app",
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
                    title: "Capture failed",
                    userMessage: "Unable to capture photo: \(message)",
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
                    title: "Camera permission denied",
                    userMessage: "Please go to Settings > Privacy & Security > Camera, enable camera permission for JustRaw",
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
                    title: "RAW format not supported",
                    userMessage: "Current device does not support RAW photo capture",
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
                    title: "Camera switch failed",
                    userMessage: "Unable to switch to specified camera: \(message)",
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
        
        // 4. Default general error
        return CaptureErrorInfo(
            title: "Error occurred during capture",
            userMessage: "Unknown error occurred: \(error.localizedDescription), please retry",
            stage: "unknown",
            type: "unknown",
            category: .camera,
            severity: .medium,
            canRetry: true,
            iconName: "exclamationmark.circle.fill",
            iconColor: .yellow
        )
    }
    
    /// Show enhanced error feedback
    /// - Parameter errorInfo: Error info
    private func showEnhancedErrorFeedback(_ errorInfo: CaptureErrorInfo) {
        currentErrorInfo = errorInfo
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showingEnhancedError = true
        }
        
        // For non-critical errors, auto-hide after 5 seconds
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
    
    // MARK: - Device motion detection removed
    
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