//
//  CameraViewRepresentable.swift
//  CameraApp
//

import SwiftUI
import AVFoundation

struct CameraViewRepresentable: UIViewControllerRepresentable {
    let cameraService: CameraService
    let onPhotoCaptured: (UIImage) -> Void
    let onError: (Error) -> Void

    func makeUIViewController(context: Context) -> CameraPreviewViewController {
        let vc = CameraPreviewViewController()
        vc.cameraService = cameraService
        vc.onPhotoCaptured = onPhotoCaptured
        vc.onError = onError
        return vc
    }

    func updateUIViewController(_ vc: CameraPreviewViewController, context: Context) {
        vc.cameraService = cameraService
        vc.onPhotoCaptured = onPhotoCaptured
        vc.onError = onError
    }
}

final class CameraPreviewViewController: UIViewController {
    var cameraService: CameraService?
    var onPhotoCaptured: ((UIImage) -> Void)?
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
}
