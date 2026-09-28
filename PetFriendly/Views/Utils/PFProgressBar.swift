import SwiftUI

/// 🐾 宠物友好指南精美进度加载条
/// 采用 iOS 26/27 拟态微动弹簧设计，支持液态渐变色与弹性动画
struct PFProgressBar: View {
    var value: Double
    var total: Double
    var tintColor: Color = PFColors.primary
    
    private var progressRatio: CGFloat {
        total > 0 ? CGFloat(max(0, min(value / total, 1.0))) : 0.0
    }
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Spacer()
                Text("Step \(Int(value)) of \(Int(total))")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color.secondary.opacity(0.7))
            }
            .padding(.trailing, 2)
            
            ZStack(alignment: .leading) {
                // 底层拟态轨道背景 (自适应撑满)
                Capsule()
                    .frame(height: 8)
                    .foregroundColor(Color(.systemGray5).opacity(0.5))
                
                // 顶层流态渐变填充 (自适应撑满，通过 scaleEffect 比例缩放实现稳定渲染)
                Capsule()
                    .frame(height: 8)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [tintColor.opacity(0.85), tintColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: tintColor.opacity(0.25), radius: 4, x: 0, y: 1.5)
                    // 采用 scaleEffect 配合 .leading 锚点进行左起缩放，完美解决 GeometryReader 在自适应容器中宽度退化为 0 的问题
                    .scaleEffect(x: progressRatio, y: 1.0, anchor: .leading)
                    // 拟微动阻尼弹簧曲线，切换步骤时进度会有自然的液态弹性缓冲回弹
                    .animation(.spring(response: 0.45, dampingFraction: 0.72), value: value)
            }
            .frame(height: 8)
        }
    }
}
