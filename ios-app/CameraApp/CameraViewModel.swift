import SwiftUI
import AVFoundation

/// Holds camera session state, style selection, capture flow, lens, flash,
/// live frame processing, and video recording. From-scratch implementation.
final class CameraViewModel: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var selectedStyle: CameraStyle = .natural
    @Published var isReviewing = false
    @Published var capturedImage: UIImage?
    @Published var isCaptureInProgress = false
    @Published var isRecording = false
    @Published var processedFrame: UIImage?
    @Published var lens: CameraLens = .wide
    @Published var flashMode: FlashMode = .off
    @Published var errorMessage: String?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let processingQueue = DispatchQueue(label: "camera.processing.queue")
    private var videoOutput: AVCaptureVideoDataOutput?
    private var photoOutput: AVCapturePhotoOutput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var currentDeviceInput: AVCaptureDeviceInput?
    private var isProcessingFrame = false

    var previewLayerView: AVCaptureVideoPreviewLayer? { previewLayer }

    func requestCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorizationStatus = .authorized
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.authorizationStatus = granted ? .authorized : .denied
                    if granted { self.startSession() }
                }
            }
        default:
            authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }

    func startSession() {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            // Remove existing inputs/outputs.
            if let input = self.currentDeviceInput {
                self.session.removeInput(input)
                self.currentDeviceInput = nil
            }
            self.session.outputs.forEach { self.session.removeOutput($0) }

            // Video input for the selected lens.
            guard let device = self.deviceForLens(self.lens),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                DispatchQueue.main.async {
                    self.errorMessage = "Unable to access the camera."
                }
                self.session.commitConfiguration()
                return
            }
            self.currentDeviceInput = input
            self.session.addInput(input)
            self.applyFlashMode(to: device)

            // Video data output for live frame processing.
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: self.processingQueue)
            if self.session.canAddOutput(videoOutput) {
                self.session.addOutput(videoOutput)
                self.videoOutput = videoOutput
            }

            // Photo output.
            let photoOutput = AVCapturePhotoOutput()
            if self.session.canAddOutput(photoOutput) {
                self.session.addOutput(photoOutput)
                self.photoOutput = photoOutput
            }

            // Movie output for video recording.
            let movieOutput = AVCaptureMovieFileOutput()
            if self.session.canAddOutput(movieOutput) {
                self.session.addOutput(movieOutput)
                self.movieOutput = movieOutput
            }

            self.session.commitConfiguration()
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
            }
        }
    }

    func stopSession() {
        sessionQueue.async {
            self.session.stopRunning()
            DispatchQueue.main.async { self.isSessionRunning = false }
        }
    }

    func setPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = layer
        layer.session = session
        layer.videoGravity = .resizeAspectFill
    }

    func switchStyle(_ style: CameraStyle) {
        selectedStyle = style
    }

    func switchLens(_ lens: CameraLens) {
        guard self.lens != lens else { return }
        self.lens = lens
        startSession()
    }

    func toggleFlash() {
        switch flashMode {
        case .off: flashMode = .on
        case .on: flashMode = .auto
        case .auto: flashMode = .off
        }
        sessionQueue.async {
            guard let device = self.currentDeviceInput?.device else { return }
            self.applyFlashMode(to: device)
        }
    }

    private func applyFlashMode(to device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            switch flashMode {
            case .off:
                device.torchMode = .off
            case .on:
                if device.isTorchModeSupported(.on) { device.torchMode = .on }
            case .auto:
                device.torchMode = .auto
            }
            device.unlockForConfiguration()
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Unable to configure flash: \(error.localizedDescription)"
            }
        }
    }

    private func deviceForLens(_ lens: CameraLens) -> AVCaptureDevice? {
        switch lens {
        case .ultraWide:
            return AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
        case .wide:
            return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        case .telephoto:
            return AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
        }
    }

    func capturePhoto() {
        guard let photoOutput = photoOutput, session.isRunning else { return }
        isCaptureInProgress = true
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func toggleVideoRecording() {
        guard let movieOutput = movieOutput, session.isRunning else { return }
        if isRecording {
            movieOutput.stopRecording()
        } else {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = documents.appendingPathComponent("recording.mp4")
            try? FileManager.default.removeItem(at: url)
            movieOutput.startRecording(to: url, delegate: self)
        }
    }

    func dismissReview() {
        isReviewing = false
        capturedImage = nil
    }

    /// Process a captured UIImage through the Rust core and return the styled image.
    func styleImage(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let context = CIContext(options: nil)
        let ciImage = CIImage(cgImage: cgImage)
        guard let cg = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }

        let width = cg.width
        let height = cg.height
        let bytesPerRow = width * 4
        let byteCount = bytesPerRow * height

        guard let data = CFDataCreateMutable(nil, byteCount) else { return nil }
        CFDataSetLength(data, byteCount)
        let mutablePtr: UnsafeMutablePointer<UInt8> = CFDataGetMutableBytePtr(data)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let bitmapContext = CGContext(
            data: mutablePtr,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        bitmapContext.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        var frame = CameraFrame(
            width: UInt32(width),
            height: UInt32(height),
            bytes: mutablePtr,
            byte_count: byteCount
        )

        let result = withUnsafeMutablePointer(to: &frame) { framePtr in
            camera_process_frame(framePtr, CameraStyle(rawValue: selectedStyle.rawValue))
        }

        guard result.ok else {
            errorMessage = "Processing failed (code \(result.code))."
            return nil
        }

        guard let outCg = bitmapContext.makeImage() else { return nil }
        return UIImage(cgImage: outCg)
    }
}

