//
//  CameraView.swift
//  CameraApp
//
//  Camera UI ported directly from Xiaomi MIUI Camera APK.
//  - Pure black background
//  - Amber shutter button (#FFFFCE16)
//  - Mode pills at top center (PHOTO / VIDEO)
//  - Flash toggle top-left, Settings top-right
//  - Lens pills vertical on left side (0.5× / 1× / 2×)
//  - Gallery bottom-left, Style bottom-right
//  - Recording indicator top-right
//  - Post-capture review screen with style badge
//

import SwiftUI
import AVFoundation
import UIKit

struct CameraView: View {
    
    @EnvironmentObject var cameraService: CameraService
    @EnvironmentObject var appStateManager: AppStateManager
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var errorHandler: ErrorHandler
    @StateObject private var photoSaveService = PhotoSaveService.shared
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.openURL) var openURL
    
    // UI state
    @State private var showingControls = true
    @State private var isCapturing = false
    @State private var isProcessingRAW = false
    
    // Focus and exposure
    @State private var focusPoint: CGPoint?
    @State private var showingFocusIndicator = false
    
    // Device orientation state
    @State private var deviceOrientation: UIDeviceOrientation = .portrait
    @State private var isLandscape: Bool = false
    
    // Auto-hide controls timer
    @State private var hideControlsTimer: Timer?
    
    // Zoom state management
    @State private var currentZoomFactor: CGFloat = 1.0
    @State private var lastScaleValue: CGFloat = 1.0
    @State private var showingZoomIndicator = false
    @State private var showingZoomSlider = true
    @State private var targetCropRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    
    // Raw processing service
    @StateObject private var rawProcessor = RAWProcessorService.shared
    
    // Error feedback state
    @State private var showingEnhancedError = false
    @State private var currentErrorInfo: CaptureErrorInfo?
    
    var body: some View {
        ZStack {
            // ── Camera preview (full bleed, black background) ──
            CameraViewRepresentable(
                cameraService: cameraService,
                onPhotoCaptured: { image in
                    Task {
                        await processCapturedImage(image)
                    }
                },
                onError: { error in
                    handleCameraError(error)
                }
            )
            .ignoresSafeArea()
            .background(Color.black)
            
            // ── Top bar: Flash | Mode pills | Settings ──
            VStack {
                HStack(spacing: 0) {
                    // Flash toggle (top-left)
                    Button(action: cameraService.toggleFlash) {
                        Image(systemName: cameraService.flashMode.icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(cameraService.flashMode == .on ? Color(hex: "FFFFCE16") : .white)
                            .frame(width: 56, height: 56)
                            .contentShape(Rectangle())
                    }
                    
                    Spacer()
                    
                    // Mode pills: PHOTO / VIDEO (top center)
                    HStack(spacing: 0) {
                        ModePill(
                            title: "PHOTO",
                            isSelected: !cameraService.isVideoMode
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                cameraService.isVideoMode = false
                            }
                        }
                        ModePill(
                            title: "VIDEO",
                            isSelected: cameraService.isVideoMode
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                cameraService.isVideoMode = true
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
                    Button(action: { cameraService.showSettings = true }) {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                Spacer()
                
                // ── Bottom bar: Gallery | Shutter | Style ──
                HStack(spacing: 0) {
                    // Gallery shortcut (bottom-left)
                    Button(action: openPhotosApp) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 66, height: 66)
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 19, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 66, height: 66)
                    
                    Spacer()
                    
                    // ── Shutter button (center, amber #FFFFCE16) ──
                    ZStack {
                        // Outer dark ring
                        Circle()
                            .stroke(Color.white.opacity(0.25), lineWidth: 3)
                            .frame(width: 93, height: 93)
                        // Inner amber button
                        Circle()
                            .fill(cameraService.isVideoMode && cameraService.isRecording ? Color.red : Color(hex: "FFFFCE16"))
                            .frame(width: 80, height: 80)
                    }
                    .scaleEffect(cameraService.shutterPressed ? 0.86 : 1.0)
                    .animation(.easeInOut(duration: 0.08), value: cameraService.shutterPressed)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !cameraService.shutterPressed {
                                    cameraService.shutterPressed = true
                                }
                            }
                            .onEnded { _ in
                                cameraService.shutterPressed = false
                                if cameraService.isVideoMode {
                                    cameraService.toggleVideoRecording()
                                } else {
                                    capturePhoto()
                                }
                            }
                    )
                    .disabled(cameraService.isProcessing)
                    .frame(width: 93, height: 93)
                    
                    Spacer()
                    
                    // Styles / Profiles (bottom-right)
                    Button(action: { cameraService.showStylePicker = true }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 66, height: 66)
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(cameraService.selectedStyle.accentColor)
                                    .frame(width: 11, height: 11)
                                Text(cameraService.selectedStyle.shortName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(width: 66, height: 66)
                    .sheet(isPresented: $cameraService.showStylePicker) {
                        StylePickerView(selectedStyle: $cameraService.selectedStyle)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // ── Lens pills (vertical stack on LEFT side) ──
            HStack(spacing: 0) {
                VStack(spacing: 12) {
                    LensPill(
                        title: "0.5×",
                        isSelected: cameraService.selectedLens == .ultraWide
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            cameraService.switchToUltraWide()
                        }
                    }
                    LensPill(
                        title: "1×",
                        isSelected: cameraService.selectedLens == .wide
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            cameraService.switchToWide()
                        }
                    }
                    LensPill(
                        title: "2×",
                        isSelected: cameraService.selectedLens == .telephoto
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            cameraService.switchToTelephoto()
                        }
                    }
                }
                .padding(.top, 60)
                .padding(.bottom, 140)
                
                Spacer()
            }
            .padding(.leading, 22)
            
            // ── Recording indicator (top right) ──
            if cameraService.isVideoMode && cameraService.isRecording {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .animation(
                                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                    value: cameraService.isRecording
                                )
                            Text(cameraService.recordTime)
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.black.opacity(0.6)))
                    }
                    .padding(.top, 14)
                    .padding(.trailing, 24)
                    Spacer()
                }
                .ignoresSafeArea()
            }
            
            // ── Loading overlay ──
            if cameraService.isProcessing {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.4)
                }
            }
            
            // ── Style Applied badge (top-right, Xiaomi style) ──
            if cameraService.selectedStyle != .natural {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(cameraService.selectedStyle.accentColor)
                                .frame(width: 6, height: 6)
                            Text("STYLE APPLIED")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(cameraService.selectedStyle.accentColor)
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
        }
        .sheet(isPresented: $cameraService.showStylePicker) {
            StylePickerView(selectedStyle: $cameraService.selectedStyle)
        }
        .sheet(isPresented: $cameraService.showSettings) {
            SettingsView(viewModel: cameraService)
        }
        .sheet(isPresented: $cameraService.showGallery) {
            GalleryView(viewModel: cameraService)
        }
        .sheet(isPresented: $cameraService.showReview) {
            ReviewView(
                image: $cameraService.reviewImage,
                videoURL: $cameraService.reviewVideoURL,
                isPresented: $cameraService.showReview,
                onSave: { cameraService.showReview = false },
                onRetake: { cameraService.showReview = false }
            )
        }
        .alert("Camera Error", isPresented: $errorHandler.showingErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let currentError = errorHandler.currentErrors.first {
                Text(currentError.message)
            }
        }
        .onAppear {
            setupCamera()
        }
    }
    
    // MARK: - Camera control methods
    
    private func setupCamera() {
        Task {
            do {
                try await cameraService.configureSession()
                await cameraService.startSession()
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
            Logger.shared.warning(module: .camera, operation: "CapturePhoto", details: "Previous photo still saving")
            return
        }
        
        withAnimation(.easeInOut(duration: 0.1)) {
            isCapturing = true
        }
        
        Task {
            do {
                let result = try await cameraService.captureRAWWithZoomReset(originalZoomFactor: currentZoomFactor)
                
                guard let rawData = result.rawPhotoData else {
                    throw CameraService.CameraError.captureError("No RAW data")
                }
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isCapturing = false
                        isProcessingRAW = true
                    }
                }
                
                var croppedJPEGData: Data?
                
                if currentZoomFactor > 1.0 {
                    croppedJPEGData = try await rawProcessor.processRAWToJPEG(
                        rawData,
                        cropRect: targetCropRect,
                        style: cameraService.selectedStyle
                    )
                }
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isProcessingRAW = false
                    }
                }
                
                let assetID: String
                
                if let jpegData = croppedJPEGData {
                    assetID = try await photoSaveService.saveDualPhotos(
                        originalRAW: rawData,
                        croppedJPEG: jpegData,
                        metadata: result.metadata
                    )
                } else {
                    assetID = try await photoSaveService.saveRAWPhoto(
                        rawData: rawData,
                        metadata: result.metadata
                    )
                }
                
                await MainActor.run {
                    showCaptureAndSaveSuccess(result: result, assetID: assetID)
                    
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
                
                await MainActor.run {
                    showEnhancedErrorFeedback(errorInfo)
                }
            }
        }
    }
    
    private func processCapturedImage(_ image: UIImage) {
        Task {
            await capturePhoto()
        }
    }
    
    private func handleCameraError(_ error: Error) {
        errorHandler.handleError(
            error,
            category: .camera,
            severity: .high,
            context: ["action": "cameraError"]
        )
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
        guard let url = URL(string: "photos-navigation://") else { return }
        openURL(url) { _ in }
    }
    
    private func analyzeError(_ error: Error, userZoom: CGFloat) -> CaptureErrorInfo {
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
                    userMessage: "Error occurred during RAW file processing: \(message)",
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
        
        if let saveError = photoSaveService.lastError {
            switch saveError {
            case .permissionDenied:
                return CaptureErrorInfo(
                    title: "Album permission denied",
                    userMessage: "Please go to Settings > Privacy & Security > Photos, enable album access for CameraApp",
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
                    userMessage: "Please enable camera permission in Settings",
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
                    userMessage: "Unable to switch camera: \(message)",
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
        
        return CaptureErrorInfo(
            title: "Capture error",
            userMessage: "Unknown error: \(error.localizedDescription), please retry",
            stage: "unknown",
            type: "unknown",
            category: .camera,
            severity: .medium,
            canRetry: true,
            iconName: "exclamationmark.circle.fill",
            iconColor: .yellow
        )
    }
    
    private func showEnhancedErrorFeedback(_ errorInfo: CaptureErrorInfo) {
        currentErrorInfo = errorInfo
        withAnimation(.easeInOut(duration: 0.3)) {
            showingEnhancedError = true
        }
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
}

// MARK: - Mode pill (Xiaomi MIUI: selected = amber fill + dark text)

struct ModePill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? Color(red: 0.067, green: 0.067, blue: 0.067) : .white)
                .frame(width: 52, height: 26)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color(hex: "FFFFCE16") : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.clear : Color.white.opacity(0.35), lineWidth: 1)
                )
        )
    }
}

// MARK: - Lens pill (vertical left side, Xiaomi style)

struct LensPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(isSelected ? Color(red: 0.067, green: 0.067, blue: 0.067) : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(width: 44, height: 24)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color(hex: "FFFFCE16") : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.clear : Color.white.opacity(0.35), lineWidth: 1)
                )
        )
    }
}
