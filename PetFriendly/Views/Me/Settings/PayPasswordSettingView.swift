import SwiftUI
import Alamofire

/// 支付密码设置/重置页
/// 统一风格：品牌渐变主按钮 + PFPetLoadingInline 加载 + Toast 错误提示（与 App 全局一致）
struct PayPasswordSettingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hasPayPassword = false
    @State private var isChecking = true
    @State private var isLoading = false
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    if isChecking {
                        VStack(spacing: 12) {
                            PFPetLoadingView(size: 36)
                            Text("loading")
                                .font(PFFonts.caption)
                                .foregroundColor(PFColors.textSecondary)
                        }
                        .padding(.top, 60)
                    } else {
                        Image(systemName: hasPayPassword ? "lock.shield.fill" : "lock.shield")
                            .font(.system(size: 52))
                            .foregroundColor(hasPayPassword ? PFColors.success : PFColors.warning)
                            .padding(.top, 20)
                        Text(hasPayPassword ? "pay_pwd_title_reset" : "pay_pwd_title_set")
                            .font(PFFonts.title2.bold())
                            .foregroundColor(PFColors.textPrimary)
                        Text(hasPayPassword ? "pay_pwd_desc_reset" : "pay_pwd_desc_set")
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.textSecondary)
                            .multilineTextAlignment(.center)

                        if hasPayPassword {
                            passwordField(label: "pay_pwd_old_label", placeholderKey: "pay_pwd_old_placeholder", text: $oldPassword)
                        }
                        passwordField(label: "pay_pwd_new_label", placeholderKey: "pay_pwd_new_placeholder", text: $newPassword)
                        passwordField(label: "pay_pwd_confirm_label", placeholderKey: "pay_pwd_confirm_placeholder", text: $confirmPassword)

                        if !confirmPassword.isEmpty && newPassword != confirmPassword {
                            Text("pay_pwd_mismatch")
                                .font(PFFonts.caption)
                                .foregroundColor(PFColors.danger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // 主按钮（App 统一风格）
                        Button(action: submit) {
                            HStack {
                                if isLoading {
                                    PFPetLoadingInline(size: 16)
                                }
                                Text(isLoading ? "loading" : "confirm")
                                    .font(PFFonts.body)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(canSubmit ? AnyShapeStyle(PFGradients.brand) : AnyShapeStyle(PFColors.textTertiary.opacity(0.4)))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
                        }
                        .disabled(!canSubmit)
                        .opacity(canSubmit ? 1 : 0.7)

                        Text("pay_pwd_note")
                            .font(PFFonts.caption2)
                            .foregroundColor(PFColors.textTertiary)
                    }
                }
                .padding(32)
            }
        }
        .navigationTitle("pay_pwd_title")
        .navigationBarTitleDisplayMode(.inline)
        .pfToyBackground()
        .task { await checkStatus() }
    }

    private func passwordField(label: LocalizedStringKey, placeholderKey: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(PFFonts.caption)
                .foregroundColor(PFColors.textSecondary)
            // 支付密码：仅允许数字（numberPad 输入法 + 逐字符过滤，最多 6 位）
            // 不用 SecureField，避免 SecureField 忽略 numberPad 导致能输入非数字
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(text.wrappedValue.isEmpty ? PFColors.textTertiary : PFColors.primary)
                TextField("", text: text)
                    .keyboardType(.numberPad)
                    .font(PFFonts.body)
                    .foregroundColor(PFColors.textPrimary)
                    .tint(PFColors.primary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onChange(of: text.wrappedValue) { value in
                        // 仅保留数字，最多 6 位
                        let filtered = String(value.filter { $0.isASCII && $0.isNumber }.prefix(6))
                        if filtered != value { text.wrappedValue = filtered }
                    }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(PFColors.surfaceSecondary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(text.wrappedValue.isEmpty ? Color.clear : PFColors.primary, lineWidth: 2)
            )
        }
    }

    private var canSubmit: Bool {
        !isLoading && newPassword.count == 6 && newPassword == confirmPassword && (!hasPayPassword || oldPassword.count == 6)
    }

    @MainActor private func checkStatus() async {
        isChecking = true
        defer { isChecking = false }
        do {
            let response: RespWrapper<Bool> = try await NetworkManager.shared.request(
                "/petFriendly/client/pay-password/status", method: .get, needToken: true, showLoading: false)
            if response.code == 200 { hasPayPassword = response.data ?? false }
            else {
                errorMessage = localizedPayPasswordMessage(response.msg, fallbackKey: "pay_pwd_status_failed")
                UIState.shared.showToast(errorMessage ?? NSLocalizedString("pay_pwd_status_failed", comment: ""), style: .error)
            }
        } catch {
            let msg = (error as? BizError)?.errorDescription
                ?? NSLocalizedString("pay_pwd_status_failed", comment: "")
            UIState.shared.showToast(msg, style: .error)
        }
    }

    @MainActor private func submit() {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil
        let request = PayPasswordFormState(hasPassword: hasPayPassword).request(old: oldPassword, new: newPassword)
        Task {
            do {
                let response: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                    request.path, method: .post, parameters: request.parameters,
                    encoding: JSONEncoding.default, needToken: true, showLoading: false)
                await MainActor.run {
                    isLoading = false
                    if response.code == 200 {
                        // 仅成功后关闭页面
                        UIState.shared.showToast(NSLocalizedString("pay_pwd_success", comment: ""))
                        dismiss()
                    } else {
                        // 提示统一走 Toast，直接透传后端错误 msg；不关闭页面，可重试
                        errorMessage = localizedPayPasswordMessage(response.msg, fallbackKey: "pay_pwd_submit_failed")
                        UIState.shared.showToast(errorMessage ?? NSLocalizedString("pay_pwd_submit_failed", comment: ""), style: .error)
                        if hasPayPassword { oldPassword = "" }
                    }
                }
            } catch {
                // NetworkManager 对 code!=200 会抛 BizError（带后端 msg），这里直接展示该 msg；不关闭页面
                await MainActor.run {
                    isLoading = false
                    let msg = (error as? BizError)?.errorDescription
                        ?? error.localizedDescription
                    UIState.shared.showToast(msg, style: .error)
                    if hasPayPassword { oldPassword = "" }
                }
            }
        }
    }
}

private func localizedPayPasswordMessage(_ message: String?, fallbackKey: String) -> String {
    let language = Bundle.main.preferredLocalizations.first ?? Locale.current.identifier
    if language.hasPrefix("zh"), let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return message }
    return NSLocalizedString(fallbackKey, comment: "")
}
