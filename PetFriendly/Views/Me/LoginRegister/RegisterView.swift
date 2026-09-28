import SwiftUI

/// 邮箱验证注册流程。接口与业务步骤保持不变，界面统一为原生 iOS 表单体验。
struct RegisterView: View {
    @EnvironmentObject private var store: AccountStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @State private var step = 1
    @State private var email = ""
    @State private var code = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPwd = ""
    @State private var isLoading = false
    @State private var errorMsg = ""
    @State private var countdown = 0
    @State private var showSuccessAlert = false
    @State private var acceptedLegalTerms = false
    @State private var presentedLegalDocument: LegalDocument?
    @State private var codeFeedback: VerifyFeedback = .idle
    @State private var revealPassword = false
    @State private var attemptedSubmission = false

    private let codeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private enum Field: Hashable {
        case email, code, username, password, confirmation
    }

    var body: some View {
        NavigationStack {
            ZStack {
                registrationBackground

                ScrollView {
                    VStack(spacing: PFSpacing.xxl) {
                        progressHeader
                        hero

                        Group {
                            if step == 1 {
                                emailForm
                                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
                            } else {
                                accountForm
                                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                            }
                        }
                    }
                    .padding(.horizontal, PFSpacing.xl)
                    .padding(.top, PFSpacing.md)
                    .padding(.bottom, 126)
                }
            }
            .safeAreaInset(edge: .bottom) { bottomAction }
            .navigationTitle("reg_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(navActionTitle) {
                        if step == 1 {
                            dismiss()
                        } else {
                            withAnimation(PFAnimation.springGentle) {
                                step = 1
                                errorMsg = ""
                                attemptedSubmission = false
                            }
                            focusedField = .email
                        }
                    }
                }
            }
            .alert("reg_success_title", isPresented: $showSuccessAlert) {
                Button("settings_confirm") { dismiss() }
            } message: {
                Text("reg_success_msg")
            }
            .onReceive(codeTimer) { _ in
                if countdown > 0 { countdown -= 1 }
            }
            .sheet(item: $presentedLegalDocument) { document in
                NavigationStack { LegalDocumentView(document: document) }
            }
            .animation(PFAnimation.ease, value: errorMsg)
            .animation(PFAnimation.ease, value: canProceed)
        }
    }

    private var registrationBackground: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            Circle()
                .fill(PFColors.primary.opacity(0.12))
                .frame(width: 250, height: 250)
                .blur(radius: 8)
                .offset(x: 150, y: -260)
            Circle()
                .fill(PFColors.accent.opacity(0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 12)
                .offset(x: -170, y: 290)
        }
        .allowsHitTesting(false)
    }

    private var progressHeader: some View {
        VStack(spacing: PFSpacing.sm) {
            HStack {
                Text(String(format: NSLocalizedString("reg_progress_format", comment: ""), step, 2))
                    .font(PFFonts.caption2)
                    .foregroundColor(PFColors.textSecondary)
                Spacer()
                Text(step == 1 ? "reg_step_email" : "reg_step_code")
                    .font(PFFonts.caption2)
                    .foregroundColor(PFColors.primary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(PFColors.primary.opacity(0.12))
                    Capsule()
                        .fill(PFGradients.brandHorizontal)
                        .frame(width: proxy.size.width * CGFloat(step) / 2)
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .combine)
    }

    private var hero: some View {
        VStack(spacing: PFSpacing.md) {
            ZStack {
                Circle()
                    .fill(PFGradients.brand)
                    .frame(width: 72, height: 72)
                    .shadow(color: PFColors.primary.opacity(0.22), radius: 16, y: 8)
                Image(systemName: step == 1 ? "envelope.badge.fill" : "person.crop.circle.badge.checkmark")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: PFSpacing.sm) {
                Text(heroTitle)
                    .font(PFFonts.largeTitle)
                    .foregroundColor(PFColors.textPrimary)
                    .multilineTextAlignment(.center)
                Text(step == 1
                     ? NSLocalizedString("reg_email_desc", comment: "")
                     : String(format: NSLocalizedString("reg_combined_desc", comment: ""), email))
                    .font(PFFonts.body)
                    .foregroundColor(PFColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var emailForm: some View {
        formCard {
            fieldLabel("reg_email_field_label")
            inputContainer(icon: "envelope") {
                TextField("reg_email_placeholder", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.continue)
                    .onSubmit(handleStepAction)
                    .onChange(of: email) { value in
                        email = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        errorMsg = ""
                    }
            }

            if attemptedSubmission && !isEmailValid {
                validationLine("reg_email_invalid", icon: "exclamationmark.circle.fill", color: PFColors.danger)
            } else {
                validationLine("reg_email_privacy_hint", icon: "lock.shield.fill", color: PFColors.textSecondary)
            }
        }
    }

    private var accountForm: some View {
        VStack(spacing: PFSpacing.lg) {
            formCard {
                HStack {
                    fieldLabel("reg_code_field_label")
                    Spacer()
                    Button(action: resendCode) {
                        Text(countdown > 0
                             ? String(format: NSLocalizedString("reg_resend_countdown", comment: ""), countdown)
                             : NSLocalizedString("reg_resend", comment: ""))
                            .font(PFFonts.caption2)
                            .foregroundColor(countdown > 0 ? PFColors.textTertiary : PFColors.primary)
                    }
                    .disabled(countdown > 0 || isLoading)
                }

                inputContainer(icon: "number", feedback: codeFeedback) {
                    TextField("reg_code_placeholder", text: $code)
                        .textContentType(.oneTimeCode)
                        .keyboardType(.numberPad)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .focused($focusedField, equals: .code)
                        .onChange(of: code) { value in
                            let digits = value.filter(\.isNumber)
                            code = String(digits.prefix(6))
                            if codeFeedback != .idle, code.count < 6 { codeFeedback = .idle }
                            errorMsg = ""
                        }
                }
                validationLine("reg_code_hint", icon: "clock", color: PFColors.textSecondary)
            }

            formCard {
                fieldLabel("reg_account_details_label")

                inputContainer(icon: "person") {
                    TextField("reg_username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .username)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        .onChange(of: username) { _ in errorMsg = "" }
                }

                inputContainer(icon: "lock") {
                    Group {
                        if revealPassword {
                            TextField("reg_password", text: $password)
                        } else {
                            SecureField("reg_password", text: $password)
                        }
                    }
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .confirmation }
                    .onChange(of: password) { _ in errorMsg = "" }

                    revealPasswordButton
                }

                inputContainer(icon: "lock.rotation") {
                    Group {
                        if revealPassword {
                            TextField("reg_confirm_pwd", text: $confirmPwd)
                        } else {
                            SecureField("reg_confirm_pwd", text: $confirmPwd)
                        }
                    }
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .confirmation)
                    .submitLabel(.done)
                    .onSubmit(handleStepAction)
                    .onChange(of: confirmPwd) { _ in errorMsg = "" }
                }

                HStack(spacing: PFSpacing.lg) {
                    validationLine("reg_password_requirement", icon: password.count >= 6 ? "checkmark.circle.fill" : "circle", color: password.count >= 6 ? PFColors.success : PFColors.textTertiary)
                    validationLine(passwordsMatch ? "reg_password_match" : "reg_password_mismatch", icon: passwordsMatch ? "checkmark.circle.fill" : "circle", color: passwordsMatch ? PFColors.success : PFColors.textTertiary)
                }
            }

            legalConsentCard
        }
    }

    private var legalConsentCard: some View {
        VStack(alignment: .leading, spacing: PFSpacing.md) {
            Button {
                acceptedLegalTerms.toggle()
                errorMsg = ""
            } label: {
                HStack(alignment: .top, spacing: PFSpacing.md) {
                    Image(systemName: acceptedLegalTerms ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(acceptedLegalTerms ? PFColors.primary : PFColors.textTertiary)
                    Text(String(format: NSLocalizedString("legal_consent_version_format", comment: ""), LegalDocument.version))
                        .font(PFFonts.callout)
                        .foregroundColor(PFColors.textPrimary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), alignment: .leading)], alignment: .leading, spacing: PFSpacing.sm) {
                legalDocumentButtons
            }
            .padding(.leading, 34)

            if attemptedSubmission && !acceptedLegalTerms {
                validationLine("reg_legal_required", icon: "exclamationmark.circle.fill", color: PFColors.danger)
                    .padding(.leading, 34)
            }
        }
        .padding(PFSpacing.lg)
        .background(RoundedRectangle(cornerRadius: PFRadius.lg).fill(PFColors.surface))
        .overlay(RoundedRectangle(cornerRadius: PFRadius.lg).stroke(acceptedLegalTerms ? PFColors.primary.opacity(0.35) : PFColors.divider, lineWidth: 1))
    }

    @ViewBuilder private var legalDocumentButtons: some View {
        legalButton("legal_privacy_short", document: .privacy)
        legalButton("legal_terms_short", document: .terms)
        legalButton("legal_community_short", document: .community)
        legalButton("legal_ai_rules_short", document: .ai)
    }

    private func legalButton(_ title: LocalizedStringKey, document: LegalDocument) -> some View {
        Button(title) { presentedLegalDocument = document }
            .font(PFFonts.caption2)
            .foregroundColor(PFColors.primary)
            .buttonStyle(.plain)
    }

    private var bottomAction: some View {
        VStack(spacing: PFSpacing.sm) {
            if !errorMsg.isEmpty {
                HStack(alignment: .top, spacing: PFSpacing.sm) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(errorMsg).fixedSize(horizontal: false, vertical: true)
                }
                .font(PFFonts.caption)
                .foregroundColor(PFColors.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Button(action: handleStepAction) {
                HStack(spacing: PFSpacing.sm) {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(primaryActionTitle)
                        Image(systemName: step == 1 ? "arrow.right" : "checkmark")
                    }
                }
                .font(PFFonts.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .foregroundColor(.white)
                .background(canProceed ? AnyShapeStyle(PFGradients.brandHorizontal) : AnyShapeStyle(Color.gray.opacity(0.35)))
                .clipShape(RoundedRectangle(cornerRadius: PFRadius.lg))
                .shadow(color: canProceed ? PFColors.primary.opacity(0.22) : .clear, radius: 12, y: 6)
            }
            .disabled(isLoading)
        }
        .padding(.horizontal, PFSpacing.xl)
        .padding(.top, PFSpacing.md)
        .padding(.bottom, PFSpacing.sm)
        .background(.ultraThinMaterial)
    }

    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: PFSpacing.md, content: content)
            .padding(PFSpacing.lg)
            .background(RoundedRectangle(cornerRadius: PFRadius.xl).fill(PFColors.surface))
            .overlay(RoundedRectangle(cornerRadius: PFRadius.xl).stroke(PFColors.divider, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.05), radius: 18, y: 8)
    }

    private func fieldLabel(_ key: LocalizedStringKey) -> some View {
        Text(key).font(PFFonts.subheadline).foregroundColor(PFColors.textPrimary)
    }

    private func inputContainer<Content: View>(icon: String, feedback: VerifyFeedback = .idle, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: PFSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(PFColors.primary)
                .frame(width: 22)
            content()
                .font(PFFonts.body)
                .foregroundColor(PFColors.textPrimary)
        }
        .padding(.horizontal, PFSpacing.md)
        .frame(minHeight: 52)
        .background(RoundedRectangle(cornerRadius: PFRadius.md).fill(PFColors.surfaceSecondary))
        .overlay(RoundedRectangle(cornerRadius: PFRadius.md).stroke(feedbackColor(feedback), lineWidth: feedback == .idle ? 0 : 1.5))
    }

    private var revealPasswordButton: some View {
        Button { revealPassword.toggle() } label: {
            Image(systemName: revealPassword ? "eye.slash" : "eye")
                .foregroundColor(PFColors.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(revealPassword ? "reg_hide_password" : "reg_show_password"))
    }

    private func validationLine(_ key: LocalizedStringKey, icon: String, color: Color) -> some View {
        Label(key, systemImage: icon)
            .font(PFFonts.caption)
            .foregroundColor(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func feedbackColor(_ feedback: VerifyFeedback) -> Color {
        switch feedback {
        case .success: return PFColors.success
        case .error: return PFColors.danger
        case .idle: return .clear
        }
    }

    private var isEmailValid: Bool {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".")
    }

    private var passwordsMatch: Bool {
        !confirmPwd.isEmpty && password == confirmPwd
    }

    private var navActionTitle: LocalizedStringKey {
        step == 1 ? "common_cancel" : "common_back"
    }

    private var heroTitle: LocalizedStringKey {
        step == 1 ? "reg_email_title" : "reg_profile_title"
    }

    private var primaryActionTitle: LocalizedStringKey {
        step == 1 ? "reg_send_code" : "reg_button"
    }

    private var canProceed: Bool {
        switch step {
        case 1:
            return isEmailValid
        case 2:
            return code.count == 6
                && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && password.count >= 6
                && passwordsMatch
                && acceptedLegalTerms
        default:
            return false
        }
    }

    private func handleStepAction() {
        attemptedSubmission = true
        errorMsg = ""
        guard canProceed else { return }
        focusedField = nil
        step == 1 ? sendCode() : submitRegister()
    }

    private func sendCode() {
        isLoading = true
        Task {
            do {
                try await AuthService.shared.registerSendCode(email: email)
                await MainActor.run {
                    isLoading = false
                    attemptedSubmission = false
                    withAnimation(PFAnimation.springGentle) { step = 2 }
                    countdown = 60
                    focusedField = .code
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMsg = localizedRegistrationError(error, fallbackKey: "reg_send_code_failed")
                }
            }
        }
    }

    private func resendCode() {
        guard !email.isEmpty, countdown == 0 else { return }
        errorMsg = ""
        Task {
            do {
                try await AuthService.shared.registerSendCode(email: email)
                await MainActor.run { countdown = 60 }
            } catch {
                await MainActor.run {
                    errorMsg = localizedRegistrationError(error, fallbackKey: "reg_send_code_failed")
                }
            }
        }
    }

    private func submitRegister() {
        isLoading = true
        Task {
            do {
                try await AuthService.shared.registerByEmail(
                    email: email,
                    code: code,
                    username: username,
                    password: password,
                    legalVersion: LegalDocument.version
                )
                await MainActor.run { codeFeedback = .success }
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run {
                    isLoading = false
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run { codeFeedback = .error }
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run {
                    isLoading = false
                    errorMsg = localizedRegistrationError(error, fallbackKey: "reg_register_failed")
                    code = ""
                    codeFeedback = .idle
                    focusedField = .code
                }
            }
        }
    }

    /// 后端业务消息目前可能是中文；英文环境使用客户端文案，避免混合语言。
    private func localizedRegistrationError(_ error: Error, fallbackKey: String) -> String {
        let nsError = error as NSError
        let language = Bundle.main.preferredLocalizations.first ?? Locale.current.identifier
        let serverMessage = nsError.domain.trimmingCharacters(in: .whitespacesAndNewlines)
        let containsChineseBusinessText = serverMessage.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
        }
        if language.hasPrefix("zh"), containsChineseBusinessText {
            return serverMessage
        }
        return NSLocalizedString(fallbackKey, comment: "")
    }
}
