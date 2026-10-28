//
//  CameraView.swift
//  CameraApp
//
//  AVFoundation camera viewfinder with photo + video capture.
//  Integrates Rust processing core for post-capture styling.
//

import SwiftUI
import AVFoundation
import Photos
import UIKit

/// Delegate to receive captured/processed media
protocol CameraViewDelegate: AnyObject {
    func cameraView(_ view: CameraViewController, didProcessPhoto image: UIImage)
    func cameraView(_ view: CameraViewController, didRecordVideo url: URL)
    func cameraViewDidStartRecording(_ view: CameraViewController)
    func cameraViewDidStopRecording(_ view: CameraViewController)
    func cameraView(_ view: CameraViewController, didFail error: Error)
}

/// AVCaptureSession-backed camera view controller, wrapped for SwiftUI
final class CameraViewController: UIViewController {

    // MARK: - Capture session

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var photoOutput = AVCapturePhotoOutput()
    private var movieOutput = AVCaptureMovieFileOutput()

    // MARK: - Preview

    private let previewView = PreviewView()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    // MARK: - State

    weak var delegate: CameraViewDelegate?
    var currentStyle: CameraStyle = .natural
    var watermarkImage: CGImage?
    var watermarkAlpha: Float = 0.6
    var isVideoMode = false
    var videoURL: URL?

    private var isCaptureInProgress = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupPreview()
        setupSessionInterruptionHandling()
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    private func setupSessionInterruptionHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionWasInterrupted),
            name: .AVCaptureSessionWasInterrupted,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded),
            name: .AVCaptureSessionInterruptionEnded,
            object: session
        )
    }

    @objc private func sessionWasInterrupted(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVCaptureSessionInterruptionReasonKey] as? Int,
              let reason = AVCaptureSession.InterruptionReason(rawValue: reasonValue) else {
            return
        }
        DispatchQueue.main.async {
            self.delegate?.cameraView(self, didFail: CameraError.captureInterrupted)
        }
    }

    @objc private func sessionInterruptionEnded(_ notification: Notification) {
        DispatchQueue.main.async {
            self.session.startRunning()
        }
    }

    private func setupPreview() {
        previewView.frame = view.bounds
        previewView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(previewView)
        view.sendSubviewToBack(previewView)
    }

    private func configureSession() {
        session.beginConfiguration()

        // Input — choose best wide camera
        session.sessionPreset = .photo
        guard let videoDevice = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .back
        ).devices.first else {
            DispatchQueue.main.async {
                self.delegate?.cameraView(self, didFail: CameraError.noCameraAvailable)
            }
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(input) {
                session.addInput(input)
                self.videoDeviceInput = input
            }
        } catch {
            DispatchQueue.main.async {
                self.delegate?.cameraView(self, didFail: error)
            }
            return
        }

        // Photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
        }

        // Video output
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        session.commitConfiguration()

        // Start running
        sessionQueue.async {
            self.session.startRunning()
            DispatchQueue.main.async {
                self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
                self.previewLayer?.videoGravity = .resizeAspectFill
                self.previewLayer?.frame = self.previewView.bounds
                if let layer = self.previewLayer {
                    self.previewView.layer.addSublayer(layer)
                }
            }
        }
    }

    // MARK: - Capture

    func capturePhoto() {
        guard !isCaptureInProgress else { return }
        isCaptureInProgress = true

        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        settings.isHighResolutionPhotoEnabled = true

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func toggleVideoRecording() {
        if movieOutput.isRecording {
            movieOutput.stopRecording()
        } else {
            startVideoRecording()
        }
    }

    private func startVideoRecording() {
        guard !movieOutput.isRecording else { return }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documents.appendingPathComponent("video-\(dateString()).mov")
        videoURL = url
        movieOutput.startRecording(to: url, recordingDelegate: self)
    }

    private func dateString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd-HHmmss"
        return fmt.string(from: Date())
    }

    // MARK: - Lens switching

    func switchCamera(to deviceType: AVCaptureDevice.DeviceType) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            // Remove existing input
            if let input = self.videoDeviceInput {
                self.session.removeInput(input)
            }
            
            // Add new input
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [deviceType],
                mediaType: .video,
                position: .back
            )
            guard let device = discovery.devices.first else {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.delegate?.cameraView(self, didFail: CameraError.noCameraAvailable)
                }
                return
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.videoDeviceInput = input
                } else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async {
                        self.delegate?.cameraView(self, didFail: CameraError.noCameraAvailable)
                    }
                    return
                }
            } catch {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.delegate?.cameraView(self, didFail: error)
                }
                return
            }
            
            self.session.commitConfiguration()
        }
    }

    var previewFrame: CGRect {
        previewView.bounds
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        defer { isCaptureInProgress = false }

        if let error = error {
            DispatchQueue.main.async {
                self.delegate?.cameraView(self, didFail: error)
            }
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else {
            DispatchQueue.main.async {
                self.delegate?.cameraView(self, didFail: CameraError.invalidImageData)
            }
            return
        }

        // Process through Rust core
        let processed = CameraCoreBridge.process(
            image: cgImage,
            style: self.currentStyle,
            watermark: self.watermarkImage,
            watermarkAlpha: self.watermarkAlpha
        )

        if let processed = processed {
            let resultImage = UIImage(cgImage: processed, scale: uiImage.scale, orientation: uiImage.imageOrientation)
            self.delegate?.cameraView(self, didProcessPhoto: resultImage)
        } else {
            // Fallback: deliver unprocessed
            let uiImage = UIImage(cgImage: cgImage, scale: uiImage.scale, orientation: uiImage.imageOrientation)
            self.delegate?.cameraView(self, didProcessPhoto: uiImage)
        }
    }
}

extension CameraViewController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didStartRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]) {
        DispatchQueue.main.async {
            self.delegate?.cameraViewDidStartRecording(self)
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.delegate?.cameraView(self, didFail: error)
            }
            return
        }
        DispatchQueue.main.async {
            self.delegate?.cameraView(self, didRecordVideo: outputFileURL)
            self.delegate?.cameraViewDidStopRecording(self)
        }
    }
}

// MARK: - Preview view

class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer? { layer as? AVCaptureVideoPreviewLayer }
}

// MARK: - Errors

enum CameraError: LocalizedError {
    case noCameraAvailable
    case invalidImageData
    case captureInterrupted

    var errorDescription: String? {
        switch self {
        case .noCameraAvailable: return "No camera available"
        case .invalidImageData: return "Invalid image data"
        case .captureInterrupted: return "Capture was interrupted"
        }
    }
}
