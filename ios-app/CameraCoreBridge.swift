//
//  CameraCoreBridge.swift
//  CameraApp
//

import Foundation
import CoreGraphics
import UIKit

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

@_silgen_name("fill_lut_for_style")
func fill_lut_for_style(
    _ styleId: Int32,
    _ size: Int32,
    _ output: UnsafeMutablePointer<Float>,
    _ outputLen: Int32
) -> Int32

@objcMembers
final class CameraCoreBridge: NSObject {
    enum CameraCoreError: Int32, Error {
        case nullPointer = -1
        case invalidDimensions = -2
        case invalidLutSize = -3
        case unknown = -999
    }

    static let xiaomiMatrix: UnsafePointer<Float> = {
        let ptr = UnsafeMutablePointer<Float>.allocate(capacity: 9)
        let values: [Float] = [1.10, 0.03, -0.05, -0.02, 1.05, 0.01, -0.03, -0.02, 1.07]
        for i in 0..<9 { ptr[i] = values[i] }
        return UnsafePointer(ptr)
    }()

    static let oppoMatrix: UnsafePointer<Float> = {
        let ptr = UnsafeMutablePointer<Float>.allocate(capacity: 9)
        let values: [Float] = [1.03, -0.01, -0.04, 0.00, 1.07, -0.02, -0.04, -0.01, 1.05]
        for i in 0..<9 { ptr[i] = values[i] }
        return UnsafePointer(ptr)
    }()

    static let vivoMatrix: UnsafePointer<Float> = {
        let ptr = UnsafeMutablePointer<Float>.allocate(capacity: 9)
        let values: [Float] = [1.07, 0.01, -0.02, 0.01, 1.03, -0.03, -0.02, -0.04, 1.06]
        for i in 0..<9 { ptr[i] = values[i] }
        return UnsafePointer(ptr)
    }()

    static func process(image: CGImage,
                        style: CameraStyle,
                        watermark: CGImage?,
                        watermarkAlpha: Float) -> CGImage? {
        guard let colorSpace = image.colorSpace,
              colorSpace.model == .rgb else {
            Logger.shared.error("Image color space is not RGB")
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
            Logger.shared.error("Failed to create CGContext")
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let rawPointer = context.data else {
            Logger.shared.error("CGContext data pointer is nil")
            return nil
        }

        let (matrixPtr, gamma) = style.renderParams()

        var effectParams = [Float](repeating: 0, count: 4)
        _ = effectParams.withUnsafeMutableBufferPointer { buf in
            fill_effect_params_for_style(style.lutStyleId, buf.baseAddress!, Int32(buf.count))
        }

        let lutSize: Int32 = style.lutSize
        var lutDataPtr: UnsafeMutablePointer<Float>? = nil
        if lutSize > 0 {
            let lutFloatCount = Int(lutSize * lutSize * lutSize * 3)
            lutDataPtr = UnsafeMutablePointer<Float>.allocate(capacity: lutFloatCount)
            let rc = fill_lut_for_style(style.lutStyleId, lutSize, lutDataPtr!, Int32(lutFloatCount))
            if rc < 0 {
                lutDataPtr?.deallocate()
                lutDataPtr = nil
            }
        }
        defer { lutDataPtr?.deallocate() }

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
            effectParams[0],
            effectParams[1],
            effectParams[2],
            42,
            wmPtr,
            wmW,
            wmH,
            wmRow,
            Int32(width) - wmW - 20,
            Int32(height) - wmH - 20,
            watermarkAlpha
        )

        guard rc == 0 else {
            Logger.shared.error("process_photo error: \(rc)")
            return nil
        }

        return context.makeImage()
    }

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
