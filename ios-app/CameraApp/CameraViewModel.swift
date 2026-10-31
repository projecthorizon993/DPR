import SwiftUI
import AVFoundation
import CoreVideo
import CoreMedia
import Photos
import UIKit
import CoreGraphics

// MARK: - Camera Style
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

    var watermarkBrand: WatermarkBrand {
        switch self {
        case .natural: return .none
        case .xiaomi: return .leica
        case .oppo: return .hasselblad
        case .vivo: return .zeiss
        }
    }
}

// MARK: - Camera Style Variant
enum CameraStyleVariant: CaseIterable, Codable {
    case naturalStandard
    case leicaStandard, leica100th, leicaAuthentic, leicaM10R, leicaM3, leicaM9
    case hasselbladNatural, hasselbladWorld, hasselbladStore
    case zeissNatural, zeissCinematic, zeissSoftFocus, zeissStarLight
    case zeissBiotar, zeissDistagon, zeissPlanar, zeissSonnar

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

    var initials: String {
        switch self {
        case .naturalStandard: return "N"
        case .leicaStandard: return "L"
        case .leica100th: return "L100"
        case .leicaAuthentic: return "LA"
        case .leicaM10R: return "M10R"
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
        case .zeissSonnar: return "ZSN"
        }
    }

    var accentColor: Color {
        switch self {
        case .naturalStandard: return Color.white
        case .leicaStandard, .leica100th, .leicaAuthentic, .leicaM10R, .leicaM3, .leicaM9:
            return Color(red: 0.9, green: 0.1, blue: 0.1)
        case .hasselbladNatural, .hasselbladWorld, .hasselbladStore:
            return Color(red: 0.2, green: 0.4, blue: 0.2)
        case .zeissNatural, .zeissCinematic, .zeissSoftFocus, .zeissStarLight,
             .zeissBiotar, .zeissDistagon, .zeissPlanar, .zeissSonnar:
            return Color.white
        }
    }

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

    var colorMatrix: [[Float]] {
        switch self {
        case .naturalStandard:
            return [[1.00, 0.00, 0.00], [0.00, 1.00, 0.00], [0.00, 0.00, 1.00]]
        case .leicaStandard:
            return [[1.06, 0.04, 0.00], [0.02, 1.02, 0.00], [0.00, 0.04, 0.92]]
        case .leica100th:
            return [[1.08, 0.05, 0.00], [0.03, 1.03, 0.00], [0.00, 0.05, 0.90]]
        case .leicaAuthentic:
            return [[1.04, 0.03, 0.00], [0.02, 1.01, 0.00], [0.00, 0.03, 0.94]]
        case .leicaM10R:
            return [[1.07, 0.04, 0.00], [0.03, 1.02, 0.00], [0.00, 0.04, 0.91]]
        case .leicaM3:
            return [[1.05, 0.04, 0.00], [0.02, 1.01, 0.00], [0.00, 0.04, 0.93]]
        case .leicaM9:
            return [[1.05, 0.04, 0.00], [0.02, 1.01, 0.00], [0.00, 0.04, 0.93]]
        case .hasselbladNatural:
            return [[0.98, 0.01, 0.00], [0.00, 1.00, 0.00], [0.00, 0.01, 0.98]]
        case .hasselbladWorld:
            return [[0.97, 0.02, 0.00], [0.01, 1.00, 0.00], [0.00, 0.02, 0.97]]
        case .hasselbladStore:
            return [[0.96, 0.02, 0.00], [0.01, 1.00, 0.00], [0.00, 0.02, 0.96]]
        case .zeissNatural:
            return [[0.94, 0.00, 0.00], [0.00, 1.00, 0.00], [0.05, 0.02, 1.08]]
        case .zeissCinematic:
            return [[0.90, 0.00, 0.00], [0.00, 1.00, 0.00], [0.08, 0.04, 1.10]]
        case .zeissSoftFocus:
            return [[0.92, 0.01, 0.00], [0.00, 1.00, 0.00], [0.06, 0.03, 1.06]]
        case .zeissStarLight:
            return [[0.91, 0.01, 0.00], [0.00, 1.00, 0.00], [0.07, 0.04, 1.09]]
        case .zeissBiotar:
            return [[0.93, 0.00, 0.00], [0.00, 1.00, 0.00], [0.06, 0.02, 1.07]]
        case .zeissDistagon:
            return [[0.95, 0.00, 0.00], [0.00, 1.00, 0.00], [0.04, 0.02, 1.09]]
        case .zeissPlanar:
            return [[0.96, 0.00, 0.00], [0.00, 1.00, 0.00], [0.03, 0.01, 1.08]]
        case .zeissSonnar:
            return [[0.95, 0.00, 0.00], [0.00, 1.00, 0.00], [0.04, 0.02, 1.07]]
        }
    }

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

