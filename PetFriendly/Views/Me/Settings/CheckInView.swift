//
//  CheckInView.swift
//  PetFriendly
//
//  每日签到页：连续天数 / 积分 / 爱心 / 30 天日历 / 手动签到 / 补签 / 自动签到开关
//  接口：GET /checkIn/status、POST /checkIn、POST /checkIn/repair、POST /settings/autoCheckin
//

import SwiftUI
import Alamofire

private func localizedCheckInAPIMessage(_ message: String?, fallbackKey: String) -> String {
    let language = Bundle.main.preferredLocalizations.first ?? Locale.current.identifier
    if language.hasPrefix("zh"), let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return message
    }
    return NSLocalizedString(fallbackKey, comment: "")
}

// MARK: - 模型

struct CheckInStatusResp: Decodable {
    let code: Int
    let msg: String?
    let data: CheckInStatusData?
}

struct CheckInStatusData: Decodable {
    let todayChecked: Bool?
    let streakDays: Int?
    @Int64String var integral: Int64?
    @Int64String var loveValue: Int64?
    let autoCheckin: Bool?
    let checkinDates: [String]?
    let repairDates: [String]?
}

// MARK: - 视图模型

@MainActor
class CheckInViewModel: ObservableObject {
    @Published var todayChecked = false
    @Published var streakDays = 0
    @Published var integral: Int64 = 0
    @Published var loveValue: Int64 = 0
    @Published var autoCheckin = true
    @Published var checkinDates: Set<String> = []
    @Published var repairDates: Set<String> = []
    @Published var isLoading = false

    func loadStatus() async {
        isLoading = true
        do {
            let resp: CheckInStatusResp = try await NetworkManager.shared.request(
                "/petFriendly/client/checkIn/status",
                method: .get,
                needToken: true,
                showLoading: false
            )
            await MainActor.run {
                if resp.code == 200, let data = resp.data {
                    todayChecked = data.todayChecked ?? false
                    streakDays = data.streakDays ?? 0
                    integral = data.integral ?? 0
                    loveValue = data.loveValue ?? 0
                    autoCheckin = data.autoCheckin ?? true
                    checkinDates = Set(data.checkinDates ?? [])
                    repairDates = Set(data.repairDates ?? [])
                    // 同步本地自动签到开关（与 AppDelegate.checkDailyLogin 共用）
                    UserDefaults.standard.set(autoCheckin, forKey: "autoCheckin")
                } else {
                    UIState.shared.showToast(localizedCheckInAPIMessage(resp.msg, fallbackKey: "checkin_load_failed"))
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                UIState.shared.showToast(NSLocalizedString("checkin_load_failed", comment: ""))
            }
        }
    }
}

// MARK: - 视图

struct CheckInView: View {
    @StateObject private var vm = CheckInViewModel()

