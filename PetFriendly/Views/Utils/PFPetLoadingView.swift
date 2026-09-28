//
//  PFPetLoadingView.swift
//  PetFriendly
//
//  可爱宠物主题加载动画组件 (iOS 27 设计规范)
//  单个爪印弹跳 + 打字指示器风格圆点，简洁可爱
//

import SwiftUI

// MARK: - 1. 主加载视图（弹跳爪印 + 圆点指示器）

struct PFPetLoadingView: View {
    let text: LocalizedStringKey?
    let size: CGFloat

    @State private var isBouncing = false
    @State private var dotPhase: Int = 0

    init(_ text: LocalizedStringKey? = nil, size: CGFloat = 36) {
        self.text = text
        self.size = size
    }

    var body: some View {
        VStack(spacing: size * 0.5) {
            // 弹跳爪印
            Image(systemName: "pawprint.fill")
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(PFColors.primary)
                .rotationEffect(.degrees(isBouncing ? -12 : 12))
                .offset(y: isBouncing ? -size * 0.4 : 0)
                .animation(
                    .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                    value: isBouncing
                )

            // 三个圆点指示器（类似打字指示器）
            HStack(spacing: size * 0.18) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(PFColors.accent)
                        .frame(width: size * 0.16, height: size * 0.16)
                        .opacity(dotPhase == index ? 1.0 : 0.3)
                        .scaleEffect(dotPhase == index ? 1.3 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.35),
                            value: dotPhase
                        )
                }
            }

            // 提示文案
            if let text = text {
                Text(text)
                    .font(PFFonts.caption)
                    .foregroundColor(PFColors.textSecondary)
            }
        }
        .onAppear {
            isBouncing = true
            startDotAnimation()
        }
    }

    private func startDotAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            dotPhase = (dotPhase + 1) % 3
        }
    }
}

// MARK: - 2. 内联轻量加载动画（用于按钮/输入框/底部占位）

struct PFPetLoadingInline: View {
    let size: CGFloat

    init(size: CGFloat = 16) {
        self.size = size
    }

    var body: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
            .scaleEffect(size / 20.0)
            .frame(width: size, height: size)
    }
}

// MARK: - 3. 全屏/卡片加载遮罩（用于地图全屏加载）

struct PFPetLoadingOverlay: View {
    let text: LocalizedStringKey?

    init(text: LocalizedStringKey? = nil) {
        self.text = text
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.12)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                PFPetLoadingView(text, size: 32)
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 28)
            .liquidFrostedGlass(cornerRadius: PFRadius.xl)
            .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 12)
        }
    }
}
