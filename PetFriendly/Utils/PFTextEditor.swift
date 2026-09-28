//
//  PFTextEditor.swift
//  PetFriendly
//
//  全局统一样式的多行文本输入框 — 替代零散的 TextEditor 样式
//  统一风格：圆角 16、浅灰背景、主色描边（已输入时）、占位文字
//

import SwiftUI

/// 统一风格的多行文本编辑器
struct PFTextEditor: View {
    let placeholder: String
    @Binding var text: String
    var height: CGFloat = 120
    var maxLength: Int = 500
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // 实际编辑器
            TextEditor(text: $text)
                .font(PFFonts.body)
                .foregroundColor(PFColors.textPrimary)
                .frame(height: height)
                // .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(16)
                .focused($isFocused)
                .onChange(of: text) { newValue in
                    if newValue.count > maxLength {
                        text = String(newValue.prefix(maxLength))
                    }
                }
            
            // 占位文字（仿原生 TextField placeholder 效果）
            if text.isEmpty && !isFocused {
                Text(LocalizedStringKey(placeholder))
                    .font(PFFonts.body)
                    .foregroundColor(PFColors.textTertiary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
            }
        }
        .background(PFColors.surfaceSecondary)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isFocused ? PFColors.primary : (text.isEmpty ? Color.clear : PFColors.primary.opacity(0.5)), lineWidth: isFocused ? 2 : 1.5)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
    }
}

// MARK: - 统一风格的单行文本字段

struct PFTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var maxLength: Int = 100
    var isSecure: Bool = false
    var icon: String? = nil
    /// 验证反馈：idle=无，success=绿描边，error=红描边
    var verifyFeedback: VerifyFeedback = .idle

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(text.isEmpty ? PFColors.textTertiary : PFColors.primary)
            }
            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .font(PFFonts.body)
            .foregroundColor(PFColors.textPrimary)
            .tint(PFColors.primary)
            .keyboardType(keyboardType)
            .autocapitalization(.none)
            .disableAutocorrection(true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(PFColors.surfaceSecondary)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(strokeColor, lineWidth: 2)
        )
        .onChange(of: text) { newValue in
            if newValue.count > maxLength {
                text = String(newValue.prefix(maxLength))
            }
        }
    }

    /// 描边色：验证反馈优先（绿/红），否则聚焦填字时用主色
    private var strokeColor: Color {
        switch verifyFeedback {
        case .success: return Color(hex: "34D399")
        case .error: return Color(hex: "F87171")
        case .idle: return text.isEmpty ? Color.clear : PFColors.primary
        }
    }
}

// MARK: - 预览
// 注：Xcode-beta 27.0 SDK 下 #Preview 宏展开异常（invalid redeclaration of 'PFTextField'），
// 临时注释以通过 Release 打包；Xcode 预览功能暂不可用，不影响 App 运行。

/* #Preview {
    VStack(spacing: 20) {
        PFTextEditor(placeholder: NSLocalizedString("place_enter_desc", comment: ""), text: .constant(""))
        PFTextEditor(placeholder: NSLocalizedString("place_enter_desc", comment: ""), text: .constant(NSLocalizedString("has_content_example", comment: "")))
        PFTextField(placeholder: NSLocalizedString("place_enter_name", comment: ""), text: .constant(""))
        PFTextField(placeholder: NSLocalizedString("place_enter_addr", comment: ""), text: .constant(NSLocalizedString("has_addr_example", comment: "")))
    }
    .padding()
} */
