import SwiftUI

struct PointCommodity: Codable, Identifiable {
    /// 稳定唯一标识。优先 integralCommodityId，fallback 用 commodityCode 防重复 0
    var id: String {
        if let cid = integralCommodityId, cid != 0 { return String(cid) }
        var hasher = Hasher()
        hasher.combine(commodityCode)
        hasher.combine(commodityTitle)
        return "pc_\(hasher.finalize())"
    }
    @Int64String var integralCommodityId: Int64?
    let commodityTitle: String?
    let commodityCode: String?
    let commodityInformation: String?
    let commodityImg: String?
    
    // 后端返回字符串形式的数字，如 "1000.0"
    let commodityValue: String?
    let inventory: Int?
    
    var valueDouble: Double {
        Double(commodityValue ?? "0") ?? 0
    }
    
    var isVirtual: Bool {
        let code = (commodityCode ?? "").lowercased()
        return code.contains("card") || code.contains("jd") || code.contains("e-card")
    }

    enum CodingKeys: String, CodingKey {
        case integralCommodityId, commodityTitle, commodityCode, commodityInformation, commodityImg, commodityValue, inventory
    }
}

struct PointCommodityResponse: Codable {
    let code: Int
    let msg: String?
    let rows: [PointCommodity]?
    let total: Int?
}

class PointsMallViewModel: ObservableObject {
    @Published var commodities: [PointCommodity] = []
    @Published var isLoading = false
    @Published var isBuying = false
    
    // 分页
    private var pageNum = 1
    private let pageSize = 20
    private var hasMore = true
    
    func fetchCommodities(isRefresh: Bool = false) {
        if isRefresh {
            pageNum = 1
            hasMore = true
            commodities.removeAll()
        }
        guard hasMore, !isLoading else { return }
        
        isLoading = true
        let params: [String: Any] = [
            "pageNum": pageNum,
            "pageSize": pageSize
        ]
        
        Task {
            do {
                let resp: PointCommodityResponse = try await NetworkManager.shared.request(
                    "/petFriendly/client/mall/list",
                    parameters: params
                )
                await MainActor.run {
                    if let rows = resp.rows {
                        self.commodities.append(contentsOf: rows)
                        self.hasMore = rows.count == self.pageSize
                        self.pageNum += 1
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    /// 兑换商品：返回 nil 表示成功（关闭弹窗）；返回非 nil 表示失败（保留弹窗 + 错误提示）。
    /// B 方案：点「立即兑换」后弹窗不立即关闭，等接口响应成功才关，失败保留可重试。
    @MainActor
    func buyCommodity(commodity: PointCommodity, phone: String) async -> String? {
        guard !isBuying else { return nil }
        isBuying = true
        defer { isBuying = false }

        let params: [String: Any] = [
            "integralCommodityId": commodity.id,
            "commodityValue": commodity.valueDouble,
            "phone": phone
        ]

        do {
            let resp: BoolResp = try await NetworkManager.shared.request(
                "/petFriendly/client/mall/buy",
                method: .post,
                parameters: params
            )
            if resp.code == 200 {
                Haptics.notify(.success)
                showSuccessHUD(message: NSLocalizedString("mall_redeem_success", comment: ""))
                return nil
            }
            Haptics.notify(.error)
            return resp.msg ?? NSLocalizedString("redeem_fail", comment: "")
        } catch {
            Haptics.notify(.error)
            // 500 级错误统一走 AirPods 风格错误 toast
            showErrorAlert(error)
            return nil
        }
    }
}

struct PointsMallView: View {
    @StateObject private var vm = PointsMallViewModel()
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var uiState: UIState
    @State private var showHistory = false
    @State private var historyRefreshId = UUID()  // 每次打开 sheet 强制重建
    /// 兑换确认弹窗（B 方案：加载态 + 成功才关 + 失败保留可重试）
    @State private var buyDialog: PFActionDialogConfig?
    /// 当前准备兑换的商品（确认回调用）
    @State private var buyingCommodity: PointCommodity?
    
    // 网格布局，两列
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部资产区
                mallHeader
                
                // 列表区
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(vm.commodities) { item in
                            CommodityCard(commodity: item) {
                                presentBuyAlert(for: item)
                            }
                            .onAppear {
                                if item.id == vm.commodities.last?.id {
                                    vm.fetchCommodities()
                                }
                            }
                        }
                    }
                    .padding(16)
                    
                    if vm.isLoading {
                        PFPetLoadingInline(size: 20)
                            .padding(.vertical, 20)
                    }
                }
                .refreshable {
                    vm.fetchCommodities(isRefresh: true)
                }
            }
        }
        .navigationTitle("mall_title")
        .navigationBarTitleDisplayMode(.inline)
        .pfToyBackground()
        .trackScene("PointsMall")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { 
                    historyRefreshId = UUID()
                    showHistory = true 
                }) {
                    Text("mall_history")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(PFColors.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                ExchangeRecordListView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("common_close") { showHistory = false }
                        }
                    }
            }
            .id(historyRefreshId)  // 每次打开强制重建整个 NavigationStack + @StateObject
        }
        .onAppear {
            uiState.isTabBarForceHidden = true
            if vm.commodities.isEmpty {
                vm.fetchCommodities(isRefresh: true)
            }
        }
        .onDisappear {
            uiState.isTabBarForceHidden = false
        }
        // B 方案：兑换确认弹窗（带手机号输入 + 加载态，成功才关）
        .fullScreenCover(item: $buyDialog) { config in
            PFActionDialog(
                config: config,
                onConfirm: { input in await confirmBuy(phone: input) },
                onCancel: {
                    buyDialog = nil
                    buyingCommodity = nil
                }
            )
        }
    }
    
    private var mallHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("mall_my_points")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Button(action: showPointsHelp) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Text("\(accountStore.petOwner?.integralValue ?? 0)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Spacer()
            Image(systemName: "cart.fill")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: PFRadius.lg)
                .fill(LinearGradient(colors: [PFColors.warning, PFColors.warning.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .padding(16)
    }
    
    private func showPointsHelp() {
        let alert = UIAlertController(
            title: NSLocalizedString("mall_points_rule_title", comment: ""),
            message: NSLocalizedString("mall_points_rule_content", comment: ""),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("alert_ok", comment: ""), style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true)
        }
    }
    
    private func presentBuyAlert(for item: PointCommodity) {
        let title = item.commodityTitle ?? NSLocalizedString("person_no_nickname", comment: "")
        let cost = Int(item.valueDouble)
        let currentIntegral = Int(accountStore.petOwner?.integralValue ?? 0)
        
        // 1. 积分校验
        guard currentIntegral >= cost else {
            showErrorAlert(BizError.biz(code: 400, msg: String(format: NSLocalizedString("mall_insufficient_points", comment: ""), currentIntegral)))
            Haptics.notify(.error)
            return
        }
        
        // 2. 构造 B 方案确认弹窗（不立即关闭，等接口响应）
        buyingCommodity = item
        let currentPhone = accountStore.petOwner?.phoneInformation ?? ""
        buyDialog = PFActionDialogConfig(
            title: NSLocalizedString("mall_confirm_title", comment: ""),
            message: String(format: NSLocalizedString("mall_confirm_message", comment: ""), cost, title),
            confirmTitle: NSLocalizedString("mall_redeem_now", comment: ""),
            destructive: false,
            confirmIcon: "gift.fill",
            showTextField: true,
            textFieldPlaceholder: NSLocalizedString("mall_phone_placeholder", comment: ""),
            textFieldInitial: currentPhone,
            textFieldIsPhone: true
        )
    }

    /// 兑换确认回调：校验手机号 → 调用接口，返回 nil 成功（关弹窗）/ 非 nil 失败（保留弹窗）
    @MainActor
    private func confirmBuy(phone: String) async -> String? {
        guard let item = buyingCommodity else {
            return NSLocalizedString("redeem_fail", comment: "")
        }
        let cost = Int(item.valueDouble)
        // 虚拟商品必须校验手机号长度（简单校验）
        if item.isVirtual && phone.count < 11 {
            Haptics.notify(.warning)
            return NSLocalizedString("mall_virtual_phone_error", comment: "")
        }
        let result = await vm.buyCommodity(commodity: item, phone: phone)
        if result == nil {
            // 成功扣分后同步内存资产
            if let current = accountStore.petOwner?.integralValue {
                accountStore.petOwner?.integralValue = current - Int64(cost)
            }
        }
        return result
    }
}

