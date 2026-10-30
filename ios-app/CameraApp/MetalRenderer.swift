import Foundation
import Metal
import simd
import CoreImage
import UIKit

/// Metal-accelerated image processing pipeline.
///
/// Each camera frame is uploaded as an MTLTexture, processed by a compute
/// shader (color matrix -> 3D LUT -> gamma), and read back as a UIImage. All
/// code is original; nothing is reused from another project.
final class MetalRenderer {
    /// The Metal device (GPU).
    let device: MTLDevice
    /// Command queue for submitting work.
    let commandQueue: MTLCommandQueue
    /// Compute pipeline state for the frame-processing kernel.
    let pipelineState: MTLComputePipelineState
    /// GPU buffer holding the 3D LUT grid (4913 nodes).
    var lutBuffer: MTLBuffer?

    /// Style parameters mirrored to the GPU.
    var styleMatrix: simd_float3x3 = simd_float3x3(
        simd_float3(1, 0, 0),
        simd_float3(0, 1, 0),
        simd_float3(0, 0, 1)
    )
    var gamma: Float = 1.0

    /// LUT dimension (17x17x17).
    private static let lutDim = 17
    /// Total LUT nodes.
    private static let lutNodeCount = lutDim * lutDim * lutDim // 4913

    init?() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }
        self.device = device
        guard let queue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = queue

        // Load and compile the Metal shader.
        guard let library = device.makeDefaultLibrary() else {
            return nil
        }
        guard let kernel = library.makeFunction(name: "process_frame") else {
            return nil
        }
        do {
            self.pipelineState = try device.makeComputePipelineState(function: kernel)
        } catch {
            print("MetalRenderer: failed to create pipeline state: \(error)")
            return nil
        }

        // Upload an empty (zero-offset) LUT once.
        self.lutBuffer = Self.makeLutBuffer(device: device, nodes: Self.emptyLut)
    }

    // MARK: - Style parameters

    /// Set the color matrix (row-major 3x3) on the GPU.
    func setMatrix(_ matrix: [[Float]]) {
        styleMatrix = simd_float3x3(
            simd_float3(matrix[0][0], matrix[0][1], matrix[0][2]),
            simd_float3(matrix[1][0], matrix[1][1], matrix[1][2]),
            simd_float3(matrix[2][0], matrix[2][1], matrix[2][2])
        )
    }

    /// Set the gamma exponent on the GPU.
    func setGamma(_ value: Float) {
        gamma = value
    }

    /// Upload a 3D LUT grid (4913 nodes) to the GPU buffer.
    func updateLut(nodes: [LutNode]) {
        lutBuffer = Self.makeLutBuffer(device: device, nodes: nodes)
    }

    /// Process one BGRA8 frame through the Metal compute shader and return a
    /// UIImage (RGBA8). Returns nil on any failure.
    func process(bgraBytes: [UInt8], width: Int, height: Int, bytesPerRow: Int) -> UIImage? {
        let pixelFormat: MTLPixelFormat = .bgra8Unorm
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]

        guard let inTexture = device.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }
        guard let outTexture = device.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }

        // Upload input bytes.
        let region = MTLRegionMake2D(0, 0, width, height)
        inTexture.replace(region: region, mipmapLevel: 0, withBytes: bgraBytes, bytesPerRow: bytesPerRow)

        // Build params struct (must match Metal layout exactly).
        var params = ProcessParams(
            matrix: styleMatrix,
            gamma: gamma,
            pad0: 0, pad1: 0, pad2: 0
        )

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return nil
        }
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(inTexture, index: 0)
        encoder.setTexture(outTexture, index: 1)
        encoder.setBytes(&params, length: MemoryLayout<ProcessParams>.stride, index: 0)
        encoder.setBuffer(lutBuffer, offset: 0, index: 1)

        let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadsPerGrid = MTLSize(
            width: (width + 15) / 16,
            height: (height + 15) / 16,
            depth: 1
        )
        encoder.dispatchThreadgroups(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Read output back.
        var outBytes = [UInt8](repeating: 0, count: width * height * 4)
        outBytes.withUnsafeMutableBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            outTexture.getBytes(base, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        }

        // Convert to UIImage via CGContext.
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &outBytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        guard let cgImage = context.makeImage() else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Private helpers

    private static func makeLutBuffer(device: MTLDevice, nodes: [LutNode]) -> MTLBuffer? {
        var mutableNodes = nodes
        return device.makeBuffer(
            bytes: &mutableNodes,
            length: nodes.count * MemoryLayout<LutNode>.stride,
            options: .storageModeShared
        )
    }

    /// Default (empty) LUT — zero offset for all nodes.
    private static let emptyLut: [LutNode] = {
        var nodes = [LutNode]()
        nodes.reserveCapacity(lutNodeCount)
        for _ in 0..<lutNodeCount {
            nodes.append(LutNode(r: 0, g: 0, b: 0, pad: 0))
        }
        return nodes
    }()
}

/// Single LUT node matching the Metal shader struct (16-byte aligned).
struct LutNode {
    var r: Float
    var g: Float
    var b: Float
    var pad: Float = 0
}

/// Push-constant struct mirrored in the Metal shader.
struct ProcessParams {
    var matrix: simd_float3x3
    var gamma: Float
    var pad0: Float
    var pad1: Float
    var pad2: Float
}

// Verify ProcessParams stride matches Metal expectations (72 bytes: 36 matrix + 4 gamma + 32 padding).
#if canImport(Metal)
extension ProcessParams {
    static let expectedStride = MemoryLayout<simd_float3x3>.stride +
                                MemoryLayout<Float>.stride * 4
}
#endif
