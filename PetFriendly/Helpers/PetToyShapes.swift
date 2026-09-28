//
//  PetToyShapes.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 26/5/6.
//

import SwiftUI

/// 狗骨头形状
struct BoneShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // 骨头中间的杠
        let rectBar = CGRect(x: w * 0.2, y: h * 0.35, width: w * 0.6, height: h * 0.3)
        path.addPath(Path(roundedRect: rectBar, cornerRadius: h * 0.1))
        
        // 左侧两个圆头
        path.addEllipse(in: CGRect(x: w * 0.05, y: h * 0.2, width: w * 0.3, height: w * 0.3))
        path.addEllipse(in: CGRect(x: w * 0.05, y: h * 0.5, width: w * 0.3, height: w * 0.3))
        
        // 右侧两个圆头
        path.addEllipse(in: CGRect(x: w * 0.65, y: h * 0.2, width: w * 0.3, height: w * 0.3))
        path.addEllipse(in: CGRect(x: w * 0.65, y: h * 0.5, width: w * 0.3, height: w * 0.3))
        
        return path
    }
}

/// 毛线球形状
struct YarnBallShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        // 基础圆
        path.addEllipse(in: rect)
        
        // 毛线纹路
        for i in 0..<3 {
            let angle = Double(i) * Double.pi / 3
            path.move(to: CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            ))
            path.addQuadCurve(
                to: CGPoint(
                    x: center.x - CGFloat(cos(angle)) * radius,
                    y: center.y - CGFloat(sin(angle)) * radius
                ),
                control: CGPoint(
                    x: center.x + CGFloat(cos(angle + 0.5)) * radius * 0.5,
                    y: center.y + CGFloat(sin(angle + 0.5)) * radius * 0.5
                )
            )
        }
        
        return path
    }
}

/// 玩具球形状
struct ToyBallShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.addEllipse(in: rect)
        
        // 类似网球的弧线
        path.move(to: CGPoint(x: w * 0.2, y: h * 0.2))
        path.addQuadCurve(to: CGPoint(x: w * 0.8, y: h * 0.8), control: CGPoint(x: w * 0.1, y: h * 0.9))
        
        path.move(to: CGPoint(x: w * 0.8, y: h * 0.2))
        path.addQuadCurve(to: CGPoint(x: w * 0.2, y: h * 0.8), control: CGPoint(x: w * 0.9, y: h * 0.9))
        
        return path
    }
}

// MARK: - 预览组件
struct PetToyDecoration: View {
    var body: some View {
        HStack(spacing: 20) {
            BoneShape()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 24)
            
            YarnBallShape()
                .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)
                .frame(width: 30, height: 30)
            
            ToyBallShape()
                .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)
                .frame(width: 25, height: 25)
        }
    }
}

// MARK: - 全局背景装饰 Modifier
struct PetToyBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            // 背景层：散布的玩具 (SVG Path 风格)
            Self.toyDecorationView()
                .ignoresSafeArea()
            
            content
        }
    }
    
    /// 单独提供装饰层视图，可用于 .background() 场景（不包裹 ZStack，不破坏导航链）
    @ViewBuilder
    static func toyDecorationView() -> some View {
        GeometryReader { _ in
            ZStack {
                // 漂浮的骨头 - 左上
                BoneShape()
                    .stroke(Color.primary.opacity(0.16), lineWidth: 3)
                    .frame(width: 50, height: 30)
                    .rotationEffect(.degrees(-15))
                    .position(x: 60, y: 150)
                
                // 漂浮的毛线球 - 右上
                YarnBallShape()
                    .stroke(Color.accentColor.opacity(0.18), lineWidth: 3)
                    .frame(width: 40, height: 40)
                    .position(x: PFScreen.width - 60, y: 100)
                
                // 漂浮的小球 - 左中
                ToyBallShape()
                    .stroke(Color.green.opacity(0.15), lineWidth: 3)
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(20))
                    .position(x: 40, y: 400)
                
                // 漂浮的毛线球 - 右下
                YarnBallShape()
                    .stroke(Color.primary.opacity(0.16), lineWidth: 4)
                    .frame(width: 80, height: 80)
                    .position(x: PFScreen.width - 80, y: PFScreen.height - 200)
                
                // 漂浮的骨头 - 底部
                BoneShape()
                    .stroke(Color.primary.opacity(0.14), lineWidth: 3)
                    .frame(width: 70, height: 42)
                    .rotationEffect(.degrees(10))
                    .position(x: 100, y: PFScreen.height - 100)
            }
        }
        .allowsHitTesting(false)
    }
}

extension View {
    /// 为视图添加宠物玩具背景装饰 (隐约散布的手绘风格)
    func pfToyBackground() -> some View {
        self.modifier(PetToyBackgroundModifier())
    }
}
