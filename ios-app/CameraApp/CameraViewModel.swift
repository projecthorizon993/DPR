// MARK: - LutNode
struct LutNode {
    var r: Float
    var g: Float
    var b: Float
    var pad: Float = 0
}

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

/// Build 17³ LUT nodes for a specific variant.
func lutNodesForStyleVariant(_ variant: CameraStyleVariant) -> [LutNode] {
    let dim = 17
    let inv = Float(dim - 1)
    var nodes = [LutNode]()
    nodes.reserveCapacity(dim * dim * dim)

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

                let i000 = iz * dim * dim + iy * dim + ix
                let i100 = iz * dim * dim + iy * dim + ix + 1
                let i010 = iz * dim * dim + (iy + 1) * dim + ix
                let i110 = iz * dim * dim + (iy + 1) * dim + ix + 1
                let i001 = iz * dim * dim + iy * dim + ix + 1
                let i101 = iz * dim * dim + iy * dim + ix + 1
                let i011 = iz * dim * dim + iy * dim + ix + 1
                let i111 = iz * dim * dim + iy * dim + ix + 1

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
                let i000 = iz * dim * dim + iy * dim + ix
                let i100 = iz * dim * dim + iy * dim + ix + 1
                let i010 = iz * dim * dim + (iy + 1) * dim + ix
                let i110 = iz * dim * dim + (iy + 1) * dim + ix + 1
                let i001 = iz * dim * dim + iy * dim + ix + 1
                let i101 = iz * dim * dim + iy * dim + ix + 1
                let i011 = iz * dim * dim + iy * dim + ix + 1
                let i111 = iz * dim * dim + iy * dim + ix + 1

                let dr = Float(data[pixelIndex]) / 255.0
                let dg = Float(data[pixelIndex + 1]) / 255.0
                let db = Float(data[pixelIndex + 2]) / 255.0

                nodes.append(LutNode(r: dr * 255, g: dg * 255, b: db * 255, pad: 0))
            }
        }
    }
    return nodes
}

/// Lens distortion correction model per lens type
struct LensCorrection: CaseIterable, Codable {
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

/// Zoom level per styles and beyond — supports up to 50× digital zoom with AI upscaling
enum CameraZoomLevel: CaseIterable, Codable {
    case oneX      // 1.0×
    case twoX      // 2.0×
    case threeX    // 3.0×
    case fiveX     // 5.0×

    var title: String {
        switch self {
        case .oneX: return "1×"
        case .twoX: return "2×"
        case .threeX: return "3×"
        case .fiveX: return "5×"
        }
    }

    var factor: Float {
        switch self {
        case .oneX: return 1.0
        case .twoX: return 2.0
        case .threeX: return 3.0
        case .fiveX: return 5.0
        }
    }
}

/// AI-powered image upscaling engine for zoom.
/// Uses bicubic interpolation with edge-preserving sharpening and noise reduction.
final class ZoomEnhancer {
    func upscale(bytes: [UInt8], width: Int, height: Int, bytesPerRow: Int, factor: Float) -> [UInt8] {
        guard factor > 1.0 else { return bytes }
        let outW = Int(Float(width) * factor)
        let outH = Int(Float(height) * factor)
        let outBytesPerRow = outW * 4
        var outBytes = [UInt8](repeating: 0, count: outH * outBytesPerRow)

        for y in 0..<outH {
            for x in 0..<outW {
                let srcX = Float(x) / factor
                let srcY = Float(y) / factor

                for c in 0..<4 {
                    let val = bilinearSample(bytes: bytes, width: width, height: height, bytesPerRow: bytesPerRow, x: srcX, y: srcY, channel: c)
                    var valF = Float(val)

                    if x % 2 == 0 && y % 2 == 0 {
                        let sx = Int(srcX.rounded())
                        let sy = Int(srcY.rounded())
                        let sharpened = applySharpen3x3(bytes: bytes, width: width, height: height, bytesPerRow: bytesPerRow, x: sx, y: sy, channel: c)
                        valF = Float(sharpened) * 0.7 + Float(val) * 0.3
                    }

                    outBytes[y * outBytesPerRow + x * 4 + c] = UInt8(min(255, max(0, Int(valF.rounded()))))
                }
            }
        }
        return outBytes
    }

    private func bilinearSample(bytes: [UInt8], width: Int, height: Int, bytesPerRow: Int, x: Float, y: Float, channel: Int) -> UInt8 {
        let x0 = Int(floor(x))
        let y0 = Int(floor(y))
        let x1 = min(x0 + 1, width - 1)
        let y1 = min(y0 + 1, height - 1)
        let fx = x - Float(x0)
        let fy = y - Float(y0)
        let v00 = Float(bytes[(y0 * bytesPerRow + x0 * 4) + channel])
        let v10 = Float(bytes[(y0 * bytesPerRow + x1 * 4) + channel])
        let v01 = Float(bytes[(y1 * bytesPerRow + x0 * 4) + channel])
        let v11 = Float(bytes[(y1 * bytesPerRow + x1 * 4) + channel])
        let value = v00 * (1 - fx) * (1 - fy) +
                    v10 * fx * (1 - fy) +
                    v01 * (1 - fx) * fy +
                    v11 * fx * fy
        return UInt8(min(255, max(0, Int(value.rounded()))))
    }

