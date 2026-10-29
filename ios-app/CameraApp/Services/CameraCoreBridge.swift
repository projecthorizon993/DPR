//
//  CameraCoreBridge.swift
//  JustRaw
//
//  Swift <-> Rust FFI bridge for camera_core processing.
//  Links against libcamera_core.a (built for aarch64-apple-ios).
//

import Foundation
import CoreGraphics
import UIKit

// MARK: - C ABI declarations (imported from Rust camera_core staticlib)

/// These functions are implemented in Rust and linked via libcamera_core.a.
/// @_silgen_name prevents Swift name mangling so the C symbol matches.

@_silgen_name("process_photo")
func process_photo(
    _ pixels: UnsafeMutableRawPointer?,
    _ width: Int32,
    _ height: Int32,
    _ rowBytes: Int32,
    _ matrix: UnsafePointer<Float>?,
    _ lutData: UnsafePointer<Float>?,
    _ lutSize: Int32,
    _ gamma: Float,
    _ saturation: Float,
    _ vignette: Float,
    _ noise: Float,
    _ noiseSeed: UInt32,
    _ wmPixels: UnsafePointer<UInt8>?,
    _ wmWidth: Int32,
    _ wmHeight: Int32,
    _ wmRowBytes: Int32,
    _ wmOffsetX: Int32,
    _ wmOffsetY: Int32,
    _ wmAlpha: Float
) -> Int32

/// Fill effect parameters for a given style.
/// style_id: 0=natural, 1=xiaomi, 2=oppo, 3=vivo
/// Output: [saturation, vignette, noise, sharpen] (4 Float values)
@_silgen_name("fill_effect_params_for_style")
func fill_effect_params_for_style(
    _ styleId: Int32,
    _ output: UnsafeMutablePointer<Float>,
    _ outputLen: Int32
) -> Int32

@_silgen_name("apply_lut_3d")
func apply_lut_3d(
    _ pixels: UnsafeMutableRawPointer?,
    _ width: Int32,
    _ height: Int32,
    _ rowBytes: Int32,
    _ lutData: UnsafePointer<Float>?,
    _ lutSize: Int32
) -> Int32

/// Apply 512^3 LUT from 2D texture (vivo style).
@_silgen_name("apply_lut_512")
func apply_lut_512(
    _ pixels: UnsafeMutableRawPointer?,
    _ width: Int32,
    _ height: Int32,
    _ rowBytes: Int32,
    _ lutTexture: UnsafePointer<UInt8>?,
    _ lutWidth: Int32,
    _ lutHeight: Int32,
    _ strength: Float
) -> Int32

@_silgen_name("apply_color_matrix")
func apply_color_matrix(
    _ pixels: UnsafeMutableRawPointer?,
    _ width: Int32,
    _ height: Int32,
    _ rowBytes: Int32,
    _ matrix: UnsafePointer<Float>?
) -> Int32

@_silgen_name("apply_tone_curve")
func apply_tone_curve(
    _ pixels: UnsafeMutableRawPointer?,
    _ width: Int32,
    _ height: Int32,
    _ rowBytes: Int32,
    _ gamma: Float
) -> Int32

@_silgen_name("blend_watermark")
func blend_watermark(
    _ pixels: UnsafeMutableRawPointer?,
    _ width: Int32,
    _ height: Int32,
    _ rowBytes: Int32,
    _ wmPixels: UnsafePointer<UInt8>?,
    _ wmWidth: Int32,
    _ wmHeight: Int32,
    _ wmRowBytes: Int32,
    _ offsetX: Int32,
    _ offsetY: Int32,
    _ wmAlpha: Float
) -> Int32

/// Fill a caller-allocated buffer with LUT data for a given style.
/// style_id: 0=natural, 1=xiaomi, 2=oppo, 3=vivo
/// Returns the number of floats written, or negative on error.
@_silgen_name("fill_lut_for_style")
func fill_lut_for_style(
    _ styleId: Int32,
    _ size: Int32,
    _ output: UnsafeMutablePointer<Float>,
    _ outputLen: Int32
) -> Int32

// MARK: - Bridge class

@objcMembers
final class CameraCoreBridge: NSObject {

    /// Opaque result codes from Rust camera_core
    enum CameraCoreError: Int32, Error {
        case nullPointer = -1
        case invalidDimensions = -2
        case invalidLutSize = -3
        case unknown = -999
    }

    // MARK: - Photo processing

