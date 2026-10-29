//
//  CameraService.swift
//  CameraApp
//

import Foundation
import AVFoundation
import UIKit
import CoreGraphics

enum CameraMode: String, CaseIterable {
    case rawPhoto
    case jpegPhoto
    case video
}

enum SessionState: String {
    case notConfigured
    case configuring
    case running
    case stopped
}

struct CapturedPhotoResult {
    let rawPhotoData: Data?
    let jpegData: Data?
    let metadata: [String: Any]
    var formattedFileSize: String {
        let bytes = rawPhotoData?.count ?? 0
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024.0) }
        return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
    }
}

enum CameraError: Error, Equatable {
    case configurationFailed(String)
    case deviceNotFound
    case sessionNotRunning
    case captureError(String)
    case permissionDenied
    case rawNotSupported
    case deviceChangeFailed(String)
}

enum CameraStyle: String, CaseIterable {
    case natural
    case xiaomi
    case oppo
    case vivo

    var displayName: String {
        switch self {
        case .natural: return "Natural"
        case .xiaomi: return "Xiaomi"
        case .oppo: return "OPPO"
        case .vivo: return "Vivo"
        }
    }

    var accentColor: Color {
        switch self {
        case .natural: return Color.white
        case .xiaomi: return Color(hex: "FFFFCE16")
        case .oppo: return Color(hex: "FF2274A5")
        case .vivo: return Color(hex: "FF0066FF")
        }
    }

    var shortName: String {
        switch self {
        case .natural: return "N"
        case .xiaomi: return "MI"
        case .oppo: return "OP"
        case .vivo: return "VI"
        }
    }

    var lutStyleId: Int32 {
        switch self {
        case .natural: return 0
        case .xiaomi: return 1
        case .oppo: return 2
        case .vivo: return 3
        }
    }

    var lutSize: Int32 {
        switch self {
        case .natural: return 0
        case .xiaomi: return 17
        case .oppo: return 17
        case .vivo: return 17
        }
    }

    func renderParams() -> (UnsafePointer<Float>?, Float) {
        switch self {
        case .natural:
            return (nil, 1.0)
        case .xiaomi:
            return (CameraCoreBridge.xiaomiMatrix, 1.04)
        case .oppo:
            return (CameraCoreBridge.oppoMatrix, 1.02)
        case .vivo:
            return (CameraCoreBridge.vivoMatrix, 1.0)
        }
    }
}

enum FlashMode: String, CaseIterable {
    case auto, on, off

    var icon: String {
        switch self {
        case .auto: return "bolt.circle"
        case .on: return "bolt.fill"
        case .off: return "bolt.slash"
        }
    }
}

enum Lens: String, CaseIterable {
    case ultraWide, wide, telephoto

    var displayName: String {
        switch self {
        case .ultraWide: return "0.5×"
        case .wide: return "1×"
        case .telephoto: return "2×"
        }
    }
}

final class CameraService: ObservableObject {
    static let shared = CameraService()

    @Published var sessionState: SessionState = .notConfigured
    @Published var currentMode: CameraMode = .rawPhoto
    @Published var isVideoMode = false
    @Published var showSettings = false
    @Published var showStylePicker = false
    @Published var showGallery = false
    @Published var showReview = false
    @Published var reviewImage: UIImage?
    @Published var reviewVideoURL: URL?
    @Published var currentCameraPosition: AVCaptureDevice.Position = .back
    @Published var isConfiguring: Bool = false
    @Published var supportsRAWCapture: Bool = false
    @Published var zoomFactor: CGFloat = 1.0
    @Published var maxZoomFactor: CGFloat = 1.0
    var activeSensorResolution: CMVideoDimensions = CMVideoDimensions(width: 4032, height: 3024)
    @Published var isFlashEnabled: Bool = false
    @Published var supportsFlash: Bool = false
    private var recordingStart: Date?
    private var recordingTimer: Timer?
    @Published var selectedStyle: CameraStyle = .natural
    @Published var selectedLens: Lens = .wide
    @Published var shutterPressed = false
    @Published var lastThumbnail: UIImage?
    @Published var recordTime = "00:00"
    @Published var isRecording = false
    @Published var isProcessing = false

    private let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var photoOutput: AVCapturePhotoOutput?
    private var currentDevice: AVCaptureDevice?
    private var currentCaptureDelegate: PhotoCaptureDelegate?

    private let sessionQueue = DispatchQueue(label: "camera.session.queue", qos: .userInitiated)
    private let captureQueue = DispatchQueue(label: "camera.capture.queue", qos: .userInitiated)

    private let performanceMonitor = PerformanceMonitor.shared
    private let errorHandler = ErrorHandler.shared
    private let appStateManager = AppStateManager.shared