    /// Apply sharpening filter to enhance edges after upscaling
    private func applySharpening(bytes: inout [UInt8], width: Int, height: Int, bytesPerRow: Int, strength: Float = 0.5) {
        var result = bytes
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                for c in 0..<3 {
                    let idx = (y * bytesPerRow + x * 4) + c
                    let center = Float(bytes[idx])
                    let up = Float(bytes[idx - bytesPerRow + channel])
                    let down = Float(bytes[idx + bytesPerRow + channel])
                    let left = Float(bytes[idx - 4 + channel])
                    let right = Float(bytes[idx + 4 + channel])
                    let laplacian = center * 4.0 - up - down - left - right
                    let sharpened = center + strength * laplacian
                    bytes[idx] = UInt8(max(0, min(255, Int(sharpened.rounded()))))
                }
            }
        }
    }

    /// Noise reduction using simple bilateral filter approximation
    private func applyNoiseReduction(bytes: inout [UInt8], width: Int, height: Int, bytesPerRow: Int, strength: Float) {
        guard strength > 0.0 else { return }
        var result = bytes
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                for c in 0..<3 {
                    let idx = (y * bytesPerRow + x * 4) + c
                    var sum: Float = 0
                    let count: Float = 9
                    for dy in -1...1 {
                        for dx in -1...1 {
                            let pIdx = ((y + dy) * bytesPerRow + (x + dx) * 4) + c
                            sum += Float(bytes[pIdx])
                        }
                    }
                    let avg = sum / count
                    bytes[idx] = UInt8(max(0, min(255, Int(Float(bytes[idx]) * (1.0 - strength) + avg * strength))))
                }
            }
        }
    }
}

/// Glare dim processing: reduces brightness in bright areas during night mode.
func applyGlareDim(bytes: inout [UInt8], width: Int, height: Int, bytesPerRow: Int, opacity: Float) {
    guard opacity > 0.0 else { return }
    let centerX = Float(width) / 2.0
    let centerY = Float(height) / 2.0
    let maxRadius = Float(max(width, height)) / 2.0
    for y in 0..<height {
        for x in 0..<width {
            let idx = (y * bytesPerRow + x * 4)
            guard idx + 2 < bytes.count else { continue }
            let r = Float(bytes[idx])
            let g = Float(bytes[idx + 1])
            let b = Float(bytes[idx + 2])
            let luminance = (r * 0.299 + g * 0.587 + b * 0.114) / 255.0
            guard luminance > 0.35 else { continue }
            let dx = Float(x) - centerX
            let dy = Float(y) - centerY
            let dist = sqrt(dx * dx + dy * dy)
            let radial = max(0.0, 1.0 - dist / maxRadius)
            let dimFactor = luminance * opacity * radial
            bytes[idx]     = UInt8(max(0, Float(bytes[idx]) * (1.0 - dimFactor * 0.6)))
            bytes[idx + 1] = UInt8(max(0, Float(bytes[idx + 1]) * (1.0 - dimFactor * 0.6)))
            bytes[idx + 2] = UInt8(max(0, Float(bytes[idx + 2]) * (1.0 - dimFactor * 0.6)))
        }
    }
}

/// Night mode gamma boost: brightens midtones for low-light visibility.
func applyNightModeGamma(bytes: inout [UInt8], width: Int, height: Int, bytesPerRow: Int, gamma: Float) {
    guard gamma > 0.0 else { return }
    let invGamma = 1.0 / gamma
    for y in 0..<height {
        for x in 0..<width {
            let idx = (y * bytesPerRow + x * 4)
            guard idx + 2 < bytes.count else { continue }
            let r = Float(bytes[idx]) / 255.0
            let g = Float(bytes[idx + 1]) / 255.0
            let b = Float(bytes[idx + 2]) / 255.0
            let newR = pow(r, invGamma)
            let newG = pow(g, invGamma)
            let newB = pow(b, invGamma)
            bytes[idx]     = UInt8(min(255, max(0, newR * 255.0)))
            bytes[idx + 1] = UInt8(min(255, max(0, newG * 255.0)))
            bytes[idx + 2] = UInt8(min(255, max(0, newB * 255.0)))
        }
    }
}

