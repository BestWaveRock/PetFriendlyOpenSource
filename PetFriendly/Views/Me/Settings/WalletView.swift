//
//  WalletView.swift
//  PetFriendly
//
//  我的钱包：余额 / 充值 / 提现 / 账单明细 / 支付密码入口
//  1.1.0 后端接口：GET /wallet/balance、POST /wallet/recharge、POST /wallet/withdraw、GET /wallet/bill
//

import SwiftUI
import Alamofire

private func localizedWalletAPIMessage(_ message: String?, fallbackKey: String) -> String {
    let language = Bundle.main.preferredLocalizations.first ?? Locale.current.identifier
    let value = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if language.hasPrefix("zh"), !value.isEmpty { return value }
    let lower = value.lowercased()
    if value.contains("支付密码错误") || lower.contains("incorrect pay") || lower.contains("wrong pay") {
        return NSLocalizedString("pay_pwd_wrong", comment: "")
    }
    if value.contains("未设置支付密码") || value.contains("请先设置支付密码") || lower.contains("pay password not set") {
        return NSLocalizedString("pay_password_not_set_msg", comment: "")
    }
    return NSLocalizedString(fallbackKey, comment: "")
}

// MARK: - 模型

struct WalletBalanceResp: Decodable {
    let code: Int
    let msg: String?
    @StringCodedOptionalDouble var data: Double?
}

struct WalletBillResp: Decodable {
    let code: Int
    let msg: String?
    let total: Int?
    let rows: [WalletBillRow]?
}

struct WalletBillRow: Identifiable, Decodable {
    @Int64String var walletRecordId: Int64?
    var id: String { walletRecordId.map(String.init) ?? UUID().uuidString }

    @Int64String var userId: Int64?
    let accountType: Int?    // 1=积分 2=爱心 3=余额
    let changeType: Int?     // 1=收入 2=支出
    @StringCodedOptionalDouble var amount: Double?
    @StringCodedOptionalDouble var beforeValue: Double?
    @StringCodedOptionalDouble var afterValue: Double?
    let bizType: Int?        // 1签到 2补签 3充值 4消费 5退款 6提现 7证件图 8商品兑换 9平台调整 10售后赔付
    @Int64String var bizId: Int64?
    let remark: String?
    @SafeDateString var createTime: String?

    /// 账户类型展示文案（优先字典渲染，fallback 硬编码）
    var accountTypeText: String {
        let fallback: String
        switch accountType {
        case 1: fallback = NSLocalizedString("wallet_account_points", comment: "")
        case 2: fallback = NSLocalizedString("wallet_account_love", comment: "")
        default: fallback = NSLocalizedString("wallet_account_balance", comment: "")
        }
        guard let accountType else { return fallback }
        return DictLabelStore.shared.text(forDictType: "pet_wallet_account_type",
                                          value: "\(accountType)", fallback: fallback)
    }

    @MainActor
    var accountTypeColor: Color {
        switch accountType {
        case 1: return PFColors.warning
        case 2: return PFColors.accent
        case 3: return PFColors.success
        default: return PFColors.textSecondary
        }
    }

    /// 业务类型文案（1签到 2补签 3充值 4消费 5退款 6提现 7证件图 8商品兑换 9平台调整 10售后赔付 11新版本彩蛋奖励）
    var bizTypeText: String {
        let fallback: String
        switch bizType {
        case 1: fallback = NSLocalizedString("wallet_biz_1", comment: "")
        case 2: fallback = NSLocalizedString("wallet_biz_2", comment: "")
        case 3: fallback = NSLocalizedString("wallet_biz_3", comment: "")
        case 4: fallback = NSLocalizedString("wallet_biz_4", comment: "")
        case 5: fallback = NSLocalizedString("wallet_biz_5", comment: "")
        case 6: fallback = NSLocalizedString("wallet_biz_6", comment: "")
        case 7: fallback = NSLocalizedString("wallet_biz_7", comment: "")
        case 8: fallback = NSLocalizedString("wallet_biz_8", comment: "")
        case 9: fallback = NSLocalizedString("wallet_biz_9", comment: "")
        case 10: fallback = NSLocalizedString("wallet_biz_10", comment: "")
        case 11: fallback = NSLocalizedString("wallet_biz_11", comment: "")
        default: fallback = NSLocalizedString("common_unknown", comment: "")
        }
        guard let bizType else { return fallback }
        return DictLabelStore.shared.text(forDictType: "pet_wallet_biz_type",
                                          value: "\(bizType)", fallback: fallback)
    }

