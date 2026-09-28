//
//  SlideNumberEffect.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2025/10/15.
//
import SwiftUI

/// 只做“数字上下滑动”动画，不关心业务
struct SlideNumberEffect: AnimatableModifier {
    var target: Int          // 新值
    var animatableData: Double = 0   // 0~1 插值
    private var old: Int             // 旧值
    
    // 计算当前应该显示的数字
    private var current: Int {
        Int(Double(target) * animatableData)
    }
    
    init(target: Int, animatableData: Double) {
        self.target = target
        self.old = target
        self.animatableData = animatableData
    }
    
    func body(content: Content) -> some View {
        let offset = 1 - animatableData
        
        Image(systemName: "scribble.variable")
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(.green)
            .frame(height: 20, alignment: .center)
            .padding(.horizontal, 0)
        VStack(spacing: 0) {
            Text("\(old)")
                .font(.system(size: 16, weight: .bold))
                .offset(y: -offset * 20 + 10)
                .opacity(animatableData)
                .foregroundStyle(.green)
            
            Text("\(target)")
                .font(.system(size: 16, weight: .bold))
                .offset(y: (1 - offset) * 20 - 10)
                .opacity(1 - animatableData)
                .foregroundStyle(.green)
            
        }
        .frame(height: 20, alignment: .center)
        .clipped()
    }
}
