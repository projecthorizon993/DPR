import SwiftUI
import AVFoundation
import UIKit

/// 相机预览视图组件
/// 使用AVCaptureVideoPreviewLayer显示实时相机画面，支持固定宽高比
struct CameraPreviewView: UIViewRepresentable {
    
    let session: AVCaptureSession
    @Binding var previewLayer: AVCaptureVideoPreviewLayer?
    
    func makeUIView(context: Context) -> PreviewView {
        let previewView = PreviewView()
        previewView.backgroundColor = UIColor.black
        previewView.previewLayer.session = session
        // 改为 .resizeAspect 保持宽高比，避免裁剪
        previewView.previewLayer.videoGravity = .resizeAspect
        
        DispatchQueue.main.async {
            self.previewLayer = previewView.previewLayer
        }
        
        return previewView
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        // 更新会话（如果需要）
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }
}

/// UIView子类，封装AVCaptureVideoPreviewLayer
/// 针对拍照预览优化，保持传感器原生比例
class PreviewView: UIView {
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 确保预览层填充整个视图（容器已经是固定比例）
        previewLayer.frame = bounds
        
        // 根据设备方向调整预览层方向
        if let connection = previewLayer.connection,
           connection.isVideoOrientationSupported {
            connection.videoOrientation = getVideoOrientation()
        }
    }
    
    /// 获取当前设备方向对应的视频方向
    /// 针对拍照应用优化
    private func getVideoOrientation() -> AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        default:
            // 默认竖屏方向，适合拍照预览
            return .portrait
        }
    }
}

/// 对焦指示器视图
struct FocusIndicatorView: View {
    let position: CGPoint
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 外圈
            Rectangle()
                .stroke(Color.yellow, lineWidth: 2)
                .frame(width: 80, height: 80)
                .scaleEffect(isAnimating ? 0.8 : 1.0)
                .opacity(isAnimating ? 0.8 : 1.0)
            
            // 内圈
            Rectangle()
                .stroke(Color.yellow, lineWidth: 1)
                .frame(width: 40, height: 40)
        }
        .position(position)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                isAnimating = true
            }
        }
    }
}

/// 曝光指示器视图
struct ExposureIndicatorView: View {
    let position: CGPoint
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 圆形指示器
            Circle()
                .stroke(Color.orange, lineWidth: 2)
                .frame(width: 60, height: 60)
                .scaleEffect(isAnimating ? 0.9 : 1.0)
                .opacity(isAnimating ? 0.9 : 1.0)
            
            // 中心点
            Circle()
                .fill(Color.orange)
                .frame(width: 4, height: 4)
            
            // 太阳图标
            Image(systemName: "sun.max")
                .foregroundColor(.orange)
                .font(.system(size: 12, weight: .medium))
        }
        .position(position)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                isAnimating = true
            }
        }
    }
}

/// 网格线视图
struct GridLinesView: View {
    let isVisible: Bool
    
    var body: some View {
        GeometryReader { geometry in
            if isVisible {
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    
                    // 垂直线
                    path.move(to: CGPoint(x: width / 3, y: 0))
                    path.addLine(to: CGPoint(x: width / 3, y: height))
                    path.move(to: CGPoint(x: width * 2 / 3, y: 0))
                    path.addLine(to: CGPoint(x: width * 2 / 3, y: height))
                    
                    // 水平线
                    path.move(to: CGPoint(x: 0, y: height / 3))
                    path.addLine(to: CGPoint(x: width, y: height / 3))
                    path.move(to: CGPoint(x: 0, y: height * 2 / 3))
                    path.addLine(to: CGPoint(x: width, y: height * 2 / 3))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
            }
        }
    }
}

/// 水平仪视图
struct LevelIndicatorView: View {
    @Binding var roll: Double
    let isVisible: Bool
    
    var body: some View {
        VStack {
            if isVisible {
                HStack(spacing: 20) {
                    // 左侧指示器
                    Circle()
                        .fill(abs(roll) < 2.0 ? Color.green : Color.white.opacity(0.7))
                        .frame(width: 8, height: 8)
                    
                    // 中央水平线
                    Rectangle()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 100, height: 2)
                        .rotationEffect(.degrees(roll))
                    
                    // 右侧指示器  
                    Circle()
                        .fill(abs(roll) < 2.0 ? Color.green : Color.white.opacity(0.7))
                        .frame(width: 8, height: 8)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(20)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            // 预览示例（无实际相机会话）
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 400)
                .overlay(
                    Text("相机预览区域")
                        .foregroundColor(.white)
                )
            
            // 网格线示例
            Rectangle()
                .fill(Color.clear)
                .frame(height: 200)
                .overlay(
                    GridLinesView(isVisible: true)
                )
            
            // 控制指示器示例
            HStack(spacing: 20) {
                LevelIndicatorView(roll: .constant(1.5), isVisible: true)
                
                Button("对焦") {
                    // 对焦动作
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
    }
}