    /// 金额展示（含方向符号）
    var amountText: String {
        let val = amount ?? 0
        let sign = changeType == 1 ? "+" : "-"
        if val.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%@%d", sign, Int(val))
        }
        return String(format: "%@%.2f", sign, val)
    }

    var isIncome: Bool { changeType == 1 }
}

// MARK: - 视图模型

@MainActor
class WalletViewModel: ObservableObject {
    @Published var balance: Double = 0
    @Published var hasPayPassword = false
    @Published var bills: [WalletBillRow] = []
    @Published var isLoadingBills = false
    @Published var hasMoreBills = true

    private var pageNum = 1
    private let pageSize = 15

    func loadBalance() async {
        do {
            let resp: WalletBalanceResp = try await NetworkManager.shared.request(
                "/petFriendly/client/wallet/balance",
                method: .get,
                needToken: true,
                showLoading: false
            )
            if resp.code == 200 {
                balance = resp.data ?? 0
            } else {
                UIState.shared.showToast(localizedWalletAPIMessage(resp.msg, fallbackKey: "wallet_balance_load_failed"))
            }
        } catch {
            UIState.shared.showToast(NSLocalizedString("wallet_balance_load_failed", comment: ""))
        }
    }

    func checkPayPassword() async {
        do {
            let resp: RespWrapper<Bool> = try await NetworkManager.shared.request(
                "/petFriendly/client/pay-password/status", method: .get,
                needToken: true, showLoading: false)
            hasPayPassword = resp.code == 200 && (resp.data ?? false)
        } catch {
            hasPayPassword = false
        }
    }

    func loadBills(isRefresh: Bool = false) {
        if isRefresh {
            pageNum = 1
            hasMoreBills = true
            bills.removeAll()
        }
        guard hasMoreBills && !isLoadingBills else { return }
        isLoadingBills = true

        let params: [String: Any] = [
            "pageNum": pageNum,
            "pageSize": pageSize
        ]
        Task {
            do {
                let resp: WalletBillResp = try await NetworkManager.shared.request(
                    "/petFriendly/client/wallet/bill",
                    method: .get,
                    parameters: params,
                    needToken: true,
                    showLoading: false
                )
                await MainActor.run {
                    if resp.code == 200 {
                        let rows = resp.rows ?? []
                        self.bills.append(contentsOf: rows)
                        self.hasMoreBills = rows.count == self.pageSize
                        self.pageNum += 1
                    } else {
                        UIState.shared.showToast(localizedWalletAPIMessage(resp.msg, fallbackKey: "wallet_bill_load_failed"))
                    }
                    self.isLoadingBills = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingBills = false
                    UIState.shared.showToast(NSLocalizedString("wallet_bill_load_failed", comment: ""))
                }
            }
        }
    }
}

// MARK: - 视图

/// 支付密码弹窗配置：作为 fullScreenCover(item:) 的驱动项，
/// 将操作类型与金额作为参数直接传入弹窗内容，避免闭包捕获过期状态。
struct WalletPayConfig: Identifiable {
    let id = UUID()
    let operation: WalletOperation
    let amount: Double
}

struct WalletView: View {
    @StateObject private var vm = WalletViewModel()