    @State private var isCheckingIn = false
    @State private var isRepairing = false
    /// 补签确认弹窗（B 方案：加载态 + 成功才关 + 失败保留可重试）
    @State private var repairDialog: PFActionDialogConfig?

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let dayNumFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: PFSpacing.lg) {
                    summaryCard
                    calendarCard
                    actionCard
                }
                .padding(PFSpacing.lg)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("checkin_title")
        .navigationBarTitleDisplayMode(.inline)
        .pfToyBackground()
        .trackScene("CheckIn")
        .onAppear {
            Task { await vm.loadStatus() }
        }
        // B 方案：补签确认弹窗（加载态，成功才关，失败保留可重试）
        .fullScreenCover(item: $repairDialog) { config in
            PFActionDialog(
                config: config,
                onConfirm: { _ in await submitRepair() },
                onCancel: { repairDialog = nil }
            )
        }
    }

    // MARK: - 顶部汇总卡
    private var summaryCard: some View {
        VStack(spacing: PFSpacing.md) {
            HStack(spacing: PFSpacing.xl) {
                // 连续天数
                VStack(spacing: 6) {
                    Text("\(vm.streakDays)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(PFColors.warning)
                    Text("checkin_streak")
                        .font(PFFonts.caption)
                        .foregroundColor(PFColors.textSecondary)
                    Text(String(format: NSLocalizedString("checkin_streak_days", comment: ""), vm.streakDays))
                        .font(PFFonts.caption2)
                        .foregroundColor(PFColors.textTertiary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 48)

                // 积分
                VStack(spacing: 6) {
                    Text("\(vm.integral)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(PFColors.primary)
                    Text("wallet_account_points")
                        .font(PFFonts.caption)
                        .foregroundColor(PFColors.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 48)

                // 爱心
                VStack(spacing: 6) {
                    Text("\(vm.loveValue)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(PFColors.accent)
                    Text("wallet_account_love")
                        .font(PFFonts.caption)
                        .foregroundColor(PFColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }

            Divider()

            // 自动签到开关
            Toggle(isOn: Binding(
                get: { vm.autoCheckin },
                set: { newValue in
                    vm.autoCheckin = newValue
                    UserDefaults.standard.set(newValue, forKey: "autoCheckin")
                    Task { await setAutoCheckin(newValue) }
                }
            )) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(PFColors.info)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("checkin_auto")
                            .font(PFFonts.body)
                            .foregroundColor(PFColors.textPrimary)
                        Text("checkin_auto_hint")
                            .font(PFFonts.caption2)
                            .foregroundColor(PFColors.textTertiary)
                    }
                }
            }
            .tint(PFColors.info)
        }
        .padding(PFSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: PFRadius.lg)
                .fill(PFColors.surface)
                .pfCardShadow()
        )
    }

    // MARK: - 30 天日历
    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: PFSpacing.md) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(PFColors.primary)
                Text("checkin_calendar")
                    .font(PFFonts.headline)
                    .foregroundColor(PFColors.textPrimary)
                Spacer()
                // 图例
                HStack(spacing: 10) {
                    legendItem("✓", PFColors.success, "checkin_legend_checked")
                    legendItem("⚡", PFColors.warning, "checkin_legend_repaired")
                }
            }

            // 星期表头
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(weekdayHeader.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(PFFonts.caption2)
                        .foregroundColor(PFColors.textTertiary)
                }
            }

            // 日期格子：前置空格 + 30 天
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear
                        .frame(height: 40)
                }
                ForEach(last30Days, id: \.timeIntervalSince1970) { day in
                    dayCell(day)
                }
            }
        }
        .padding(PFSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: PFRadius.lg)
                .fill(PFColors.surface)
                .pfCardShadow()
        )
    }

    private func legendItem(_ symbol: String, _ color: Color, _ titleKey: LocalizedStringKey) -> some View {
        HStack(spacing: 3) {
            Text(symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
            Text(titleKey)
                .font(PFFonts.caption2)
                .foregroundColor(PFColors.textTertiary)
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(day)
        let checked = isCheckedDay(day)
        let repaired = isRepairedDay(day)

        return ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor(checked: checked, repaired: repaired, isToday: isToday))
                .frame(height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isToday ? PFColors.primary : Color.clear, lineWidth: 1.5)
                )

            VStack(spacing: 1) {
                Text(Self.dayNumFormatter.string(from: day))
                    .font(PFFonts.caption)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundColor(foregroundColor(checked: checked, repaired: repaired, isToday: isToday))
                if checked || repaired {
                    Text(repaired ? "⚡" : "✓")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(repaired ? PFColors.warning : PFColors.success)
                } else {
                    Text(" ")
                        .font(.system(size: 10))
                }
            }
        }
    }

    private func backgroundColor(checked: Bool, repaired: Bool, isToday: Bool) -> Color {
        if repaired { return PFColors.warning.opacity(0.14) }
        if checked { return PFColors.success.opacity(0.14) }
        if isToday { return PFColors.primary.opacity(0.08) }
        return PFColors.surfaceSecondary
    }

    private func foregroundColor(checked: Bool, repaired: Bool, isToday: Bool) -> Color {
        if repaired || checked { return PFColors.textPrimary }
        if isToday { return PFColors.primary }
        return PFColors.textSecondary
    }

    // MARK: - 操作区
    private var actionCard: some View {
        VStack(spacing: PFSpacing.md) {
            // 签到按钮
            Button(action: submitCheckIn) {
                HStack {
                    if isCheckingIn {
                        PFPetLoadingInline(size: 16)
                    }
                    Image(systemName: vm.todayChecked ? "checkmark.circle.fill" : "pawprint.fill")
                    Text(LocalizedStringKey(vm.todayChecked ? "checkin_today_checked" : "checkin_go"))
                        .font(PFFonts.body)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Group {
                        if vm.todayChecked {
                            PFColors.textTertiary
                        } else {
                            PFGradients.brand
                        }
                    }
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
            }
            .disabled(vm.todayChecked || isCheckingIn)
            .opacity((vm.todayChecked || isCheckingIn) ? 0.6 : 1)

            // 补签按钮
            Button(action: {
                repairDialog = PFActionDialogConfig(
                    title: NSLocalizedString("checkin_repair_confirm_title", comment: ""),
                    message: NSLocalizedString("checkin_repair_confirm_msg", comment: ""),
                    confirmTitle: NSLocalizedString("checkin_repair", comment: ""),
                    destructive: false,
                    confirmIcon: "bolt.fill"
                )
            }) {
                HStack {
                    if isRepairing {
                        PFPetLoadingInline(size: 16)
                    }
                    Image(systemName: "bolt.fill")
                    Text("checkin_repair")
                        .font(PFFonts.body)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canRepair ? PFColors.warning : PFColors.textTertiary.opacity(0.4))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
            }
            .disabled(!canRepair || isRepairing)
            .opacity((!canRepair || isRepairing) ? 0.6 : 1)

            // 补签说明
            Text(repairHintText)
                .font(PFFonts.caption)
                .foregroundColor(PFColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(PFSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: PFRadius.lg)
                .fill(PFColors.surface)
                .pfCardShadow()
        )
    }

    private var canRepair: Bool {
        guard vm.loveValue >= 5 else { return false }
        let ys = Self.dayFormatter.string(from: yesterday)
        return !vm.checkinDates.contains(ys) && !vm.repairDates.contains(ys)
    }

    private var repairHintText: String {
        if vm.loveValue < 5 {
            return NSLocalizedString("checkin_repair_love_insufficient", comment: "")
        }
        let ys = Self.dayFormatter.string(from: yesterday)
        if vm.checkinDates.contains(ys) || vm.repairDates.contains(ys) {
            return NSLocalizedString("checkin_repair_not_needed", comment: "")
        }
        return NSLocalizedString("checkin_repair_cost", comment: "")
    }

    // MARK: - 日期工具

    private var yesterday: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    }

    private var last30Days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<30).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
    }

    private var leadingBlanks: Int {
        let cal = Calendar.current
        guard let first = last30Days.first else { return 0 }
        let weekday = cal.component(.weekday, from: first)   // 1=周日 ... 7=周六
        let firstWeekday = max(1, cal.firstWeekday)
        return (weekday - firstWeekday + 7) % 7
    }

    private var weekdayHeader: [String] {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        let first = max(1, Calendar.current.firstWeekday)
        guard symbols.count == 7, first >= 1, first <= 7 else {
            return [
                NSLocalizedString("checkin_weekday_sun", comment: ""),
                NSLocalizedString("checkin_weekday_mon", comment: ""),
                NSLocalizedString("checkin_weekday_tue", comment: ""),
                NSLocalizedString("checkin_weekday_wed", comment: ""),
                NSLocalizedString("checkin_weekday_thu", comment: ""),
                NSLocalizedString("checkin_weekday_fri", comment: ""),
                NSLocalizedString("checkin_weekday_sat", comment: "")
            ]
        }
        return Array(symbols[(first - 1)...]) + Array(symbols[..<(first - 1)])
    }

    private func isCheckedDay(_ day: Date) -> Bool {
        let s = Self.dayFormatter.string(from: day)
        if vm.checkinDates.contains(s) { return true }
        if Calendar.current.isDateInToday(day) && vm.todayChecked { return true }
        return false
    }

    private func isRepairedDay(_ day: Date) -> Bool {
        vm.repairDates.contains(Self.dayFormatter.string(from: day))
    }

    // MARK: - 动作

    private func submitCheckIn() {
        guard !isCheckingIn, !vm.todayChecked else { return }
        isCheckingIn = true
        Task {
            do {
                let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                    "/petFriendly/client/checkIn",
                    method: .post,
                    needToken: true
                )
                await MainActor.run {
                    isCheckingIn = false
                    if resp.code == 200 {
                        UIState.shared.showToast(NSLocalizedString("checkin_reward_toast", comment: ""))
                        Haptics.notify(.success)
                        vm.todayChecked = true
                        vm.streakDays += 1
                        vm.integral += 5
                        vm.loveValue += 1
                        let todayStr = Self.dayFormatter.string(from: Date())
                        vm.checkinDates.insert(todayStr)
                        // 同步 AccountStore 内存资产
                        if let current = AccountStore.shared.petOwner?.integralValue {
                            AccountStore.shared.petOwner?.integralValue = current + 5
                        }
                        if let love = AccountStore.shared.petOwner?.loveValue {
                            AccountStore.shared.petOwner?.loveValue = love + 1
                        }
                        Task { await vm.loadStatus() }
                    } else {
                        UIState.shared.showToast(localizedCheckInAPIMessage(resp.msg, fallbackKey: "checkin_submit_failed"))
                    }
                }
            } catch {
                await MainActor.run {
                    isCheckingIn = false
                    UIState.shared.showToast(NSLocalizedString("checkin_submit_failed", comment: ""))
                }
            }
        }
    }

    /// 补签：返回 nil 成功（关弹窗）/ 非 nil 失败（保留弹窗）。B 方案：等接口响应成功才关。
    @MainActor
    private func submitRepair() async -> String? {
        guard !isRepairing, canRepair else { return nil }
        isRepairing = true
        defer { isRepairing = false }
        let yesterdayStr = Self.dayFormatter.string(from: yesterday)
        do {
            let params: [String: Any] = ["date": yesterdayStr]
            let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                "/petFriendly/client/checkIn/repair",
                method: .post,
                parameters: params,
                encoding: JSONEncoding.default,
                needToken: true
            )
            if resp.code == 200 {
                UIState.shared.showToast(NSLocalizedString("checkin_repair_success", comment: ""))
                Haptics.notify(.success)
                vm.loveValue = max(0, vm.loveValue - 5)
                vm.repairDates.insert(yesterdayStr)
                Task { await vm.loadStatus() }
                return nil
            }
            return localizedCheckInAPIMessage(resp.msg, fallbackKey: "checkin_repair_failed")
        } catch {
            return NSLocalizedString("checkin_repair_failed", comment: "")
        }
    }

    private func setAutoCheckin(_ enabled: Bool) async {
        do {
            let params: [String: Any] = ["enabled": enabled]
            let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                "/petFriendly/client/settings/autoCheckin",
                method: .post,
                parameters: params,
                encoding: JSONEncoding.default,
                needToken: true,
                showLoading: false
            )
            await MainActor.run {
                if resp.code != 200 {
                    UIState.shared.showToast(localizedCheckInAPIMessage(resp.msg, fallbackKey: "checkin_auto_update_failed"))
                    // 失败回滚本地开关
                    vm.autoCheckin = !enabled
                    UserDefaults.standard.set(!enabled, forKey: "autoCheckin")
                }
            }
        } catch {
            await MainActor.run {
                vm.autoCheckin = !enabled
                UserDefaults.standard.set(!enabled, forKey: "autoCheckin")
                UIState.shared.showToast(NSLocalizedString("checkin_auto_update_failed", comment: ""))
            }
        }
    }
}
