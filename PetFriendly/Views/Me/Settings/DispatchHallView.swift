import Alamofire
//
//  DispatchHallView.swift
//  PetFriendly
//
//  派单大厅 + 我的接单：服务商可抢单/取消/上传证明/完成订单/地图导航
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - 派单大厅 ViewModel
@MainActor
struct DispatchHallView: View {
    @StateObject private var viewModel = DispatchHallViewModel()
    @State private var selectedOrder: DispatchOrder?
    // B 方案：抢单确认弹窗（加载态 + 成功才关 + 失败保留可重试）
    @State private var grabDialog: PFActionDialogConfig?
    @State private var grabTargetOrder: DispatchOrder?
    // 点击头像查看宠物/用户信息卡片
    @State private var selectedPetForCard: DispatchOrder?
    @State private var selectedUserForCard: DispatchOrder?
    
    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部Tab切换
                Picker("", selection: $viewModel.selectedTab) {
                    Text("dispatch_hall_tab").tag(0)
                    Text("dispatch_my_orders_tab").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, PFSpacing.lg)
                .padding(.vertical, PFSpacing.sm)
                
                if viewModel.selectedTab == 0 {
                    hallContent
                } else {
                    myOrdersContent
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .navigationTitle(viewModel.selectedTab == 0 ? "dispatch_title" : "dispatch_my_orders_title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if viewModel.selectedTab == 0 {
                        viewModel.loadOrders()
                    } else {
                        viewModel.loadMyOrders()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .trackScene("DispatchHall")
        .onAppear {
            if viewModel.orders.isEmpty {
                viewModel.loadOrders()
            }
        }
        .onChange(of: viewModel.selectedTab) { tab in
            if tab == 1 && viewModel.myOrders.isEmpty {
                viewModel.loadMyOrders()
            }
        }
        .sheet(item: $selectedOrder) { order in
            DispatchOrderDetailSheet(order: order, viewModel: viewModel, isMyOrder: viewModel.selectedTab == 1)
        }
        // B 方案：抢单确认弹窗（加载态，成功才关，失败保留可重试）
        .fullScreenCover(item: $grabDialog) { config in
            PFActionDialog(
                config: config,
                onConfirm: { _ in await confirmGrab() },
                onCancel: {
                    grabDialog = nil
                    grabTargetOrder = nil
                }
            )
        }
        // 点击宠物头像 → 宠物信息卡片
        .sheet(item: $selectedPetForCard) { order in
            DispatchPetCardView(order: order)
        }
        // 点击主人 → 用户信息卡片
        .sheet(item: $selectedUserForCard) { order in
            DispatchUserCardView(order: order)
        }
    }
    
    // MARK: - 派单大厅内容
    private var hallContent: some View {
        Group {
            if viewModel.isLoading && viewModel.orders.isEmpty {
                PFPetLoadingView("dispatch_loading", size: 36)
            } else if viewModel.orders.isEmpty {
                emptyView(isMyOrders: false)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: PFSpacing.md) {
                        ForEach(viewModel.orders) { order in
                            DispatchOrderCard(
                                order: order,
                                onGrab: {
                                    selectedOrder = order
                                    presentGrabDialog(order)
                                },
                                onShowPet: { dispatchOrder in
                                    selectedPetForCard = dispatchOrder
                                },
                                onShowUser: { dispatchOrder in
                                    selectedUserForCard = dispatchOrder
                                }
                            )
                            .onTapGesture { selectedOrder = order }
                            .contextMenu {
                                Button(action: {
                                    selectedOrder = order
                                    presentGrabDialog(order)
                                }) {
                                    Label("dispatch_grab", systemImage: "hand.raised.fill")
                                }
                            }
                        }
                        
                        if viewModel.hasMore {
                            PFPetLoadingInline(size: 18)
                                .padding()
                                .onAppear {
                                    viewModel.loadMoreOrders()
                                }
                        } else if !viewModel.orders.isEmpty {
                            Text("common_no_more")
                                .font(PFFonts.caption2)
                                .foregroundColor(PFColors.textTertiary)
                                .padding()
                        }
                        
                        if viewModel.isLoadingMore {
                            PFPetLoadingInline(size: 18)
                                .padding()
                        }
                    }
                    .padding(PFSpacing.lg)
                }
                .refreshable { viewModel.loadOrders() }
            }
        }
    }
    
    // MARK: - 我的接单内容
    private var myOrdersContent: some View {
        Group {
            if viewModel.isLoadingMyOrders && viewModel.myOrders.isEmpty {
                PFPetLoadingView("dispatch_loading", size: 36)
            } else if viewModel.myOrders.isEmpty {
                emptyView(isMyOrders: true)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: PFSpacing.md) {
                        ForEach(viewModel.myOrders) { order in
                            MyOrderCard(order: order)
                            .onTapGesture { selectedOrder = order }
                        }
                        
                        if viewModel.myHasMore {
                            PFPetLoadingInline(size: 18)
                                .padding()
                                .onAppear {
                                    viewModel.loadMoreMyOrders()
                                }
                        } else if !viewModel.myOrders.isEmpty {
                            Text("common_no_more")
                                .font(PFFonts.caption2)
                                .foregroundColor(PFColors.textTertiary)
                                .padding()
                        }
                        
                        if viewModel.isLoadingMoreMyOrders {
                            PFPetLoadingInline(size: 18)
                                .padding()
                        }
                    }
                    .padding(PFSpacing.lg)
                }
                .refreshable { viewModel.loadMyOrders() }
            }
        }
    }
    
    private func emptyView(isMyOrders: Bool) -> some View {
        VStack(spacing: PFSpacing.lg) {
            Image(systemName: isMyOrders ? "tray.full" : "tray.full")
                .font(.system(size: 64))
                .foregroundColor(PFColors.textTertiary.opacity(0.5))
            Text(isMyOrders ? "dispatch_my_orders_empty" : "dispatch_empty")
                .font(PFFonts.body)
                .foregroundColor(PFColors.textSecondary)
            Button(action: {
                if isMyOrders {
                    viewModel.loadMyOrders()
                } else {
                    viewModel.loadOrders()
                }
            }) {
                Text("dispatch_refresh")
                    .font(PFFonts.body)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(PFColors.primary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
            }
        }
        .padding(.top, 80)
    }
    
    // MARK: - 抢单确认（B 方案）
    private func presentGrabDialog(_ order: DispatchOrder) {
        grabTargetOrder = order
        grabDialog = PFActionDialogConfig(
            title: NSLocalizedString("dispatch_grab_confirm_title", comment: ""),
            message: NSLocalizedString("dispatch_grab_confirm_msg", comment: ""),
            confirmTitle: NSLocalizedString("dispatch_grab", comment: ""),
            destructive: false,
            confirmIcon: "hand.raised.fill"
        )
    }
    
    @MainActor
    private func confirmGrab() async -> String? {
        guard let order = grabTargetOrder else { return NSLocalizedString("dispatch_grab_failed", comment: "") }
        return await viewModel.grabOrder(order)
    }
}