    // 充值
    private let presets: [Double] = [50, 100, 200, 500]
    @State private var rechargeAmountText: String = "50"
    @State private var isRecharging = false

    // 提现
    @State private var withdrawAmountText: String = ""
    @State private var isWithdrawing = false
    @State private var showPayPasswordSetup = false
    // 支付密码弹窗配置：用 Identifiable item 驱动 fullScreenCover，
    // 避免 fullScreenCover(isPresented:) 闭包捕获过期的 pendingOperation/pendingAmount 导致标题/金额显示错误
    @State private var payConfig: WalletPayConfig?

    // 字典 label 提供者：账单行展示用字典渲染，加载完成自动刷新
    @StateObject private var dictLabelStore = DictLabelStore.shared

    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: PFSpacing.lg) {
                    balanceCard
                    rechargeSection
                    withdrawSection
                    billSection
                }
                .padding(PFSpacing.lg)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("wallet_title")
        .navigationBarTitleDisplayMode(.inline)
        .pfToyBackground()
        .trackScene("Wallet")
        .onAppear {
            Task {
                await vm.loadBalance()
                await vm.checkPayPassword()
            }
            if vm.bills.isEmpty {
                vm.loadBills(isRefresh: true)
            }
        }
        .fullScreenCover(item: $payConfig) { config in
            PaymentPasswordGate(
                title: config.operation == .recharge ? "wallet_recharge" : "wallet_section_withdraw",
                amount: config.amount,
                onCancel: { payConfig = nil },
                onConfirm: submitPendingOperation
            )
        }
        .sheet(isPresented: $showPayPasswordSetup, onDismiss: { Task { await vm.checkPayPassword() } }) {
            NavigationStack { PayPasswordSettingView() }
        }
    }

    // MARK: - 余额卡
    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: PFSpacing.md) {
            Text("wallet_balance")
                .font(PFFonts.callout)
                .foregroundColor(.white.opacity(0.85))

            Text("¥ " + String(format: "%.2f", vm.balance))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            HStack(spacing: 6) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 12))
                Text("wallet_balance_hint")
                    .font(PFFonts.caption)
                    .foregroundColor(.white.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PFSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: PFRadius.lg)
                .fill(LinearGradient(colors: [PFColors.success, PFColors.success.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .pfCardShadow()
    }


    // MARK: - 充值区
    private var rechargeSection: some View {
        VStack(alignment: .leading, spacing: PFSpacing.md) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(PFColors.warning)
                Text("wallet_section_recharge")
                    .font(PFFonts.headline)
                    .foregroundColor(PFColors.textPrimary)
            }

            Divider()

            // 预设金额
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(presets, id: \.self) { amount in
                    let isSelected = (Double(rechargeAmountText) ?? 0) == amount
                    Button(action: {
                        Haptics.play(.light)
                        rechargeAmountText = String(Int(amount))
                    }) {
                        Text("¥\(Int(amount))")
                            .font(PFFonts.callout)
                            .fontWeight(isSelected ? .bold : .regular)
                            .foregroundColor(isSelected ? .white : PFColors.warning)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: PFRadius.md)
                                    .fill(isSelected ? PFColors.warning : PFColors.warning.opacity(0.1))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // 自定义金额
            HStack(spacing: 8) {
                Text("¥")
                    .font(PFFonts.headline)
                    .foregroundColor(PFColors.textSecondary)
                TextField(NSLocalizedString("wallet_recharge_custom_placeholder", comment: ""), text: $rechargeAmountText)
                    .keyboardType(.decimalPad)
                    .font(PFFonts.body)
            }
            .padding(PFSpacing.md)
            .background(PFColors.surfaceSecondary)
            .cornerRadius(PFRadius.md)

            Button(action: submitRecharge) {
                HStack {
                    if isRecharging {
                        PFPetLoadingInline(size: 16)
                    }
                    Text("wallet_recharge")
                        .font(PFFonts.body)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(PFColors.warning)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
            }
            .disabled(isRecharging)
            .opacity(isRecharging ? 0.6 : 1)
        }
        .padding(PFSpacing.lg)
        .background(cardBackground)
    }

    // MARK: - 提现区
    private var withdrawSection: some View {
        VStack(alignment: .leading, spacing: PFSpacing.md) {
            HStack {
                Image(systemName: "arrow.up.right.circle.fill")
                    .foregroundColor(PFColors.danger)
                Text("wallet_section_withdraw")
                    .font(PFFonts.headline)
                    .foregroundColor(PFColors.textPrimary)
            }

            Divider()

            TextField(NSLocalizedString("wallet_withdraw_amount_placeholder", comment: ""), text: $withdrawAmountText)
                .keyboardType(.decimalPad)
                .font(PFFonts.body)
                .padding(PFSpacing.md)
                .background(PFColors.surfaceSecondary)
                .cornerRadius(PFRadius.md)


            Text("wallet_pay_password_hint")
                .font(PFFonts.caption)
                .foregroundColor(PFColors.textTertiary)

            Button(action: {
                presentPasswordGate(for: .withdraw)
            }) {
                HStack {
                    if isWithdrawing {
                        PFPetLoadingInline(size: 16)
                    }
                    Text("wallet_withdraw")
                        .font(PFFonts.body)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(PFColors.danger)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
            }
            .disabled(isWithdrawing)
            .opacity(isWithdrawing ? 0.6 : 1)
        }
        .padding(PFSpacing.lg)
        .background(cardBackground)
    }

    // MARK: - 账单列表
    private var billSection: some View {
        VStack(alignment: .leading, spacing: PFSpacing.md) {
            HStack {
                Image(systemName: "list.bullet.rectangle.fill")
                    .foregroundColor(PFColors.primary)
                Text("wallet_bill")
                    .font(PFFonts.headline)
                    .foregroundColor(PFColors.textPrimary)
                Spacer()
            }

            if vm.bills.isEmpty && !vm.isLoadingBills {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 44))
                        .foregroundColor(PFColors.textTertiary.opacity(0.5))
                    Text("wallet_no_records")
                        .font(PFFonts.body)
                        .foregroundColor(PFColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(vm.bills) { bill in
                        billRow(bill)
                        Divider().padding(.leading, 12)
                    }
                    if vm.isLoadingBills {
                        PFPetLoadingInline(size: 18)
                            .padding()
                    } else if vm.hasMoreBills {
                        PFPetLoadingInline(size: 18)
                            .padding()
                            .onAppear {
                                vm.loadBills()
                            }
                    } else if !vm.bills.isEmpty {
                        Text("common_no_more")
                            .font(PFFonts.caption2)
                            .foregroundColor(PFColors.textTertiary)
                            .padding()
                    }
                }
            }
        }
        .padding(PFSpacing.lg)
        .background(cardBackground)
    }

    private func billRow(_ bill: WalletBillRow) -> some View {
        HStack(spacing: PFSpacing.md) {
            // 账户类型 tag
            Text(bill.accountTypeText)
                .font(PFFonts.caption2)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(bill.accountTypeColor.opacity(0.12))
                .foregroundColor(bill.accountTypeColor)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 4) {
                Text(bill.bizTypeText)
                    .font(PFFonts.subheadline)
                    .foregroundColor(PFColors.textPrimary)
                    .lineLimit(1)
                Text(bill.createTime ?? "")
                    .font(PFFonts.caption)
                    .foregroundColor(PFColors.textSecondary)
            }

            Spacer()

            Text(bill.amountText)
                .font(PFFonts.headline)
                .foregroundColor(bill.isIncome ? PFColors.success : PFColors.danger)
        }
        .padding(.vertical, 12)
    }

    // MARK: - 动作

    /// 充值不需要支付密码（后端 recharge 不校验），直接发起
    private func submitRecharge() {
        guard !isRecharging else { return }
        guard let amount = Double(rechargeAmountText), amount > 0 else {
            UIState.shared.showToast(NSLocalizedString("wallet_amount_invalid", comment: ""))
            return
        }
        isRecharging = true
        Task {
            defer { isRecharging = false }
            do {
                let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                    "/petFriendly/client/wallet/recharge", method: .post,
                    parameters: ["amount": amount],
                    encoding: JSONEncoding.default, needToken: true, showLoading: false)
                guard resp.code == 200 else {
                    UIState.shared.showToast(NSLocalizedString("wallet_recharge_failed", comment: ""))
                    return
                }
                UIState.shared.showToast(NSLocalizedString("wallet_recharge_success", comment: ""))
                await vm.loadBalance()
                vm.loadBills(isRefresh: true)
            } catch {
                // 5xx 已由 NetworkManager 统一通过全局错误通知展示，不能在此覆盖服务端文案。
                if let bizError = error as? BizError, bizError.isSystemError { return }
                UIState.shared.showToast(NSLocalizedString("wallet_recharge_failed", comment: ""))
            }
        }
    }

    private func presentPasswordGate(for operation: WalletOperation) {
        guard payConfig == nil else { return }
        let text = operation == .recharge ? rechargeAmountText : withdrawAmountText
        switch WalletAmountValidator.validate(text, balance: vm.balance, operation: operation) {
        case .invalid:
            UIState.shared.showToast(NSLocalizedString("wallet_amount_invalid", comment: ""))
        case .exceedsBalance:
            UIState.shared.showToast(NSLocalizedString("wallet_withdraw_exceed", comment: ""))
        case .valid(let amount):
            guard vm.hasPayPassword else {
                UIState.shared.showToast(NSLocalizedString("pay_password_not_set_msg", comment: ""))
                showPayPasswordSetup = true
                return
            }
            payConfig = WalletPayConfig(operation: operation, amount: amount)
        }
    }

    @MainActor private func submitPendingOperation(password: String) async -> String? {
        guard let config = payConfig else { return NSLocalizedString("common_unknown", comment: "") }
        let operation = config.operation
        if operation == .recharge { isRecharging = true } else { isWithdrawing = true }
        defer {
            isRecharging = false
            isWithdrawing = false
        }
        do {
            let path = operation == .recharge ? "/petFriendly/client/wallet/recharge" : "/petFriendly/client/wallet/withdraw"
            let response: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                path, method: .post,
                parameters: ["amount": config.amount, "payPassword": password],
                encoding: JSONEncoding.default, needToken: true, showLoading: false)
            guard response.code == 200 else {
                return localizedWalletAPIMessage(response.msg, fallbackKey: operation == .recharge ? "wallet_recharge_failed" : "wallet_withdraw_failed")
            }
            // 不在此处关闭弹窗：绿描边反馈 + 延迟关闭由 PaymentPasswordGate.submit() 统一处理
            if operation == .withdraw { withdrawAmountText = "" }
            UIState.shared.showToast(NSLocalizedString(operation == .recharge ? "wallet_recharge_success" : "wallet_withdraw_success", comment: ""))
            await vm.loadBalance()
            vm.loadBills(isRefresh: true)
            return nil
        } catch {
            // 保持支付密码输入框的失败状态；5xx 的文字提示已由网络层统一展示。
            if let bizError = error as? BizError, bizError.isSystemError {
                return PaymentPasswordGate.globallyPresentedError
            }
            return NSLocalizedString(operation == .recharge ? "wallet_recharge_failed" : "wallet_withdraw_failed", comment: "")
        }
    }

    // MARK: - Helper

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: PFRadius.lg)
            .fill(PFColors.surface)
            .pfCardShadow()
    }

    private func formatAmount(_ text: String) -> String {
        let val = Double(text) ?? 0
        return String(format: "%.2f", val)
    }
}
