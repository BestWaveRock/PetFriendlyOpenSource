//
//  TelegramBindView.swift
//  PetFriendly
//
//  Telegram 绑定页面 — 支持 Bot→App 和 App→Bot 两种绑定模式
//

import SwiftUI

// MARK: - 数据模型

private struct BindStatusResp: Decodable {
    let code: Int
    let data: BindStatusData?
}

private struct BindStatusData: Decodable {
    let bound: Bool
    let chatId: Int64?
    let botUsername: String?
}

private struct RequestCodeResp: Decodable {
    let code: Int
    let data: RequestCodeData?
}

private struct RequestCodeData: Decodable {
    let code: String
    let expireIn: Int
    let hint: String?
}

private struct ConfirmCodeResp: Decodable {
    let code: Int
    let msg: String?
}

private struct UnbindResp: Decodable {
    let code: Int
    let msg: String?
}

// MARK: - 绑定模式

private enum BindMode: String, CaseIterable {
    case botToApp
    case appToBot

    var titleKey: String {
        switch self {
        case .botToApp: return "tg_bind_mode_bot_to_app"
        case .appToBot: return "tg_bind_mode_app_to_bot"
        }
    }

    var descriptionKey: String {
        switch self {
        case .botToApp: return "tg_bind_mode_bot_to_app_desc"
        case .appToBot: return "tg_bind_mode_app_to_bot_desc"
        }
    }
}

// MARK: - 主视图

struct TelegramBindView: View {
    @Environment(\.dismiss) var dismiss

    // 绑定状态
    @State private var isLoading = true
    @State private var isBound = false
    @State private var chatId: Int64?
    @State private var botUsername: String?

    // 模式选择
    @State private var selectedMode: BindMode = .botToApp

    // Bot→App: 验证码输入
    @State private var verificationCode: String = ""
    @State private var isConfirmingCode = false

    // App→Bot: 授权码
    @State private var authCode: String?
    @State private var authExpireIn: Int = 60
    @State private var isRequestingCode = false
    @State private var isSubmittingAuth = false

    // 解绑
    @State private var showUnbindAlert = false
    @State private var isUnbinding = false

    // 通用
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccess = false
    @State private var successMessage: String?

    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()

