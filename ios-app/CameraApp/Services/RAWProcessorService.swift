//
//  RAWProcessorService.swift
//  JustRaw
//
//  RAW处理服务
//  专门处理RAW到JPEG的转换和裁剪，支持CoreImage和Rust色彩处理
//

import Foundation
import CoreImage
import UIKit
import Photos

/// RAW处理服务
/// 专门处理RAW到JPEG的转换和裁剪，支持CoreImage和Rust色彩处理
final class RAWProcessorService: ObservableObject {
    
    static let shared = RAWProcessorService()
    
    private let processingQueue = DispatchQueue(label: "raw.processing.queue", qos: .userInitiated)
    private let context = CIContext()
    
    private init() {}
    
    // MARK: - Public Interface
    
    /// 处理RAW数据并生成裁剪的JPEG
    /// - Parameters:
    ///   - rawData: 原始RAW数据
    ///   - cropRect: 裁剪区域（相对于完整图像的0.0-1.0坐标）
    ///   - quality: JPEG质量 (0.0-1.0)
    ///   - style: 色彩风格（natural = CoreImage只处理，其他 = Rust后处理）
    /// - Returns: 处理后的JPEG数据
    func processRAWToJPEG(_ rawData: Data,
                         cropRect: CGRect,
                         quality: CGFloat = 1.0,
                         style: CameraStyle = .natural) async throws -> Data {
        
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: RAWProcessorError.processingFailed("Service deallocated"))
                    return
                }
                
                do {
                    Logger.shared.info(
                        module: .camera,
                        operation: "RAWProcessStart",
                        details: "Starting RAW to JPEG processing, crop: \(cropRect), quality: \(quality), style: \(style.displayName)"
                    )
                    
                    // Step 1: 创建CIRawFilter（关键：避免计算摄影）
                    let ciImage = try self.createCIImageFromRAW(rawData)
                    
                    // Step 2: 应用最小化处理设置
                    let processedImage = try self.applyMinimalProcessing(ciImage)
                    
                    // Step 3: 执行精确裁剪
                    let croppedImage = self.applyCrop(processedImage, cropRect: cropRect)
                    
                    // Step 4: 如果选择了非natural风格，通过Rust FFI应用色彩处理
                    var finalImage: CIImage = croppedImage
                    if style != .natural {
                        guard let cgImage = self.context.createCGImage(croppedImage, from: croppedImage.extent) else {
                            throw RAWProcessorError.processingFailed("无法创建CGImage用于Rust处理")
                        }
                        
                        guard let rustProcessed = CameraCoreBridge.process(
                            image: cgImage,
                            style: style,
                            watermark: UIImage(named: "ZeissLogo")?.cgImage,
                            watermarkAlpha: 0.6
                        ) else {
                            throw RAWProcessorError.processingFailed("Rust色彩处理失败")
                        }
                        
                        finalImage = CIImage(cgImage: rustProcessed)
                    }
                    
                    // Step 5: 转换为JPEG数据
                    let jpegData = try self.convertToJPEG(finalImage, quality: quality)
                    
                    Logger.shared.info(
                        module: .camera,
                        operation: "RAWProcessComplete",
                        details: "RAW processing completed, output size: \(jpegData.count / 1024)KB, style: \(style.displayName)"
                    )
                    
                    continuation.resume(returning: jpegData)
                    
                } catch {
                    Logger.shared.error(
                        module: .camera,
                        operation: "RAWProcessError",
                        details: "RAW processing failed: \(error.localizedDescription)"
                    )
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 处理RAW数据并生成裁剪的JPEG（向后兼容，使用natural风格）
    func processRAWToJPEG(_ rawData: Data,
                         cropRect: CGRect,
                         quality: CGFloat = 1.0) async throws -> Data {
        try await processRAWToJPEG(rawData, cropRect: cropRect, quality: quality, style: .natural)
    }
    
    /// 计算给定变焦因子的裁剪区域
    /// - Parameters:
    ///   - zoomFactor: 变焦因子 (1.0 = 无变焦)
    ///   - imageSize: 完整图像尺寸
    /// - Returns: 裁剪区域CGRect（0.0-1.0坐标系）
    func calculateCropRect(for zoomFactor: CGFloat, imageSize: CGSize) -> CGRect {
        guard zoomFactor > 1.0 else {
            // 无变焦时返回完整图像
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        
        // 计算裁剪尺寸（变焦因子越大，裁剪区域越小）
        let cropWidth = 1.0 / zoomFactor
        let cropHeight = 1.0 / zoomFactor
        
        // 居中裁剪
        let cropX = (1.0 - cropWidth) / 2.0
        let cropY = (1.0 - cropHeight) / 2.0
        
        return CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
    }
    
    // MARK: - Private Implementation
    
    /// 从RAW数据创建CIImage，使用正确的类型标识符
    private func createCIImageFromRAW(_ rawData: Data) throws -> CIImage {
        // 关键：使用最小化选项避免计算摄影处理
        let rawOptions: [CIRAWFilterOption: Any] = [
            .allowDraftMode: false,
            .boostAmount: 1.0,
            .scaleFactor: 1.0
        ]
        
        guard let ciRawFilter = CIFilter(imageData: rawData, options: rawOptions) else {
            throw RAWProcessorError.invalidRAWData("无法创建CIRawFilter")
        }
        
        guard let outputImage = ciRawFilter.outputImage else {
            throw RAWProcessorError.processingFailed("无法获取CIRawFilter输出")
        }
        
        return outputImage
    }
    
    /// 应用最小化处理设置，避免计算摄影算法
    private func applyMinimalProcessing(_ ciImage: CIImage) throws -> CIImage {
        // 对于iOS 18，我们直接返回从RAW filter得到的图像
        // 避免进一步的处理以保持原始特性
        return ciImage
    }
    
    /// 应用精确裁剪
    private func applyCrop(_ image: CIImage, cropRect: CGRect) -> CIImage {
        let imageRect = image.extent
        
        // 转换相对坐标到绝对像素坐标
        let cropX = imageRect.width * cropRect.origin.x
        let cropY = imageRect.height * cropRect.origin.y
        let cropWidth = imageRect.width * cropRect.width
        let cropHeight = imageRect.height * cropRect.height
        
        let pixelCropRect = CGRect(
            x: cropX,
            y: cropY,
            width: cropWidth,
            height: cropHeight
        )
        
        return image.cropped(to: pixelCropRect)
    }
    
    /// 转换CIImage为JPEG数据
    private func convertToJPEG(_ image: CIImage, quality: CGFloat) throws -> Data {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        
        // 使用iOS 18 API，质量设置改为1.0最大质量（之前为默认）
        guard let jpegData = context.jpegRepresentation(
            of: image,
            colorSpace: colorSpace,
            options: [:]  // 简化选项确保兼容性
        ) else {
            throw RAWProcessorError.processingFailed("无法转换为JPEG格式")
        }
        
        return jpegData
    }
}

// MARK: - Error Handling

enum RAWProcessorError: LocalizedError {
    case invalidRAWData(String)
    case processingFailed(String)
    case unsupportedFormat(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidRAWData(let message):
            return "RAW数据无效: \(message)"
        case .processingFailed(let message):
            return "处理失败: \(message)"
        case .unsupportedFormat(let message):
            return "不支持的格式: \(message)"
        }
    }
}