    private init() {
        Logger.shared.info(module: .camera, operation: "Init", details: "CameraService initialized")
    }

    // MARK: - Session management

    var cameraSession: AVCaptureSession {
        return captureSession
    }

    func configureSession() async throws {
        guard sessionState == .notConfigured else { return }

        sessionState = .configuring
        isConfiguring = true

        try configureVideoInput()
        try configurePhotoOutput()
        updateDeviceCapabilities()

        sessionState = .running
        isConfiguring = false

        Logger.shared.info(module: .camera, operation: "ConfigureSession", details: "Camera session configured successfully")
    }

    func startSession() async {
        sessionQueue.async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
        Logger.shared.logCameraSessionStart()
    }

    func stopSession() {
        sessionQueue.async {
            self.captureSession.stopRunning()
        }
        sessionState = .stopped
        Logger.shared.logCameraSessionStop()
    }

    // MARK: - Input/Output configuration

    private func configureVideoInput() throws {
        if let existingInput = videoDeviceInput {
            captureSession.removeInput(existingInput)
        }

        guard let device = getDefaultDevice() else {
            throw CameraError.deviceNotFound
        }

        let deviceInput = try AVCaptureDeviceInput(device: device)

        guard captureSession.canAddInput(deviceInput) else {
            throw CameraError.configurationFailed("Cannot add camera input")
        }

        captureSession.addInput(deviceInput)
        videoDeviceInput = deviceInput
        currentDevice = device

        Logger.shared.info(module: .camera, operation: "ConfigureInput", details: "Video input configured for \(device.position == .back ? "back" : "front") camera")
    }

    private func configurePhotoOutput() throws {
        let output = AVCapturePhotoOutput()

        guard captureSession.canAddOutput(output) else {
            throw CameraError.configurationFailed("Cannot add photo output")
        }

        captureSession.addOutput(output)
        photoOutput = output

        Logger.shared.info(module: .camera, operation: "ConfigureOutput", details: "Photo output configured")
    }

    private func updateDeviceCapabilities() {
        guard let device = currentDevice else { return }

        if let photoOutput = photoOutput {
            supportsRAWCapture = photoOutput.availableRawPhotoPixelFormatTypes.count > 0
        }

        supportsFlash = device.hasFlash
        maxZoomFactor = device.activeFormat.videoMaxZoomFactor

        activeSensorResolution = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)

        Logger.shared.info(
            module: .camera,
            operation: "UpdateCapabilities",
            details: "RAW: \(supportsRAWCapture), Flash: \(supportsFlash), MaxZoom: \(maxZoomFactor), Resolution: \(activeSensorResolution.width)x\(activeSensorResolution.height)"
        )
    }

    private func getDefaultDevice() -> AVCaptureDevice? {
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            return device
        }
        return AVCaptureDevice.default(for: .video)
    }

    // MARK: - Capture

    func captureRAWWithZoomReset(originalZoomFactor: CGFloat) async throws -> CapturedPhotoResult {
        // Simplified capture - return a placeholder result
        let data = Data()
        return CapturedPhotoResult(
            rawPhotoData: data,
            jpegData: nil,
            metadata: [:]
        )
    }

    func capturePhoto() async throws -> CapturedPhotoResult {
        return try await captureRAWWithZoomReset(originalZoomFactor: zoomFactor)
    }

    func switchCamera() async throws {
        // Simplified - toggle between back and front
        currentCameraPosition = currentCameraPosition == .back ? .front : .back
        try configureVideoInput()
        Logger.shared.logCameraSwitch(to: currentCameraPosition == .back ? "back" : "front")
    }

    func toggleFlash() {
        switch flashMode {
        case .auto: flashMode = .on
        case .on: flashMode = .off
        case .off: flashMode = .auto
        }
    }

    var flashMode: FlashMode = .auto

    func toggleVideoRecording() {
        isRecording.toggle()
        if isRecording {
            startRecordingTimer()
        } else {
            stopRecordingTimer()
        }
    }

    func startRecordingTimer() {
        recordingStart = Date()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let start = self?.recordingStart else { return }
            let elapsed = Date().timeIntervalSince(start)
            self?.recordTime = String(format: "%02d:%02d", Int(elapsed) / 60, Int(elapsed) % 60)
        }
    }

    func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordTime = "00:00"
    }

    func switchToUltraWide() {
        selectedLens = .ultraWide
    }

    func switchToWide() {
        selectedLens = .wide
    }

    func switchToTelephoto() {
        selectedLens = .telephoto
    }

    func applicationDidBecomeActive() {
        // Resume camera if needed
    }

    func applicationDidEnterBackground() {
        // Pause camera if needed
    }

    func applicationWillTerminate() {
        stopSession()
    }

    // MARK: - PhotoCaptureDelegate protocol stub

    private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            // Stub
        }
    }
}
