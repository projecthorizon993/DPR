import SwiftUI

// MARK: - 简化版变焦滑块控制

/// 简化版变焦滑块控制组件
struct ZoomSliderControl: View {
    
    // MARK: - 绑定属性
    
    /// 当前变焦倍数
    @Binding var currentZoomFactor: CGFloat
    
    /// 是否显示控制条
    @Binding var isVisible: Bool
    
    // MARK: - 配置属性
    
    /// 最小变焦倍数
    let minZoom: CGFloat
    
    /// 最大变焦倍数
    let maxZoom: CGFloat
    
    /// 变焦变化回调
    let onZoomChange: (CGFloat) -> Void
    
    // MARK: - 私有状态
    
    /// 本地变焦值（用于滑块）
    @State private var sliderValue: Double = 1.0
    
    // MARK: - 计算属性
    
    private let controlHeight: CGFloat = 50
    private let controlWidth: CGFloat = 280
    
    // MARK: - 主视图
    
    var body: some View {
        VStack(spacing: 8) {
            // 变焦值显示
            zoomValueDisplay
            
            // 变焦滑块
            zoomSlider
        }
        .opacity(isVisible ? 1.0 : 0.8)
        .scaleEffect(isVisible ? 1.0 : 0.9)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
        .onAppear {
            // 初始化滑块值
            sliderValue = Double(currentZoomFactor)
        }
        .onChange(of: currentZoomFactor) { _, newValue in
            // 外部变焦变化时更新滑块
            if abs(sliderValue - Double(newValue)) > 0.1 {
                sliderValue = Double(newValue)
            }
        }
    }
    
    // MARK: - 子视图组件
    
    /// 变焦值显示
    private var zoomValueDisplay: some View {
        Text("\(String(format: "%.1f", currentZoomFactor))×")
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
    
    /// 变焦滑块
    private var zoomSlider: some View {
        HStack(spacing: 12) {
            // 缩小图标
            Image(systemName: "minus.magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 20, height: 20)
            
            // 滑块
            Slider(
                value: $sliderValue,
                in: Double(minZoom)...Double(maxZoom),
                step: 0.1
            ) {
                // 滑动标题（可选）
            }
            .onChange(of: sliderValue) { _, newValue in
                // 实时响应滑块变化
                let newZoom = CGFloat(newValue)
                currentZoomFactor = newZoom
                onZoomChange(newZoom)
            }
            .accentColor(.blue)
            .frame(width: controlWidth - 80)
            
            // 放大图标
            Image(systemName: "plus.magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 20, height: 20)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(
                            Color.white.opacity(0.3),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

// MARK: - 预览

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            
            ZoomSliderControl(
                currentZoomFactor: .constant(2.0),
                isVisible: .constant(true),
                minZoom: 0.5,
                maxZoom: 10.0
            ) { newZoom in
                print("变焦到: \(newZoom)x")
            }
            .padding(.bottom, 100)
        }
    }
}