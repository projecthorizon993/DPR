//
//  CameraViewModel.swift
//  CameraApp
//
//  ViewModel bridging UI state to CameraViewController + PhotoLibrary.
//

import SwiftUI
import AVFoundation
import Photos
import UIKit

final class CameraViewModel: ObservableObject {

    // MARK: - UI state
    @Published var isVideoMode = false
    @Published var isRecording = false
    @Published var shutterPressed = false
    @Published var recordTime = "00:00"
    @Published var selectedStyle: CameraStyle = .natural
    @Published var selectedLens: Lens = .wide
    @Published var flashMode: FlashMode = .auto
    @Published var watermarkImage: CGImage?
    @Published var watermarkAlpha: Float = 0.6
    @Published var isProcessing = false

    // Review state
    @Published var showReview = false
    @Published var reviewImage: UIImage?
    @Published var reviewVideoURL: URL?
    @Published var lastThumbnail: UIImage?

    // Settings
    @Published var showSettings = false
    @Published var showStylePicker = false
    @Published var showGallery = false
    @Published var showError = false
    @Published var errorMessage = ""

    // Photo library
    private var photoLibrary = PhotoLibrary.shared

    // Recording timer
    private var recordingTimer: Timer?
    private var recordingStart: Date?

    // Camera controller reference (set from CameraViewRepresentable coordinator)
    weak var cameraController: CameraViewController?

    init() {
        loadSettings()
        loadWatermarkLogo()
    }

    /// Load last thumbnail asynchronously - call when needed, not during init()
    func loadLastThumbnailAsync() {
        PhotoLibrary.shared.lastThumbnail(completion: { [weak self] image in
            DispatchQueue.main.async {
                self?.lastThumbnail = image
            }
        })
    }

    private func loadWatermarkLogo() {
        // Load the salvaged Zeiss watermark logo from asset bundle
        if let uiImage = UIImage(named: "ZeissLogo") {
            watermarkImage = uiImage.cgImage
        }
    }

    // MARK: - Permissions

    func requestPermissions() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { _ in }
        }
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in }
    }

    // MARK: - Actions

    func capturePhoto() {
        isProcessing = true
        cameraController?.capturePhoto()
    }

    func toggleVideo() {
        cameraController?.toggleVideoRecording()
    }

    func toggleFlash() {
        switch flashMode {
        case .auto: flashMode = .on
        case .on: flashMode = .off
        case .off: flashMode = .auto
        }
    }

    func switchToUltraWide() {
        cameraController?.switchCamera(to: .builtInUltraWideCamera)
    }
    func switchToWide() {
        cameraController?.switchCamera(to: .builtInWideAngleCamera)
    }
    func switchToTelephoto() {
        cameraController?.switchCamera(to: .builtInTelephotoCamera)
    }

    // MARK: - Recording timer

    func startRecordingTimer() {
        recordingStart = Date()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let start = self.recordingStart else { return }
            let elapsed = Date().timeIntervalSince(start)
            self.recordTime = self.formatTime(elapsed)
        }
    }

    func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStart = nil
        recordTime = "00:00"
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Settings persistence

    private func loadSettings() {
        if let raw = UserDefaults.standard.string(forKey: "selectedStyle"),
           let style = CameraStyle(rawValue: raw) {
            selectedStyle = style
        }
        watermarkAlpha = UserDefaults.standard.float(forKey: "watermarkAlpha")
        if watermarkAlpha == 0 { watermarkAlpha = 0.6 }
    }

    func saveSettings() {
        UserDefaults.standard.set(selectedStyle.rawValue, forKey: "selectedStyle")
        UserDefaults.standard.set(watermarkAlpha, forKey: "watermarkAlpha")
    }

    private func loadLastThumbnail() {
        lastThumbnail = photoLibrary.lastThumbnail()
    }
}

// MARK: - Supporting enums

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
}

extension CameraStyle: RawRepresentable {
    typealias RawValue = String
    init?(rawValue: String) {
        switch rawValue {
        case "natural": self = .natural
        case "xiaomi": self = .xiaomi
        case "oppo": self = .oppo
        case "vivo": self = .vivo
        default: return nil
        }
    }
    var rawValue: String {
        switch self {
        case .natural: return "natural"
        case .xiaomi: return "xiaomi"
        case .oppo: return "oppo"
        case .vivo: return "vivo"
        }
    }
}
