import SwiftUI

// MARK: - 配置

/// B 方案通用「确认操作」弹窗配置。
/// 通过 fullScreenCover(item:) 驱动，点击确认后不立即关闭：
/// - 展示加载态，等异步接口返回
/// - 成功才关闭弹窗；失败保留弹窗并展示错误（可重试）
/// - 支持可选输入框（如手机号、取消原因等）
struct PFActionDialogConfig: Identifiable {
    let id = UUID()
    var title: String
    var message: String
    var confirmTitle: String
    /// 确认按钮是否红色（破坏性操作，如退款/取消/注销/提现）
    var destructive: Bool = true
    /// 确认按钮是否带图标（如点赞、完成）
    var confirmIcon: String? = nil
    /// 是否展示输入框
    var showTextField: Bool = false
    var textFieldPlaceholder: String = ""
    /// 输入框初始值（如当前手机号）
    var textFieldInitial: String = ""
    var textFieldIsPhone: Bool = false
    /// 自定义取消文案
    var cancelTitle: String = ""
}

// MARK: - 弹窗视图

/// 通用确认操作弹窗：加载态 + 成功才关 + 失败保留可重试。
/// 用法：`.fullScreenCover(item: $dialogConfig) { config in
///     PFActionDialog(config: config,
///                    onConfirm: { input in await doSomething(input) },
///                    onCancel: { dialogConfig = nil })
/// }`
struct PFActionDialog: View {
    let config: PFActionDialogConfig
    /// 返回 nil 表示成功（关闭弹窗）；返回非 nil 表示失败（保留弹窗 + Toast 提示错误）
    let onConfirm: (String) async -> String?
    let onCancel: () -> Void

    @State private var inputValue: String = ""
    @State private var isSubmitting = false

    var body: some View {
        ZStack {
            // 半透明遮罩，点击空白取消（提交中不可取消）
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { if !isSubmitting { onCancel() } }

            VStack(spacing: 16) {
                // 标题
                Text(config.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(PFColors.textPrimary)

                // 文案
                Text(config.message)
                    .font(.system(size: 14))
                    .foregroundColor(PFColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)

                // 可选输入框
                if config.showTextField {
                    TextField(config.textFieldPlaceholder, text: $inputValue)
                        .keyboardType(config.textFieldIsPhone ? .phonePad : .default)
                        .textInputAutocapitalization(.never)
                        .padding(10)
                        .background(PFColors.surfaceSecondary)
                        .cornerRadius(PFRadius.md)
                        .disabled(isSubmitting)
                }

                // 按钮区
                HStack(spacing: 12) {
                    // 取消
                    Button(action: { if !isSubmitting { onCancel() } }) {
                        Text(config.cancelTitle.isEmpty ? "alert_cancel" : LocalizedStringKey(config.cancelTitle))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(PFColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(PFColors.surfaceSecondary)
                            .cornerRadius(12)
                    }
                    .disabled(isSubmitting)

                    // 确认
                    Button(action: submit) {
                        HStack(spacing: 6) {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            } else if let icon = config.confirmIcon {
                                Image(systemName: icon)
                            }
                            Text(isSubmitting ? "loading" : LocalizedStringKey(config.confirmTitle))
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(config.destructive ? PFColors.danger : PFColors.primary)
                        )
                    }
                    .disabled(isSubmitting)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(PFColors.surface)
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
            )
            .padding(.horizontal, 36)
        }
        .interactiveDismissDisabled(isSubmitting)
        .onAppear { inputValue = config.textFieldInitial }
    }

    private func submit() {
        guard !isSubmitting else { return }
        isSubmitting = true
        Task {
            let result = await onConfirm(inputValue)
            await MainActor.run {
                isSubmitting = false
                if let error = result {
                    UIState.shared.showToast(error, style: .error)
                    // 失败保留弹窗，可重试
                } else {
                    onCancel() // 成功关闭
                }
            }
        }
    }
}