    /// Process a CGImage (RGBA8) through the Rust core.
    /// Applies color matrix, 3D LUT, tone curve, saturation, vignette, noise, and watermark.
    /// Returns a new CGImage or nil on failure.
    static func process(image: CGImage,
                        style: CameraStyle,
                        watermark: CGImage?,
                        watermarkAlpha: Float) -> CGImage? {
        guard let colorSpace = image.colorSpace,
              colorSpace.model == .rgb else {
            logError("Image color space is not RGB")
            return nil
        }

        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            logError("Failed to create CGContext for image \(width)x\(height)")
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let rawPointer = context.data else {
            logError("CGContext data pointer is nil")
            return nil
        }

        // Extract style parameters
        let (matrixPtr, gamma) = style.renderParams()

        // Get effect parameters from Rust (saturation, vignette, noise, sharpen)
        let styleId: Int32 = style.lutStyleId
        var effectParams = [Float](repeating: 0, count: 4)
        let rcParams = effectParams.withUnsafeMutableBufferPointer { buf in
            fill_effect_params_for_style(styleId, buf.baseAddress!, Int32(buf.count))
        }
        if rcParams < 0 {
            logError("fill_effect_params_for_style error: \(rcParams)")
        }
        let saturation = effectParams[0]
        let vignette = effectParams[1]
        let noise = effectParams[2]
        // effectParams[3] = sharpen reserved for future

        // Generate LUT data from Rust for this style (17^3)
        let lutSize: Int32 = style.lutSize
        var lutDataPtr: UnsafeMutablePointer<Float>? = nil
        if lutSize > 0 {
            let lutFloatCount = Int(lutSize * lutSize * lutSize * 3)
            lutDataPtr = UnsafeMutablePointer<Float>.allocate(capacity: lutFloatCount)
            let rc = fill_lut_for_style(styleId, lutSize, lutDataPtr!, Int32(lutFloatCount))
            if rc < 0 {
                lutDataPtr?.deallocate()
                lutDataPtr = nil
                logError("fill_lut_for_style error: \(rc)")
            }
        }
        defer {
            lutDataPtr?.deallocate()
        }

        // Watermark raw bytes (Zeiss logo salvaged from vivo.apk)
        var wmPtr: UnsafePointer<UInt8>? = nil
        var wmW: Int32 = 0, wmH: Int32 = 0, wmRow: Int32 = 0
        if let wm = watermark {
            wmW = Int32(wm.width)
            wmH = Int32(wm.height)
            wmRow = Int32(wm.width * 4)
            wmPtr = watermarkRGBABuffer(image: wm)?.withUnsafeBufferPointer { $0.baseAddress }
        }

        let rc = process_photo(
            rawPointer,
            Int32(width),
            Int32(height),
            Int32(bytesPerRow),
            matrixPtr,
            lutDataPtr,
            lutSize,
            gamma,
            saturation,
            vignette,
            noise,
            42, // noise_seed (fixed for deterministic output)
            wmPtr,
            wmW,
            wmH,
            wmRow,
            Int32(width) - wmW - Int32(20),   // bottom-right, 20px margin
            Int32(height) - wmH - Int32(20),
            watermarkAlpha
        )

        guard rc == 0 else {
            logError("process_photo error: \(rc)")
            return nil
        }

        return context.makeImage()
    }

    /// Prepare a CGImage as a contiguous RGBA8 buffer for FFI.
    private static func watermarkRGBABuffer(image: CGImage) -> [UInt8]? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let w = image.width
        let h = image.height
        let rowBytes = w * 4
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: rowBytes,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return nil }
        let count = h * w * 4
        return Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: count))
    }
}

// MARK: - Camera style configuration

enum CameraStyle: CaseIterable, Codable {
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

    var accentColor: SwiftUI.Color {
        switch self {
        case .natural: return SwiftUI.Color.white
        case .xiaomi: return SwiftUI.Color(hex: "FFFFCE16")
        case .oppo: return SwiftUI.Color(hex: "FF2274A5")
        case .vivo: return SwiftUI.Color(hex: "FF0066FF")
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

    /// Style ID passed to Rust fill_lut_for_style (0=natural, 1=xiaomi, 2=oppo, 3=vivo)
    var lutStyleId: Int32 {
        switch self {
        case .natural: return 0
        case .xiaomi: return 1
        case .oppo: return 2
        case .vivo: return 3
        }
    }

    /// LUT grid size (0 = matrix-only, no LUT)
    var lutSize: Int32 {
        switch self {
        case .natural: return 0
        case .xiaomi: return 17
        case .oppo: return 17
        case .vivo: return 17
        }
    }

    // MARK: - Static color matrix pointers (program lifetime storage)

    /// Precomputed color matrices allocated once with `allocate` + `initialize`
    /// and intentionally never deallocated, so the returned `UnsafePointer<Float>`
    /// remains valid for the entire program lifetime (no dangling pointers).
    private enum Matrices {
        /// Xiaomi: warm, vivid look — derived from Xiaomi libMiFilterSDK.so
        static let xiaomi: UnsafePointer<Float> = {
            let ptr = UnsafeMutablePointer<Float>.allocate(capacity: 9)
            ptr.initialize(from: [
                1.10, 0.03, -0.05,
                -0.02, 1.05, 0.01,
                -0.03, -0.02, 1.07
            ])
            return UnsafePointer(ptr)
        }()
        /// OPPO: cool, crisp — Hasselblad/Zeiss-inspired
        static let oppo: UnsafePointer<Float> = {
            let ptr = UnsafeMutablePointer<Float>.allocate(capacity: 9)
            ptr.initialize(from: [
                1.03, -0.01, -0.04,
                0.00, 1.07, -0.02,
                -0.04, -0.01, 1.05
            ])
            return UnsafePointer(ptr)
        }()
        /// Vivo: portrait-soft, warm skin tones (Zeiss-inspired)
        static let vivo: UnsafePointer<Float> = {
            let ptr = UnsafeMutablePointer<Float>.allocate(capacity: 9)
            ptr.initialize(from: [
                1.07, 0.01, -0.02,
                0.01, 1.03, -0.03,
                -0.02, -0.04, 1.06
            ])
            return UnsafePointer(ptr)
        }()
    }

    /// Returns (matrix: UnsafePointer<Float>?, gamma: Float)
    /// LUT data and effect params are generated by Rust (fill_lut_for_style, fill_effect_params_for_style).
    ///
    /// The returned pointer points to heap-allocated, never-deallocated static
    /// storage and therefore remains valid for the entire program lifetime,
    /// including the duration of the `process_photo()` FFI call. Previously this
    /// used `withUnsafeBufferPointer` which returned a dangling pointer once the
    /// closure returned.
    func renderParams() -> (UnsafePointer<Float>?, Float) {
        switch self {
        case .natural:
            return (nil, 1.0)

        case .xiaomi:
            return (Matrices.xiaomi, 1.04)

        case .oppo:
            return (Matrices.oppo, 1.02)

        case .vivo:
            return (Matrices.vivo, 1.0)
        }
    }
}

// MARK: - SwiftUI Color import

import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
