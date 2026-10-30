import SwiftUI
import AVFoundation

/// Holds camera session state, style selection, and capture flow.
/// From-scratch implementation.
final class CameraViewModel: ObservableObject {
    @Published var isSessionRunning = false
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var selectedStyle: CameraStyle = .natural
    @Published var isReviewing = false
    @Published var capturedImage: UIImage?
    @Published var isCaptureInProgress = false
    @Published var errorMessage: String?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var videoOutput: AVCaptureVideoDataOutput?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?

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

            // Video input.
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                DispatchQueue.main.async {
                    self.errorMessage = "Unable to access the back camera."
                }
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(input)

            // Video preview stream (for live-style processing).
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            videoOutput.alwaysDiscardsLateVideoFrames = true
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

    func capturePhoto() {
        guard let photoOutput = photoOutput, session.isRunning else { return }
        isCaptureInProgress = true
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func switchStyle(_ style: CameraStyle) {
        selectedStyle = style
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

        // Apply style via the Rust core.
        let styled = self.styleImage(image) ?? image

        DispatchQueue.main.async {
            self.capturedImage = styled
            self.isReviewing = true
        }
    }
}
