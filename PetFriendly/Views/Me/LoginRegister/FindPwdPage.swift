//
//  FindPwdPage.swift
//  PetFriendly
//
//  忘记密码 - 三步找回（邮箱验证码方式）
//

import SwiftUI

struct FindPwdPage: View {
    @Environment(\.dismiss) var dismiss
    
    // MARK: - State
    @State private var currentStep = 0          // 0=邮箱, 1=验证码, 2=新密码
    @State private var email = ""
    @State private var verifyCode = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    
    @State private var loading = false
    @State private var successMsg = ""
    /// 验证码输入框的验证反馈（绿=通过，红=错误）
    @State private var codeFeedback: VerifyFeedback = .idle
    
    // 倒计时
    @State private var countdown = 0
    @State private var timer: Timer?
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                PFColors.background.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 30) {
                        
                        // Logo
                        HStack {
                            Spacer()
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 40))
                                .foregroundColor(PFColors.textPrimary)
                                .padding(.top, 20)
                            Spacer()
                        }
                        
                        // 标题
                        Text("find_pwd_title")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(PFColors.textPrimary)
                        
                        // 副标题 (分步提示)
                        Text(stepSubtitle)
                            .font(PFFonts.body)
                            .foregroundColor(PFColors.textSecondary)
                        
                        // 进度指示器
                        progressIndicator
                        
                        // 分步内容（步骤1 = 验证码+新密码合并，最后提交统一验证）
                        switch currentStep {
                        case 0: emailStep
                        case 1: codePasswordStep
                        default: EmptyView()
                        }
                        
                        // 错误提示统一走全局 ToastView，不在 UI 内联红字
                        
                        // 成功提示
                        if !successMsg.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text(successMsg)
                                    .font(PFFonts.caption)
                                    .foregroundColor(.green)
                            }
                            .transition(.opacity)
                        }
                        
                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 10)
                }
            }
            .navigationTitle("find_pwd_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common_close") { dismiss() }
                }
            }
        }
        .onDisappear { timer?.invalidate() }
    }
    
    // MARK: - Step Subtitle
    
    private var stepSubtitle: LocalizedStringKey {
        switch currentStep {
        case 0: return "find_pwd_step1_hint"
        case 1: return "find_pwd_combined_hint"
        default: return ""
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<2) { i in
                Capsule()
                    .fill(i <= currentStep ? PFColors.primary : PFColors.primary.opacity(0.2))
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
    }
    
    // MARK: - Step 1: Email Input
    
    private var emailStep: some View {
        VStack(spacing: 20) {
            // 邮箱输入
            VStack(alignment: .leading, spacing: 8) {
                Text("find_pwd_email_label")
                    .font(PFFonts.callout)
                    .foregroundColor(PFColors.textSecondary)
                
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(PFColors.textTertiary)
                    TextField("find_pwd_email_placeholder", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: PFRadius.md)
                        .fill(PFColors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PFRadius.md)
                        .stroke(PFColors.primary.opacity(0.3), lineWidth: 1)
                )
            }
            
            // 发送验证码按钮
            Button {
                sendCode()
            } label: {
                HStack {
                    if loading {
                        PFPetLoadingInline(size: 14)
                    }
                    Text(countdown > 0
                         ? String(format: NSLocalizedString("find_pwd_resend_countdown", comment: ""), countdown)
                         : NSLocalizedString("find_pwd_send_code", comment: ""))
                        .font(PFFonts.body.bold())
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: PFRadius.md)
                        .fill(canSend ? PFColors.primary : PFColors.primary.opacity(0.4))
                )
                .foregroundColor(.white)
            }
            .disabled(!canSend)
        }
    }
    
    // MARK: - Step 1: 验证码 + 新密码（合并，最后提交统一验证）
    
    private var codePasswordStep: some View {
        VStack(spacing: 20) {
            // 验证码
            VStack(alignment: .leading, spacing: 8) {
                Text("find_pwd_code_label")
                    .font(PFFonts.callout)
                    .foregroundColor(PFColors.textSecondary)
                
                HStack {
                    Image(systemName: "number")
                        .foregroundColor(PFColors.textTertiary)
                    TextField("find_pwd_code_placeholder", text: $verifyCode)
                        .keyboardType(.numberPad)
                        .onChange(of: verifyCode) { newValue in
                            if newValue.count > 6 { verifyCode = String(newValue.prefix(6)) }
                        }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: PFRadius.md)
                        .fill(PFColors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PFRadius.md)
                        .stroke(strokeColor, lineWidth: 1)
                )
            }
            
            // 新密码
            VStack(alignment: .leading, spacing: 8) {
                Text("find_pwd_new_password")
                    .font(PFFonts.callout)
                    .foregroundColor(PFColors.textSecondary)
                
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(PFColors.textTertiary)
                    if showPassword {
                        TextField("find_pwd_password_placeholder", text: $newPassword)
                    } else {
                        SecureField(NSLocalizedString("find_pwd_password_placeholder", comment: ""), text: $newPassword)
                    }
                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(PFColors.textTertiary)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: PFRadius.md)
                        .fill(PFColors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PFRadius.md)
                        .stroke(PFColors.primary.opacity(0.3), lineWidth: 1)
                )
            }
            
            // 确认密码
            VStack(alignment: .leading, spacing: 8) {
                Text("find_pwd_confirm_password")
                    .font(PFFonts.callout)
                    .foregroundColor(PFColors.textSecondary)
                
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(PFColors.textTertiary)
                    SecureField(NSLocalizedString("find_pwd_confirm_placeholder", comment: ""), text: $confirmPassword)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: PFRadius.md)
                        .fill(PFColors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PFRadius.md)
                        .stroke(PFColors.primary.opacity(0.3), lineWidth: 1)
                )
            }
            
            // 重新发送验证码
            Button {
                sendCode()
            } label: {
                Text(countdown > 0
                     ? String(format: NSLocalizedString("find_pwd_resend_countdown", comment: ""), countdown)
                     : NSLocalizedString("find_pwd_resend", comment: ""))
                    .font(PFFonts.caption)
                    .foregroundColor(countdown > 0 ? PFColors.textTertiary : PFColors.primary)
            }
            .disabled(countdown > 0)
            
            // 提交重置（验证码+密码统一验证）
            Button {
                resetPassword()
            } label: {
                HStack {
                    if loading {
                        PFPetLoadingInline(size: 14)
                    }
                    Text("find_pwd_reset_button")
                        .font(PFFonts.body.bold())
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: PFRadius.md)
                        .fill(canReset ? PFColors.primary : PFColors.primary.opacity(0.4))
                )
                .foregroundColor(.white)
            }
            .disabled(!canReset)
        }
    }
    
    // MARK: - Computed
    
    private var canSend: Bool {
        !loading && countdown == 0 && email.contains("@") && email.contains(".")
    }
    
    private var canReset: Bool {
        !loading && verifyCode.count == 6 && newPassword.count >= 6 && newPassword == confirmPassword
    }
    
    /// 验证码输入框描边色：验证反馈优先（绿/红），否则主色
    private var strokeColor: Color {
        switch codeFeedback {
        case .success: return Color(hex: "34D399")
        case .error: return Color(hex: "F87171")
        case .idle: return PFColors.primary.opacity(0.3)
        }
    }
    
    // MARK: - Actions
    
    private func sendCode() {
        guard canSend else { return }
        loading = true
        successMsg = ""
        
        Task {
            do {
                try await AuthService.shared.sendResetCode(email: email)
                await MainActor.run {
                    loading = false
                    successMsg = NSLocalizedString("find_pwd_code_sent", comment: "")
                    startCountdown()
                    if currentStep == 0 {
                        withAnimation { currentStep = 1 }
                    }
                }
            } catch {
                await MainActor.run {
                    loading = false
                    UIState.shared.showToast(error.localizedDescription, style: .error)
                }
            }
        }
    }
    
    private func resetPassword() {
        guard canReset else { return }
        loading = true
        successMsg = ""
        
        Task {
            do {
                try await AuthService.shared.resetPassword(
                    email: email,
                    code: verifyCode,
                    newPassword: newPassword)
                // 验证通过：绿描边反馈
                codeFeedback = .success
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run {
                    loading = false
                    successMsg = NSLocalizedString("find_pwd_success", comment: "")
                    Haptics.notify(.success)
                    // 2 秒后自动关闭
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                }
            } catch {
                // 验证失败：红描边反馈 → 0.5s 后清空验证码
                codeFeedback = .error
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run {
                    loading = false
                    UIState.shared.showToast(error.localizedDescription, style: .error)
                    verifyCode = ""
                    codeFeedback = .idle
                }
            }
        }
    }
    
    private func startCountdown() {
        countdown = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            if countdown > 0 {
                countdown -= 1
            } else {
                t.invalidate()
            }
        }
    }
}
