//
//  RAWProcessorService.swift
//  CameraApp
//

import Foundation
import UIKit

final class RAWProcessorService: NSObject {
    static let shared = RAWProcessorService()
    private override init() {}

    enum RAWProcessorError: Error {
        case invalidRAWData
        case processingFailed(String)
        case unsupportedFormat
    }

    func processRAWToJPEG(_ rawData: Data, cropRect: CGRect, style: CameraStyle) async throws -> Data {
        // Simplified - return JPEG data from RAW
        return rawData
    }

    func calculateCropRect(for zoom: CGFloat, imageSize: CGSize) -> CGRect {
        let cropFactor = 1.0 / max(zoom, 1.0)
        let cropWidth = imageSize.width * cropFactor
        let cropHeight = imageSize.height * cropFactor
        let x = (imageSize.width - cropWidth) / 2
        let y = (imageSize.height - cropHeight) / 2
        return CGRect(x: x, y: y, width: cropWidth, height: cropHeight)
    }
}
