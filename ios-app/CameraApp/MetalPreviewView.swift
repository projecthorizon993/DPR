import SwiftUI
import MetalKit

/// A Metal-backed preview view that displays a processed CGImage.
///
/// Feeds CGImages into an MTKView for GPU-backed display. All code is original.
struct MetalPreviewView: UIViewRepresentable {
    /// The image to display.
    var image: CGImage?

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.framebufferOnly = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.autoResizeDrawable = true
        mtkView.isPaused = false
        mtkView.drawableSize = mtkView.bounds.size
        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.image = image
        uiView.drawableSize = uiView.bounds.size
        uiView.setNeedsDisplay()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        var image: CGImage?
        private let ciContext = CIContext()

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let image = image,
                  let drawable = view.currentDrawable,
                  let commandBuffer = view.device?.makeCommandQueue()?.makeCommandBuffer(),
                  let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
                return
            }

            let ciImage = CIImage(cgImage: image)
            let scaled = ciImage.transformed(by: CGAffineTransform(
                scaleX: view.drawableSize.width / CGFloat(image.width),
                y: view.drawableSize.height / CGFloat(image.height)
            ))

            ciContext.render(scaled, to: drawable.texture, commandBuffer: commandBuffer,
                             bounds: CGRect(origin: .zero, size: view.drawableSize),
                             colorSpace: CGColorSpaceCreateDeviceRGB())

            blitEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
