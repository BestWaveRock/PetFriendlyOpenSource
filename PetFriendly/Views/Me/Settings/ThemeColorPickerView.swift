//
//  ThemeColorPickerView.swift
//  PetFriendly
//
//  主题色选择页面 — 10 色圆形网格 + 预览区 + 确认切换
//

import SwiftUI

struct ThemeColorPickerView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    /// 临时预览色（未确认前不写入 AppStorage）
    @State private var previewPreset: ThemePreset?
    /// 确认动画
    @State private var didConfirm = false
    
    /// 当前正在预览的主题（未选择时用已保存的）
    private var activePreset: ThemePreset {
        previewPreset ?? themeManager.currentPreset
    }
    
    /// 根据配色模式取色
    private var activeColor: Color {
        colorScheme == .dark ? activePreset.darkColor : activePreset.color
    }
    
    // 两列网格
    private let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20),
    ]
    
    var body: some View {
        ZStack {
            // 背景
            (colorScheme == .dark ? Color.black : Color(hex: "F8F7FF"))
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // ── 1. 预览区 ──
                    previewSection
                    
                    // ── 2. 色板网格 ──
                    colorGridSection
                    
                    // ── 3. 确认按钮 ──
                    confirmButton
                    
                    Spacer(minLength: 40)
                }
                .padding(.top, 20)
            }
        }
        .navigationTitle("theme_picker_title")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - 预览区
    private var previewSection: some View {
        VStack(spacing: 16) {
            Text("theme_preview_title")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : PFColors.textSecondary)
            
            // 模拟导航栏 + 按钮 + 标签
            VStack(spacing: 16) {
                // 模拟导航栏
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.15) : Color.gray.opacity(0.15))
                        .frame(width: 80, height: 8)
                    Spacer()
                    Circle()
                        .fill(activeColor)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "bell.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                        )
                }
                
                // 模拟标签 + 按钮
                HStack(spacing: 12) {
                    // 标签
                    Text("theme_new_feature")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(activeColor))
                    
                    Text("theme_completed")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(activeColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .stroke(activeColor, lineWidth: 1.5)
                        )
                    
                    Spacer()
                    
                    // 图标按钮
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16))
                        .foregroundColor(activeColor)
                }
                
                // 模拟进度条
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.gray.opacity(0.1))
                            .frame(height: 6)
                        Capsule()
                            .fill(activeColor)
                            .frame(width: geo.size.width * 0.65, height: 6)
                    }
                }
                .frame(height: 6)
                
                // 模拟文字行
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.7) : Color(hex: "1F2937"))
                            .frame(width: 120, height: 8)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.3) : Color.gray.opacity(0.3))
                            .frame(width: 180, height: 6)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.3) : Color.gray.opacity(0.3))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.white)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.06) : Color.clear, lineWidth: 1)
            )
        }
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.25), value: activePreset.hex)
    }
    
    // MARK: - 色板网格
    private var colorGridSection: some View {
        VStack(spacing: 16) {
            Text("theme_select_title")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : PFColors.textSecondary)
            
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(ThemePreset.all) { preset in
                    colorCell(preset)
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    // 单个色圆
    private func colorCell(_ preset: ThemePreset) -> some View {
        let isActive = activePreset.hex == preset.hex
        let isSaved = themeManager.currentPreset.hex == preset.hex
        let displayColor = colorScheme == .dark ? preset.darkColor : preset.color
        
        return VStack(spacing: 8) {
            ZStack {
                // 选中外圈
                if isActive {
                    Circle()
                        .stroke(displayColor, lineWidth: 2.5)
                        .frame(width: 52, height: 52)
                        .transition(.scale)
                }
                
                // 色圆
                Circle()
                    .fill(displayColor)
                    .frame(width: 42, height: 42)
                    .shadow(color: displayColor.opacity(0.3), radius: isActive ? 8 : 0, x: 0, y: 2)
                
                // 已确认标记
                if isSaved {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            Text(LocalizedStringKey(preset.name))
                .font(.system(size: 10, weight: isActive ? .semibold : .regular))
                .foregroundColor(
                    isActive
                    ? (colorScheme == .dark ? .white : PFColors.textPrimary)
                    : (colorScheme == .dark ? .white.opacity(0.4) : PFColors.textTertiary)
                )
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                previewPreset = preset
            }
            // 触觉反馈
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    
    // MARK: - 确认按钮
    private var confirmButton: some View {
        VStack(spacing: 12) {
            Button(action: confirmSelection) {
                HStack(spacing: 8) {
                    if didConfirm {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .transition(.scale.combined(with: .opacity))
                    }
                    Text(didConfirm ? "theme_switched" : "theme_confirm_select")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    Capsule().fill(activeColor)
                )
                .shadow(color: activeColor.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .disabled(previewPreset == nil || previewPreset?.hex == themeManager.currentPreset.hex)
            .opacity(previewPreset == nil || previewPreset?.hex == themeManager.currentPreset.hex ? 0.5 : 1.0)
            
            // 当前状态提示
            if let preview = previewPreset, preview.hex != themeManager.currentPreset.hex {
                Text("theme_previewing \(Text(LocalizedStringKey(preview.name)))")
                    .font(.system(size: 11))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : PFColors.textTertiary)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.2), value: previewPreset?.hex)
        .animation(.easeInOut(duration: 0.2), value: didConfirm)
    }
    
    // MARK: - 确认逻辑
    private func confirmSelection() {
        guard let preset = previewPreset else { return }
        
        // 1. 写入 ThemeManager
        themeManager.applyPreset(preset)
        
        // 2. 成功动画反馈
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { didConfirm = true }
        
        // 3. 短暂延迟后返回
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            dismiss()
        }
    }
}
