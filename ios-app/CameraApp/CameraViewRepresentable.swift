//
//  CameraViewRepresentable.swift
//  CameraApp
//
//  SwiftUI wrapper for CameraViewController.
//  ContentView owns CameraViewModel and passes it in.
//

import SwiftUI

struct CameraViewRepresentable: UIViewControllerRepresentable {
    @ObservedObject var viewModel: CameraViewModel

    var onPhotoCaptured: (UIImage) -> Void
    var onVideoRecorded: (URL) -> Void
    var onRecordingStarted: () -> Void
    var onRecordingStopped: () -> Void
    var onError: (Error) -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.delegate = context.coordinator
        vc.currentStyle = viewModel.selectedStyle
        vc.watermarkImage = viewModel.watermarkImage
        vc.watermarkAlpha = viewModel.watermarkAlpha
        vc.isVideoMode = viewModel.isVideoMode

        // Link controller back to view model so UI actions reach AVFoundation
        viewModel.cameraController = vc

        return vc
    }

    func updateUIViewController(_ vc: CameraViewController, context: Context) {
        vc.currentStyle = viewModel.selectedStyle
        vc.watermarkImage = viewModel.watermarkImage
        vc.watermarkAlpha = viewModel.watermarkAlpha
        vc.isVideoMode = viewModel.isVideoMode
        vc.flashMode = viewModel.flashMode.flashMode
        viewModel.cameraController = vc
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onPhotoCaptured: onPhotoCaptured,
            onVideoRecorded: onVideoRecorded,
            onRecordingStarted: { },
            onRecordingStopped: { },
            onError: onError
        )
    }

    final class Coordinator: NSObject, CameraViewDelegate {
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

        func cameraView(_ view: CameraViewController, didProcessPhoto image: UIImage) {
            onPhotoCaptured(image)
        }

        func cameraView(_ view: CameraViewController, didRecordVideo url: URL) {
            onVideoRecorded(url)
            onRecordingStopped()
        }

        func cameraViewDidStartRecording(_ view: CameraViewController) {
            onRecordingStarted()
        }

        func cameraViewDidStopRecording(_ view: CameraViewController) {
            // Already called from didRecordVideo
        }

        func cameraView(_ view: CameraViewController, didFail error: Error) {
            onError(error)
        }
    }
}