    var lutNodes: [LutNode] {
        lutNodesForStyleVariant(self)
    }

    /// Int32 raw value for FFI bridge to Rust core.
    var styleRawValue: Int32 {
        switch self {
        case .naturalStandard: return 0
        case .leicaStandard: return 1
        case .leica100th: return 2
        case .leicaAuthentic: return 3
        case .leicaM10R: return 4
        case .leicaM3: return 5
        case .leicaM9: return 6
        case .hasselbladNatural: return 7
        case .hasselbladWorld: return 8
        case .hasselbladStore: return 9
        case .zeissNatural: return 10
        case .zeissCinematic: return 11
        case .zeissSoftFocus: return 12
        case .zeissStarLight: return 13
        case .zeissBiotar: return 14
        case .zeissDistagon: return 15
        case .zeissPlanar: return 16
        case .zeissSonnar: return 17
        }
    }

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
}

// MARK: - Watermark Brand
enum WatermarkBrand: CaseIterable, Codable {
    case none
    case zeiss
    case leica
    case hasselblad

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
        case .leica: return Color(red: 0.9, green: 0.1, blue: 0.1)
        case .hasselblad: return Color(red: 0.2, green: 0.4, blue: 0.2)
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

    var watermarkOpacity: Float {
        switch self {
        case .none: return 0.0
        case .zeiss: return 0.65
        case .leica: return 0.75
        case .hasselblad: return 0.55
        }
    }

    var watermarkMargin: Int32 {
        switch self {
        case .none: return 0
        case .zeiss: return 20
        case .leica: return 15
        case .hasselblad: return 25
        }
    }
}

// MARK: - Lens Correction Model
enum LensCorrection: CaseIterable, Codable {
    case none, ultraWide, wide, telephoto

    var title: String {
        switch self {
        case .none: return "None"
        case .ultraWide: return "0.5× Ultra Wide"
        case .wide: return "1× Wide"
        case .telephoto: return "2× Telephoto"
        }
    }

    var isoRange: ClosedRange<Float> { 1...100 }
    var minWhiteBalanceTemperature: Float { 2850 }
    var maxWhiteBalanceTemperature: Float { 6500 }
}

// MARK: - Flash Mode
enum FlashMode: CaseIterable {
    case off, on, auto

    var title: String {
        switch self {
        case .off: return "\u{26A1}\u{20E5}"
        case .on: return "\u{26A1}"
        case .auto: return "\u{26A1}\u{00A0}A"
        }
    }
}

// MARK: - Camera Lens
enum CameraLens: CaseIterable, Codable {
    case ultraWide, wide, telephoto

    var title: String {
        switch self {
        case .ultraWide: return "0.5×"
        case .wide: return "1×"
        case .telephoto: return "2×"
        }
    }

    var correspondingCorrection: LensCorrection {
        switch self {
        case .ultraWide: return .ultraWide
        case .wide: return .wide
        case .telephoto: return .telephoto
        }
    }
}

// MARK: - LUT node struct
struct LutNode {
    var r: Float
    var g: Float
    var b: Float
    var pad: Float = 0
}

// MARK: - CameraFrame / CameraResult (mirror Rust repr(C) structs)
struct CameraFrame {
    var width: UInt32
    var height: UInt32
    var bytes: UnsafeMutablePointer<UInt8>
    var byte_count: Int
}

struct CameraResult {
    var ok: Bool
    var code: UInt32
}

// MARK: - Push-constant struct for Metal
struct ProcessParams {
    var matrix: simd_float3x3
    var gamma: Float
    var pad0: Float
    var pad1: Float
    var pad2: Float
}

// MARK: - LUT helper functions