            if isLoading {
                VStack(spacing: PFSpacing.lg) {
                    PFPetLoadingView(size: 48)
                    Text(LocalizedStringKey("common_loading"))
                        .font(PFFonts.body)
                        .foregroundColor(PFColors.textSecondary)
                }
            } else {
                ScrollView {
                    VStack(spacing: PFSpacing.xl) {
                        if isBound {
                            boundSection
                        } else {
                            modePickerSection
                            bindContentSection
                        }
                        Spacer(minLength: 50)
                    }
                    .padding(.vertical, PFSpacing.lg)
                }
            }
        }
        .navigationTitle(NSLocalizedString("tg_bind_title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await fetchBindStatus() }
        }
        .alert(LocalizedStringKey("common_error"), isPresented: $showError) {
            Button(LocalizedStringKey("common_confirm")) { }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(LocalizedStringKey("common_success"), isPresented: $showSuccess) {
            Button(LocalizedStringKey("common_confirm")) {
                Task { await fetchBindStatus() }
            }
        } message: {
            Text(successMessage ?? "")
        }
        .alert(LocalizedStringKey("tg_unbind_confirm_title"), isPresented: $showUnbindAlert) {
            Button(LocalizedStringKey("alert_cancel"), role: .cancel) { }
            Button(LocalizedStringKey("tg_unbind_confirm"), role: .destructive) {
                Task { await performUnbind() }
            }
        } message: {
            Text(LocalizedStringKey("tg_unbind_confirm_msg"))
        }
    }

    // MARK: - 已绑定视图

    private var boundSection: some View {
        VStack(spacing: PFSpacing.xxl) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(PFColors.success)

            Text(LocalizedStringKey("tg_bound_success"))
                .font(PFFonts.title2)
                .foregroundColor(PFColors.textPrimary)

            VStack(spacing: PFSpacing.sm) {
                if let username = botUsername, !username.isEmpty {
                    Label(username, systemImage: "paperplane.fill")
                        .font(PFFonts.body)
                        .foregroundColor(PFColors.textSecondary)
                }
                if let cid = chatId {
                    Text(String(format: NSLocalizedString("tg_chat_id_format", comment: ""), cid))
                        .font(PFFonts.caption)
                        .foregroundColor(PFColors.textTertiary)
                }
            }

            Spacer()

            Button(action: { showUnbindAlert = true }) {
                HStack {
                    if isUnbinding {
                        PFPetLoadingInline(size: 18)
                    } else {
                        Image(systemName: "link.badge.minus")
                    }
                    Text(LocalizedStringKey("tg_unbind_button"))
                }
                .font(PFFonts.headline)
                .foregroundColor(PFColors.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: PFRadius.md)
                        .fill(PFColors.surface)
                )
                .pfCardShadow()
            }
            .disabled(isUnbinding)
            .padding(.horizontal, PFSpacing.lg)
        }
        .padding(.vertical, PFSpacing.xxl)
    }

    // MARK: - 模式选择

    private var modePickerSection: some View {
        VStack(alignment: .leading, spacing: PFSpacing.sm) {
            Text(LocalizedStringKey("tg_select_mode"))
                .font(PFFonts.callout)
                .foregroundColor(PFColors.textSecondary)
                .padding(.horizontal, PFSpacing.xl)

            VStack(spacing: 0) {
                ForEach(BindMode.allCases, id: \.self) { mode in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedMode = mode
                        }
                    }) {
                        HStack(spacing: PFSpacing.md) {
                            Image(systemName: selectedMode == mode ? "circle.fill" : "circle")
                                .foregroundColor(selectedMode == mode ? PFColors.primary : PFColors.textTertiary)
                                .font(.system(size: 18))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(LocalizedStringKey(mode.titleKey))
                                    .font(PFFonts.body)
                                    .foregroundColor(PFColors.textPrimary)
                                Text(LocalizedStringKey(mode.descriptionKey))
                                    .font(PFFonts.caption)
                                    .foregroundColor(PFColors.textSecondary)
                            }

                            Spacer()
                        }
                        .padding(PFSpacing.lg)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    if mode != BindMode.allCases.last {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: PFRadius.md)
                    .fill(PFColors.surface)
            )
            .padding(.horizontal, PFSpacing.lg)
            .pfCardShadow()
        }
    }

    // MARK: - 绑定内容

    @ViewBuilder
    private var bindContentSection: some View {
        switch selectedMode {
        case .botToApp:
            botToAppView
        case .appToBot:
            appToBotView
        }

        // 底部提示信息
        VStack(spacing: PFSpacing.xs) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(PFColors.info)
            Text(LocalizedStringKey("tg_bot_username_hint"))
                .font(PFFonts.caption2)
                .foregroundColor(PFColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, PFSpacing.xxl)
        .padding(.top, PFSpacing.lg)
    }

    // MARK: - 模式A: Bot→App

    private var botToAppView: some View {
        VStack(alignment: .leading, spacing: PFSpacing.sm) {
            Text(LocalizedStringKey("tg_bind_mode_bot_to_app_title"))
                .font(PFFonts.callout)
                .foregroundColor(PFColors.textSecondary)
                .padding(.horizontal, PFSpacing.xl)

            VStack(spacing: 0) {
                // 说明
                Text(LocalizedStringKey("tg_bot_to_app_instruction"))
                    .font(PFFonts.body)
                    .foregroundColor(PFColors.textSecondary)
                    .padding(PFSpacing.lg)

                Divider().padding(.leading, PFSpacing.lg)

                // 验证码输入
                VStack(alignment: .leading, spacing: PFSpacing.sm) {
                    Text(LocalizedStringKey("tg_verification_code_label"))
                        .font(PFFonts.caption)
                        .foregroundColor(PFColors.textTertiary)
                        .padding(.horizontal, PFSpacing.lg)
                        .padding(.top, PFSpacing.sm)

                    TextField(NSLocalizedString("tg_verification_code_placeholder", comment: ""), text: $verificationCode)
                        .font(PFFonts.body)
                        .textFieldStyle(.plain)
                        .keyboardType(.numberPad)
                        .padding(.horizontal, PFSpacing.lg)
                        .padding(.vertical, PFSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: PFRadius.sm)
                                .stroke(PFColors.divider, lineWidth: 1)
                                .background(PFColors.surfaceSecondary.cornerRadius(PFRadius.sm))
                        )
                        .padding(.horizontal, PFSpacing.lg)
                }
                .padding(.bottom, PFSpacing.md)

                // 确认绑定按钮
                Button(action: {
                    Task { await performConfirmCode() }
                }) {
                    HStack {
                        if isConfirmingCode {
                            PFPetLoadingInline(size: 18)
                        } else {
                            Image(systemName: "link.badge.plus")
                        }
                        Text(LocalizedStringKey("tg_confirm_bind"))
                    }
                    .font(PFFonts.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: PFRadius.md)
                            .fill(verificationCode.count == 6 ? Color(.sRGB, red: 0.42, green: 0.39, blue: 1.0) : PFColors.textTertiary.opacity(0.3))
                    )
                    .padding(.horizontal, PFSpacing.lg)
                    .padding(.bottom, PFSpacing.lg)
                }
                .disabled(verificationCode.count != 6 || isConfirmingCode)
            }
            .background(
                RoundedRectangle(cornerRadius: PFRadius.md)
                    .fill(PFColors.surface)
            )
            .padding(.horizontal, PFSpacing.lg)
            .pfCardShadow()
        }
    }

    // MARK: - 模式B: App→Bot

    private var appToBotView: some View {
        VStack(alignment: .leading, spacing: PFSpacing.sm) {
            Text(LocalizedStringKey("tg_bind_mode_app_to_bot_title"))
                .font(PFFonts.callout)
                .foregroundColor(PFColors.textSecondary)
                .padding(.horizontal, PFSpacing.xl)

            VStack(spacing: 0) {
                if let code = authCode {
                    // 显示授权码
                    VStack(spacing: PFSpacing.md) {
                        Text(LocalizedStringKey("tg_auth_code_label"))
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.textTertiary)

                        Text(code)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(PFColors.primary)
                            .monospacedDigit()
                            .padding(.vertical, PFSpacing.sm)
                            .padding(.horizontal, PFSpacing.xl)
                            .background(
                                RoundedRectangle(cornerRadius: PFRadius.sm)
                                    .fill(PFColors.primary.opacity(0.08))
                            )

                        Text(LocalizedStringKey("tg_auth_code_instruction"))
                            .font(PFFonts.body)
                            .foregroundColor(PFColors.textSecondary)
                            .multilineTextAlignment(.center)

                        if let hint = getBotHint() {
                            Text(hint)
                                .font(PFFonts.caption)
                                .foregroundColor(PFColors.textTertiary)
                        }

                        // "已在TG中发码，提交绑定" 按钮
                        Button(action: {
                            Task { await performConfirmCodeWithAuthCode() }
                        }) {
                            HStack {
                                if isSubmittingAuth {
                                    PFPetLoadingInline(size: 18)
                                } else {
                                    Image(systemName: "checkmark.circle")
                                }
                                Text(LocalizedStringKey("tg_submit_bind"))
                            }
                            .font(PFFonts.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: PFRadius.md)
                                    .fill(PFGradients.brand)
                            )
                            .padding(.horizontal, PFSpacing.lg)
                        }
                        .disabled(isSubmittingAuth)
                    }
                    .padding(PFSpacing.lg)
                } else {
                    // 获取授权码按钮
                    VStack(spacing: PFSpacing.md) {
                        Text(LocalizedStringKey("tg_app_to_bot_instruction"))
                            .font(PFFonts.body)
                            .foregroundColor(PFColors.textSecondary)
                            .padding(.horizontal, PFSpacing.lg)
                            .padding(.top, PFSpacing.lg)
                            .multilineTextAlignment(.center)

                        Button(action: {
                            Task { await performRequestCode() }
                        }) {
                            HStack {
                                if isRequestingCode {
                                    PFPetLoadingInline(size: 18)
                                } else {
                                    Image(systemName: "arrow.right.doc.on.clipboard")
                                }
                                Text(LocalizedStringKey("tg_get_auth_code"))
                            }
                            .font(PFFonts.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: PFRadius.md)
                                    .fill(PFGradients.brand)
                            )
                            .padding(.horizontal, PFSpacing.lg)
                        }
                        .disabled(isRequestingCode)

                        Text(LocalizedStringKey("tg_get_auth_code_hint"))
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.textTertiary)
                            .padding(.horizontal, PFSpacing.lg)
                            .padding(.bottom, PFSpacing.lg)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: PFRadius.md)
                    .fill(PFColors.surface)
            )
            .padding(.horizontal, PFSpacing.lg)
            .pfCardShadow()
        }
    }

    // MARK: - API 调用

    private func fetchBindStatus() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let resp: BindStatusResp = try await NetworkManager.shared.request(
                "/petFriendly/telegram/bind/status",
                method: .get,
                needToken: true,
                showLoading: false
            )
            await MainActor.run {
                if let data = resp.data {
                    isBound = data.bound
                    chatId = data.chatId
                    botUsername = data.botUsername
                }
            }
        } catch {
            // 静默失败，视作未绑定
            await MainActor.run {
                isBound = false
            }
        }
    }

    private func performRequestCode() async {
        isRequestingCode = true
        defer { isRequestingCode = false }

        do {
            let resp: RequestCodeResp = try await NetworkManager.shared.request(
                "/petFriendly/telegram/bind/requestCode",
                method: .post,
                needToken: true,
                showLoading: false
            )
            await MainActor.run {
                if let data = resp.data {
                    authCode = data.code
                    authExpireIn = data.expireIn
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func performConfirmCode() async {
        guard verificationCode.count == 6 else { return }
        isConfirmingCode = true
        defer { isConfirmingCode = false }

        do {
            let resp: ConfirmCodeResp = try await NetworkManager.shared.request(
                "/petFriendly/telegram/bind/confirmCode",
                method: .post,
                parameters: ["code": verificationCode],
                needToken: true,
                showLoading: false
            )
            await MainActor.run {
                successMessage = resp.msg ?? NSLocalizedString("tg_bind_success", comment: "")
                showSuccess = true
                verificationCode = ""
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func performConfirmCodeWithAuthCode() async {
        guard let code = authCode else { return }
        isSubmittingAuth = true
        defer { isSubmittingAuth = false }

        do {
            let resp: ConfirmCodeResp = try await NetworkManager.shared.request(
                "/petFriendly/telegram/bind/confirmCode",
                method: .post,
                parameters: ["code": code],
                needToken: true,
                showLoading: false
            )
            await MainActor.run {
                successMessage = resp.msg ?? NSLocalizedString("tg_bind_success", comment: "")
                showSuccess = true
                authCode = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func performUnbind() async {
        isUnbinding = true
        defer { isUnbinding = false }

        do {
            let resp: UnbindResp = try await NetworkManager.shared.request(
                "/petFriendly/telegram/bind/unbind",
                method: .post,
                needToken: true,
                showLoading: false
            )
            await MainActor.run {
                successMessage = resp.msg ?? NSLocalizedString("tg_unbind_success", comment: "")
                showSuccess = true
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func getBotHint() -> String? {
        guard let username = botUsername, !username.isEmpty else { return nil }
        return String(format: NSLocalizedString("tg_bot_code_hint", comment: ""), username)
    }
}
