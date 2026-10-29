//
//  CameraViewRepresentable.swift
//  CameraApp
//
//  SwiftUI wrapper for AVCaptureVideoPreviewLayer using CameraService session.
//

import SwiftUI
import AVFoundation

struct CameraViewRepresentable: UIViewControllerRepresentable {
    
    let cameraService: CameraService
    let onPhotoCaptured: (UIImage) -> Void
    let onVideoRecorded: (URL) -> Void
    let onRecordingStarted: () -> Void
    let onRecordingStopped: () -> Void
    let onError: (Error) -> Void
    
    func makeUIViewController(context: Context) -> CameraPreviewViewController {
        let vc = CameraPreviewViewController()
        vc.cameraService = cameraService
        vc.onPhotoCaptured = onPhotoCaptured
        vc.onVideoRecorded = onVideoRecorded
        vc.onRecordingStarted = onRecordingStarted
        vc.onRecordingStopped = onRecordingStopped
        vc.onError = onError
        return vc
    }
    
    func updateUIViewController(_ vc: CameraPreviewViewController, context: Context) {
        vc.cameraService = cameraService
        vc.onPhotoCaptured = onPhotoCaptured
        vc.onVideoRecorded = onVideoRecorded
        vc.onRecordingStarted = onRecordingStarted
        vc.onRecordingStopped = onRecordingStopped
        vc.onError = onError
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            onPhotoCaptured: onPhotoCaptured,
            onVideoRecorded: onVideoRecorded,
            onRecordingStarted: onRecordingStarted,
            onRecordingStopped: onRecordingStopped,
            onError: onError
        )
    }
    
    final class Coordinator: NSObject {
        let onPhotoCaptured: (UIImage) -> Void
        let onVideoRecorded: (URL) -> Void
        let onRecordingStarted: () -> Void
        let onRecordingStopped: () -> Void
        let onError: (Error) -> Void
        
        init(onPhotoCaptured: @escaping (UIImage) -> Void,
             onVideoRecorded: @escaping (URL) -> Void,
             onRecordingStarted: @escaping () -> Void,
             onRecordingStopped: @escaping () -> Void,
             onError: @escaping (Error) -> Void) {
            self.onPhotoCaptured = onPhotoCaptured
            self.onVideoRecorded = onVideoRecorded
            self.onRecordingStarted = onRecordingStarted
            self.onRecordingStopped = onRecordingStopped
            self.onError = onError
        }
    }
}

/// UIViewController that displays AVCaptureVideoPreviewLayer and handles capture
final class CameraPreviewViewController: UIViewController {
    
    var cameraService: CameraService?
    var onPhotoCaptured: ((UIImage) -> Void)?
    var onVideoRecorded: ((URL) -> Void)?
    var onRecordingStarted: (() -> Void)?
    var onRecordingStopped: (() -> Void)?
    var onError: ((Error) -> Void)?
    
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPreview()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    private func setupPreview() {
        guard let cameraService = cameraService else { return }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: cameraService.cameraSession)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = view.bounds
        
        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }
    }
    
    // Photo capture is handled via AVCapturePhotoOutput delegate
    // which is configured in CameraService
}