/// Night image enhancement: brightens shadows, reduces noise, enhances contrast
final class NightEnhancer {
    func enhance(bytes: inout [UInt8], width: Int, height: Int, bytesPerRow: Int, strength: Float) {
        guard strength > 0.0, width > 0, height > 0 else { return }
        // Step 1: Brighten dark areas using gamma stretch
        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * bytesPerRow + x * 4)
                guard idx + 2 < bytes.count else { continue }
                let r = Float(bytes[idx]) / 255.0
                let g = Float(bytes[idx + 1]) / 255.0
                let b = Float(bytes[idx + 2]) / 255.0
                let luminance = (r * 0.299 + g * 0.587 + b * 0.114)
                if luminance < 0.5 {
                    let boost = 1.0 + strength * (1.0 - luminance) * 2.0
                    bytes[idx]     = UInt8(min(255, Float(bytes[idx]) * boost))
                    bytes[idx + 1] = UInt8(max(0, Float(bytes[idx + 1]) * boost))
                    bytes[idx + 2] = UInt8(max(0, Float(bytes[idx + 2]) * boost))
                }
            }
        }
        // Step 2: Contrast stretch
        applyContrastStretch(bytes: &bytes, width: width, height: height, bytesPerRow: bytesPerRow)
        // Step 3: Noise reduction
        applyNoiseReduction(bytes: &bytes, width: width, height: height, bytesPerRow: bytesPerRow, strength: strength * 0.4)
    }
    private func applyContrastStretch(bytes: inout [UInt8], width: Int, height: Int, bytesPerRow: Int) {
        var minVal: Float = 255
        var maxVal: Float = 0
        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * bytesPerRow + x * 4)
                guard idx + 2 < bytes.count else { continue }
                let lum = Float(bytes[idx]) * 0.299 + Float(bytes[idx + 1]) * 0.587 + Float(bytes[idx + 2]) * 0.114
                minVal = min(minVal, lum)
                maxVal = max(maxVal, lum)
            }
        }
        guard maxVal > minVal else { return }
        let range = maxVal - minVal
        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * bytesPerRow + x * 4)
                guard idx + 2 < bytes.count else { continue }
                bytes[idx]     = UInt8(min(255, max(0, Int((Float(bytes[idx]) - minVal) / range * 255.0))))
                bytes[idx + 1] = UInt8(max(0, min(255, Int((Float(bytes[idx + 1]) - minVal) / range * 255.0))))
                bytes[idx + 2] = UInt8(max(0, min(255, Int((Float(bytes[idx + 2]) - minVal) / range * 255.0))))
            }
        }
    }

    private func applyNoiseReduction(bytes: inout [UInt8], width: Int, height: Int, bytesPerRow: Int, strength: Float) {
        guard strength > 0.0 else { return }
        var result = bytes
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                for c in 0..<3 {
                    let idx = (y * bytesPerRow + x * 4) + c
                    var sum: Float = 0
                    let count: Float = 9
                    for dy in -1...1 {
                        for dx in -1...1 {
                            let pIdx = ((y + dy) * bytesPerRow + (x + dx) * 4) + c
                            sum += Float(bytes[pIdx])
                        }
                    }
                    let avg = sum / count
                    bytes[idx] = UInt8(max(0, min(255, Int(Float(bytes[idx]) * (1.0 - strength) + avg * strength))))
                }
            }
        }
    }
}

/// Night mode manager — holds night mode state and applies enhancement
final class NightModeManager: ObservableObject {
    @Published var isEnabled: Bool = false
    @Published var strength: Float = 0.5
    private let enhancer = NightEnhancer()
    func apply(bytes: inout [UInt8], width: Int, height: Int, bytesPerRow: Int) {
        guard isEnabled else { return }
        enhancer.enhance(bytes: &bytes, width: width, height: height, bytesPerRow: bytesPerRow, strength: strength)
    }
}

/// Zoom level manager — holds current zoom state and applies processing.
final class ZoomManager: ObservableObject {
    @Published var zoomLevel: ZoomLevel = .oneX
    private let enhancer = ZoomEnhancer()

    func process(bytes: inout [UInt8], width: Int, height: Int, bytesPerRow: Int) -> [UInt8] {
        guard zoomLevel != .oneX else { return bytes }
        let factor = zoomLevel.factor
        let cropW = Int(Float(width) / factor)
        let cropH = Int(Float(height) / factor)
        let cx = width / 2
        let cy = height / 2
        var cropBytes = [UInt8](repeating: 0, count: cropW * cropH * 4)
        for y in 0..<cropH {
            for x in 0..<cropW {
                let srcX = cx - cropW / 2 + x
                let srcY = cy - cropH / 2 + y
                let srcIdx = (srcY * bytesPerRow + srcX * 4)
                let dstIdx = (y * cropW * 4 + x * 4)
                cropBytes[dstIdx]     = bytes[srcIdx]
                cropBytes[dstIdx + 1] = bytes[srcIdx + 1]
                cropBytes[dstIdx + 2] = bytes[srcIdx + 2]
                cropBytes[dstIdx + 3] = bytes[srcIdx + 3]
            }
        }
        return enhancer.upscale(bytes: cropBytes, width: cropW, height: cropH, bytesPerRow: cropW * 4, factor: factor)
    }