import SwiftUI

/// 验证反馈状态：用于输入框/掩码位的绿红描边提示
enum VerifyFeedback: Equatable {
    case idle
    case success
    case error
}

struct PaymentPasswordState: Equatable {
    var password = ""
    var isSubmitting = false
    var errorMessage: String?
    /// 验证反馈：idle=无，success=通过（绿描边），error=错误（红描边）
    var feedback: VerifyFeedback = .idle

    var canConfirm: Bool { password.count == 6 && !isSubmitting }

    mutating func append(_ character: Character) {
        guard !isSubmitting, password.count < 6, character.isASCII, character.isNumber else { return }
        password.append(character)
        errorMessage = nil
        // 输入新位时清除之前的反馈状态
        feedback = .idle
    }

    mutating func delete() {
        guard !isSubmitting, !password.isEmpty else { return }
        password.removeLast()
        errorMessage = nil
        feedback = .idle
    }

    mutating func beginSubmission() {
        guard password.count == 6, !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        feedback = .idle
    }

    /// 验证失败后：显示红描边反馈（延迟清空由外层处理）
    mutating func markError() {
        isSubmitting = false
        feedback = .error
        errorMessage = nil
    }

    /// 验证通过：显示绿描边反馈（延迟关闭由外层处理）
    mutating func markSuccess() {
        isSubmitting = false
        feedback = .success
    }

    /// 延迟结束后：清空密码、恢复可输入
    mutating func clearAfterFeedback() {
        password = ""
        isSubmitting = false
        feedback = .idle
        errorMessage = nil
    }
}

enum WalletOperation: Equatable { case recharge, withdraw }
enum WalletAmountValidation: Equatable { case invalid, exceedsBalance, valid(Double) }

enum WalletAmountValidator {
    static func validate(_ text: String, balance: Double, operation: WalletOperation) -> WalletAmountValidation {
        guard let amount = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)), amount > 0, amount.isFinite else { return .invalid }
        if operation == .withdraw && amount > balance { return .exceedsBalance }
        return .valid(amount)
    }
}

struct PayPasswordRequest: Equatable {
    let path: String
    let parameters: [String: String]
}

struct PayPasswordFormState {
    let hasPassword: Bool
    func request(old: String, new: String) -> PayPasswordRequest {
        hasPassword
            ? PayPasswordRequest(path: "/petFriendly/client/pay-password/reset", parameters: ["oldPassword": old, "newPassword": new])
            : PayPasswordRequest(path: "/petFriendly/client/pay-password/set", parameters: ["newPassword": new])
    }
}

enum AccountSessionEvent { case loginStarted, loginSucceeded, loginFailed, logoutStarted, logoutSucceeded, logoutFailed, tokenExpired }
enum AccountSessionState: Equatable {
    case signedOut, authenticating, authenticated, signingOut
    mutating func reduce(_ event: AccountSessionEvent) {
        switch event {
        case .loginStarted: self = .authenticating
        case .loginSucceeded: self = .authenticated
        case .loginFailed, .logoutSucceeded, .logoutFailed, .tokenExpired: self = .signedOut
        case .logoutStarted: self = .signingOut
        }
    }
}

/// 统一支付密码输入组件。
/// 适用场景：专车预约、上门服务等预订下单、钱包提现/充值 等需要校验支付密码的地方。
/// 特性：数字键盘输入、密码掩码显示、输入框聚焦状态、错误提示、提交加载态。
struct PaymentPasswordGate: View {
    /// 回调失败但错误已由网络层全局展示时的内部标记，仍保留输入错误状态而不重复弹 Toast。
    static let globallyPresentedError = "\u{0}"
    let title: LocalizedStringKey
    let amount: Double
    let onCancel: () -> Void
    let onConfirm: (String) async -> String?

    /// 聚焦/正在输入的密码框下标（用于高亮当前输入位，输入满 6 位后无聚焦位）
    private var focusedIndex: Int? {
        guard !state.isSubmitting, state.password.count < 6 else { return nil }
        return state.password.count
    }

    @State private var state = PaymentPasswordState()