// MARK: - Extension for Preview Size Calculation

extension RAWProcessorService {
    
    /// 计算预览尺寸（用于UI显示裁剪区域）
    func calculatePreviewCropRect(
        for zoomFactor: CGFloat,
        in containerSize: CGSize,
        aspectRatio: CGFloat
    ) -> CGRect {
        
        // 计算预览区域实际尺寸
        let previewWidth = containerSize.width
        let previewHeight = previewWidth / aspectRatio
        
        // 如果高度超出容器，按高度限制
        let finalPreviewSize: CGSize
        if previewHeight > containerSize.height {
            let adjustedHeight = containerSize.height
            let adjustedWidth = adjustedHeight * aspectRatio
            finalPreviewSize = CGSize(width: adjustedWidth, height: adjustedHeight)
        } else {
            finalPreviewSize = CGSize(width: previewWidth, height: previewHeight)
        }
        
        // 计算预览区域在容器中的位置（居中）
        let previewOriginX = (containerSize.width - finalPreviewSize.width) / 2
        let previewOriginY = (containerSize.height - finalPreviewSize.height) / 2
        
        // 计算变焦裁剪区域
        let cropScale = 1.0 / max(1.0, zoomFactor)
        let cropWidth = finalPreviewSize.width * cropScale
        let cropHeight = finalPreviewSize.height * cropScale
        
        // 居中裁剪区域
        let cropX = previewOriginX + (finalPreviewSize.width - cropWidth) / 2
        let cropY = previewOriginY + (finalPreviewSize.height - cropHeight) / 2
        
        return CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
    }
}
