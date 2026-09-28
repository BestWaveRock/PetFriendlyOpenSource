//
//  ServiceOrderListView.swift
//  PetFriendly
//
//  Created by PetFriendly Team.
//

import SwiftUI
import Alamofire

// MARK: - 属性包装器：兼容时间戳与字符串
@propertyWrapper
struct SafeDateString: Codable {
    var wrappedValue: String?
    
    init(wrappedValue: String? = nil) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            wrappedValue = nil
            return
        }
        
        // 尝试按字符串解
        if let strVal = try? container.decode(String.self) {
            wrappedValue = strVal
            return
        }
        // 尝试按数字解 (假设是毫秒时间戳)
        if let intVal = try? container.decode(Int64.self) {
            let date = Date(timeIntervalSince1970: Double(intVal) / 1000.0)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            wrappedValue = formatter.string(from: date)
            return
        }
        // 尝试按 Double 解
        if let doubleVal = try? container.decode(Double.self) {
            let date = Date(timeIntervalSince1970: doubleVal / 1000.0)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            wrappedValue = formatter.string(from: date)
            return
        }
        wrappedValue = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

// MARK: - API 模型（需根据业务补充）
struct ServiceOrderResp: Decodable {
    let code: Int
    let msg: String?
    let total: Int?
    let rows: [ServiceOrderRow]?
}

struct ServiceOrderRow: Identifiable, Decodable {
    @Int64String var consumerId: Int64?
    var id: String { consumerId.map(String.init) ?? UUID().uuidString }
    let serviceName: String?
    let status: Int?
    @SafeDateString var createTime: String?
    @StringCodedOptionalDouble var actualAmount: Double?
    let serviceCertificate: String?
    
    // 更多详情字段
    let serviceType: Int?
    let serviceInformation: String?
    let reserveInformation: String?
    let phoneInformation: String?
    @SafeDateString var downTime: String?
    @SafeDateString var reserveStartTime: String?
    @SafeDateString var reserveEndTime: String?
    @SafeDateString var appointmentTime: String?
    @SafeDateString var serviceTime: String?
    @StringCodedOptionalDouble var refundAmount: Double?
    @StringCodedOptionalDouble var consumptionAmount: Double?
    let remark: String?
    let ext: String?
    
    // 评价相关
    let commentRate: Int?
    let commentContent: String?
    // 服务证明（已存在）
    // serviceCertificate: String? 已在上面声明
    // 退款原因
    let refundReason: String?
    
    // API 返回的额外字段
    let userName: String?     // 客户姓名
    let userPhone: String?    // 客户电话
    
    // 1.1.0 订单流转字段
    @Int64String var userId: Int64?            // 下单用户
    @Int64String var providerUserId: Int64?    // 接单服务商（用户ID）
    let payStatus: Int?                        // 0=未支付 1=已支付
    let afterSaleHandlerName: String?
    let afterSaleRemark: String?

    /// 便捷构造：供「提交订单成功后」跳转订单详情页使用（仅填详情页所需的关键字段，其余为 nil）
    /// 需要读取 AccountStore.shared.user（主线程隔离），故标注 @MainActor
    @MainActor
    init(consumerId: Int64?,
         serviceName: String?,
         serviceType: Int?,
         status: Int?,
         payStatus: Int?,
         consumptionAmount: Double?,
         actualAmount: Double?) {
        self._consumerId = Int64String(wrappedValue: consumerId)
        self.serviceName = serviceName
        self.serviceType = serviceType
        self.status = status
        self.payStatus = payStatus
        self._consumptionAmount = StringCodedOptionalDouble(wrappedValue: consumptionAmount)
        self._actualAmount = StringCodedOptionalDouble(wrappedValue: actualAmount)
        // 以下字段默认 nil
        self._createTime = SafeDateString(wrappedValue: nil)
        self.serviceCertificate = nil
        self.serviceInformation = nil
        self.reserveInformation = nil
        self.phoneInformation = nil
        self._downTime = SafeDateString(wrappedValue: nil)
        self._reserveStartTime = SafeDateString(wrappedValue: nil)
        self._reserveEndTime = SafeDateString(wrappedValue: nil)
        self._appointmentTime = SafeDateString(wrappedValue: nil)
        self._serviceTime = SafeDateString(wrappedValue: nil)
        self._refundAmount = StringCodedOptionalDouble(wrappedValue: nil)
        self.remark = nil
        self.ext = nil
        self.commentRate = nil
        self.commentContent = nil
        self.refundReason = nil
        self.userName = nil
        self.userPhone = nil
        // 提交订单的操作人必然是当前登录用户，填 userId 以便详情页正确展示操作按钮（取消/支付等）
        self._userId = Int64String(wrappedValue: AccountStore.shared.user?.userId)
        self._providerUserId = Int64String(wrappedValue: nil)
        self.afterSaleHandlerName = nil
        self.afterSaleRemark = nil
    }

