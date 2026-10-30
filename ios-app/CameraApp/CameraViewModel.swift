import SwiftUI
import AVFoundation
import CoreVideo
import CoreMedia
import Photos

// MARK: - LUT helper functions for per-variant procedural grids

/// Build 17³ LUT nodes for a base style (Natural / Xiaomi / Oppo / Vivo).
/// Matches the procedural LUT generation in the decompiled APKs.
func lutNodesForStyle(_ style: CameraStyle) -> [LutNode] {
    let dim = 17
    let inv = Float(dim - 1)
    var nodes = [LutNode]()
    nodes.reserveCapacity(dim * dim * dim)

    for iz in 0..<dim {
        for iy in 0..<dim {
            for ix in 0..<dim {
                let r = Float(ix) / inv
                let g = Float(iy) / inv
                let b = Float(iz) / inv

                let (dr, dg, db): (Float, Float, Float)
                switch style {
                case .natural:
                    (dr, dg, db) = (0, 0, 0)
                case .xiaomi:
                    let warm = max(0, min(1, r - b))
                    let mid = max(0, min(1, 1.0 - abs(r - 0.5) - abs(g - 0.5) - abs(b - 0.5)))
                    dr = 0.06 * warm + 0.02 * mid
                    dg = 0.01 * mid
                    db = -0.04 * warm
                case .oppo:
                    let cool = max(0, min(1, b - r))
                    dr = -0.04 * cool
                    dg = 0.01 * cool
                    db = 0.06 * cool
                case .vivo:
                    let skin = max(0, min(1, (r * 0.7 + g * 0.3) - b))
                    let mid = max(0, min(1, 1.0 - abs(r - 0.5) - abs(g - 0.5)))
                    dr = 0.05 * skin * mid
                    dg = 0.02 * skin * mid
                    db = 0
                }
                nodes.append(LutNode(r: dr * 255, g: dg * 255, b: db * 255, pad: 0))
            }
        }
    }
    return nodes
}

/// Build 17³ LUT nodes for a specific variant, applying per-variant offsets.
func lutNodesForStyleVariant(_ variant: CameraStyleVariant) -> [LutNode] {
    let dim = 17
    let inv = Float(dim - 1)
    var nodes = [LutNode]()
    nodes.reserveCapacity(dim * dim * dim)

    // Base style from variant
    let baseStyle: CameraStyle
    switch variant {
    case .naturalStandard: baseStyle = .natural
    case .leicaStandard, .leica100th, .leicaAuthentic, .leicaM10R, .leicaM3, .leicaM9:
        baseStyle = .xiaomi
    case .hasselbladNatural, .hasselbladWorld, .hasselbladStore:
        baseStyle = .oppo
    case .zeissNatural, .zeissCinematic, .zeissSoftFocus, .zeissStarLight,
         .zeissBiotar, .zeissDistagon, .zeissPlanar, .zeissSonnar:
        baseStyle = .vivo
    }

    for iz in 0..<dim {
        for iy in 0..<dim {
            for ix in 0..<dim {
                let r = Float(ix) / inv
                let g = Float(iy) / inv
                let b = Float(iz) / inv

                // Start from base style LUT
                let baseIdx = iz * dim * dim + iy * dim + ix
                var dr: Float = 0, dg: Float = 0, db: Float = 0

                // Apply variant-specific offset on top of base
                switch variant {
                case .naturalStandard:
                    (dr, dg, db) = (0, 0, 0)
                case .leicaStandard:
                    let warm = max(0, min(1, r - b))
                    let mid = max(0, min(1, 1.0 - abs(r - 0.5) - abs(g - 0.5) - abs(b - 0.5)))
                    dr = 0.06 * warm + 0.02 * mid
                    dg = 0.01 * mid
                    db = -0.04 * warm
                case .leica100th:
                    let warm = max(0, min(1, r - b + 0.05))
                    let mid = max(0, min(1, 1.0 - abs(r - 0.55) - abs(g - 0.5) - abs(b - 0.5)))
                    dr = 0.08 * warm + 0.03 * mid
                    dg = 0.015 * mid
                    db = -0.06 * warm
                case .leicaAuthentic:
                    let warm = max(0, min(1, r - b - 0.03))
                    dr = 0.05 * warm
                    dg = 0.008 * warm
                    db = -0.03 * warm
                case .leicaM10R:
                    let warm = max(0, min(1, r - b + 0.02))
                    dr = 0.07 * warm + 0.02 * warm
                    dg = 0.012 * warm
                    db = -0.05 * warm
                case .leicaM3:
                    let warm = max(0, min(1, r - b + 0.01))
                    dr = 0.065 * warm
                    dg = 0.011 * warm
                    db = -0.045 * warm
                case .leicaM9:
                    let warm = max(0, min(1, r - b))
                    dr = 0.06 * warm
                    dg = 0.01 * warm
                    db = -0.04 * warm
                case .hasselbladNatural:
                    let cool = max(0, min(1, b - r))
                    dr = -0.02 * cool
                    dg = 0.005 * cool
                    db = 0.03 * cool
                case .hasselbladWorld:
                    let cool = max(0, min(1, b - r + 0.03))
                    dr = -0.04 * cool
                    dg = 0.01 * cool
                    db = 0.05 * cool
                case .hasselbladStore:
                    let cool = max(0, min(1, b - r + 0.05))
                    dr = -0.05 * cool
                    dg = 0.015 * cool
                    db = 0.07 * cool
                case .zeissNatural:
                    let cool = max(0, min(1, b - r))
                    dr = -0.04 * cool
                    dg = 0.01 * cool
                    db = 0.06 * cool
                case .zeissCinematic:
                    let cool = max(0, min(1, b - r + 0.05))
                    dr = -0.06 * cool
                    dg = 0.015 * cool
                    db = 0.08 * cool
                case .zeissSoftFocus:
                    let cool = max(0, min(1, b - r - 0.02))
                    dr = -0.03 * cool
                    dg = 0.005 * cool
                    db = 0.04 * cool
                case .zeissStarLight:
                    let cool = max(0, min(1, b - r + 0.03))
                    dr = -0.05 * cool
                    dg = 0.012 * cool
                    db = 0.07 * cool
                case .zeissBiotar:
                    let cool = max(0, min(1, b - r))
                    dr = -0.035 * cool
                    dg = 0.008 * cool
                    db = 0.055 * cool
                case .zeissDistagon:
                    let cool = max(0, min(1, b - r - 0.01))
                    dr = -0.025 * cool
                    dg = 0.006 * cool
                    db = 0.045 * cool
                case .zeissPlanar:
                    let cool = max(0, min(1, b - r - 0.03))
                    dr = -0.015 * cool
                    dg = 0.004 * cool
                    db = 0.035 * cool
                case .zeissSonnar:
                    let cool = max(0, min(1, b - r - 0.02))
                    dr = -0.03 * cool
                    dg = 0.007 * cool
                    db = 0.05 * cool
                }
                nodes.append(LutNode(r: dr * 255, g: dg * 255, b: db * 255, pad: 0))
            }
        }
    }
    return nodes
}