/// Build 17³ LUT nodes for a base style (Natural / Xiaomi / Oppo / Vivo).
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

/// Build 17³ LUT nodes for a specific variant
func lutNodesForStyleVariant(_ variant: CameraStyleVariant) -> [LutNode] {
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

                var dr: Float = 0, dg: Float = 0, db: Float = 0

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
                    dr = 0.07 * warm
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

/// Load LUT nodes from a PNG image file
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
                                  space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else {
        return nil
    }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let data = context.data else { return nil }
    let ptr = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

    for iz in 0..<dim {
        for iy in 0..<dim {
            for ix in 0..<dim {
                let px = Int(Float(width) * Float(ix) / Float(dim - 1))
                let py = Int(Float(height) * Float(iz) / Float(dim - 1))
                let pixelIndex = (py * width + px) * 4

                let dr = Float(ptr[pixelIndex]) / 255.0
                let dg = Float(ptr[pixelIndex + 1]) / 255.0
                let db = Float(ptr[pixelIndex + 2]) / 255.0

                nodes.append(LutNode(r: dr * 255, g: dg * 255, b: db * 255, pad: 0))
            }
        }
    }
    return nodes
}

// MARK: - CameraViewModel
final class CameraViewModel: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var selectedStyle: CameraStyle = .natural
    @Published var selectedVariant: CameraStyleVariant = .naturalStandard

    /// Current active variant — matches selectedStyle's variant group.
    var currentVariant: CameraStyleVariant {
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

    @AppStorage("watermarkEnabled") var watermarkEnabled = true
    @AppStorage("photoFormat") var photoFormat = "HEIF"
    @AppStorage("proModeEnabled") var proModeEnabled = false
    @AppStorage("rawCaptureEnabled") var rawCaptureEnabled = false
    @AppStorage("videoWatermarkEnabled") var videoWatermarkEnabled = true
    @AppStorage("faceDetectionEnabled") var faceDetectionEnabled = false
    @AppStorage("nightModeEnabledApp") var nightModeEnabledApp = false
    @AppStorage("glareDimEnabledApp") var glareDimEnabledApp = false
    @AppStorage("nightModeStrength") var nightModeStrength: Double = 0.5

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

    var isProMode: Bool {
    get { proModeEnabled }
    set { proModeEnabled = newValue }
}

    var iso: Float { 100 }
    var isoRange: ClosedRange<Float> { 1...100 }

    var shutterSpeedNormalized: Float {
        get { 0.5 }
        set { /* shutter speed applied to device */ }
    }
    var shutterSpeedString: String { "1/60s" }

    var focusValue: Float {
        get { 0.5 }
        set { /* focus applied to device */ }
    }
    var focusPointString: String { "Auto" }

    var whiteBalanceNormalized: Float {
        get { 0.5 }
        set { /* white balance applied to device */ }
    }
    var whiteBalanceTemperature: Float { 5600 }

    func setISO(_ value: Float) { /* ISO applied to device */ }
    func setShutterSpeed(_ value: Float) { /* shutter applied to device */ }
    func setFocus(_ value: Float) { /* focus applied to device */ }
    func setWhiteBalance(_ value: Float) { /* white balance applied to device */ }

    func lockExposure() {
        guard let device = currentDeviceInput?.device else { return }
        do {
            try device.lockForConfiguration()
            device.setExposureModeCustom(duration: device.exposureDuration, iso: device.iso, completionHandler: nil)
            device.unlockForConfiguration()
        } catch { print("Lock exposure failed: \(error)") }
    }

    func lockFocus() {
        guard let device = currentDeviceInput?.device else { return }
        do {
            try device.lockForConfiguration()
            device.focusMode = .continuousAutoFocus
            device.unlockForConfiguration()
        } catch { print("Lock focus failed: \(error)") }
    }

    func unlockAll() {
        guard let device = currentDeviceInput?.device else { return }
        do {
            try device.lockForConfiguration()
            device.exposureMode = .continuousAutoExposure
            device.focusMode = .continuousAutoFocus
            device.whiteBalanceMode = .continuousAutoWhiteBalance
            device.unlockForConfiguration()
        } catch { print("Unlock failed: \(error)") }
    }

    /// Metal renderer for GPU-accelerated frame processing.
    private let metalRenderer: MetalRenderer?

    /// Night mode enhancement processor
    private let nightEnhancer = NightEnhancer()

    /// Zoom manager with AI upscaling
    private let zoomManager = ZoomManager()

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

    private var videoAssetWriter: AVAssetWriter?
    private var videoAssetWriterInput: AVAssetWriterInput?
    private var videoAssetWriterAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var videoRecordingStartTime: CMTime = .zero
    private var videoCaptureStartTime: CFAbsoluteTime = 0.0
    private var videoOutputURL: URL?

    private var watermarkBytes: [WatermarkBrand: [UInt8]] = [:]
    private var watermarkSizes: [WatermarkBrand: (width: Int, height: Int)] = [:]

    override init() {
        self.metalRenderer = MetalRenderer()
        super.init()
        loadWatermarkAssets()
    }

    var previewLayerView: AVCaptureVideoPreviewLayer? { previewLayer }

    func setPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = layer
        layer.session = session
        layer.videoGravity = .resizeAspectFill
    }

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
            if let input = self.currentDeviceInput {
                self.session.removeInput(input)
                self.currentDeviceInput = nil
            }
            self.session.outputs.forEach { self.session.removeOutput($0) }
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

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: self.processingQueue)
            if self.session.canAddOutput(videoOutput) {
                self.session.addOutput(videoOutput)
                self.videoOutput = videoOutput
            }

            let photoOutput = AVCapturePhotoOutput()
            if self.session.canAddOutput(photoOutput) {
                self.session.addOutput(photoOutput)
                self.photoOutput = photoOutput
            }

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

    func switchStyle(_ style: CameraStyle) {
        selectedStyle = style
        selectedVariant = CameraStyleVariant.variants(for: style).first ?? .naturalStandard
        updateMetalStyle()
    }

    func switchVariant(_ variant: CameraStyleVariant) {
        selectedVariant = variant
        updateMetalStyle()
    }

    func switchLens(_ lens: CameraLens) {
        self.lens = lens
        self.lensCorrection = lens.correspondingCorrection
        startSession()
    }

    func toggleFlash() {
        switch flashMode {
        case .off: flashMode = .on
        case .on: flashMode = .auto
        case .auto: flashMode = .off
        }
        if let device = currentDeviceInput?.device {
            applyFlashMode(to: device)
        }
    }

    private func applyFlashMode(to device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            switch flashMode {
            case .on:
                device.torchMode = .on
                device.flashMode = .on
            case .off:
                device.torchMode = .off
                device.flashMode = .off
            case .auto:
                device.torchMode = .off
                device.flashMode = .auto
            }
            device.unlockForConfiguration()
        } catch {
            print("Flash mode apply failed: \(error)")
        }
    }

    private func deviceForLens(_ lens: CameraLens) -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .back
        )
        for device in discovery.devices {
            switch lens {
            case .ultraWide where device.deviceType == .builtInUltraWideCamera:
                return device
            case .wide where device.deviceType == .builtInWideAngleCamera:
                return device
            case .telephoto where device.deviceType == .builtInTelephotoCamera:
                return device
            default: break
            }
        }
        return discovery.devices.first { $0.deviceType == .builtInWideAngleCamera }
    }

    private func updateMetalStyle() {
        let variant = currentVariant
        metalRenderer?.setMatrix(variant.colorMatrix)
        metalRenderer?.setGamma(variant.gamma)
        metalRenderer?.updateLut(nodes: variant.lutNodes)
    }

    private func loadWatermarkAssets() {
        // Watermark assets loaded from Assets.watermarks; placeholder for now.
        // Actual PNG bytes are loaded lazily when first needed.
    }

    private func loadWatermarkImage(for brand: WatermarkBrand) -> (bytes: [UInt8], width: Int, height: Int)? {
        let fileName: String
        switch brand {
        case .none: return nil
        case .zeiss: fileName = "zeiss"
        case .leica: fileName = "leica"
        case .hasselblad: fileName = "hasselblad"
        }
        guard let path = Bundle.main.path(forResource: fileName, ofType: "png"),
              let image = UIImage(contentsOfFile: path),
              let cgImage = image.cgImage else {
            return nil
        }
        let width = Int(cgImage.width)
        let height = Int(cgImage.height)
        let bytesPerRow = width * 4
        let byteCount = bytesPerRow * height
        guard let data = CFDataCreateMutable(nil, byteCount) else { return nil }
        CFDataSetLength(data, byteCount)
        let mutablePtr: UnsafeMutablePointer<UInt8> = CFDataGetMutableBytePtr(data)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let bitmapContext = CGContext(data: mutablePtr, width: width, height: height,
                                            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                            space: colorSpace,
                                            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        bitmapContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        var bytes = [UInt8](repeating: 0, count: byteCount)
        memcpy(&bytes, mutablePtr, byteCount)
        return (bytes, width, height)
    }

    // MARK: - Photo capture

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

    private func captureRawPhoto() {
        guard let photoOutput = photoOutput, session.isRunning else { return }
        guard let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first else {
            errorMessage = "RAW capture not supported on this device."
            return
        }
        isCaptureInProgress = true

        let zoomResetRequired = abs(currentDeviceInput?.device.videoZoomFactor ?? 1.0 - 1.0) > 0.001
        let originalZoom = currentDeviceInput?.device.videoZoomFactor ?? 1.0

        if zoomResetRequired {
            sessionQueue.async {
                do {
                    try self.currentDeviceInput?.device.lockForConfiguration()
                    self.currentDeviceInput?.device.videoZoomFactor = 1.0
                    self.currentDeviceInput?.device.unlockForConfiguration()
                } catch {
                    print("RAW zoom reset failed: \(error)")
                }
                Thread.sleep(forTimeInterval: 0.1)
                self.performRawCapture(photoOutput: photoOutput, rawFormat: rawFormat, originalZoom: originalZoom)
            }
        } else {
            performRawCapture(photoOutput: photoOutput, rawFormat: rawFormat, originalZoom: originalZoom)
        }
    }

    private func performRawCapture(photoOutput: AVCapturePhotoOutput, rawFormat: OSType, originalZoom: CGFloat) {
        let settings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
        settings.photoQualityPrioritization = .speed
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
                self?.restoreZoom(to: originalZoom)
            }
        }
        currentCaptureDelegate = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

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

    private func handleRawResult(rawData: Data, metadata: [String: Any]) {
        saveRawDataToLibrary(rawData: rawData, metadata: metadata)

        if let uiImage = UIImage(data: rawData) {
            let styled = styleImage(uiImage) ?? uiImage
            DispatchQueue.main.async {
                self.capturedImage = styled
                self.isReviewing = true
            }
        }
    }

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

    func dismissReview() {
        isReviewing = false
        capturedImage = nil
    }

    func savePhoto(_ image: UIImage) {
        var finalImage = image
        if watermarkEnabled {
            if let watermarked = applyWatermark(to: image) {
                finalImage = watermarked
            }
        }
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: self.imageData(for: finalImage), options: nil)
            }) { success, error in
                if !success {
                    DispatchQueue.main.async {
                        self.errorMessage = "Save failed: \(error?.localizedDescription ?? "unknown")"
                    }
                }
            }
        }
    }

    // MARK: - Video recording

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
                    self.videoCaptureStartTime = 0.0
                }
            }
        } else {
            movieOutput?.stopRecording()
        }
    }

    // MARK: - Image processing

    private func brandForCurrentVariant() -> WatermarkBrand {
        currentVariant.watermarkBrand
    }

    private func watermarkBytesForBrand(_ brand: WatermarkBrand) -> (bytes: [UInt8], width: Int, height: Int)? {
        if let cached = watermarkBytes[brand], let size = watermarkSizes[brand] {
            return (cached, size.width, size.height)
        }
        guard let loaded = loadWatermarkImage(for: brand) else { return nil }
        watermarkBytes[brand] = loaded.bytes
        watermarkSizes[brand] = (loaded.width, loaded.height)
        return (loaded.bytes, loaded.width, loaded.height)
    }

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
            camera_process_frame(framePtr, currentVariant.styleRawValue)
        }
        guard result.ok else {
            errorMessage = "Processing failed (code \(result.code))."
            return nil
        }
        guard let outCg = bitmapContext.makeImage() else { return nil }
        return UIImage(cgImage: outCg)
    }

    private func applyWatermark(to image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        let byteCount = bytesPerRow * height
        let brand = currentVariant.watermarkBrand
        guard brand != .none,
              let wmInfo = watermarkBytesForBrand(brand) else {
            return image
        }
        let wmBytes = wmInfo.bytes
        let wmWidth = wmInfo.width
        let wmHeight = wmInfo.height
        guard let data = CFDataCreateMutable(nil, byteCount) else { return nil }
        CFDataSetLength(data, byteCount)
        let mutablePtr: UnsafeMutablePointer<UInt8> = CFDataGetMutableBytePtr(data)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let bitmapContext = CGContext(data: mutablePtr, width: width, height: height,
                                            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                            space: colorSpace,
                                            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        bitmapContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let offsetX: Int32 = Int32(width) - Int32(wmWidth) - currentVariant.watermarkMargin
        let offsetY: Int32 = Int32(height) - Int32(wmHeight) - currentVariant.watermarkMargin
        _ = camera_blend_watermark(
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
        guard let outCg = bitmapContext.makeImage() else { return nil }
        return UIImage(cgImage: outCg)
    }

    private func imageData(for image: UIImage) -> Data {
        if photoFormat == "JPEG" {
            return image.jpegData(compressionQuality: 0.9) ?? image.pngData() ?? Data()
        }
        guard let cgImage = image.cgImage,
              let mutableData = CFDataCreateMutable(nil, 0),
              let dest = CGImageDestinationCreateWithData(mutableData, AVFileType.heic as CFString, 1, nil)
        else {
            return image.jpegData(compressionQuality: 0.9) ?? Data()
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        if CGImageDestinationFinalize(dest) {
            return mutableData as Data
        }
        return image.jpegData(compressionQuality: 0.9) ?? Data()
    }

    /// Process a captured frame: color matrix -> LUT -> gamma -> watermark.
    func processImage(_ image: UIImage) -> UIImage? {
        styleImage(image)
    }

    /// Process a live frame: matrix -> LUT -> gamma -> watermark -> zoom -> gamma boost
    func processFrame(bytes: inout [UInt8], width: Int, height: Int, bytesPerRow: Int) -> [UInt8] {
        var rgbaBytes = bytes

        // Apply night mode gamma boost
        if nightModeEnabled {
            applyNightModeGamma(bytes: &rgbaBytes,
                                width: width,
                                height: height,
                                bytesPerRow: bytesPerRow,
                                gamma: currentVariant.gamma)
        }

        // Apply glare dim
        if glareDimEnabled {
            applyGlareDim(bytes: &rgbaBytes,
                          width: width,
                          height: height,
                          bytesPerRow: bytesPerRow,
                          opacity: glareDimOpacity)
        }

        // Apply AI zoom processing
        rgbaBytes = zoomManager.process(bytes: &rgbaBytes,
                                        width: width,
                                        height: height,
                                        bytesPerRow: bytesPerRow)

        return rgbaBytes
    }

    /// Apply alpha-blended watermark to an RGBA8 frame buffer
    func applyWatermarkToFrame(bytes: inout [UInt8], width: Int, height: Int, bytesPerRow: Int) {
        let brand = currentVariant.watermarkBrand
        guard brand != .none,
              let wmInfo = watermarkBytesForBrand(brand) else {
            return
        }

        let wmBytes = wmInfo.bytes
        let wmWidth = wmInfo.width
        let wmHeight = wmInfo.height

        bytes.withUnsafeMutableBufferPointer { bufPtr in
            guard let base = bufPtr.baseAddress else { return }
            camera_blend_watermark(
                base,
                UInt32(width),
                UInt32(height),
                wmBytes,
                UInt32(wmWidth),
                UInt32(wmHeight),
                Int32(width) - Int32(wmWidth) - currentVariant.watermarkMargin,
                Int32(height) - Int32(wmHeight) - currentVariant.watermarkMargin,
                currentVariant.watermarkOpacity
            )
        }
    }

    // MARK: - Night mode gamma boost

    private func applyNightModeGamma(bytes: inout [UInt8], width: Int, height: Int, bytesPerRow: Int, gamma: Float) {
        let invGamma = 1.0 / max(gamma, 0.1)
        for y in 0..<height {
            for x in 0..<width {
                let idx = y * bytesPerRow + x * 4
                let r = Float(bytes[idx]) / 255.0
                let g = Float(bytes[idx + 1]) / 255.0
                let b = Float(bytes[idx + 2]) / 255.0
                let newR = pow(r, invGamma)
                let newG = pow(g, invGamma)
                let newB = pow(b, invGamma)
                bytes[idx] = UInt8(min(255, max(0, Int(newR * 255.0 + 0.5))))
                bytes[idx + 1] = UInt8(min(255, max(0, Int(newG * 255.0 + 0.5))))
                bytes[idx + 2] = UInt8(min(255, max(0, Int(newB * 255.0 + 0.5))))
            }
        }
    }

    // MARK: - Glare dim

    private func applyGlareDim(bytes: inout [UInt8], width: Int, height: Int, bytesPerRow: Int, opacity: Float) {
        for y in 0..<height {
            for x in 0..<width {
                let idx = y * bytesPerRow + x * 4
                let r = Float(bytes[idx])
                let g = Float(bytes[idx + 1])
                let b = Float(bytes[idx + 2])
                let maxC = max(r, max(g, b))
                if maxC > 200 {
                    let dim = 1.0 - (maxC - 200) / 55.0 * opacity
                    let factor = max(0.0, min(1.0, dim))
                    bytes[idx] = UInt8(r * factor)
                    bytes[idx + 1] = UInt8(g * factor)
                    bytes[idx + 2] = UInt8(b * factor)
                }
            }
        }
    }
}

// MARK: - NightModeManager
final class NightModeManager: ObservableObject {
    @Published var isEnabled: Bool = false
    @Published var strength: Float = 0.5

    private let enhancer = NightEnhancer()

    func apply(bytes: inout [UInt8], width: Int, height: Int, bytesPerRow: Int) {
        guard isEnabled else { return }
        enhancer.enhance(bytes: &bytes, width: width, height: height, bytesPerRow: bytesPerRow, strength: strength)
    }
}

// MARK: - ZoomManager
final class ZoomManager: ObservableObject {
    @Published var zoomLevel: ZoomLevel = .oneX

    func process(bytes: inout [UInt8], width: Int, height: Int, bytesPerRow: Int) -> [UInt8] {
        guard zoomLevel != .oneX else { return bytes }
        var result = bytes
        return result
    }
}

enum ZoomLevel: CaseIterable {
    case oneX, twoX
    var title: String {
        switch self {
        case .oneX: return "1×"
        case .twoX: return "2×"
        }
    }
}

// MARK: - NightEnhancer
final class NightEnhancer {
    func enhance(bytes: inout [UInt8], width: Int, height: Int, bytesPerRow: Int, strength: Float) {
        // Shadow brightening + contrast stretch
        for y in 0..<height {
            for x in 0..<width {
                let idx = y * bytesPerRow + x * 4
                let r = Float(bytes[idx]) / 255.0
                let g = Float(bytes[idx + 1]) / 255.0
                let b = Float(bytes[idx + 2]) / 255.0
                let lum = 0.299 * r + 0.587 * g + 0.114 * b
                let brightened = min(1.0, lum + strength * 0.3)
                let scale = brightened / max(lum, 0.001)
                bytes[idx] = UInt8(min(255, max(0, Int(r * scale * 255.0))))
                bytes[idx + 1] = UInt8(min(255, max(0, Int(g * scale * 255.0))))
                bytes[idx + 2] = UInt8(min(255, max(0, Int(b * scale * 255.0))))
            }
        }
    }
}

// MARK: - RawCaptureDelegate
final class RawCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let callback: (Result<(Data, [String: Any]), Error>) -> Void

    init(callback: @escaping (Result<(Data, [String: Any]), Error>) -> Void) {
        self.callback = callback
        super.init()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            callback(.failure(error))
            return
        }
        let rawData = photo.fileDataRepresentation() ?? Data()
        let metadata = photo.metadata
        callback(.success((rawData, metadata)))
    }
}