    /// 提交订单成功后，根据 consumerId 拉取后端完整订单数据（复用详情页，展示完整字段）
    /// 后端接口: GET /petFriendly/client/service/order/detail?consumerId=xxx
    static func fetchDetail(consumerId: Int64?) async throws -> ServiceOrderRow? {
        guard let cid = consumerId else { return nil }
        let path = "/petFriendly/client/service/order/detail"
        let params: [String: Any] = ["consumerId": "\(cid)"]
        let resp: RespWrapper<ServiceOrderRow> = try await NetworkManager.shared.request(
            path,
            method: .get,
            parameters: params,
            encoding: URLEncoding.default)
        return resp.code == 200 ? resp.data : nil
    }
}

// MARK: - 视图模型（分页加载模板）
@MainActor
class ServiceOrderViewModel: ObservableObject {
    @Published var dataList: [ServiceOrderRow] = []
    @Published var isLoading = false
    @Published var isLoadMore = false
    @Published var hasMore = true
    
    private var pageNum = 1
    private let pageSize = 10
    private let serviceType: String
    
    init(serviceType: String) {
        self.serviceType = serviceType
    }
    
    // 下拉刷新：请求成功才替换数据；失败时保留旧数据，避免刷新把列表清空
    func refreshData() async {
        pageNum = 1
        hasMore = true
        isLoading = true
        let result = await fetchPage()
        
        if let result {
            dataList = result
            if result.count < pageSize { hasMore = false }
        }
        isLoading = false
    }
    
    // 上拉加载
    func loadMore() async {
        guard !isLoadMore, hasMore else { return }
        isLoadMore = true
        pageNum += 1
        
        if let result = await fetchPage() {
            if result.isEmpty {
                hasMore = false
            } else {
                dataList.append(contentsOf: result)
                if result.count < pageSize { hasMore = false }
            }
        }
        isLoadMore = false
    }
    
    // 实际网络请求；返回 nil 表示请求失败（刷新时保留旧数据）
    private func fetchPage() async -> [ServiceOrderRow]? {
        let path = "/petFriendly/client/serviceOrderList"
        
        let params: [String: Any] = [
            "pageNum": pageNum,
            "pageSize": pageSize,
            "serviceType": serviceType
        ]
        
        do {
            let resp: ServiceOrderResp = try await NetworkManager.shared.request(
                path,
                method: .get, // 或 .post
                parameters: params,
                needToken: true,
                showLoading: false
            )
            if resp.code == 200 {
                return resp.rows ?? []
            }
        } catch {
            print("加载服务订单失败: \(error)")
        }
        return nil
    }
}

// MARK: - 视图展示
struct ServiceOrderListView: View {
    let serviceTitle: String
    let serviceType: String // e.g. "taxi", "mall", "emergency"
    /// 是否显示自定义返回按钮：提交页以 fullScreenCover 弹出时显示；列表 push 进入用系统返回
    var showCloseButton: Bool = false
    
