//
//  SlideNumber.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2025/10/15.
//
import SwiftUI


struct SlideNumber: View {
    let number: Int
    @State private var trigger = false   // 用来强制刷新动画
    
    var body: some View {
        Text("-(\(number))")      // 占位，实际内容由 modifier 画
            .font(.system(size: 16, weight: .bold))
            .lineLimit(1)
            .modifier(SlideNumberEffect(target: number,
                                        animatableData: trigger ? 1 : 0))
            .onChange(of: number) { _ in        // ✅ 这里才用 .onChange
                withAnimation(.easeInOut(duration: 0.3)) {
                    trigger.toggle()            // 0->1 或 1->0 都能再次插值
                }
            }
            .onAppear {
                trigger = true                   // 第一次也走动画
            }
    }
}