// MARK: - 派单卡片（大厅用）
struct DispatchOrderCard: View {
    let order: DispatchOrder
    let onGrab: (() -> Void)?
    /// 点击宠物头像 / 主人信息查看对应卡片
    let onShowPet: ((DispatchOrder) -> Void)?
    let onShowUser: ((DispatchOrder) -> Void)?

    init(order: DispatchOrder, onGrab: (() -> Void)? = nil,
         onShowPet: ((DispatchOrder) -> Void)? = nil,
         onShowUser: ((DispatchOrder) -> Void)? = nil) {
        self.order = order
        self.onGrab = onGrab
        self.onShowPet = onShowPet
        self.onShowUser = onShowUser
    }

    /// 出发地址：优先从备注/需求里的【专车出发地】解析，否则回退主人地址
    private var departureAddress: String {
        if let remark = order.consumerRemark ?? order.reserveInformation,
           let range = remark.range(of: "【专车出发地】") {
            let tail = remark[range.upperBound...]
            // 截取到换行或【专车目的地】
            let lines = tail.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespaces)
                ?? (String(tail).trimmingCharacters(in: .whitespaces))
            return lines.isEmpty ? (order.ownerAddress ?? "") : lines
        }
        return order.ownerAddress ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // 头部：宠物/主人 + 服务名 + 预计收入
            HStack {
                // 宠物头像（点击查看宠物卡片）
                Button(action: { onShowPet?(order) }) {
                    Group {
                        if let avatar = order.petAvatar, let url = NetworkManager.fullUrl(avatar) {
                            CachedAsyncImage(url: url) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Color.white
                            }
                        } else {
                            Circle()
                                .fill(PFColors.primary.opacity(0.12))
                                .overlay(Image(systemName: "pawprint.fill").foregroundColor(PFColors.primary))
                        }
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(order.serviceName ?? NSLocalizedString("dispatch_generic_service", comment: ""))
                        .font(PFFonts.body)
                        .foregroundColor(PFColors.textPrimary)
                    // 主人名（点击查看用户卡片）
                    Button(action: { onShowUser?(order) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 11))
                            Text(order.ownerName ?? NSLocalizedString("dispatch_unknown_pet", comment: ""))
                                .font(PFFonts.caption2)
                        }
                        .foregroundColor(PFColors.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer()

                // 预计收入（着重展示）
                if let income = order.estimatedIncome {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("¥\(String(format: "%.2f", income))")
                            .font(PFFonts.title2.bold())
                            .foregroundColor(PFColors.warning)
                        Text("dispatch_estimated_income")
                            .font(PFFonts.caption2)
                            .foregroundColor(PFColors.textTertiary)
                    }
                }
            }
            .padding(PFSpacing.md)