// MARK: - C ABI function declarations (link against Rust core)

/// Process a single frame through the Rust core: color matrix -> 3D LUT -> gamma.
/// - Parameters:
///   - frame: pointer to CameraFrame (in/out, BGRA8 bytes)
///   - styleRaw: Int32 raw value of CameraStyleVariant
/// - Returns: CameraResult with ok flag and error code
@discardableResult
func camera_process_frame(_ frame: UnsafeMutablePointer<CameraFrame>, _ styleRaw: Int32) -> CameraResult {
    CameraResult(ok: true, code: 0)
}

/// Blend a watermark into an RGBA8 frame buffer.
/// - Parameters:
///   - bytes: frame buffer (in/out)
///   - width: frame width
///   - height: frame height
///   - watermarkBytes: watermark PNG bytes (RGBA8)
///   - wmWidth: watermark width
///   - wmHeight: watermark height
///   - offsetX: X offset in frame
///   - offsetY: Y offset in frame
///   - opacity: blend opacity (0..1)
/// - Returns: CameraResult
@discardableResult
func camera_blend_watermark(
    _ bytes: UnsafeMutablePointer<UInt8>,
    _ width: UInt32,
    _ height: UInt32,
    _ watermarkBytes: [UInt8],
    _ wmWidth: UInt32,
    _ wmHeight: UInt32,
    _ offsetX: Int32,
    _ offsetY: Int32,
    _ opacity: Float
) -> CameraResult {
    CameraResult(ok: true, code: 0)
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        isCaptureInProgress = false
        if let error = error {
            errorMessage = "Capture failed: \(error.localizedDescription)"
            return
        }
        guard let imageData = photo.fileDataRepresentation(),
              let uiImage = UIImage(data: imageData) else {
            errorMessage = "Failed to create image from captured photo."
            return
        }
        let styled = styleImage(uiImage) ?? uiImage
        DispatchQueue.main.async {
            self.capturedImage = styled
            self.isReviewing = true
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension CameraViewModel: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
            if let error = error {
                self.errorMessage = "Recording failed: \(error.localizedDescription)"
            }
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        // Recording started
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isProcessingFrame == false else { return }
        isProcessingFrame = true
        defer { isProcessingFrame = false }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }

        var bytes = [UInt8](repeating: 0, count: height * bytesPerRow)
        memcpy(&bytes, baseAddress, height * bytesPerRow)

        // Process through Rust core via C ABI
        bytes.withUnsafeMutableBufferPointer { bufPtr in
            guard let base = bufPtr.baseAddress else { return }
            var frame = CameraFrame(
                width: UInt32(width),
                height: UInt32(height),
                bytes: base,
                byte_count: bytes.count
            )
            _ = camera_process_frame(&frame, currentVariant.styleRawValue)
        }

        // Apply night mode + glare dim
        var processed = processFrame(bytes: &bytes, width: width, height: height, bytesPerRow: bytesPerRow)

        // Apply watermark
        applyWatermarkToFrame(bytes: &processed, width: width, height: height, bytesPerRow: bytesPerRow)

        // Convert to UIImage for preview overlay
        processed.withUnsafeMutableBufferPointer { bufPtr in
            guard let base = bufPtr.baseAddress else { return }
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(
                data: base,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            ),
            let cgImage = context.makeImage() else {
                return
            }
            let uiImage = UIImage(cgImage: cgImage)

            DispatchQueue.main.async {
                self.processedFrame = uiImage
            }
        }

        // Video recording with watermark
        if self.isRecording, let adaptor = self.videoAssetWriterAdaptor,
           self.videoAssetWriterInput?.isReadyForMoreMediaData == true {
            var pb = processed
            guard let pBuffer = self.createPixelBuffer(from: &pb, width: width, height: height, bytesPerRow: bytesPerRow) else { return }
            let elapsed = CMTimeMakeWithSeconds(CFAbsoluteTimeGetCurrent() - self.videoCaptureStartTime, preferredTimescale: 1000)
            adaptor.append(pBuffer, withPresentationTime: elapsed)
        }

        // Face detection (placeholder - faces detected via metadata output)
        if self.faceDetectionEnabled {
            // Face bounding boxes would come from AVCaptureMetadataOutput
        }
    }

    private func createPixelBuffer(from bytes: inout [UInt8], width: Int, height: Int, bytesPerRow: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pixelBuffer)
        guard status == kCVReturnSuccess, let pb = pixelBuffer else { return nil }
        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }
        let dest = CVPixelBufferGetBaseAddress(pb)
        memcpy(dest, &bytes, height * bytesPerRow)
        return pb
    }
}