    private let keys: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "delete.left"]]

    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            VStack(spacing: 24) {
                HStack {
                    Button("common_cancel", action: onCancel).disabled(state.isSubmitting)
                    Spacer()
                    Text(title).font(PFFonts.headline)
                    Spacer()
                    Color.clear.frame(width: 50, height: 1)
                }
                // amount > 0 时展示金额；金额为 0（如无固定定价的服务下单）则隐藏金额行
                if amount > 0 {
                    Text(String(format: "¥ %.2f", amount)).font(.system(size: 32, weight: .bold, design: .rounded))
                }
                HStack(spacing: 16) {
                    ForEach(0..<6, id: \.self) { index in
                        // 密码掩码位 + 聚焦位高亮 + 验证反馈描边（通过=绿，错误=红）
                        Circle()
                            .fill(index < state.password.count ? PFColors.textPrimary : PFColors.divider)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle()
                                    .stroke(feedbackStrokeColor, lineWidth: 1.5)
                                    .opacity(feedbackStrokeOpacity(for: index))
                            )
                            .scaleEffect(feedbackScale(for: index))
                            .animation(.easeInOut(duration: 0.2), value: focusedIndex)
                            .animation(.easeInOut(duration: 0.25), value: state.feedback)
                    }
                }
                // 错误提示统一走全局 ToastView，不再内联红字显示到 UI
                Spacer()
                VStack(spacing: 10) {
                    ForEach(keys.indices, id: \.self) { row in
                        HStack(spacing: 10) {
                            ForEach(keys[row], id: \.self) { key in keypadButton(key) }
                        }
                    }
                }
                Button(action: submit) {
                    HStack {
                        if state.isSubmitting { ProgressView().tint(.white) }
                        Text(state.isSubmitting ? "loading" : "confirm").fontWeight(.semibold)
                    }.frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!state.canConfirm)
            }
            .padding(24)
        }
        .interactiveDismissDisabled(state.isSubmitting)
    }

    @ViewBuilder private func keypadButton(_ key: String) -> some View {
        if key.isEmpty {
            Color.clear.frame(maxWidth: .infinity, minHeight: 56)
        } else {
            Button {
                // 点击数字键/删除键时给予轻微震动反馈
                Haptics.play(key == "delete.left" ? .medium : .light, intensity: 0.6)
                if key == "delete.left" {
                    state.delete()
                } else if let digit = key.first {
                    state.append(digit)
                    // 输入满 6 位自动触发提交验证（无需点确认按钮）
                    if state.canConfirm {
                        submit()
                    }
                }
            } label: {
                Group {
                    if key == "delete.left" { Image(systemName: key) }
                    else { Text(key).font(.title2.weight(.semibold)) }
                }.frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.bordered)
            .disabled(state.isSubmitting)
        }
    }

    private func submit() {
        guard state.canConfirm else { return }
        let password = state.password
        state.beginSubmission()
        Task {
            if let message = await onConfirm(password) {
                // 验证失败：红描边反馈 → 0.5s 后清空，Toast 提示
                state.markError()
                if message != Self.globallyPresentedError {
                    UIState.shared.showToast(message, style: .error)
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
                state.clearAfterFeedback()
            } else {
                // 验证通过：绿描边反馈 → 0.5s 后关闭弹窗（进入下一步操作）
                state.markSuccess()
                try? await Task.sleep(nanoseconds: 500_000_000)
                onCancel()
            }
        }
    }

    // MARK: - 验证反馈样式（通过=绿，错误=红）

    /// 反馈描边颜色：success 用主题绿，error 用红色；idle 用主色
    private var feedbackStrokeColor: Color {
        switch state.feedback {
        case .success: return Color(hex: "34D399")
        case .error: return Color(hex: "F87171")
        case .idle: return PFColors.primary
        }
    }

    /// 描边透明度：focus 位或反馈态显示；idle 且非 focus 位隐藏
    private func feedbackStrokeOpacity(for index: Int) -> Double {
        switch state.feedback {
        case .success, .error: return 1
        case .idle: return focusedIndex == index ? 1 : 0
        }
    }

    /// 缩放：反馈态所有位放大提示，idle 仅聚焦位放大
    private func feedbackScale(for index: Int) -> CGFloat {
        switch state.feedback {
        case .success, .error: return 1.15
        case .idle: return focusedIndex == index ? 1.15 : 1.0
        }
    }
}