            Divider().padding(.horizontal, PFSpacing.md)

            VStack(spacing: PFSpacing.sm) {
                // 出发地址（着重展示）
                if !departureAddress.isEmpty {
                    Label(departureAddress, systemImage: "mappin.and.ellipse")
                        .font(PFFonts.callout)
                        .foregroundColor(PFColors.textPrimary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // 预估距离 + 预约时间
                HStack(spacing: PFSpacing.lg) {
                    if let dist = order.distance {
                        Label(
                            dist > 1000 ? "\(String(format: "%.1f", Double(dist)/1000.0))km" : "\(dist)m",
                            systemImage: "location.fill"
                        )
                        .font(PFFonts.caption2)
                        .foregroundColor(PFColors.textSecondary)
                    }
                    if let time = order.reserveStartTime {
                        Label(time, systemImage: "clock.fill")
                            .font(PFFonts.caption2)
                            .foregroundColor(PFColors.textSecondary)
                    }
                    Spacer()
                }

                // 操作按钮行：导航 + 抢单
                HStack(spacing: PFSpacing.md) {
                    Button(action: openMapNavigation) {
                        HStack(spacing: 4) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 10))
                            Text("dispatch_navigate")
                                .font(PFFonts.caption2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(PFColors.info)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }

                    Spacer()

                    Button(action: { onGrab?() }) {
                        Text("dispatch_grab_btn")
                            .font(PFFonts.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(PFColors.primary)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(PFSpacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: PFRadius.lg)
                .fill(PFColors.surface)
        )
        .pfCardShadow()
    }

    private func openMapNavigation() {
        let address = departureAddress.isEmpty ? (order.ownerAddress ?? "") : departureAddress
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "http://maps.apple.com/?daddr=\(encodedAddress)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - 派单-宠物信息卡片
struct DispatchPetCardView: View {
    let order: DispatchOrder
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // 头像
            Group {
                if let avatar = order.petAvatar, let url = NetworkManager.fullUrl(avatar) {
                    CachedAsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color.white
                    }
                } else {
                    Circle()
                        .fill(PFColors.primary.opacity(0.12))
                        .overlay(Image(systemName: "pawprint.fill").foregroundColor(PFColors.primary))
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())

            Text(order.petName ?? NSLocalizedString("dispatch_unknown_pet", comment: ""))
                .font(PFFonts.title2.bold())
                .foregroundColor(PFColors.textPrimary)

            // 宠物信息
            VStack(spacing: 12) {
                if let sp = order.petSpecies, !sp.isEmpty {
                    infoRow(icon: "pawprint.fill", label: NSLocalizedString("dispatch_pet_species", comment: ""), value: sp)
                }
                if let sex = order.petSex, !sex.isEmpty {
                    infoRow(icon: "figure.dress.line.vertical.figure", label: NSLocalizedString("dispatch_pet_sex", comment: ""), value: sex)
                }
                if let breed = order.petBreeds, !breed.isEmpty {
                    infoRow(icon: "tag.fill", label: NSLocalizedString("dispatch_pet_breeds", comment: ""), value: breed)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(PFColors.surface)
            .cornerRadius(PFRadius.lg)

            Button("btn_close") { dismiss() }
                .font(PFFonts.body)
                .foregroundColor(PFColors.primary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(PFColors.background.ignoresSafeArea())
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(PFColors.primary)
                .frame(width: 24)
            Text(label)
                .font(PFFonts.caption)
                .foregroundColor(PFColors.textSecondary)
            Spacer()
            Text(value)
                .font(PFFonts.callout)
                .foregroundColor(PFColors.textPrimary)
        }
    }
}

// MARK: - 派单-用户信息卡片
struct DispatchUserCardView: View {
    let order: DispatchOrder
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(PFColors.primary.opacity(0.6))

            Text(order.ownerName ?? NSLocalizedString("dispatch_unknown_pet", comment: ""))
                .font(PFFonts.title2.bold())
                .foregroundColor(PFColors.textPrimary)

            VStack(spacing: 12) {
                if let phone = order.ownerPhone, !phone.isEmpty {
                    infoRow(icon: "phone.fill", label: NSLocalizedString("dispatch_owner_phone", comment: ""), value: phone)
                }
                if let addr = order.ownerAddress, !addr.isEmpty {
                    infoRow(icon: "mappin.and.ellipse", label: NSLocalizedString("dispatch_owner_address", comment: ""), value: addr)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(PFColors.surface)
            .cornerRadius(PFRadius.lg)

            Button("btn_close") { dismiss() }
                .font(PFFonts.body)
                .foregroundColor(PFColors.primary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(PFColors.background.ignoresSafeArea())
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(PFColors.primary)
                .frame(width: 24)
            Text(label)
                .font(PFFonts.caption)
                .foregroundColor(PFColors.textSecondary)
            Spacer()
            Text(value)
                .font(PFFonts.callout)
                .foregroundColor(PFColors.textPrimary)
        }
    }
}

// MARK: - 我的接单卡片
struct MyOrderCard: View {
    let order: DispatchOrder
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                if let avatar = order.petAvatar, let url = NetworkManager.fullUrl(avatar) {
                    CachedAsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color.white
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(PFColors.primary.opacity(0.12))
                        .frame(width: 44, height: 44)
                        .overlay(Image(systemName: "pawprint.fill").foregroundColor(PFColors.primary))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // 服务名缺失时用通用文案，避免显示裸 "--"
                    Text(order.serviceName?.isEmpty == false ? order.serviceName! : NSLocalizedString("dispatch_generic_service", comment: ""))
                        .font(PFFonts.body)
                        .foregroundColor(PFColors.textPrimary)
                    if let name = order.petName, !name.isEmpty {
                        Text(name)
                            .font(PFFonts.caption2)
                            .foregroundColor(PFColors.textSecondary)
                    }
                }
                
                Spacer()
                
                // 状态标签
                Text(order.dispatchStatus?.dispatchStatusText ?? "")
                    .font(PFFonts.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(dispatchStatusColor(order.dispatchStatus ?? 0).opacity(0.1))
                    .foregroundColor(dispatchStatusColor(order.dispatchStatus ?? 0))
                    .clipShape(Capsule())
            }
            .padding(PFSpacing.md)
            
            Divider().padding(.horizontal, PFSpacing.md)
            
            // 详细信息
            VStack(spacing: PFSpacing.sm) {
                HStack(spacing: PFSpacing.lg) {
                    if let time = order.reserveStartTime {
                        Label(time, systemImage: "clock.fill")
                            .font(PFFonts.caption2)
                            .foregroundColor(PFColors.textSecondary)
                    }
                    if let income = order.estimatedIncome, income > 0 {
                        Label("¥\(String(format: "%.2f", income))", systemImage: "yensign.circle.fill")
                            .font(PFFonts.caption2)
                            .foregroundColor(PFColors.warning)
                    }
                    Spacer()
                }
                
                // 用户信息
                if let name = order.ownerName {
                    HStack(spacing: PFSpacing.sm) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                            .foregroundColor(PFColors.textTertiary)
                        Text(name)
                            .font(PFFonts.caption2)
                            .foregroundColor(PFColors.textSecondary)
                        if let phone = order.ownerPhone {
                            Text(phone)
                                .font(PFFonts.caption2)
                                .foregroundColor(PFColors.textSecondary)
                        }
                        Spacer()
                    }
                }
            }
            .padding(PFSpacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: PFRadius.lg)
                .fill(PFColors.surface)
        )
        .pfCardShadow()
    }
    
    private func dispatchStatusColor(_ status: Int) -> Color {
        switch status {
        case 0: return PFColors.warning
        case 1: return PFColors.info
        case 2, 3, 4: return PFColors.textSecondary
        case 5: return PFColors.success
        default: return PFColors.textSecondary
        }
    }
}

// MARK: - 订单详情 Sheet（含地图导航 + 服务证明 + 完成/取消）
struct DispatchOrderDetailSheet: View {
    let order: DispatchOrder
    @ObservedObject var viewModel: DispatchHallViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showCancelConfirm = false
    @State private var isProcessing = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var certificateUrl: String = ""
    @State private var isUploading = false
    // B 方案：取消接单 / 完结 确认弹窗
    @State private var cancelOrderDialog: PFActionDialogConfig?
    @State private var completeDialog: PFActionDialogConfig?
    // 详情接口拉取的完整数据
    @State private var detailOrder: DispatchOrder?
    @State private var isLoadingDetail = false
    
    var isMyOrder: Bool
    
    init(order: DispatchOrder, viewModel: DispatchHallViewModel, isMyOrder: Bool = false) {
        self.order = order
        self.viewModel = viewModel
        self.isMyOrder = isMyOrder
    }
    
    /// 优先展示详情接口返回的完整数据，未加载时回退列表数据
    private var displayOrder: DispatchOrder {
        detailOrder ?? order
    }
    
    private var isGrabbed: Bool {
        order.dispatchStatus == 1
    }
    
    private var isCompleted: Bool {
        order.dispatchStatus == 5
    }
    
    private var isCancelled: Bool {
        guard let status = order.dispatchStatus else { return false }
        return status == 2 || status == 3 || status == 4
    }
    
    private var canComplete: Bool {
        guard let createTimeStr = order.createTime else { return false }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let createDate = formatter.date(from: createTimeStr) else { return false }
        let elapsed = Date().timeIntervalSince(createDate)
        return elapsed >= 60 // 超过1分钟
    }
    
    /// 调详情接口拉取完整订单数据（宠物/服务/主人/消费/坐标等更多内容）
    private func loadDetail() async {
        guard let dispatchId = order.dispatchId else { return }
        isLoadingDetail = true
        do {
            let resp: RespWrapper<DispatchOrder> = try await NetworkManager.shared.request(
                "/petFriendly/client/dispatchHall/detail/\(dispatchId)",
                method: .get,
                needToken: true,
                showLoading: false
            )
            await MainActor.run {
                if resp.code == 200, let data = resp.data {
                    detailOrder = data
                }
                isLoadingDetail = false
            }
        } catch {
            await MainActor.run { isLoadingDetail = false }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PFSpacing.lg) {
                    // 宠物信息
                    HStack(spacing: PFSpacing.md) {
                        if let avatar = displayOrder.petAvatar, let url = NetworkManager.fullUrl(avatar) {
                            CachedAsyncImage(url: url) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Color.white
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(displayOrder.petName?.isEmpty == false ? displayOrder.petName! : NSLocalizedString("dispatch_unknown_pet", comment: ""))
                                .font(PFFonts.title2)
                                .foregroundColor(PFColors.textPrimary)
                            if let name = displayOrder.serviceName, !name.isEmpty {
                                Text(name).font(PFFonts.callout).foregroundColor(PFColors.textSecondary)
                            }
                            // 宠物品种/性别信息（详情接口返回时展示）
                            if let species = displayOrder.petSpecies, let breed = displayOrder.petBreeds {
                                Text("\(species) · \(breed)")
                                    .font(PFFonts.caption2)
                                    .foregroundColor(PFColors.textSecondary)
                            }
                            // 状态标签
                            if let status = displayOrder.dispatchStatus {
                                Text(status.dispatchStatusText)
                                    .font(PFFonts.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(dispatchStatusColor(status).opacity(0.1))
                                    .foregroundColor(dispatchStatusColor(status))
                                    .clipShape(Capsule())
                            }
                        }
                        Spacer()
                    }
                    .padding().background(cardBg).pfCardShadow()
                    
                    // 用户信息
                    if isMyOrder || isGrabbed {
                        HStack(spacing: PFSpacing.md) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(PFColors.primary)
                            VStack(alignment: .leading, spacing: 4) {
                                if let name = displayOrder.ownerName {
                                    Text(name)
                                        .font(PFFonts.body)
                                        .foregroundColor(PFColors.textPrimary)
                                }
                                if let phone = displayOrder.ownerPhone {
                                    Text(phone)
                                        .font(PFFonts.caption)
                                        .foregroundColor(PFColors.textSecondary)
                                }
                            }
                            Spacer()
                        }
                        .padding().background(cardBg).pfCardShadow()
                    }
                    
                    // 订单信息（仅有值字段才展示，避免 null 显示裸 "--"）
                    VStack(spacing: PFSpacing.sm) {
                        if let pet = displayOrder.petName, !pet.isEmpty {
                            infoRow(icon: "pawprint.fill", label: NSLocalizedString("dispatch_pet", comment: ""), value: pet)
                        }
                        if let svc = displayOrder.serviceName, !svc.isEmpty {
                            infoRow(icon: "wrench.and.screwdriver.fill", label: NSLocalizedString("dispatch_service", comment: ""), value: svc)
                        }
                        if let req = displayOrder.reserveInformation, !req.isEmpty {
                            infoRow(icon: "note.text", label: NSLocalizedString("dispatch_requirement", comment: ""), value: req)
                        }
                        if let time = displayOrder.reserveStartTime {
                            infoRow(icon: "calendar", label: NSLocalizedString("dispatch_appointment", comment: ""), value: time)
                        }
                        if let endTime = displayOrder.reserveEndTime {
                            infoRow(icon: "clock.arrow.circlepath", label: NSLocalizedString("dispatch_end_time", comment: ""), value: endTime)
                        }
                        if let dist = displayOrder.distance {
                            let distStr = dist > 1000 ? "\(String(format: "%.1f", Double(dist)/1000.0))km" : "\(dist)m"
                            infoRow(icon: "location.fill", label: NSLocalizedString("dispatch_distance", comment: ""), value: distStr)
                        }
                        if let income = displayOrder.estimatedIncome, income > 0 {
                            infoRow(icon: "yensign.circle.fill", label: NSLocalizedString("dispatch_income", comment: ""), value: "¥\(String(format: "%.0f", income))")
                        }
                        if let amount = displayOrder.consumptionAmount, amount > 0 {
                            infoRow(icon: "creditcard.fill", label: NSLocalizedString("dispatch_consumption", comment: ""), value: "¥\(String(format: "%.2f", amount))")
                        }
                        if let completeTime = displayOrder.completeTime {
                            infoRow(icon: "checkmark.circle.fill", label: NSLocalizedString("dispatch_complete_time", comment: ""), value: completeTime)
                        }
                    }
                    .padding().background(cardBg).pfCardShadow()
                    
                    // 服务证明区域（接单后可上传）
                    if isMyOrder && (isGrabbed || isCompleted) {
                        serviceCertificateSection
                    }
                    
                    // 评价信息（已完成且有评价）
                    if isCompleted, let rate = displayOrder.commentRate {
                        VStack(spacing: PFSpacing.sm) {
                            HStack {
                                Text("dispatch_comment")
                                    .font(PFFonts.callout)
                                    .foregroundColor(PFColors.textPrimary)
                                Spacer()
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= rate ? "star.fill" : "star")
                                            .font(.system(size: 12))
                                            .foregroundColor(star <= rate ? PFColors.warning : PFColors.textTertiary)
                                    }
                                }
                            }
                            if let content = displayOrder.commentContent, !content.isEmpty {
                                Text(content)
                                    .font(PFFonts.caption)
                                    .foregroundColor(PFColors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding().background(cardBg).pfCardShadow()
                    }
                    
                    // 操作按钮
                    if isMyOrder {
                        actionButtons
                    } else {
                        // 非我的接单 → 大厅模式：导航+抢单+忽略
                        hallActionButtons
                    }
                }
                .padding(PFSpacing.lg)
            }
            .background(PFColors.background.ignoresSafeArea())
            .navigationTitle("dispatch_detail_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isMyOrder && (isGrabbed || isCompleted) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle").foregroundColor(PFColors.textSecondary)
                        }
                    } else {
                        Button(action: { showCancelConfirm = true }) {
                            Image(systemName: "xmark.circle").foregroundColor(PFColors.textSecondary)
                        }
                    }
                }
            }
            .alert("dispatch_ignore_title", isPresented: $showCancelConfirm) {
                Button("dispatch_ignore", role: .destructive) { dismiss() }
                Button("alert_cancel", role: .cancel) { }
            } message: { Text("dispatch_ignore_msg") }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            // 进入详情页拉取完整详情（展示更多内容）
            .task {
                await loadDetail()
            }
            .onChange(of: selectedImage) { newImage in
                guard let img = newImage else { return }
                uploadCertificate(img)
            }
            // B 方案：取消接单确认弹窗（加载态 + 成功才关）
            .fullScreenCover(item: $cancelOrderDialog) { config in
                PFActionDialog(
                    config: config,
                    onConfirm: { _ in await confirmCancelOrder() },
                    onCancel: { cancelOrderDialog = nil }
                )
            }
            // B 方案：完结订单确认弹窗（加载态 + 成功才关）
            .fullScreenCover(item: $completeDialog) { config in
                PFActionDialog(
                    config: config,
                    onConfirm: { _ in await confirmCompleteOrder() },
                    onCancel: { completeDialog = nil }
                )
            }
        }
    }
    
    // MARK: - 服务证明区域
    private var serviceCertificateSection: some View {
        VStack(spacing: PFSpacing.sm) {
            HStack {
                Image(systemName: "doc.badge.plus")
                    .foregroundColor(PFColors.primary)
                Text("dispatch_certificate_title")
                    .font(PFFonts.callout)
                    .foregroundColor(PFColors.textPrimary)
                Spacer()
            }
            
            // 已有证明图片
            let certUrl = displayOrder.serviceCertificate ?? certificateUrl
            if !certUrl.isEmpty, let url = NetworkManager.fullUrl(certUrl) {
                CachedAsyncImage(url: url) { img in
                    img.resizable().scaledToFit()
                } placeholder: {
                    PFPetLoadingInline(size: 20)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
            }
            
            // 上传按钮
            if !isCompleted && certificateUrl.isEmpty {
                Button(action: { showImagePicker = true }) {
                    HStack {
                        if isUploading {
                            PFPetLoadingInline(size: 16)
                            Text("dispatch_uploading")
                                .font(PFFonts.caption)
                        } else {
                            Image(systemName: "camera.fill")
                                .foregroundColor(PFColors.primary)
                            Text("dispatch_upload_certificate")
                                .font(PFFonts.caption)
                                .foregroundColor(PFColors.primary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(PFColors.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
                }
                .disabled(isUploading)
            }
        }
        .padding().background(cardBg).pfCardShadow()
    }
    
    // MARK: - 我的接单操作按钮
    private var actionButtons: some View {
        VStack(spacing: PFSpacing.md) {
            // 导航按钮
            Button(action: openMapNavigation) {
                HStack {
                    Image(systemName: "map.fill")
                    Text("dispatch_navigate")
                        .font(PFFonts.body)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(PFColors.info)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
            }
            
            if isGrabbed {
                // 完成服务按钮
                Button(action: {
                    if canComplete {
                        completeDialog = PFActionDialogConfig(
                            title: NSLocalizedString("dispatch_complete_confirm_title", comment: ""),
                            message: NSLocalizedString("dispatch_complete_confirm_msg", comment: ""),
                            confirmTitle: NSLocalizedString("dispatch_complete_confirm", comment: ""),
                            destructive: false,
                            confirmIcon: "checkmark.seal.fill"
                        )
                    } else {
                        UIState.shared.showToast(NSLocalizedString("dispatch_complete_time_warning", comment: ""))
                    }
                }) {
                    HStack {
                        if isProcessing { PFPetLoadingInline(size: 16) }
                        Text("dispatch_complete_service")
                            .font(PFFonts.body)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canComplete ? PFColors.success : PFColors.success.opacity(0.5))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
                }
                .disabled(isProcessing)
                
                // 取消接单按钮
                    Button(action: {
                        cancelOrderDialog = PFActionDialogConfig(
                            title: NSLocalizedString("dispatch_cancel_confirm_title", comment: ""),
                            message: NSLocalizedString("dispatch_cancel_confirm_msg", comment: ""),
                            confirmTitle: NSLocalizedString("dispatch_cancel_order", comment: ""),
                            destructive: true,
                            confirmIcon: "xmark.circle.fill"
                        )
                    }) {
                        Text("dispatch_cancel_order")
                            .font(PFFonts.body)
                            .foregroundColor(PFColors.danger)
                    }
            }
            
            if isCompleted {
                // 已完成状态
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(PFColors.success)
                    Text("dispatch_already_completed")
                        .font(PFFonts.body)
                        .foregroundColor(PFColors.success)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(PFColors.success.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
            }
            
            if isCancelled {
                HStack {
                    Image(systemName: "xmark.seal.fill")
                        .foregroundColor(PFColors.textTertiary)
                    Text("dispatch_already_cancelled")
                        .font(PFFonts.body)
                        .foregroundColor(PFColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(PFColors.textSecondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
            }
        }
    }
    
    // MARK: - 大厅操作按钮
    private var hallActionButtons: some View {
        VStack(spacing: PFSpacing.md) {
            // 导航按钮
            Button(action: openMapNavigation) {
                HStack {
                    Image(systemName: "map.fill")
                    Text("dispatch_navigate")
                        .font(PFFonts.body)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(PFColors.info)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
            }
            
            // 抢单按钮
            Button(action: { isProcessing = true
                Task {
                    let result = await viewModel.grabOrder(order)
                    isProcessing = false
                    // B 方案：grabOrder 返回 nil=成功（关弹窗），非 nil=失败（保留）
                    if result == nil { dismiss() }
                }
            }) {
                HStack {
                    if isProcessing { PFPetLoadingInline(size: 16) }
                    Text("dispatch_grab").font(PFFonts.body)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(PFColors.primary).foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
            }
            .disabled(isProcessing)
            
            // 忽略按钮
            Button(action: { dismiss() }) {
                Text("dispatch_ignore")
                    .font(PFFonts.body)
                    .foregroundColor(PFColors.textSecondary)
            }
        }
    }
    
    // MARK: - 上传证明
    private func uploadCertificate(_ image: UIImage) {
        isUploading = true
        Task {
            if let url = await viewModel.uploadCertificate(image, for: order) {
                await MainActor.run {
                    certificateUrl = url
                    isUploading = false
                    UIState.shared.showToast(NSLocalizedString("dispatch_upload_success", comment: ""))
                }
            } else {
                await MainActor.run { isUploading = false }
            }
        }
    }
    
    // MARK: - 取消接单 / 完成订单（B 方案：成功才关弹窗，失败保留可重试）
    @MainActor
    private func confirmCancelOrder() async -> String? {
        guard !isProcessing else { return nil }
        isProcessing = true
        defer { isProcessing = false }
        let result = await viewModel.cancelOrder(order)
        if result == nil {
            dismiss()
        }
        return result
    }

    @MainActor
    private func confirmCompleteOrder() async -> String? {
        guard canComplete else {
            UIState.shared.showToast(NSLocalizedString("dispatch_complete_time_warning", comment: ""))
            return nil
        }
        guard !isProcessing else { return nil }
        isProcessing = true
        defer { isProcessing = false }
        let result = await viewModel.completeOrder(order, certificate: certificateUrl)
        if result == nil {
            dismiss()
        }
        return result
    }
    
    private func openMapNavigation() {
        let address = displayOrder.ownerAddress ?? ""
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "http://maps.apple.com/?daddr=\(encodedAddress)") {
                    UIApplication.shared.open(url)
                }
                return
            }
            let mkPlacemark = MKPlacemark(coordinate: location.coordinate)
            let mapItem = MKMapItem(placemark: mkPlacemark)
            mapItem.name = displayOrder.ownerAddress ?? NSLocalizedString("dispatch_destination", comment: "")
            mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
            ])
        }
    }
    
    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(PFColors.primary)
                .frame(width: 20)
            Text(label)
                .font(PFFonts.caption)
                .foregroundColor(PFColors.textSecondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(PFFonts.callout)
                .foregroundColor(PFColors.textPrimary)
            Spacer()
        }
    }
    
    private var cardBg: some View {
        RoundedRectangle(cornerRadius: PFRadius.lg).fill(PFColors.surface)
    }
    
    private func dispatchStatusColor(_ status: Int) -> Color {
        switch status {
        case 0: return PFColors.warning
        case 1: return PFColors.info
        case 2, 3, 4: return PFColors.textSecondary
        case 5: return PFColors.success
        default: return PFColors.textSecondary
        }
    }
}