/// Camera lens selection.
enum CameraLens: CaseIterable, Codable {
    case ultraWide, wide, telephoto

    var title: String {
        switch self {
        case .ultraWide: return "0.5\u{00D7}"
        case .wide: return "1\u{00D7}"
        case .telephoto: return "2\u{00D7}"
        }
    }

    var icon: String {
        switch self {
        case .ultraWide: return "camera.viewfinder"
        case .wide: return "camera.macro"
        case .telephoto: return "camera.telephoto"
        }
    }
}

/// Flash mode.
enum FlashMode: CaseIterable {
    case off, on, auto

    var title: String {
        switch self {
        case .off: return "\u{26A1}\u{20E5}"  // flash off symbol
        case .on: return "\u{26A1}"            // flash on
        case .auto: return "\u{26A1}\u{00A0}A" // flash auto
        }
    }
}

/// Bridge to the Rust core (`camera-core`). External C functions imported
/// from the `camera_core` staticlib / cdylib.
extension CameraViewModel {}

// MARK: - C ABI imports

@_silgen_name("camera_process_frame")
func camera_process_frame(
    _ frame: UnsafeMutablePointer<CameraFrame>,
    _ style: Int32
) -> CameraResult

@_silgen_name("camera_blend_watermark")
func camera_blend_watermark(
    _ frame: UnsafeMutablePointer<UInt8>,
    _ frame_width: UInt32,
    _ frame_height: UInt32,
    _ watermark: UnsafePointer<UInt8>,
    _ wm_width: UInt32,
    _ wm_height: UInt32,
    _ offset_x: Int32,
    _ offset_y: Int32,
    _ opacity: Float
) -> CameraResult

/// Mirrors Rust `#[repr(C)] struct CameraFrame`.
struct CameraFrame {
    var width: UInt32
    var height: UInt32
    var bytes: UnsafeMutablePointer<UInt8>
    var byte_count: Int
}

/// Mirrors Rust `#[repr(C)] struct CameraResult`.
struct CameraResult {
    var ok: Bool
    var code: UInt32
}

/// Mirrors Rust `#[repr(C)] enum CameraStyle`.
enum CameraStyle: Int32, CaseIterable, Codable {
    case natural = 0
    case xiaomi = 1
    case oppo = 2
    case vivo = 3

    var title: String {
        switch self {
        case .natural: return "Natural"
        case .xiaomi: return "Xiaomi"
        case .oppo: return "Oppo"
        case .vivo: return "Vivo"
        }
    }

    var initials: String {
        switch self {
        case .natural: return "N"
        case .xiaomi: return "X"
        case .oppo: return "O"
        case .vivo: return "V"
        }
    }

    var accentColor: Color {
        switch self {
        case .natural: return Color.white
        case .xiaomi: return Color(red: 1.0, green: 0.82, blue: 0.20)
        case .oppo: return Color(red: 0.3, green: 0.6, blue: 1.0)
        case .vivo: return Color(red: 1.0, green: 0.7, blue: 0.3)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate (live frame processing)

extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard !isProcessingFrame else { return }
        isProcessingFrame = true
        defer { isProcessingFrame = false }

        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        guard baseAddress != nil, bytesPerRow > 0 else { return }

        let byteCount = bytesPerRow * height

        // Copy BGRA pixels into a mutable buffer for the Rust core.
        var rgbaBytes = [UInt8](repeating: 0, count: byteCount)
        rgbaBytes.withUnsafeMutableBufferPointer { dest in
            dest.baseAddress?.initializeMemory(
                from: baseAddress!.assumingMemoryBound(to: UInt8.self),
                count: byteCount
            )
        }

        // BGRA -> RGBA: swap blue and red channels.
        for i in stride(from: 0, to: byteCount, by: 4) {
            rgbaBytes.swapAt(i, i + 2)
        }

        rgbaBytes.withUnsafeMutableBufferPointer { buf in
            guard let ptr = buf.baseAddress else { return }
            var frame = CameraFrame(
                width: UInt32(width),
                height: UInt32(height),
                bytes: ptr,
                byte_count: byteCount
            )
            let result = withUnsafeMutablePointer(to: &frame) { framePtr in
                camera_process_frame(framePtr, CameraStyle(rawValue: selectedStyle.rawValue))
            }
            guard result.ok else { return }

            // Convert processed RGBA8 to CGImage.
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(
                data: ptr,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            ),
            let cgImage = context.makeImage() else { return }

            let image = UIImage(cgImage: cgImage)
            DispatchQueue.main.async {
                self.processedFrame = image
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isCaptureInProgress = false
        }
        if let error = error {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
            return
        }
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to read captured photo."
            }
            return
        }

        let styled = self.styleImage(image) ?? image

        DispatchQueue.main.async {
            self.capturedImage = styled
            self.isReviewing = true
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraViewModel: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        DispatchQueue.main.async {
            self.isRecording = true
        }
    }

    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isRecording = false
        }
        if let error = error {
            DispatchQueue.main.async {
                self.errorMessage = "Recording failed: \(error.localizedDescription)"
            }
        }
    }
}