    @StateObject private var viewModel: ServiceOrderViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    init(title: String, type: String, showCloseButton: Bool = false) {
        self.serviceTitle = title
        self.serviceType = type
        self.showCloseButton = showCloseButton
        _viewModel = StateObject(wrappedValue: ServiceOrderViewModel(serviceType: type))
    }
    
    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.dataList.isEmpty {
                PFPetLoadingView("order_loading", size: 36)
            } else if !viewModel.isLoading && viewModel.dataList.isEmpty {
                emptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: PFSpacing.md) {
                        ForEach(viewModel.dataList) { item in
                            // 点击跳转详情页
                            NavigationLink(destination: ServiceOrderDetailView(order: item, onOrderChanged: {
                                Task { await viewModel.refreshData() }
                            })) {
                                orderCard(item)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onAppear {
                                if item.id == viewModel.dataList.last?.id {
                                    Task { await viewModel.loadMore() }
                                }
                            }
                        }
                        
                        if viewModel.isLoadMore {
                            HStack {
                                Spacer()
                                PFPetLoadingInline(size: 18)
                                Spacer()
                            }
                            .padding()
                        } else if !viewModel.hasMore {
                            Text("common_no_more")
                                .font(PFFonts.caption)
                                .foregroundColor(PFColors.textTertiary)
                                .padding()
                        }
                    }
                    .padding(.horizontal, PFSpacing.lg)
                    .padding(.vertical, PFSpacing.md)
                }
                .refreshable {
                    await viewModel.refreshData()
                }
            }
        }
        .navigationTitle(serviceTitle + NSLocalizedString("order_title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .trackScene("ServiceOrders_\(serviceType)")
        // 提交页以 fullScreenCover 弹出时显示关闭按钮；push 进入复用系统返回
        .toolbar {
            if showCloseButton {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(PFColors.textPrimary)
                    }
                }
            }
        }
        .onAppear {
            if viewModel.dataList.isEmpty {
                Task { await viewModel.refreshData() }
            }
        }
    }
    
    // 空视图
    private var emptyView: some View {
        VStack(spacing: PFSpacing.lg) {
            Image(systemName: "tray")
                .font(.system(size: 64))
                .foregroundColor(PFColors.textTertiary.opacity(0.5))
            
            Text("order_list_empty")
                .font(PFFonts.body)
                .foregroundColor(PFColors.textSecondary)
        }
        .padding(.top, 100)
    }
    
    // 单个订单卡片
    private func orderCard(_ item: ServiceOrderRow) -> some View {
        VStack(spacing: 0) {
            // 顶栏：单号 + 状态
            HStack {
                Text(String(format: NSLocalizedString("order_id_prefix", comment: ""), item.consumerId.map { String($0) } ?? NSLocalizedString("boarding_not_filled", comment: "")))
                    .font(PFFonts.caption)
                    .foregroundColor(PFColors.textSecondary)
                
                Spacer()
                
                statusTag(for: item.status ?? 0)
            }
            .padding(.horizontal, PFSpacing.lg)
            .padding(.vertical, PFSpacing.md)
            
            Divider()
                .padding(.horizontal, PFSpacing.lg)
            
            // 内容区域
            HStack(spacing: PFSpacing.md) {
                // 左侧封面图
                let coverUrl = item.serviceCertificate ?? item.ext
                if let coverUrl = coverUrl, let url = NetworkManager.fullUrl(coverUrl) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.white
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
                    .clipped()
                } else {
                    // 左侧图片
                    ZStack {
                        RoundedRectangle(cornerRadius: PFRadius.md)
                            .fill(Color.white)
                            .frame(width: 64, height: 64)
                            .overlay(Image(systemName: "photo").foregroundColor(PFColors.textTertiary))
                    }
                }
                
                // 右侧信息
                VStack(alignment: .leading, spacing: PFSpacing.xs) {
                    Text(item.serviceName ?? NSLocalizedString("person_my_services", comment: ""))
                        .font(PFFonts.body)
                        .foregroundColor(PFColors.textPrimary)
                        .lineLimit(1)
                    
                    // 客户信息
                    if let name = item.userName, !name.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                            Text(name)
                                .font(PFFonts.caption2)
                        }
                        .foregroundColor(PFColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Text(item.createTime ?? "")
                        .font(PFFonts.caption2)
                        .foregroundColor(PFColors.textSecondary)
                }
                
                Spacer()
                
                // 价格/积分等额外信息
                if let amount = item.actualAmount {
                    Text("¥ \(String(format: "%.2f", amount))")
                        .font(PFFonts.headline)
                        .foregroundColor(PFColors.warning)
                }
            }
            .padding(PFSpacing.lg)
        }
        .background(
            RoundedRectangle(cornerRadius: PFRadius.lg)
                .fill(PFColors.surface)
        )
        .pfCardShadow()
    }
    
    // 状态标签
    @ViewBuilder
    private func statusTag(for status: Int) -> some View {
        let config: (text: String, bg: Color, textClr: Color) = {
            switch status {
            case 0, 1, 2, 3: 
                return (NSLocalizedString("order_tag_pending", comment: ""), PFColors.warning.opacity(0.1), PFColors.warning)
            case 4: 
                return (NSLocalizedString("order_tag_active", comment: ""), PFColors.info.opacity(0.1), PFColors.info)
            case 16:
                return (NSLocalizedString("order_status_16", comment: ""), PFColors.info.opacity(0.1), PFColors.info)
            case 17:
                return (NSLocalizedString("order_status_17", comment: ""), PFColors.info.opacity(0.1), PFColors.info)
            case 5, 6, 12: 
                return (NSLocalizedString("order_tag_completed", comment: ""), PFColors.success.opacity(0.1), PFColors.success)
            case 7, 13: 
                return (NSLocalizedString("order_tag_cancelled", comment: ""), PFColors.textSecondary.opacity(0.1), PFColors.textSecondary)
            case 8, 9, 10, 11:
                return (NSLocalizedString("order_tag_aftersales", comment: ""), PFColors.accent.opacity(0.1), PFColors.accent)
            default: 
                return (NSLocalizedString("order_tag_cancelled", comment: ""), PFColors.textSecondary.opacity(0.1), PFColors.textSecondary)
            }
        }()
        
        Text(config.text)
            .font(PFFonts.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(config.bg)
            .foregroundColor(config.textClr)
            .clipShape(Capsule())
    }
}
//
//  ServiceOrderDetailView.swift
//  PetFriendly
//
//  订单详情（美化版）
//  支持根据服务类型自适应展示
//  1.1.0：角色(用户/服务商) + 状态 操作矩阵
//

import SwiftUI