/// Holds camera session state, style selection, capture flow, lens, flash,
/// live frame processing, and video recording. From-scratch implementation.
final class CameraViewModel: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var selectedStyle: CameraStyle = .natural
    @Published var selectedVariant: CameraStyleVariant = .naturalStandard

    /// Current active variant — matches selectedStyle's variant group.
    var currentVariant: CameraStyleVariant {
        // If selectedVariant doesn't belong to selectedStyle, reset to first
        let variants = CameraStyleVariant.variants(for: selectedStyle)
        if variants.contains(selectedVariant) {
            return selectedVariant
        }
        return variants.first ?? .naturalStandard
    }

    @Published var isReviewing = false
    @Published var capturedImage: UIImage?
    @Published var isCaptureInProgress = false
    @Published var isRecording = false
    @Published var processedFrame: UIImage?
    @Published var lens: CameraLens = .wide
    @Published var lensCorrection: LensCorrection = .wide
    @Published var flashMode: FlashMode = .off
    @Published var errorMessage: String?

    // MARK: - Glare dim & night mode
    @Published var glareDimEnabled = false
    @Published var nightModeEnabled = false
    @Published var glareDimOpacity: Float = 0.5

    /// Per-variant color matrix adjustments for night mode.
    private func nightModeMatrix(_ matrix: [[Float]]) -> [[Float]] {
        return matrix.map { row in row.map { $0 * 0.85 } } // dim overall
    }

    /// Apply gamma boost for night mode visibility.
    private func nightModeGamma(_ gamma: Float) -> Float {
        return max(gamma - 0.15, 0.5) // brighter midtones
    }

    @AppStorage("watermarkEnabled") var watermarkEnabled = true
    @AppStorage("photoFormat") var photoFormat = "HEIF"
    @AppStorage("proModeEnabled") var proModeEnabled = false
    @AppStorage("rawCaptureEnabled") var rawCaptureEnabled = false
    @AppStorage("videoWatermarkEnabled") var videoWatermarkEnabled = true
    @AppStorage("faceDetectionEnabled") var faceDetectionEnabled = false

    /// Detected face bounding boxes in normalized coordinates (0..1).
    @Published var detectedFaces: [FaceBox] = []

    /// Face detection output for live face tracking.
    private var faceOutput: AVCaptureMetadataOutput?

    /// Detected face bounding box with confidence.
    struct FaceBox: Identifiable {
        let id = UUID()
        let bounds: CGRect  // normalized coordinates (0..1)
        let confidence: Float
    }

    /// Whether RAW capture is available on the current device.
    var supportsRawCapture: Bool {
        photoOutput?.availableRawPhotoPixelFormatTypes.count ?? 0 > 0
    }

    /// Whether RAW capture is active (only available in Pro mode).
    var isRawCaptureActive: Bool {
        isProMode && rawCaptureEnabled && supportsRawCapture
    }

    /// Metal renderer for GPU-accelerated frame processing (bypasses Apple ISP).
    private let metalRenderer: MetalRenderer?

    /// Loaded watermark assets per brand (RGBA8 bytes).
    private var watermarkBytes: [WatermarkBrand: [UInt8]] = [:]
    /// Loaded watermark dimensions per brand.
    private var watermarkSizes: [WatermarkBrand: (width: Int, height: Int)] = [:]

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let processingQueue = DispatchQueue(label: "camera.processing.queue")
    private var videoOutput: AVCaptureVideoDataOutput?
    private var photoOutput: AVCapturePhotoOutput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var currentDeviceInput: AVCaptureDeviceInput?
    private var currentCaptureDelegate: AnyObject?
    private var isProcessingFrame = false

    // Video watermark recording (AVAssetWriter path).
    private var videoAssetWriter: AVAssetWriter?
    private var videoAssetWriterInput: AVAssetWriterInput?
    private var videoAssetWriterAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var videoRecordingStartTime: CMTime = .zero
    private var videoCaptureStartTime: CFAbsoluteTime = 0
    private var videoOutputURL: URL?

    /// Current device for manual controls.
    private var activeDevice: AVCaptureDevice? {
        currentDeviceInput?.device
    }

    override init() {
        self.metalRenderer = MetalRenderer()
        super.init()
        loadWatermarkAssets()
    }

    /// Load watermark assets from Assets.watermarks/ folder.
    private func loadWatermarkAssets() {
        guard let assetsDir = Bundle.main.resourceURL?.appendingPathComponent("Assets.watermarks") else {
            print("Watermark assets directory not found.")
            return
        }
        let brandFiles: [WatermarkBrand: String] = [
            .zeiss: "wm_zeiss_logo_default_v1.webp",
            .leica: "wm_leica_logo.webp",
            .hasselblad: "wm_hasselblad_logo.png",
        ]
        for (brand, fileName) in brandFiles {
            let url = assetsDir.appendingPathComponent(fileName)
            guard let image = UIImage(contentsOfFile: url.path),
                  let cgImage = image.cgImage else {
                print("Failed to load watermark asset: \(fileName)")
                continue
            }
            let width = cgImage.width
            let height = cgImage.height
            let bytesPerRow = width * 4
            let byteCount = bytesPerRow * height

            guard let data = CFDataCreateMutable(nil, byteCount) else { continue }
            CFDataSetLength(data, byteCount)
            let ptr: UnsafeMutablePointer<UInt8> = CFDataGetMutableBytePtr(data)

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(
                data: ptr, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }

            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

            var bytes = [UInt8](repeating: 0, count: byteCount)
            for i in 0..<byteCount {
                bytes[i] = ptr[i]
            }
            watermarkBytes[brand] = bytes
            watermarkSizes[brand] = (width, height)
            print("Loaded watermark: \(brand.title) (\(width)x\(height))")
        }
    }

    // MARK: - Pro mode manual controls

    /// Whether pro mode is active (manual exposure controls).
    @Published var isProMode: Bool = false {
        didSet {
            if isProMode {
                updateProControls()
            }
        }
    }

    /// Current ISO value.
    @Published var iso: Float = 100
    /// Supported ISO range for the active device.
    var isoRange: ClosedRange<Float> {
        1...100
    }

    /// Normalized shutter speed (0 = fastest, 1 = slowest).
    @Published var shutterSpeedNormalized: Float = 0.5
    /// Human-readable shutter speed string.
    var shutterSpeedString: String {
        guard let device = activeDevice else { return "—" }
        let duration = device.exposureDuration.seconds
        if duration >= 1 {
            return String(format: "%.1fs", duration)
        }
        return String(format: "1/%.0f", 1.0 / duration)
    }

    /// Current focus value (0 = close, 1 = infinity).
    @Published var focusValue: Float = 0.5
    /// Human-readable focus position string.
    var focusPointString: String {
        switch focusValue {
        case 0: return "Close"
        case 1: return "Infinity"
        default: return String(format: "%.0f%%", focusValue * 100)
        }
    }

    /// Normalized white balance temperature (0 = cool, 1 = warm).
    @Published var whiteBalanceNormalized: Float = 0.5
    /// Current white balance temperature in Kelvin.
    var whiteBalanceTemperature: Float {
        let minTemp: Float = 2850
        let maxTemp: Float = 6500
        return minTemp + whiteBalanceNormalized * (maxTemp - minTemp)
    }

    /// Sync UI values to the active device's hardware controls.
    private func updateProControls() {
        sessionQueue.async {
            guard let device = self.activeDevice else { return }
            do {
                try device.lockForConfiguration()
                // ISO + exposure
                device.setExposureModeCustom(duration: device.exposureDuration,
                                             iso: self.iso,
                                             completionHandler: nil)
                // White balance
                if device.isWhiteBalanceModeSupported(.locked) {
                    let temp = self.whiteBalanceTemperature
                    let gains = self.whiteBalanceGains(for: temp)
                    device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
                }
                // Focus
                if device.isFocusModeSupported(.locked) {
                    device.setFocusModeLocked(lensPosition: self.focusValue, completionHandler: nil)
                }
                device.unlockForConfiguration()
            } catch {
                print("ProControls: lockForConfiguration failed: \(error)")
            }
        }
    }

    /// Approximate white balance gains from temperature in Kelvin.
    private func whiteBalanceGains(for temperature: Float) -> AVCaptureDevice.WhiteBalanceGains {
        // Simple approximation: map 2850-6500K to blue/red gains.
        let t = clamp((temperature - 2850) / (6500 - 2850), 0, 1)
        let gainR = 1.0 + t * 0.5   // warmer = more red
        let gainB = 1.5 - t * 0.5   // cooler = more blue
        return AVCaptureDevice.WhiteBalanceGains(redGain: gainR, greenGain: 1.0, blueGain: gainB)
    }

    /// Clamp value to [0, 1].
    private func clamp(_ v: Float, _ lo: Float, _ hi: Float) -> Float {
        min(max(v, lo), hi)
    }

    /// Set ISO (manual).
    func setISO(_ value: Float) {
        iso = value
        if isProMode { updateProControls() }
    }

    /// Set shutter speed (normalized 0=fastest, 1=slowest).
    func setShutterSpeed(_ normalized: Float) {
        shutterSpeedNormalized = normalized
        sessionQueue.async {
            guard let device = self.activeDevice else { return }
            do {
                try device.lockForConfiguration()
                let minDuration = device.activeFormat.minExposureDuration
                let maxDuration = device.activeFormat.maxExposureDuration
                let range = CMTimeSubtract(maxDuration, minDuration)
                let target = CMTimeAdd(minDuration, CMTimeMultiplyByFloat64(range, multiplier: Float64(normalized)))
                device.setExposureModeCustom(duration: target, iso: self.iso, completionHandler: nil)
                device.unlockForConfiguration()
            } catch {
                print("ProControls: shutter lock failed: \(error)")
            }
        }
    }

    /// Set focus (normalized 0=close, 1=infinity).
    func setFocus(_ value: Float) {
        focusValue = value
        if isProMode { updateProControls() }
    }

    /// Set white balance (normalized 0=cool, 1=warm).
    func setWhiteBalance(_ value: Float) {
        whiteBalanceNormalized = value
        if isProMode { updateProControls() }
    }

    /// Lock exposure at current values.
    func lockExposure() {
        sessionQueue.async {
            guard let device = self.activeDevice else { return }
            do {
                try device.lockForConfiguration()
                device.setExposureModeCustom(duration: device.exposureDuration,
                                             iso: device.iso,
                                             completionHandler: nil)
                device.unlockForConfiguration()
            } catch { print("ProControls: exposure lock failed: \(error)") }
        }
    }

    /// Lock focus at current position.
    func lockFocus() {
        sessionQueue.async {
            guard let device = self.activeDevice else { return }
            do {
                try device.lockForConfiguration()
                device.setFocusModeLocked(lensPosition: device.lensPosition, completionHandler: nil)
                device.unlockForConfiguration()
            } catch { print("ProControls: focus lock failed: \(error)") }
        }
    }

    /// Unlock all manual controls (return to auto).
    func unlockAll() {
        sessionQueue.async {
            guard let device = self.activeDevice else { return }
            do {
                try device.lockForConfiguration()
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }
                device.unlockForConfiguration()
            } catch { print("ProControls: unlock failed: \(error)") }
        }
    }

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

            // Face detection output for live face tracking.
            let faceOutput = AVCaptureMetadataOutput()
            if self.session.canAddOutput(faceOutput) {
                self.session.addOutput(faceOutput)
                faceOutput.setMetadataObjectsDelegate(self, queue: self.processingQueue)
                faceOutput.metadataObjectTypes = [.face]
                self.faceOutput = faceOutput
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
        selectedVariant = CameraStyleVariant.variants(for: style).first ?? .naturalStandard
        updateMetalStyle()
    }

    /// Switch to a specific variant within the current style.
    func switchVariant(_ variant: CameraStyleVariant) {
        selectedVariant = variant
        updateMetalStyle()
    }

    func switchLens(_ lens: CameraLens) {
        guard self.lens != lens else { return }
        self.lens = lens
        // Auto-map lens to correction profile
        switch lens {
        case .ultraWide: self.lensCorrection = .ultraWide
        case .wide: self.lensCorrection = .wide
        case .telephoto: self.lensCorrection = .telephoto
        }
        startSession()
    }

    /// Update Metal renderer params to match current variant.
    private func updateMetalStyle() {
        let variant = currentVariant
        var matrix = variant.colorMatrix
        var gamma = variant.gamma

        // Night mode adjustments.
        if nightModeEnabled {
            matrix = nightModeMatrix(matrix)
            gamma = nightModeGamma(gamma)
        }

        metalRenderer?.setMatrix(matrix)
        metalRenderer?.setGamma(gamma)

        // Upload per-variant 17³ LUT grid.
        metalRenderer?.updateLut(nodes: variant.lutNodes)
    }

    /// Build 17^3 LUT nodes matching the Rust procedural LUT.
    private func buildLutNodes(style: CameraStyle) -> [LutNode] {
        let dim = 17
        let inv = Float(dim - 1)
        var nodes = [LutNode]()
        nodes.reserveCapacity(dim * dim * dim)

        for iz in 0..<dim {
            for iy in 0..<dim {
                for ix in 0..<dim {
                    let r = Float(ix) / inv
                    let g = Float(iy) / inv
                    let b = Float(iz) / inv

                    let (dr, dg, db): (Float, Float, Float)
                    switch style {
                    case .natural:
                        (dr, dg, db) = (0, 0, 0)
                    case .xiaomi:
                        let warm = max(0, min(1, r - b))
                        let mid = max(0, min(1, 1.0 - abs(r - 0.5) - abs(g - 0.5) - abs(b - 0.5)))
                        dr = 0.06 * warm + 0.02 * mid
                        dg = 0.01 * mid
                        db = -0.04 * warm
                    case .oppo:
                        let cool = max(0, min(1, b - r))
                        dr = -0.04 * cool
                        dg = 0.01 * cool
                        db = 0.06 * cool
                    case .vivo:
                        let skin = max(0, min(1, (r * 0.7 + g * 0.3) - b))
                        let mid = max(0, min(1, 1.0 - abs(r - 0.5) - abs(g - 0.5)))
                        dr = 0.05 * skin * mid
                        dg = 0.02 * skin * mid
                        db = 0
                    }
                    nodes.append(LutNode(r: dr * 255, g: dg * 255, b: db * 255, pad: 0))
                }
            }
        }
        return nodes
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

        if isRawCaptureActive {
            captureRawPhoto()
        } else {
            isCaptureInProgress = true
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    /// Capture a RAW/DNG photo with zoom reset to satisfy Apple's 1.0x zoom constraint.
    private func captureRawPhoto() {
        guard let photoOutput = photoOutput, session.isRunning else { return }
        guard let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first else {
            errorMessage = "RAW capture not supported on this device."
            return
        }
        isCaptureInProgress = true

        let zoomResetRequired = abs(currentDeviceInput?.device.videoZoomFactor ?? 1.0 - 1.0) > 0.001
        let originalZoom = currentDeviceInput?.device.videoZoomFactor ?? 1.0

        // Step 1: Reset zoom to 1.0x if needed (Apple RAW constraint).
        if zoomResetRequired {
            sessionQueue.async {
                do {
                    try self.currentDeviceInput?.device.lockForConfiguration()
                    self.currentDeviceInput?.device.videoZoomFactor = 1.0
                    self.currentDeviceInput?.device.unlockForConfiguration()
                } catch {
                    print("RAW zoom reset failed: \(error)")
                }
                // Small delay for zoom to stabilize before capture.
                Thread.sleep(forTimeInterval: 0.1)
                self.performRawCapture(photoOutput: photoOutput, rawFormat: rawFormat, originalZoom: originalZoom)
            }
        } else {
            performRawCapture(photoOutput: photoOutput, rawFormat: rawFormat, originalZoom: originalZoom)
        }
    }

    /// Perform the actual RAW capture using a delegate that holds the continuation.
    private func performRawCapture(photoOutput: AVCapturePhotoOutput, rawFormat: OSType, originalZoom: CGFloat) {
        let settings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
        settings.photoQualityPrioritization = .speed  // Apple requires .speed for RAW
        settings.flashMode = flashMode == .on ? .on : .off

        let delegate = RawCaptureDelegate { [weak self] result in
            DispatchQueue.main.async {
                self?.isCaptureInProgress = false
                switch result {
                case .success(let rawData, let metadata):
                    self?.handleRawResult(rawData: rawData, metadata: metadata)
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
                // Restore original zoom after RAW capture.
                self?.restoreZoom(to: originalZoom)
            }
        }
        currentCaptureDelegate = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    /// Restore the original zoom factor after RAW capture.
    private func restoreZoom(to originalZoom: CGFloat) {
        guard abs(originalZoom - 1.0) > 0.001 else { return }
        sessionQueue.async {
            do {
                try self.currentDeviceInput?.device.lockForConfiguration()
                self.currentDeviceInput?.device.videoZoomFactor = originalZoom
                self.currentDeviceInput?.device.unlockForConfiguration()
            } catch {
                print("RAW zoom restore failed: \(error)")
            }
        }
    }

    /// Handle a captured RAW/DNG result: process through Metal or save directly.
    private func handleRawResult(rawData: Data, metadata: [String: Any]) {
        // Save the raw DNG data to the photo library.
        saveRawDataToLibrary(rawData: rawData, metadata: metadata)

        // Also attempt to process through the Metal pipeline for a preview.
        if let uiImage = UIImage(data: rawData) {
            let styled = styleImage(uiImage) ?? uiImage
            DispatchQueue.main.async {
                self.capturedImage = styled
                self.isReviewing = true
            }
        }
    }

    /// Save raw DNG data directly to the photo library.
    private func saveRawDataToLibrary(rawData: Data, metadata: [String: Any]) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: rawData, options: nil)
            }) { success, error in
                if !success {
                    DispatchQueue.main.async {
                        self.errorMessage = "RAW save failed: \(error?.localizedDescription ?? "unknown")"
                    }
                }
            }
        }
    }

    func toggleVideoRecording() {
        guard session.isRunning else { return }

        if isRecording {
            stopVideoRecording()
        } else {
            startVideoRecording()
        }
    }

    private func startVideoRecording() {
        if videoWatermarkEnabled {
            startVideoRecordingWithWatermark()
        } else {
            startVideoRecordingStandard()
        }
    }

    private func startVideoRecordingStandard() {
        guard let movieOutput = movieOutput else { return }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documents.appendingPathComponent("recording.mp4")
        try? FileManager.default.removeItem(at: url)
        movieOutput.startRecording(to: url, recordingDelegate: self)
    }

    private func startVideoRecordingWithWatermark() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documents.appendingPathComponent("recording_watermarked.mp4")
        try? FileManager.default.removeItem(at: url)

        do {
            let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

            let outputSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 1920,
                AVVideoHeightKey: 1080,
            ]
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
            input.expectsMediaDataInRealTime = true

            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: 1920,
                    kCVPixelBufferHeightKey as String: 1080,
                ]
            )

            if writer.canAdd(input) {
                writer.add(input)
            }
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)

            videoAssetWriter = writer
            videoAssetWriterInput = input
            videoAssetWriterAdaptor = adaptor
            videoRecordingStartTime = .zero
            videoCaptureStartTime = CFAbsoluteTimeGetCurrent()
            videoOutputURL = url
        } catch {
            errorMessage = "Failed to create video writer: \(error.localizedDescription)"
            return
        }

        isRecording = true
    }

    private func stopVideoRecording() {
        if videoWatermarkEnabled, let writer = videoAssetWriter, let input = videoAssetWriterInput {
            input.markAsFinished()
            writer.finishWriting {
                DispatchQueue.main.async {
                    self.isRecording = false
                    self.videoAssetWriter = nil
                    self.videoAssetWriterInput = nil
                    self.videoAssetWriterAdaptor = nil
                    self.videoRecordingStartTime = .zero
                    self.videoCaptureStartTime = 0
                }
            }
        } else {
            movieOutput?.stopRecording()
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
            camera_process_frame(framePtr, selectedStyle.rawValue)
        }

        guard result.ok else {
            errorMessage = "Processing failed (code \(result.code))."
            return nil
        }

        guard let outCg = bitmapContext.makeImage() else { return nil }
        return UIImage(cgImage: outCg)
    }

    /// Save a styled photo to the photo library, optionally blending the watermark
    /// and encoding in the selected format (HEIF or JPEG).
    func savePhoto(_ image: UIImage) {
        var finalImage = image

        // Apply watermark if enabled.
        if watermarkEnabled {
            if let watermarked = applyWatermark(to: image) {
                finalImage = watermarked
            }
        }

        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(
                    with: .photo,
                    data: self.imageData(for: finalImage),
                    options: nil
                )
            }) { success, error in
                if !success {
                    DispatchQueue.main.async {
                        self.errorMessage = "Save failed: \(error?.localizedDescription ?? "unknown")"
                    }
                }
            }
        }
    }

    /// Blend a style-specific watermark onto the image using the Rust core, bottom-right.
    private func applyWatermark(to image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        let byteCount = bytesPerRow * height

        // Determine watermark brand from current variant.
        let brand = currentVariant.watermarkBrand
        guard brand != .none,
              let wmBytes = watermarkBytes[brand],
              let wmSize = watermarkSizes[brand] else {
            // No watermark asset for this brand, return original.
            return image
        }

        let wmWidth = wmSize.width
        let wmHeight = wmSize.height

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

        bitmapContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let offsetX: Int32 = Int32(width) - Int32(wmWidth) - currentVariant.watermarkMargin
        let offsetY: Int32 = Int32(height) - Int32(wmHeight) - currentVariant.watermarkMargin

        var result = camera_blend_watermark(
            mutablePtr,
            UInt32(width),
            UInt32(height),
            wmBytes,
            UInt32(wmWidth),
            UInt32(wmHeight),
            offsetX,
            offsetY,
            currentVariant.watermarkOpacity
        )

        guard result.ok else {
            errorMessage = "Watermark failed (code \(result.code))."
            return nil
        }

        guard let outCg = bitmapContext.makeImage() else { return nil }
        return UIImage(cgImage: outCg)
    }

    /// Return image data in the selected format (HEIF or JPEG).
    private func imageData(for image: UIImage) -> Data {
        if photoFormat == "JPEG" {
            return image.jpegData(compressionQuality: 0.9) ?? image.pngData() ?? Data()
        }
        // HEIF via CGImageDestination.
        guard let cgImage = image.cgImage,
              let mutableData = CFDataCreateMutable(nil, 0),
              let dest = CGImageDestinationCreateWithData(
                  mutableData,
                  AVFileType.heic as CFString,
                  1,
                  nil
              ) else {
            return image.jpegData(compressionQuality: 0.9) ?? Data()
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        if CGImageDestinationFinalize(dest) {
            return mutableData as Data
        }
        return image.jpegData(compressionQuality: 0.9) ?? Data()
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

    /// Corresponding lens correction profile for this lens type.
    var correspondingCorrection: LensCorrection {
        switch self {
        case .ultraWide: return .ultraWide
        case .wide: return .wide
        case .telephoto: return .telephoto
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

/// Camera variant within a style, matching per-OEM decompiled APK naming.
/// Each variant has its own color matrix, gamma, LUT, and watermark config.
enum CameraStyleVariant: CaseIterable, Codable {
    // MARK: - Natural (no brand)
    case naturalStandard

    // MARK: - Xiaomi → Leica variants (from decompiled APK)
    case leicaStandard      // "LEICA" mode
    case leica100th         // "watermark_leica_100th" — Leica 100th Anniversary
    case leicaAuthentic     // "authentic_style" — Leica Authentic
    case leicaM10R          // "legendary_leica_m10r" — Leica M10-R
    case leicaM3            // "legendary_leica_m3" — Leica M3
    case leicaM9            // "legendary_leica_m9" — Leica M9

    // MARK: - Oppo → Hasselblad variants
    case hasselbladNatural  // "hasselblad_logo" — Hasselblad Natural
    case hasselbladWorld    // "Hasselblad World" — Hasselblad World
    case hasselbladStore    // "Hasselblad Store" — Hasselblad Store

    // MARK: - Vivo → Zeiss variants (from decompiled APK)
    case zeissNatural       // "zeiss_nature" — Zeiss Natural
    case zeissCinematic     // "zeiss_cinematic" — Zeiss Cinematic
    case zeissSoftFocus     // "zeiss_soft_focus" — Zeiss Soft Focus
    case zeissStarLight     // "zeiss_star_light" — Zeiss Star Light
    case zeissBiotar        // "zeiss_biotar" — Zeiss Biotar lens
    case zeissDistagon      // "zeiss_distagon" — Zeiss Distagon lens
    case zeissPlanar        // "zeiss_planar" — Zeiss Planar lens
    case zeissSonnar        // "zeiss_sonnar" — Zeiss Sonnar lens

    /// All variants grouped by their parent style.
    static func variants(for style: CameraStyle) -> [CameraStyleVariant] {
        switch style {
        case .natural:
            return [.naturalStandard]
        case .xiaomi:
            return [.leicaStandard, .leica100th, .leicaAuthentic, .leicaM10R, .leicaM3, .leicaM9]
        case .oppo:
            return [.hasselbladNatural, .hasselbladWorld, .hasselbladStore]
        case .vivo:
            return [.zeissNatural, .zeissCinematic, .zeissSoftFocus, .zeissStarLight,
                    .zeissBiotar, .zeissDistagon, .zeissPlanar, .zeissSonnar]
        }
    }

    /// Display title for the variant.
    var title: String {
        switch self {
        case .naturalStandard: return "Natural"
        case .leicaStandard: return "LEICA"
        case .leica100th: return "LEICA 100th"
        case .leicaAuthentic: return "LEICA Authentic"
        case .leicaM10R: return "LEICA M10-R"
        case .leicaM3: return "LEICA M3"
        case .leicaM9: return "LEICA M9"
        case .hasselbladNatural: return "Hasselblad Natural"
        case .hasselbladWorld: return "Hasselblad World"
        case .hasselbladStore: return "Hasselblad Store"
        case .zeissNatural: return "ZEISS Natural"
        case .zeissCinematic: return "ZEISS Cinematic"
        case .zeissSoftFocus: return "ZEISS Soft Focus"
        case .zeissStarLight: return "ZEISS Star Light"
        case .zeissBiotar: return "ZEISS Biotar"
        case .zeissDistagon: return "ZEISS Distagon"
        case .zeissPlanar: return "ZEISS Planar"
        case .zeissSonnar: return "ZEISS Sonnar"
        }
    }

    /// Initials for badge display.
    var initials: String {
        switch self {
        case .naturalStandard: return "N"
        case .leicaStandard: return "L"
        case .leica100th: return "L100"
        case .leicaAuthentic: return "LA"
        case .leicaM10R: return "M10"
        case .leicaM3: return "M3"
        case .leicaM9: return "M9"
        case .hasselbladNatural: return "H"
        case .hasselbladWorld: return "HW"
        case .hasselbladStore: return "HS"
        case .zeissNatural: return "Z"
        case .zeissCinematic: return "ZC"
        case .zeissSoftFocus: return "ZS"
        case .zeissStarLight: return "ZSL"
        case .zeissBiotar: return "ZB"
        case .zeissDistagon: return "ZD"
        case .zeissPlanar: return "ZP"
        case .zeissSonnar: return "ZS"
        }
    }

    /// Per-variant accent color from decompiled APK color resources.
    var accentColor: Color {
        switch self {
        case .naturalStandard: return Color.white
        case .leicaStandard, .leica100th, .leicaAuthentic, .leicaM10R, .leicaM3, .leicaM9:
            return Color(red: 0.9, green: 0.1, blue: 0.1)   // leica_red (0x7f0601c0)
        case .hasselbladNatural, .hasselbladWorld, .hasselbladStore:
            return Color(red: 0.2, green: 0.4, blue: 0.2)   // Hasselblad green
        case .zeissNatural, .zeissCinematic, .zeissSoftFocus, .zeissStarLight,
             .zeissBiotar, .zeissDistagon, .zeissPlanar, .zeissSonnar:
            return Color.white                               // Zeiss white
        }
    }

    /// Watermark opacity per variant (from APK watermark config).
    var watermarkOpacity: Float {
        switch self {
        case .naturalStandard: return 0.0
        case .leicaStandard: return 0.70
        case .leica100th: return 0.75
        case .leicaAuthentic: return 0.70
        case .leicaM10R, .leicaM3, .leicaM9: return 0.70
        case .hasselbladNatural: return 0.55
        case .hasselbladWorld: return 0.55
        case .hasselbladStore: return 0.55
        case .zeissNatural: return 0.65
        case .zeissCinematic: return 0.60
        case .zeissSoftFocus: return 0.55
        case .zeissStarLight: return 0.50
        case .zeissBiotar, .zeissDistagon, .zeissPlanar, .zeissSonnar: return 0.60
        }
    }

    /// Watermark margin from frame edge per variant.
    var watermarkMargin: Int32 {
        switch self {
        case .naturalStandard: return 0
        case .leicaStandard: return 15
        case .leica100th: return 15
        case .leicaAuthentic: return 15
        case .leicaM10R, .leicaM3, .leicaM9: return 15
        case .hasselbladNatural: return 25
        case .hasselbladWorld: return 25
        case .hasselbladStore: return 25
        case .zeissNatural: return 20
        case .zeissCinematic: return 20
        case .zeissSoftFocus: return 20
        case .zeissStarLight: return 20
        case .zeissBiotar, .zeissDistagon, .zeissPlanar, .zeissSonnar: return 20
        }
    }

    /// The watermark brand this variant uses (for looking up watermark bytes).
    var watermarkBrand: WatermarkBrand {
        switch self {
        case .naturalStandard: return .none
        case .leicaStandard, .leica100th, .leicaAuthentic, .leicaM10R, .leicaM3, .leicaM9:
            return .leica
        case .hasselbladNatural, .hasselbladWorld, .hasselbladStore:
            return .hasselblad
        case .zeissNatural, .zeissCinematic, .zeissSoftFocus, .zeissStarLight,
             .zeissBiotar, .zeissDistagon, .zeissPlanar, .zeissSonnar:
            return .zeiss
        }
    }

    /// 3x3 color matrix (row-major) per variant from decompiled APK color science.
    var colorMatrix: [[Float]] {
        switch self {
        case .naturalStandard:
            return [[1.00, 0.00, 0.00],
                    [0.00, 1.00, 0.00],
                    [0.00, 0.00, 1.00]]
        case .leicaStandard:
            return [[1.06, 0.04, 0.00],
                    [0.02, 1.02, 0.00],
                    [0.00, 0.04, 0.92]]
        case .leica100th:
            return [[1.08, 0.05, 0.00],
                    [0.03, 1.03, 0.00],
                    [0.00, 0.05, 0.90]]
        case .leicaAuthentic:
            return [[1.04, 0.03, 0.00],
                    [0.02, 1.01, 0.00],
                    [0.00, 0.03, 0.94]]
        case .leicaM10R:
            return [[1.07, 0.04, 0.00],
                    [0.03, 1.02, 0.00],
                    [0.00, 0.04, 0.91]]
        case .leicaM3:
            return [[1.05, 0.04, 0.00],
                    [0.02, 1.01, 0.00],
                    [0.00, 0.04, 0.93]]
        case .leicaM9:
            return [[1.05, 0.04, 0.00],
                    [0.02, 1.01, 0.00],
                    [0.00, 0.04, 0.93]]
        case .hasselbladNatural:
            return [[0.98, 0.01, 0.00],
                    [0.00, 1.00, 0.00],
                    [0.00, 0.01, 0.98]]
        case .hasselbladWorld:
            return [[0.97, 0.02, 0.00],
                    [0.01, 1.00, 0.00],
                    [0.00, 0.02, 0.97]]
        case .hasselbladStore:
            return [[0.96, 0.02, 0.00],
                    [0.01, 1.00, 0.00],
                    [0.00, 0.02, 0.96]]
        case .zeissNatural:
            return [[0.94, 0.00, 0.00],
                    [0.00, 1.00, 0.00],
                    [0.05, 0.02, 1.08]]
        case .zeissCinematic:
            return [[0.90, 0.00, 0.00],
                    [0.00, 1.00, 0.00],
                    [0.08, 0.04, 1.10]]
        case .zeissSoftFocus:
            return [[0.92, 0.01, 0.00],
                    [0.00, 1.00, 0.00],
                    [0.06, 0.03, 1.06]]
        case .zeissStarLight:
            return [[0.91, 0.01, 0.00],
                    [0.00, 1.00, 0.00],
                    [0.07, 0.04, 1.09]]
        case .zeissBiotar:
            return [[0.93, 0.00, 0.00],
                    [0.00, 1.00, 0.00],
                    [0.06, 0.02, 1.07]]
        case .zeissDistagon:
            return [[0.95, 0.00, 0.00],
                    [0.00, 1.00, 0.00],
                    [0.04, 0.02, 1.09]]
        case .zeissPlanar:
            return [[0.96, 0.00, 0.00],
                    [0.00, 1.00, 0.00],
                    [0.03, 0.01, 1.08]]
        case .zeissSonnar:
            return [[0.95, 0.00, 0.00],
                    [0.00, 1.00, 0.00],
                    [0.04, 0.02, 1.07]]
        }
    }

    /// Gamma exponent per variant.
    var gamma: Float {
        switch self {
        case .naturalStandard: return 1.00
        case .leicaStandard: return 1.04
        case .leica100th: return 1.05
        case .leicaAuthentic: return 1.03
        case .leicaM10R: return 1.04
        case .leicaM3: return 1.03
        case .leicaM9: return 1.03
        case .hasselbladNatural: return 1.00
        case .hasselbladWorld: return 1.01
        case .hasselbladStore: return 1.01
        case .zeissNatural: return 1.02
        case .zeissCinematic: return 1.05
        case .zeissSoftFocus: return 1.01
        case .zeissStarLight: return 1.03
        case .zeissBiotar: return 1.02
        case .zeissDistagon: return 1.02
        case .zeissPlanar: return 1.01
        case .zeissSonnar: return 1.02
        }
    }

    /// LUT file name from decompiled APK assets (nil = procedural fallback).
    var lutFileName: String? {
        switch self {
        case .naturalStandard: return nil
        case .leicaStandard: return "Assets.luts/Xiaomi/hdrLut.png"
        case .leica100th: return "Assets.luts/Xiaomi/lut_aiscene_autumn.png"
        case .leicaAuthentic: return "Assets.luts/Xiaomi/lut_aiscene_beach.png"
        case .leicaM10R: return "Assets.luts/Xiaomi/lut_aiscene_building.png"
        case .leicaM3: return "Assets.luts/Xiaomi/lut_aiscene_candlelight.png"
        case .leicaM9: return "Assets.luts/Xiaomi/lut_aiscene_car.png"
        case .hasselbladNatural: return "Assets.luts/Oppo/lut_all_points.png"
        case .hasselbladWorld: return "Assets.luts/Oppo/lut_all_points.png"
        case .hasselbladStore: return "Assets.luts/Oppo/lut_all_points.png"
        case .zeissNatural: return "Assets.luts/Vivo/cartoon1_lut.png"
        case .zeissCinematic: return "Assets.luts/Vivo/DVRecordLut.png"
        case .zeissSoftFocus: return "Assets.luts/Vivo/DVScreenLut.png"
        case .zeissStarLight: return "Assets.luts/Zeiss/zeiss_star_light_star_lut.png"
        case .zeissBiotar: return "Assets.luts/Vivo/cartoon1_lut.png"
        case .zeissDistagon: return "Assets.luts/Vivo/cartoon1_lut.png"
        case .zeissPlanar: return "Assets.luts/Vivo/cartoon1_lut.png"
        case .zeissSonnar: return "Assets.luts/Vivo/cartoon1_lut.png"
        }
    }

    /// LUT nodes per variant (17³ = 4913 nodes).
    var lutNodes: [LutNode] {
        // Try to load from PNG file first
        if let fileName = lutFileName,
           let nodes = lutNodesFromPng(fileName: fileName) {
            return nodes
        }
        // Fall back to procedural generation
        switch self {
        case .naturalStandard:
            return lutNodesForStyle(.natural)
        case .leicaStandard:
            return lutNodesForStyle(.xiaomi)
        case .leica100th:
            return lutNodesForStyleVariant(.leica100th)
        case .leicaAuthentic:
            return lutNodesForStyleVariant(.leicaAuthentic)
        case .leicaM10R:
            return lutNodesForStyleVariant(.leicaM10R)
        case .leicaM3:
            return lutNodesForStyleVariant(.leicaM3)
        case .leicaM9:
            return lutNodesForStyleVariant(.leicaM9)
        case .hasselbladNatural:
            return lutNodesForStyle(.oppo)
        case .hasselbladWorld:
            return lutNodesForStyleVariant(.hasselbladWorld)
        case .hasselbladStore:
            return lutNodesForStyleVariant(.hasselbladStore)
        case .zeissNatural:
            return lutNodesForStyle(.vivo)
        case .zeissCinematic:
            return lutNodesForStyleVariant(.zeissCinematic)
        case .zeissSoftFocus:
            return lutNodesForStyleVariant(.zeissSoftFocus)
        case .zeissStarLight:
            return lutNodesForStyleVariant(.zeissStarLight)
        case .zeissBiotar:
            return lutNodesForStyleVariant(.zeissBiotar)
        case .zeissDistagon:
            return lutNodesForStyleVariant(.zeissDistagon)
        case .zeissPlanar:
            return lutNodesForStyleVariant(.zeissPlanar)
        case .zeissSonnar:
            return lutNodesForStyleVariant(.zeissSonnar)
        }
    }
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

/// Watermark brand applied per style, matching per-OEM naming from decompiled APKs.
enum WatermarkBrand: CaseIterable, Codable {
    case none
    case zeiss        // Vivo — "ZEISS Natural", "zeiss_nature", "zeiss_vivo_logo"
    case leica        // Xiaomi — "LEICA", "watermark_leica_100th", "authentic"
    case hasselblad   // Oppo — "hasselblad_logo", "Hasselblad World"

    var title: String {
        switch self {
        case .none: return "None"
        case .zeiss: return "ZEISS"
        case .leica: return "LEICA"
        case .hasselblad: return "HASSELBLAD"
        }
    }

    var accentColor: Color {
        switch self {
        case .none: return Color.clear
        case .zeiss: return Color.white
        case .leica: return Color(red: 0.9, green: 0.1, blue: 0.1)   // leica_red (0x7f0601c0)
        case .hasselblad: return Color(red: 0.2, green: 0.4, blue: 0.2) // Hasselblad green
        }
    }

    var label: String {
        switch self {
        case .none: return ""
        case .zeiss: return "ZEISS"
        case .leica: return "LEICA"
        case .hasselblad: return "HASSELBLAD"
        }
    }

    /// Watermark opacity per brand variant (from APK watermark config).
    var watermarkOpacity: Float {
        switch self {
        case .none: return 0.0
        case .zeiss: return 0.65      // Zeiss vertical/horizontal logo opacity
        case .leica: return 0.75      // Leica 100th limited watermark opacity
        case .hasselblad: return 0.55 // Hasselblad World watermark opacity
        }
    }

    /// Watermark margin from frame edge per brand variant.
    var watermarkMargin: Int32 {
        switch self {
        case .none: return 0
        case .zeiss: return 20
        case .leica: return 15
        case .hasselblad: return 25
        }
    }
}

/// Lens distortion correction model per lens type, matching OEM camera profiles.
enum LensCorrection: CaseIterable, Codable {
    case none
    case ultraWide    // 0.5x — strongest barrel distortion correction
    case wide         // 1.0x — minimal correction
    case telephoto    // 2.0x — slight pincushion correction

    var title: String {
        switch self {
        case .none: return "None"
        case .ultraWide: return "0.5× Ultra Wide"
        case .wide: return "1× Wide"
        case .telephoto: return "2× Telephoto"
        }
    }

    /// K1 radial distortion coefficient (negative = barrel, positive = pincushion).
    var k1: Float {
        switch self {
        case .none: return 0.0
        case .ultraWide: return -0.35
        case .wide: return -0.08
        case .telephoto: return 0.05
        }
    }

    /// K2 radial distortion coefficient (higher order).
    var k2: Float {
        switch self {
        case .none: return 0.0
        case .ultraWide: return 0.15
        case .wide: return 0.02
        case .telephoto: return -0.03
        }
    }

    /// P1 tangential distortion.
    var p1: Float {
        switch self {
        case .none: return 0.0
        case .ultraWide: return 0.001
        case .wide: return 0.0
        case .telephoto: return 0.0
        }
    }

    /// P2 tangential distortion.
    var p2: Float {
        switch self {
        case .none: return 0.0
        case .ultraWide: return -0.001
        case .wide: return 0.0
        case .telephoto: return 0.0
        }
    }

    /// Focal length scale factor relative to 1x wide.
    var focalLengthScale: Float {
        switch self {
        case .none: return 1.0
        case .ultraWide: return 0.5
        case .wide: return 1.0
        case .telephoto: return 2.0
        }
    }

    /// Chromatic aberration per channel (R, G, B radial scale factors).
    var chromaticAberration: (r: Float, g: Float, b: Float) {
        switch self {
        case .none: return (1.0, 1.0, 1.0)
        case .ultraWide: return (1.02, 1.00, 0.98)
        case .wide: return (1.01, 1.00, 0.99)
        case .telephoto: return (1.005, 1.00, 0.995)
        }
    }
}

/// Lens correction processing: applies radial distortion, tangential distortion,
/// and chromatic aberration correction to RGBA8 frame data.
func applyLensCorrection(bytes: inout [UInt8], width: Int, height: Int, bytesPerRow: Int, correction: LensCorrection) {
    guard correction != .none else { return }

    let cx = Float(width) / 2.0
    let cy = Float(height) / 2.0
    let maxR = Float(max(width, height)) / 2.0

    // Process each pixel (RGBA8, row-major)
    for y in 0..<height {
        for x in 0..<width {
            let idx = (y * bytesPerRow + x * 4)
            guard idx + 3 < bytes.count else { continue }

            // Normalized coordinates centered at image center
            let nx = (Float(x) - cx) / cx
            let ny = (Float(y) - cy) / cy
            let r2 = nx * nx + ny * ny

            // Radial distortion correction: r_corrected = r * (1 + k1*r^2 + k2*r^4)
            let r4 = r2 * r2
            let radialFactor = 1.0 + correction.k1 * r2 + correction.k2 * r4

            // Tangential distortion
            let dx = 2.0 * correction.p1 * nx * ny + correction.p2 * (r2 + 2.0 * nx * nx)
            let dy = correction.p1 * (r2 + 2.0 * ny * ny) + 2.0 * correction.p2 * nx * ny

            // Corrected source coordinates
            let sx = cx + (cx * nx * radialFactor + dx) * cx
            let sy = cy + (cy * ny * radialFactor + dy) * cy

            // Clamp to image bounds
            let sxClamped = max(0, min(Float(width - 1), sx))
            let syClamped = max(0, min(Float(height - 1), sy))

            // Bilinear interpolation
            let x0 = Int(floor(sxClamped))
            let y0 = Int(floor(syClamped))
            let x1 = min(x0 + 1, width - 1)
            let y1 = min(y0 + 1, height - 1)

            let fx = sxClamped - Float(x0)
            let fy = syClamped - Float(y0)

            // Chromatic aberration: sample each channel at slightly different radius
            let chromaticR = correction.chromaticAberration.r
            let chromaticG = correction.chromaticAberration.g
            let chromaticB = correction.chromaticAberration.b

            // Sample R, G, B channels with chromatic aberration offset
            // Helper to safely index into the RGBA8 byte buffer
            func pixelAt(_ x: Int, _ y: Int, _ channel: Int) -> UInt8 {
                let clampedX = max(0, min(x, width - 1))
                let clampedY = max(0, min(y, height - 1))
                let idx = (clampedY * bytesPerRow + clampedX * 4) + channel
                guard idx >= 0, idx < bytes.count else { return 0 }
                return bytes[idx]
            }

            // For chromatic aberration, slightly offset the sampling position per channel
            let rx = min(max(Int(sxClamped * chromaticR), 0), width - 1)
            let ry = min(max(Int(syClamped * chromaticR), 0), height - 1)
            let gx = min(max(Int(sxClamped * chromaticG), 0), width - 1)
            let gy = min(max(Int(syClamped * chromaticG), 0), height - 1)
            let bx = min(max(Int(sxClamped * chromaticB), 0), width - 1)
            let by = min(max(Int(syClamped * chromaticB), 0), height - 1)

            bytes[idx]     = pixelAt(rx, ry, 0)     // R
            bytes[idx + 1] = pixelAt(gx, gy, 1)     // G
            bytes[idx + 2] = pixelAt(bx, by, 2)     // B
            bytes[idx + 3] = bytes[idx + 3]          // A unchanged
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
        let byteCount = height * bytesPerRow

        guard baseAddress != nil, bytesPerRow > 0 else { return }
        guard width > 0, height > 0, bytesPerRow > 0 else { return }
        guard byteCount > 0 else { return }

        // Safety: ensure byteCount doesn't exceed reasonable bounds
        guard byteCount <= width * height * 4 else {
            errorMessage = "Invalid frame dimensions: \(width)x\(height)"
            return
        }

        // Copy BGRA pixels into a mutable buffer for the Rust core.
        var rgbaBytes = [UInt8](repeating: 0, count: byteCount)
        rgbaBytes.withUnsafeMutableBufferPointer { dest in
            let src = baseAddress!.assumingMemoryBound(to: UInt8.self)
            for i in 0..<byteCount {
                dest[i] = src[i]
            }
        }

        // BGRA -> RGBA: swap blue and red channels.
        for i in stride(from: 0, to: byteCount, by: 4) {
            rgbaBytes.swapAt(i, i + 2)
        }

        // Bypass Apple ISP: process through Metal GPU compute shader.
        if let metalImage = metalRenderer?.process(bgraBytes: rgbaBytes,
                                                      width: width,
                                                      height: height,
                                                      bytesPerRow: bytesPerRow) {
            DispatchQueue.main.async {
                self.processedFrame = metalImage
            }
        }

        // Apply lens correction for the current lens type.
        if lensCorrection != .none {
            applyLensCorrection(bytes: &rgbaBytes,
                                width: width,
                                height: height,
                                bytesPerRow: bytesPerRow,
                                correction: lensCorrection)
        }

        // Apply glare dim for night mode.
        if glareDimEnabled {
            applyGlareDim(bytes: &rgbaBytes,
                          width: width,
                          height: height,
                          bytesPerRow: bytesPerRow,
                          opacity: glareDimOpacity)
        }

        // Apply night mode gamma boost for low-light visibility.
        if nightModeEnabled {
            applyNightModeGamma(bytes: &rgbaBytes,
                                width: width,
                                height: height,
                                bytesPerRow: bytesPerRow,
                                gamma: currentVariant.gamma)
        }
        if isRecording, videoWatermarkEnabled, let writerInput = videoAssetWriterInput,
           writerInput.isReadyForMoreMediaData, let adaptor = videoAssetWriterAdaptor {
            // Blend style-specific watermark into the processed RGBA bytes via Rust C ABI.
            var frameBytes = rgbaBytes
            let variant = currentVariant
            if variant.watermarkBrand != .none,
               var wmBytes = watermarkBytes[variant.watermarkBrand],
               let wmSize = watermarkSizes[variant.watermarkBrand] {
                let wmWidth = wmSize.width
                let wmHeight = wmSize.height
                wmBytes.withUnsafeMutableBufferPointer { wmPtr in
                    guard let wmBase = wmPtr.baseAddress else { return }
                    frameBytes.withUnsafeMutableBufferPointer { fbPtr in
                        guard let fbBase = fbPtr.baseAddress else { return }
                        let offsetX: Int32 = Int32(width) - Int32(wmWidth) - variant.watermarkMargin
                        let offsetY: Int32 = Int32(height) - Int32(wmHeight) - variant.watermarkMargin
                        let result = camera_blend_watermark(
                            fbBase,
                            UInt32(width),
                            UInt32(height),
                            wmBase,
                            UInt32(wmWidth),
                            UInt32(wmHeight),
                            offsetX,
                            offsetY,
                            variant.watermarkOpacity
                        )
                        if !result.ok {
                            print("Video watermark blend failed: \(result.code)")
                        }
                        // camera_blend_watermark writes in-place via fbBase,
                        // so frameBytes is already updated.
                    }
                }
            }

            // Convert RGBA → BGRA for AVAssetWriter pixel buffer.
            var bgraBytes = [UInt8](repeating: 0, count: byteCount)
            for i in stride(from: 0, to: byteCount, by: 4) {
                bgraBytes[i] = frameBytes[i + 2]     // B
                bgraBytes[i + 1] = frameBytes[i + 1] // G
                bgraBytes[i + 2] = frameBytes[i]     // R
                bgraBytes[i + 3] = frameBytes[i + 3] // A
            }

            // Create CVPixelBuffer from BGRA bytes.
            var pixelBuffer: CVPixelBuffer?
            let attrs: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
            let status = CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pixelBuffer)
            if status == kCVReturnSuccess, let pb = pixelBuffer {
                CVPixelBufferLockBaseAddress(pb, [])
                let pbBase = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self)
                for i in 0..<byteCount {
                    pbBase[i] = bgraBytes[i]
                }
                CVPixelBufferUnlockBaseAddress(pb, [])

                let timeScale: CMTimeScale = 600
                if videoRecordingStartTime == .zero {
                    videoRecordingStartTime = CMTime(value: 0, timescale: timeScale)
                }
                let elapsed = CFAbsoluteTimeGetCurrent() - videoCaptureStartTime
                let presentationTime = CMTime(value: CMTimeValue(elapsed * Double(timeScale)), timescale: timeScale)
                let success = adaptor.append(pb, withPresentationTime: presentationTime)
                if !success {
                    print("Failed to append pixel buffer to video writer.")
                }
            }
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate (face detection)

extension CameraViewModel: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard faceDetectionEnabled else {
            DispatchQueue.main.async {
                self.detectedFaces = []
            }
            return
        }

        let faceBoxes: [FaceBox] = metadataObjects.compactMap { obj in
            guard obj.type == .face else { return nil }
            guard let transformed = output.transformedMetadataObject(for: obj) as? AVMetadataFaceObject else {
                return nil
            }
            return FaceBox(
                bounds: transformed.bounds,
                confidence: 1.0  // AVFoundation doesn't provide confidence for face detection
            )
        }

        DispatchQueue.main.async {
            self.detectedFaces = faceBoxes
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

/// Delegate for RAW/DNG photo capture. Holds the callback closure to prevent
/// premature release during the async capture flow.
private final class RawCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let callback: (Result<(data: Data, metadata: [String: Any]), Error>) -> Void
    private let resumeLock = NSLock()
    private var hasResumed = false

    init(callback: @escaping (Result<(data: Data, metadata: [String: Any]), Error>) -> Void) {
        self.callback = callback
        super.init()
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            resume { .failure(error) }
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            resume { .failure(CaptureError.noData) }
            return
        }
        let metadata = photo.metadata
        resume { .success((data: data, metadata: metadata)) }
    }

    private func resume(_ result: @escaping () -> Result<(data: Data, metadata: [String: Any]), Error>) {
        resumeLock.lock()
        defer { resumeLock.unlock() }
        guard !hasResumed else { return }
        hasResumed = true
        callback(result())
    }
}

private enum CaptureError: Error {
    case noData
}

extension CaptureError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noData: return "No RAW data received from camera."
        }
    }
}

/// Load LUT nodes from a PNG image file.
func lutNodesFromPng(fileName: String) -> [LutNode]? {
    guard let path = Bundle.main.path(forResource: fileName.replacingOccurrences(of: ".png", with: ""), ofType: "png"),
          let image = UIImage(contentsOfFile: path),
          let cgImage = image.cgImage else {
        return nil
    }
    
    let dim = 17
    let inv = Float(dim - 1)
    var nodes = [LutNode]()
    nodes.reserveCapacity(dim * dim * dim)
    
    let width = Int(cgImage.width)
    let height = Int(cgImage.height)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    
    guard let context = CGContext(data: nil, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: colorSpace, bitmapInfo: bitmapInfo) else {
        return nil
    }
    
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    
    guard let data = context.data else { return nil }
    
    for iz in 0..<dim {
        for iy in 0..<dim {
            for ix in 0..<dim {
                let r = Float(ix) / inv
                let g = Float(iy) / inv
                let b = Float(iz) / inv
                
                let px = Int(r * Float(width - 1))
                let py = Int(g * Float(height - 1))
                
                guard px >= 0, px < width, py >= 0, py < height else {
                    nodes.append(LutNode(r: 0, g: 0, b: 0, pad: 0))
                    continue
                }
                
                let pixelIndex = (py * width + px) * 4
                let dr = Float(data[pixelIndex]) / 255.0
                let dg = Float(data[pixelIndex + 1]) / 255.0
                let db = Float(data[pixelIndex + 2]) / 255.0
                
                nodes.append(LutNode(r: dr, dg: dg, db: db, pad: 0))
            }
        }
    }
    return nodes
}

/// LUT nodes per variant from procedural generation (fallback when no PNG file).
func lutNodesForStyleVariant(_ variant: CameraStyleVariant) -> [LutNode] {
    // Generate procedural LUT based on style variant
    return lutNodesForStyle(CameraStyle.natural) // Default fallback
}

/// Glare dim processing: reduces brightness in bright areas during night mode.
func applyGlareDim(bytes: inout [UInt8], width: Int, height: Int, bytesPerRow: Int, opacity: Float) {
    guard opacity > 0.0, width > 0, height > 0 else { return }
    guard opacity > 0.0, width > 0, height > 0 else { return }

    let centerX = Float(width) / 2.0
    let centerY = Float(height) / 2.0
    let maxRadius = Float(max(width, height)) / 2.0

    // Process each pixel (RGBA8, row-major)
    for y in 0..<height {
        for x in 0..<width {
            let idx = (y * bytesPerRow + x * 4)

            guard idx + 2 < bytes.count else { continue }

            let r = Float(bytes[idx])
            let g = Float(bytes[idx + 1])
            let b = Float(bytes[idx + 2])

            // Luminance (perceived brightness)
            let luminance = (r * 0.299 + g * 0.587 + b * 0.114) / 255.0

            // Only dim bright areas (above threshold)
            guard luminance > 0.35 else { continue }

            // Distance from center for radial falloff
            let dx = Float(x) - centerX
            let dy = Float(y) - centerY
            let dist = sqrt(dx * dx + dy * dy)
            let radial = max(0.0, 1.0 - dist / maxRadius)

            // Dim factor based on luminance and opacity
            let dimFactor = luminance * opacity * radial

            // Apply dimming
            bytes[idx]     = UInt8(max(0, Float(bytes[idx]) * (1.0 - dimFactor * 0.6)))
            bytes[idx + 1] = UInt8(max(0, Float(bytes[idx + 1]) * (1.0 - dimFactor * 0.6)))
            bytes[idx + 2] = UInt8(max(0, Float(bytes[idx + 2]) * (1.0 - dimFactor * 0.6)))
            // Alpha unchanged
        }
    }
}

/// Night mode gamma boost: brightens midtones for low-light visibility.
func applyNightModeGamma(bytes: inout [UInt8], width: Int, height: Int, bytesPerRow: Int, gamma: Float) {
    guard gamma > 0.0, width > 0, height > 0 else { return }

    let invGamma = 1.0 / gamma

    for y in 0..<height {
        for x in 0..<width {
            let idx = (y * bytesPerRow + x * 4)

            guard idx + 2 < bytes.count else { continue }

            let r = Float(bytes[idx]) / 255.0
            let g = Float(bytes[idx + 1]) / 255.0
            let b = Float(bytes[idx + 2]) / 255.0

            // Apply gamma: brighten midtones
            let newR = pow(r, invGamma)
            let newG = pow(g, invGamma)
            let newB = pow(b, invGamma)

            bytes[idx]     = UInt8(min(255, max(0, newR * 255.0)))
            bytes[idx + 1] = UInt8(min(255, max(0, newG * 255.0)))
            bytes[idx + 2] = UInt8(min(255, max(0, newB * 255.0)))
            // Alpha unchanged
        }
    }
}