// 单个商品卡片
struct CommodityCard: View {
    let commodity: PointCommodity
    let onBuy: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 图
            ZStack {
                Color.black.opacity(0.05)
                if let iStr = commodity.commodityImg, let url = URL(string: NetworkManager.fullUrl(iStr)?.absoluteString ?? "") {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        PFPetLoadingInline(size: 20)
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .pfImageInteractable(url: iStr)
                } else {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 40))
                        .foregroundColor(PFColors.textTertiary.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            
            // 信息区
            VStack(alignment: .leading, spacing: 6) {
                Text(commodity.commodityTitle ?? NSLocalizedString("person_no_nickname", comment: ""))
                    .font(PFFonts.callout)
                    .fontWeight(.medium)
                    .foregroundColor(PFColors.textPrimary)
                    .lineLimit(2)
                
                HStack(alignment: .bottom, spacing: 4) {
                    Image(systemName: "rosette")
                        .foregroundColor(PFColors.warning)
                        .font(.system(size: 14))
                    Text(String(format: "%.0f", commodity.valueDouble))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(PFColors.warning)
                }
                
                if let stock = commodity.inventory {
                    Text(String(format: NSLocalizedString("mall_stock", comment: ""), stock))
                        .font(.system(size: 10))
                        .foregroundColor(PFColors.textTertiary)
                }
                
                Button(action: onBuy) {
                    Text("mall_redeem_now")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(PFGradients.brand)
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
            .padding(12)
        }
        .background(PFColors.surface)
        .cornerRadius(PFRadius.md)
        .pfElevatedShadow()
    }
}
