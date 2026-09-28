import SwiftUI
import UIKit
import Alamofire

struct ServiceOrderDetailView: View {
    let order: ServiceOrderRow
    /// 操作成功后回调（父列表刷新）
    var onOrderChanged: (() -> Void)? = nil
    /// 是否显示自定义返回按钮：提交订单后以 fullScreenCover 弹出时需要；列表 push 进入时用系统返回按钮
    var showCloseButton: Bool = false

    @EnvironmentObject var store: AccountStore
    @Environment(\.dismiss) private var dismiss

    // 本地状态覆盖（操作成功后立即刷新 UI，列表通过 onOrderChanged 回刷）
    @State private var statusOverride: Int? = nil
    @State private var payStatusOverride: Int? = nil
    @State private var didRate = false

    private var currentStatus: Int { statusOverride ?? order.status ?? 0 }
    private var currentPayStatus: Int { payStatusOverride ?? order.payStatus ?? 0 }

    // 评价状态
    @State private var rating: Int = 5
    @State private var ratingContent: String = ""
    @State private var isSubmittingRating = false
    @State private var showRatingForm = false
    @State private var ratingImages: [UIImage] = []

    // 退款状态
    @State private var refundReason: String = ""
    @State private var refundAmount: String = ""
    @State private var isSubmittingRefund = false
    @State private var showRefundInput = false

    // 服务证明/完结服务
    @State private var showProofImagePicker = false
    @State private var selectedProofImage: UIImage?
    @State private var proofImageURL: String?
    @State private var isUploadingProof = false

    // 取消订单
    @State private var cancelReason = ""
    @State private var isSubmittingCancel = false

    // 支付（全屏支付密码页）
    @State private var showPaymentGate = false
    @State private var payPassword = ""
    @State private var isSubmittingPay = false

    // B 方案：各类操作确认弹窗（加载态 + 成功才关 + 失败保留可重试）
    @State private var refundDialog: PFActionDialogConfig?
    @State private var ratingDialog: PFActionDialogConfig?
    @State private var cancelDialog: PFActionDialogConfig?
    @State private var receiptDialog: PFActionDialogConfig?
    @State private var providerRatingDialog: PFActionDialogConfig?
    @State private var completeDialog: PFActionDialogConfig?

    // 上报进度
    @State private var showProgressForm = false
    @State private var progressImages: [UIImage] = []
    @State private var isSubmittingProgress = false

    // 服务商评价客户
    @State private var showProviderRatingForm = false
    @State private var providerRating: Int = 5
    @State private var providerRatingContent = ""
    @State private var providerRatingImages: [UIImage] = []
    @State private var isSubmittingProviderRating = false

    /// 通用动作（确认接单/开始服务/确认收货等）运行标记，防止重复点击
    @State private var runningAction: String? = nil

    // MARK: - 角色判定
    /// 用户视角：order.userId == 当前登录用户
    private var isCurrentUserOrder: Bool {
        guard let uid = store.user?.userId, let oid = order.userId else { return false }
        return uid == oid
    }

    /// 服务商视角：order.providerUserId == 当前登录用户
    private var isProviderOrder: Bool {
        guard let uid = store.user?.userId, let pid = order.providerUserId else { return false }
        return uid == pid
    }

    // 是否可以评价（status=5 待评价 / 6 已办结且未评价）
    private var canRate: Bool {
        guard isCurrentUserOrder || order.userId == nil else { return false }
        guard order.commentRate == nil, !didRate else { return false }
        return currentStatus == 5 || currentStatus == 6
    }

    // 是否已评价
    private var hasRated: Bool {
        order.commentRate != nil || currentStatus == 12 || currentStatus == 15
    }

    // 是否可以退款（status=3 等待派单 或 status=4 进行中；未支付订单不支持退款）
    private var canRefund: Bool {
        guard currentPayStatus != 0 else { return false }
        return currentStatus == 3 || currentStatus == 4
    }

    // 是否已退款/取消
    private var isRefunded: Bool {
        currentStatus == 7 || currentStatus == 13 || currentStatus == 14
    }

    /// 任何动作进行中（统一禁用按钮防重复提交）
    private var isBusy: Bool {
        runningAction != nil || isSubmittingCancel || isSubmittingPay || isSubmittingRating
            || isSubmittingRefund || isUploadingProof || isSubmittingProgress || isSubmittingProviderRating
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PFSpacing.lg) {
                headerStatusCard
                
                // 1.1.0 操作区：角色 + 状态矩阵
                actionButtonsSection
                
                // 根据服务类型展示特色卡片
                // 以 2 代表打车（taxi），根据业务后端返回逻辑延展
                if let type = order.serviceType {
                    if type == 2 {
                        taxiFocusCard
                    } else if type == 1 {
                        mallFocusCard
                    } else if type == 3 {
                        emergencyFocusCard
                    } else {
                        genericFocusCard
                    }
                } else {
                    genericFocusCard
                }
                
                standardDetailGrid
                serviceCertificateCard
                financeCard
                remarkCard
                
                // 评价区
                ratingSection
                
                // 退款区
                refundSection
                
                // 服务商评价客户区
                providerRatingSection
            }
            .padding(PFSpacing.lg)
            .padding(.bottom, 20)
        }
        .background(PFColors.background.ignoresSafeArea())
        .navigationTitle("order_detail_title")
        .navigationBarTitleDisplayMode(.inline)
        // 全屏支付密码页（替代原先的 .alert + SecureField 默认键盘输入）
        .fullScreenCover(isPresented: $showPaymentGate) {
            PaymentPasswordGate(
                title: "order_pay",
                amount: order.actualAmount ?? order.consumptionAmount ?? 0,
                onCancel: { showPaymentGate = false },
                onConfirm: submitPayWithPassword
            )
        }
        // B 方案：各类操作确认弹窗（加载态 + 成功才关 + 失败保留可重试）
        .fullScreenCover(item: $refundDialog) { config in
            PFActionDialog(config: config,
                           onConfirm: { _ in await confirmRefund() },
                           onCancel: { refundDialog = nil })
        }
        .fullScreenCover(item: $ratingDialog) { config in
            PFActionDialog(config: config,
                           onConfirm: { _ in await confirmRating() },
                           onCancel: { ratingDialog = nil })
        }
        .fullScreenCover(item: $cancelDialog) { config in
            PFActionDialog(config: config,
                           onConfirm: { reason in await confirmCancel(reason: reason) },
                           onCancel: { cancelDialog = nil; cancelReason = "" })
        }
        .fullScreenCover(item: $receiptDialog) { config in
            PFActionDialog(config: config,
                           onConfirm: { _ in await confirmReceipt() },
                           onCancel: { receiptDialog = nil })
        }
        .fullScreenCover(item: $providerRatingDialog) { config in
            PFActionDialog(config: config,
                           onConfirm: { _ in await confirmProviderRating() },
                           onCancel: { providerRatingDialog = nil })
        }
        .fullScreenCover(item: $completeDialog) { config in
            PFActionDialog(config: config,
                           onConfirm: { _ in await confirmComplete() },
                           onCancel: { completeDialog = nil })
        }
        .sheet(isPresented: $showProofImagePicker) {
            ImagePicker(image: $selectedProofImage)
        }
        .onChange(of: selectedProofImage) { newImage in
            if let img = newImage {
                uploadProofImage(img)
            }
            selectedProofImage = nil
        }
        // 顶部关闭/返回按钮：仅提交订单后以 fullScreenCover 弹出详情页时显示；
        // 从订单列表 push 进入时复用系统返回按钮，避免出现两个返回按钮
        .toolbar {
            if showCloseButton {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(PFColors.textPrimary)
                    }
                }
            }
        }
    }
    
    // MARK: - 头部状态
    private var headerStatusCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(statusText(for: currentStatus))
                    .font(PFFonts.title2)
                    .foregroundColor(statusColor(for: currentStatus))
                    .fontWeight(.bold)
                
                Text(order.serviceName ?? NSLocalizedString("person_my_services", comment: ""))
                    .font(PFFonts.callout)
                    .foregroundColor(PFColors.textSecondary)
            }
            Spacer()
            // 右侧图标
            ZStack {
                Circle()
                    .fill(statusColor(for: currentStatus).opacity(0.12))
                    .frame(width: 50, height: 50)
                Image(systemName: iconForServiceType(order.serviceType ?? 0))
                    .font(.system(size: 24))
                    .foregroundColor(statusColor(for: currentStatus))
            }
        }
        .padding(PFSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: PFRadius.lg)
                .fill(PFColors.surface)
        )
        .pfCardShadow()
    }
    
    // MARK: - 操作区（角色 + 状态矩阵）
    @ViewBuilder
    private var actionButtonsSection: some View {
        let userActions = userActionItems
        let providerActions = providerActionItems
        if !userActions.isEmpty || !providerActions.isEmpty {
            VStack(spacing: PFSpacing.md) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(PFColors.primary)
                    Text("order_actions_title")
                        .font(PFFonts.headline)
                        .foregroundColor(PFColors.textPrimary)
                    Spacer()
                }
                
                Divider()
                
                if !userActions.isEmpty {
                    ForEach(userActions) { item in
                        actionButton(item)
                    }
                }
                if !providerActions.isEmpty {
                    ForEach(providerActions) { item in
                        actionButton(item)
                    }
                }
                
                // 服务证明已上传预览
                if isProviderOrder, currentStatus == 4, let url = proofImageURL, let full = NetworkManager.fullUrl(url) {
                    HStack(spacing: 8) {
                        CachedAsyncImage(url: full) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            PFPetLoadingInline(size: 14)
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .clipped()
                        Text("order_proof_uploaded")
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.success)
                        Spacer()
                    }
                }
                
                // 上报进度表单
                if showProgressForm {
                    progressForm
                }
            }
            .padding(PFSpacing.lg)
            .background(cardBackground)
        }
    }
    
    private struct OrderAction: Identifiable {
        let id: String
        let icon: String
        let title: String
        let color: Color
        let action: () -> Void
    }
    
    /// 用户视角操作（status 2/3/16/17/4 取消+支付；5 确认服务+评价；6 评价+申请售后）
    private var userActionItems: [OrderAction] {
        guard isCurrentUserOrder else { return [] }
        var items: [OrderAction] = []
        let s = currentStatus
        
        if [2, 3, 16, 17, 4].contains(s) {
            items.append(OrderAction(id: "cancel", icon: "xmark.circle.fill", title: NSLocalizedString("order_cancel", comment: ""), color: PFColors.danger) {
                cancelReason = ""
                presentCancelDialog()
            })
            if currentPayStatus == 0, let amount = order.consumptionAmount, amount > 0 {
                items.append(OrderAction(id: "pay", icon: "creditcard.fill", title: NSLocalizedString("order_pay", comment: ""), color: PFColors.warning) {
                    payPassword = ""
                    showPaymentGate = true
                })
            }
        }
        
        if s == 5 {
            items.append(OrderAction(id: "confirmReceipt", icon: "checkmark.seal.fill", title: NSLocalizedString("order_confirm_receipt", comment: ""), color: PFColors.success) {
                presentReceiptDialog()
            })
        }
        
        if (s == 5 || s == 6) && order.commentRate == nil && !didRate {
            items.append(OrderAction(id: "rate", icon: "star.fill", title: NSLocalizedString("order_rate_service", comment: ""), color: PFColors.warning) {
                showRatingForm = true
                Haptics.play(.light)
            })
        }
        
        if s == 6 {
            items.append(OrderAction(id: "aftersale", icon: "arrow.uturn.backward.circle.fill", title: NSLocalizedString("order_after_sale_apply", comment: ""), color: PFColors.accent) {
                UIState.shared.showToast(NSLocalizedString("after_sale_coming_soon", comment: ""))
            })
        }
        return items
    }
    
    /// 服务商视角操作（16 确认接单；17 开始服务；4 上报进度+完结服务；16/17/4/5 取消；6 评价客户）
    private var providerActionItems: [OrderAction] {
        guard isProviderOrder else { return [] }
        var items: [OrderAction] = []
        let s = currentStatus
        
        if s == 16 {
            items.append(OrderAction(id: "accept", icon: "hand.thumbsup.fill", title: NSLocalizedString("order_confirm_accept", comment: ""), color: PFColors.success) {
                performSimpleAction("accept",
                                    path: "/petFriendly/client/service/order/confirm",
                                    params: [:],
                                    successStatus: 17,
                                    successKey: "order_confirm_accept_success")
            })
        }
        
        if s == 17 {
            items.append(OrderAction(id: "start", icon: "play.fill", title: NSLocalizedString("order_start_service", comment: ""), color: PFColors.info) {
                performSimpleAction("start",
                                    path: "/petFriendly/client/service/order/start",
                                    params: [:],
                                    successStatus: 4,
                                    successKey: "order_start_service_success")
            })
        }
        
        if s == 4 {
            items.append(OrderAction(id: "progress", icon: "photo.on.rectangle.angled", title: NSLocalizedString("order_report_progress", comment: ""), color: PFColors.info) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showProgressForm.toggle()
                }
            })
            items.append(OrderAction(id: "complete", icon: "checkmark.circle.fill", title: NSLocalizedString("order_complete_service", comment: ""), color: PFColors.success) {
                if proofImageURL == nil {
                    UIState.shared.showToast(NSLocalizedString("order_proof_first", comment: ""))
                    showProofImagePicker = true
                } else {
                    completeDialog = PFActionDialogConfig(
                        title: NSLocalizedString("order_action_confirm_complete", comment: ""),
                        message: NSLocalizedString("order_action_confirm_complete_desc", comment: ""),
                        confirmTitle: NSLocalizedString("order_complete_service", comment: ""),
                        destructive: false,
                        confirmIcon: "checkmark.circle.fill"
                    )
                }
            })
        }
        
        if [16, 17, 4, 5].contains(s) {
            items.append(OrderAction(id: "cancel", icon: "xmark.circle.fill", title: NSLocalizedString("order_cancel", comment: ""), color: PFColors.danger) {
                cancelReason = ""
                presentCancelDialog()
            })
        }
        
        if s == 6 {
            items.append(OrderAction(id: "providerRate", icon: "star.circle.fill", title: NSLocalizedString("order_provider_evaluate", comment: ""), color: PFColors.warning) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showProviderRatingForm = true
                }
            })
        }
        return items
    }
    
    private func actionButton(_ item: ServiceOrderDetailView.OrderAction) -> some View {
        Button(action: item.action) {
            HStack(spacing: 6) {
                if runningAction == item.id {
                    PFPetLoadingInline(size: 15)
                } else {
                    Image(systemName: item.icon)
                }
                Text(item.title)
                    .font(PFFonts.body)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(item.color)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isBusy)
        .opacity(isBusy ? 0.6 : 1)
    }
    
    // MARK: - 上报进度表单
    private var progressForm: some View {
        VStack(spacing: PFSpacing.md) {
            Text("order_report_progress_title")
                .font(PFFonts.callout)
                .foregroundColor(PFColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            PFMultiImagePickerRow(
                title: NSLocalizedString("order_report_progress", comment: ""),
                images: $progressImages,
                maxCount: 6
            )
            
            Button(action: submitProgress) {
                HStack {
                    if isSubmittingProgress {
                        PFPetLoadingInline(size: 15)
                    }
                    Text("order_progress_confirm")
                        .font(PFFonts.body)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(PFColors.info)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
            }
            .disabled(isSubmittingProgress || progressImages.isEmpty || isBusy)
            .opacity((isSubmittingProgress || progressImages.isEmpty || isBusy) ? 0.6 : 1)
        }
        .padding(PFSpacing.md)
        .background(PFColors.surfaceSecondary)
        .cornerRadius(PFRadius.md)
    }
    
    // MARK: - 专车特色卡片
    private var taxiFocusCard: some View {
        VStack(alignment: .leading, spacing: PFSpacing.md) {
            Label("order_section_trip", systemImage: "car.fill")
                .font(PFFonts.headline)
                .foregroundColor(PFColors.primary)
            
            Divider()
            
            infoRow(title: NSLocalizedString("order_field_trip_req", comment: ""), value: order.reserveInformation ?? NSLocalizedString("boarding_not_filled", comment: ""))
            if let start = order.reserveStartTime {
                infoRow(title: NSLocalizedString("order_field_start_time", comment: ""), value: start)
            }
            if let end = order.reserveEndTime {
                infoRow(title: NSLocalizedString("order_field_end_time", comment: ""), value: end)
            }
            infoRow(title: NSLocalizedString("order_field_contact", comment: ""), value: order.phoneInformation ?? NSLocalizedString("login_username_placeholder", comment: ""))
            
            if let info = order.serviceInformation {
                serviceInformationBlock(info)
            }
        }
        .padding(PFSpacing.lg)
        .background(cardBackground)
    }
    
    // MARK: - 商城/商品特色卡片
    private var mallFocusCard: some View {
        VStack(alignment: .leading, spacing: PFSpacing.md) {
            Label("order_section_goods", systemImage: "cart.fill")
                .font(PFFonts.headline)
                .foregroundColor(PFColors.warning)
            
            Divider()
            
            HStack(alignment: .top, spacing: PFSpacing.md) {
                if let imgUrl = order.ext, URL(string: imgUrl) != nil {
                    CachedAsyncImage(url: NetworkManager.fullUrl(imgUrl)) { image in
                        image.resizable().scaledToFill()
                } placeholder: {
                    PFPetLoadingInline(size: 14)
                }
                .frame(width: 60, height: 60)
                .cornerRadius(PFRadius.md)
                .clipped()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.serviceName ?? "--")
                        .font(PFFonts.body)
                        .foregroundColor(PFColors.textPrimary)
                    
                    if let amount = order.actualAmount {
                        Text(String(format: NSLocalizedString("points_amount", comment: ""), amount))
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.warning)
                    }
                }
            }
            .padding(.vertical, 4)
            
            Divider()
            
            infoRow(title: NSLocalizedString("order_field_contact", comment: ""), value: order.phoneInformation ?? "--")
            
            if let info = order.serviceInformation {
                serviceInformationBlock(info)
            }
        }
        .padding(PFSpacing.lg)
        .background(cardBackground)
    }

    // MARK: - 急救特色卡片
    private var emergencyFocusCard: some View {
        VStack(alignment: .leading, spacing: PFSpacing.md) {
            Label("order_section_rescue", systemImage: "cross.case.fill")
                .font(PFFonts.headline)
                .foregroundColor(PFColors.danger)
            
            Divider()
            
            infoRow(title: NSLocalizedString("order_field_rescue_pet", comment: ""), value: order.reserveInformation ?? NSLocalizedString("person_no_nickname", comment: ""))
            infoRow(title: NSLocalizedString("order_field_contact", comment: ""), value: order.phoneInformation ?? NSLocalizedString("boarding_not_filled", comment: ""))
            
            if let info = order.serviceInformation {
                serviceInformationBlock(info)
            }
        }
        .padding(PFSpacing.lg)
        .background(cardBackground)
    }

    // MARK: - 通用特色卡片
    private var genericFocusCard: some View {
        Group {
            if order.reserveInformation != nil || order.serviceInformation != nil {
                VStack(alignment: .leading, spacing: PFSpacing.md) {
                    Label("order_section_detail", systemImage: "list.clipboard.fill")
                        .font(PFFonts.headline)
                        .foregroundColor(PFColors.primary)
                    
                    Divider()
                    
                    if let req = order.reserveInformation {
                        infoRow(title: NSLocalizedString("order_field_req_content", comment: ""), value: req)
                    }
                    if let phone = order.phoneInformation {
                        infoRow(title: NSLocalizedString("order_field_contact", comment: ""), value: phone)
                    }
                    
                    if let info = order.serviceInformation {
                        serviceInformationBlock(info)
                    }
                }
                .padding(PFSpacing.lg)
                .background(cardBackground)
            }
        }
    }

    private func serviceInformationBlock(_ info: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("order_field_core_info")
                .font(PFFonts.caption)
                .foregroundColor(PFColors.textTertiary)
            Text(info)
                .font(PFFonts.body)
                .foregroundColor(PFColors.textPrimary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PFColors.surfaceSecondary)
                .cornerRadius(PFRadius.md)
        }
        .padding(.top, 4)
    }
    
    // MARK: - 通用详情网格
    private var standardDetailGrid: some View {
        VStack(spacing: PFSpacing.md) {
            infoRow(title: NSLocalizedString("order_field_id", comment: ""), value: order.consumerId.map { String($0) } ?? NSLocalizedString("boarding_not_filled", comment: ""))
            infoRow(title: NSLocalizedString("order_field_create_time", comment: ""), value: order.createTime ?? "--")
            if let startTime = order.reserveStartTime {
                infoRow(title: NSLocalizedString("order_field_reserve_start", comment: ""), value: startTime)
            }
            if let endTime = order.reserveEndTime {
                infoRow(title: NSLocalizedString("order_field_reserve_end", comment: ""), value: endTime)
            }
            if let req = order.reserveInformation {
                infoRow(title: NSLocalizedString("order_field_requirement", comment: ""), value: req)
            }
            if let aptTime = order.appointmentTime {
                infoRow(title: NSLocalizedString("order_field_respond_time", comment: ""), value: aptTime)
            }
            if let srvTime = order.serviceTime {
                infoRow(title: NSLocalizedString("order_field_service_time", comment: ""), value: srvTime)
            }
            if let dnTime = order.downTime {
                infoRow(title: NSLocalizedString("order_field_finish_time", comment: ""), value: dnTime)
            }
            if let refundReason = order.refundReason {
                infoRow(title: NSLocalizedString("order_field_refund_reason", comment: ""), value: refundReason)
            }
        }
        .padding(PFSpacing.lg)
        .background(cardBackground)
    }
    
    // MARK: - 财务卡片
    private var financeCard: some View {
        VStack(spacing: PFSpacing.md) {
            if let rawAmount = order.consumptionAmount {
                infoRow(title: NSLocalizedString("order_field_total_amount", comment: ""), value: formatAmt(rawAmount))
            }
            if let refund = order.refundAmount, refund > 0 {
                infoRow(title: NSLocalizedString("order_field_refunded", comment: ""), value: "- " + formatAmt(refund), valueColor: PFColors.danger)
            }
            Divider()
            
            HStack {
                Text("order_field_actual_pay")
                    .font(PFFonts.callout)
                    .foregroundColor(PFColors.textPrimary)
                Spacer()
                Text(order.actualAmount.map { formatAmt($0) } ?? "¥ 0.00")
                    .font(PFFonts.title2)
                    .foregroundColor(PFColors.warning)
                    .fontWeight(.bold)
            }
            
        }
        .padding(PFSpacing.lg)
        .background(cardBackground)
    }
    
    // MARK: - 备注与凭证
    @ViewBuilder
    private var remarkCard: some View {
        if let remark = order.remark, !remark.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("order_section_remark", systemImage: "note.text")
                    .font(PFFonts.headline)
                    .foregroundColor(PFColors.textPrimary)
                
                Text(remark)
                    .font(PFFonts.body)
                    .foregroundColor(PFColors.textSecondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PFColors.surfaceSecondary)
                    .cornerRadius(PFRadius.md)
            }
            .padding(PFSpacing.lg)
            .background(cardBackground)
        }
    }
    
    // MARK: - 服务证明卡片
    @ViewBuilder
    private var serviceCertificateCard: some View {
        if let cert = order.serviceCertificate, !cert.isEmpty, let url = NetworkManager.fullUrl(cert) {
            VStack(alignment: .leading, spacing: PFSpacing.sm) {
                Label("order_section_certificate", systemImage: "doc.badge.checkmark")
                    .font(PFFonts.headline)
                    .foregroundColor(PFColors.primary)
                
                CachedAsyncImage(url: url) { img in
                    img.resizable().scaledToFit()
                } placeholder: {
                    PFPetLoadingInline(size: 20)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
            }
            .padding(PFSpacing.lg)
            .background(cardBackground)
        }
    }
    
    // MARK: - 评价区（用户视角，POST /service/order/evaluate）
    @ViewBuilder
    private var ratingSection: some View {
        if canRate || showRatingForm || hasRated || (order.commentRate != nil) {
            VStack(spacing: PFSpacing.md) {
                HStack {
                    Image(systemName: "star.bubble.fill")
                        .foregroundColor(PFColors.warning)
                    Text("order_section_rating")
                        .font(PFFonts.headline)
                        .foregroundColor(PFColors.textPrimary)
                    Spacer()
                }
                
                Divider()
                
                if hasRated || (order.commentRate != nil) {
                    // 已评价 - 显示评价内容
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= (order.commentRate ?? 0) ? "star.fill" : "star")
                                .font(.system(size: 16))
                                .foregroundColor(star <= (order.commentRate ?? 0) ? PFColors.warning : PFColors.surfaceSecondary)
                        }
                    }
                    
                    if let content = order.commentContent, !content.isEmpty {
                        Text(content)
                            .font(PFFonts.body)
                            .foregroundColor(PFColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(PFColors.surfaceSecondary)
                            .cornerRadius(PFRadius.md)
                    }
                } else {
                    // 待评价 - 显示评价输入
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 28))
                                .foregroundColor(star <= rating ? PFColors.warning : PFColors.surfaceSecondary)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        rating = star
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 8)
                    
                    PFTextEditor(placeholder: NSLocalizedString("order_rating_placeholder", comment: ""), text: $ratingContent, height: 90)
                    
                    PFMultiImagePickerRow(
                        title: NSLocalizedString("order_rating_images_hint", comment: ""),
                        images: $ratingImages,
                        maxCount: 3
                    )
                    
                    Button(action: { presentRatingDialog() }) {
                        HStack {
                            if isSubmittingRating {
                                PFPetLoadingInline(size: 16)
                            }
                            Text("form_submit")
                                .font(PFFonts.body)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(PFColors.primary)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
                    }
                    .disabled(isSubmittingRating || isBusy)
                    .opacity((isSubmittingRating || isBusy) ? 0.6 : 1)
                }
            }
            .padding(PFSpacing.lg)
            .background(cardBackground)
        }
    }
    
    // MARK: - 服务商评价客户区
    @ViewBuilder
    private var providerRatingSection: some View {
        if showProviderRatingForm {
            VStack(spacing: PFSpacing.md) {
                HStack {
                    Image(systemName: "star.circle.fill")
                        .foregroundColor(PFColors.warning)
                    Text("order_provider_evaluate_title")
                        .font(PFFonts.headline)
                        .foregroundColor(PFColors.textPrimary)
                    Spacer()
                }
                
                Divider()
                
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= providerRating ? "star.fill" : "star")
                            .font(.system(size: 26))
                            .foregroundColor(star <= providerRating ? PFColors.warning : PFColors.surfaceSecondary)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    providerRating = star
                                }
                            }
                    }
                }
                .padding(.vertical, 8)
                
                PFTextEditor(placeholder: NSLocalizedString("order_rating_placeholder", comment: ""), text: $providerRatingContent, height: 90)
                
                PFMultiImagePickerRow(
                    title: NSLocalizedString("order_rating_images_hint", comment: ""),
                    images: $providerRatingImages,
                    maxCount: 3
                )
                
                Button(action: { presentProviderRatingDialog() }) {
                    HStack {
                        if isSubmittingProviderRating {
                            PFPetLoadingInline(size: 16)
                        }
                        Text("form_submit")
                            .font(PFFonts.body)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(PFColors.warning)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
                }
                .disabled(isSubmittingProviderRating || isBusy)
                .opacity((isSubmittingProviderRating || isBusy) ? 0.6 : 1)
            }
            .padding(PFSpacing.lg)
            .background(cardBackground)
        }
    }
    
    // MARK: - 退款区
    @ViewBuilder
    private var refundSection: some View {
        if canRefund {
            VStack(spacing: PFSpacing.md) {
                HStack {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .foregroundColor(PFColors.danger)
                    Text("order_section_refund")
                        .font(PFFonts.headline)
                        .foregroundColor(PFColors.textPrimary)
                    Spacer()
                }
                
                Divider()
                
                if showRefundInput {
                    VStack(spacing: PFSpacing.sm) {
                        TextField("order_refund_reason_placeholder", text: $refundReason)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(PFFonts.body)
                        
                        if let amount = order.consumptionAmount, amount > 0 {
                            TextField("order_refund_amount_placeholder", text: $refundAmount)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(PFFonts.body)
                                .keyboardType(.decimalPad)
                        }
                    }
                }
                
                Button(action: {
                    withAnimation {
                        showRefundInput.toggle()
                        if !showRefundInput {
                            // 提交退款申请（B 方案确认弹窗）
                            presentRefundDialog()
                        }
                    }
                }) {
                    HStack {
                        if isSubmittingRefund {
                            PFPetLoadingInline(size: 16)
                        }
                        Text(showRefundInput ? "order_refund_submit" : "order_refund_apply")
                            .font(PFFonts.body)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(PFColors.danger)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
                }
                .disabled(isSubmittingRefund || (showRefundInput && (refundReason.isEmpty || (!refundAmount.isEmpty && Double(refundAmount) == nil))))
                .opacity((isSubmittingRefund || (showRefundInput && (refundReason.isEmpty || (!refundAmount.isEmpty && Double(refundAmount) == nil)))) ? 0.6 : 1)
            }
            .padding(PFSpacing.lg)
            .background(cardBackground)
        } else if isRefunded {
            // 已退款状态显示
            VStack(spacing: PFSpacing.sm) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(PFColors.textTertiary)
                    Text("order_refund_completed")
                        .font(PFFonts.callout)
                        .foregroundColor(PFColors.textTertiary)
                    Spacer()
                }
                if let reason = order.refundReason, !reason.isEmpty {
                    Text(reason)
                        .font(PFFonts.caption)
                        .foregroundColor(PFColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let refundAmt = order.refundAmount, refundAmt > 0 {
                    HStack {
                        Text("order_field_refunded")
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.textSecondary)
                        Spacer()
                        Text("- " + formatAmt(refundAmt))
                            .font(PFFonts.headline)
                            .foregroundColor(PFColors.danger)
                    }
                }
            }
            .padding(PFSpacing.lg)
            .background(cardBackground)
        }
    }
    
    // MARK: - 提交评价（用户，POST /service/order/evaluate，B 方案）
    private func presentRatingDialog() {
        ratingDialog = PFActionDialogConfig(
            title: NSLocalizedString("order_rating_confirm_title", comment: ""),
            message: NSLocalizedString("order_rating_confirm_msg", comment: ""),
            confirmTitle: NSLocalizedString("form_submit", comment: ""),
            destructive: true,
            confirmIcon: "star.fill"
        )
    }

    @MainActor
    private func confirmRating() async -> String? {
        guard !isSubmittingRating, let consumerId = order.consumerId else { return nil }
        isSubmittingRating = true
        defer { isSubmittingRating = false }

        do {
            var imagesParam = ""
            if !ratingImages.isEmpty {
                var urls: [String] = []
                for img in ratingImages {
                    let url: String = try await NetworkManager.shared.uploadImage(img, to: "/petFriendly/client/upload")
                    urls.append(url)
                }
                imagesParam = urls.joined(separator: ",")
            }
            let params: [String: Any] = [
                "consumerId": consumerId,
                "rate": rating,
                "comments": ratingContent,
                "images": imagesParam
            ]
            let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                "/petFriendly/client/service/order/evaluate",
                method: .post,
                parameters: params,
                encoding: JSONEncoding.default,
                needToken: true
            )
            if resp.code == 200 {
                UIState.shared.showToast(NSLocalizedString("order_rating_success", comment: ""))
                Haptics.notify(.success)
                didRate = true
                statusOverride = 6
                showRatingForm = false
                onOrderChanged?()
                return nil
            }
            return resp.msg ?? NSLocalizedString("common_unknown", comment: "")
        } catch {
            return error.localizedDescription
        }
    }
    
    // MARK: - 服务商评价客户（POST /service/order/providerEvaluate，B 方案）
    private func presentProviderRatingDialog() {
        providerRatingDialog = PFActionDialogConfig(
            title: NSLocalizedString("order_provider_evaluate_title", comment: ""),
            message: NSLocalizedString("order_provider_evaluate_confirm_msg", comment: ""),
            confirmTitle: NSLocalizedString("form_submit", comment: ""),
            destructive: true,
            confirmIcon: "star.circle.fill"
        )
    }

    @MainActor
    private func confirmProviderRating() async -> String? {
        guard !isSubmittingProviderRating, let consumerId = order.consumerId else { return nil }
        isSubmittingProviderRating = true
        defer { isSubmittingProviderRating = false }

        do {
            var imagesParam = ""
            if !providerRatingImages.isEmpty {
                var urls: [String] = []
                for img in providerRatingImages {
                    let url: String = try await NetworkManager.shared.uploadImage(img, to: "/petFriendly/client/upload")
                    urls.append(url)
                }
                imagesParam = urls.joined(separator: ",")
            }
            let params: [String: Any] = [
                "consumerId": consumerId,
                "rate": providerRating,
                "comment": providerRatingContent,
                "images": imagesParam
            ]
            let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                "/petFriendly/client/service/order/providerEvaluate",
                method: .post,
                parameters: params,
                encoding: JSONEncoding.default,
                needToken: true
            )
            if resp.code == 200 {
                UIState.shared.showToast(NSLocalizedString("order_provider_evaluate_success", comment: ""))
                Haptics.notify(.success)
                showProviderRatingForm = false
                onOrderChanged?()
                return nil
            }
            return resp.msg ?? NSLocalizedString("common_unknown", comment: "")
        } catch {
            return error.localizedDescription
        }
    }
    
    // MARK: - 提交退款（B 方案：成功才关弹窗，失败保留可重试）
    private func presentRefundDialog() {
        refundDialog = PFActionDialogConfig(
            title: NSLocalizedString("order_refund_confirm_title", comment: ""),
            message: NSLocalizedString("order_refund_confirm_msg", comment: ""),
            confirmTitle: NSLocalizedString("order_refund_confirm", comment: ""),
            destructive: true,
            confirmIcon: "arrow.uturn.backward.circle.fill"
        )
    }

    @MainActor
    private func confirmRefund() async -> String? {
        guard !isSubmittingRefund else { return nil }
        isSubmittingRefund = true
        defer { isSubmittingRefund = false }

        let params: [String: Any] = [
            "consumerId": order.consumerId ?? 0,
            "refundAmount": Double(refundAmount) ?? order.consumptionAmount ?? 0,
            "reason": refundReason
        ]

        do {
            let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                "/petFriendly/client/service/order/refund",
                method: .post,
                parameters: params,
                encoding: JSONEncoding.default,
                needToken: true
            )
            if resp.code == 200 {
                UIState.shared.showToast(NSLocalizedString("order_refund_success", comment: ""))
                statusOverride = 7
                onOrderChanged?()
                return nil
            }
            return resp.msg ?? NSLocalizedString("common_unknown", comment: "")
        } catch {
            return error.localizedDescription
        }
    }
    
    // MARK: - 取消订单（POST /service/order/cancel，B 方案）
    private func presentCancelDialog() {
        cancelReason = ""
        cancelDialog = PFActionDialogConfig(
            title: NSLocalizedString("order_cancel_confirm_title", comment: ""),
            message: NSLocalizedString("order_cancel_confirm_msg", comment: ""),
            confirmTitle: NSLocalizedString("order_cancel", comment: ""),
            destructive: true,
            confirmIcon: "xmark.circle.fill",
            showTextField: true,
            textFieldPlaceholder: NSLocalizedString("order_cancel_reason_placeholder", comment: "")
        )
    }

    @MainActor
    private func confirmCancel(reason: String) async -> String? {
        guard !isSubmittingCancel, let consumerId = order.consumerId else { return nil }
        isSubmittingCancel = true
        defer { isSubmittingCancel = false }
        let reason = reason.trimmingCharacters(in: .whitespacesAndNewlines)

        let params: [String: Any] = [
            "consumerId": consumerId,
            "reason": reason
        ]
        do {
            let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                "/petFriendly/client/service/order/cancel",
                method: .post,
                parameters: params,
                encoding: JSONEncoding.default,
                needToken: true
            )
            if resp.code == 200 {
                UIState.shared.showToast(NSLocalizedString("order_cancel_success", comment: ""))
                Haptics.notify(.success)
                // 用户取消 → 7；服务商取消 → 回 3 重新派单
                statusOverride = isCurrentUserOrder ? 7 : 3
                cancelReason = ""
                onOrderChanged?()
                return nil
            }
            return resp.msg ?? NSLocalizedString("common_unknown", comment: "")
        } catch {
            return error.localizedDescription
        }
    }
    
    // MARK: - 支付（POST /wallet/pay）
    /// 全屏支付密码页确认回调：返回 nil 表示支付成功（PaymentPasswordGate 会关闭弹窗），否则返回错误提示
    private func submitPayWithPassword(_ password: String) async -> String? {
        guard let consumerId = order.consumerId else { return NSLocalizedString("common_unknown", comment: "") }
        isSubmittingPay = true
        defer { isSubmittingPay = false }
        do {
            let params: [String: Any] = [
                "consumerId": consumerId,
                "payPassword": password
            ]
            let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                "/petFriendly/client/wallet/pay",
                method: .post,
                parameters: params,
                encoding: JSONEncoding.default,
                needToken: true,
                showLoading: false
            )
            if resp.code == 200 {
                await MainActor.run {
                    UIState.shared.showToast(NSLocalizedString("order_pay_success", comment: ""))
                    Haptics.notify(.success)
                    payStatusOverride = 1
                    payPassword = ""
                    onOrderChanged?()
                }
                return nil
            }
            return resp.msg ?? NSLocalizedString("common_unknown", comment: "")
        } catch {
            return error.localizedDescription
        }
    }
    
    // MARK: - 上报进度（POST /service/order/progress）
    private func submitProgress() {
        guard !isSubmittingProgress, !progressImages.isEmpty, let consumerId = order.consumerId else { return }
        isSubmittingProgress = true
        
        Task {
            do {
                var urls: [String] = []
                for img in progressImages {
                    let url: String = try await NetworkManager.shared.uploadImage(img, to: "/petFriendly/client/upload")
                    urls.append(url)
                }
                let params: [String: Any] = [
                    "consumerId": consumerId,
                    "images": urls.joined(separator: ",")
                ]
                let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                    "/petFriendly/client/service/order/progress",
                    method: .post,
                    parameters: params,
                    encoding: JSONEncoding.default,
                    needToken: true
                )
                await MainActor.run {
                    isSubmittingProgress = false
                    if resp.code == 200 {
                        UIState.shared.showToast(NSLocalizedString("order_report_progress_success", comment: ""))
                        Haptics.notify(.success)
                        progressImages.removeAll()
                        showProgressForm = false
                        onOrderChanged?()
                    } else {
                        UIState.shared.showToast(resp.msg ?? NSLocalizedString("common_unknown", comment: ""))
                    }
                }
            } catch {
                await MainActor.run {
                    isSubmittingProgress = false
                    UIState.shared.showToast(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - 提交完结服务（POST /service/order/complete，B 方案）
    @MainActor
    private func confirmComplete() async -> String? {
        guard !isUploadingProof else { return nil }
        guard let consumerId = order.consumerId else { return NSLocalizedString("common_unknown", comment: "") }
        guard let certificate = proofImageURL, !certificate.isEmpty else {
            UIState.shared.showToast(NSLocalizedString("order_proof_required", comment: ""))
            showProofImagePicker = true
            return nil
        }
        isUploadingProof = true
        defer { isUploadingProof = false }
        do {
            let params: [String: Any] = [
                "consumerId": consumerId,
                "certificate": certificate
            ]
            let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                "/petFriendly/client/service/order/complete",
                method: .post,
                parameters: params,
                encoding: JSONEncoding.default,
                needToken: true
            )
            if resp.code == 200 {
                UIState.shared.showToast(NSLocalizedString("order_complete_success", comment: ""))
                Haptics.notify(.success)
                statusOverride = 5
                onOrderChanged?()
                return nil
            }
            return resp.msg ?? NSLocalizedString("common_unknown", comment: "")
        } catch {
            return error.localizedDescription
        }
    }
    
    // MARK: - 确认收货（POST /service/order/confirmReceipt，B 方案）
    private func presentReceiptDialog() {
        receiptDialog = PFActionDialogConfig(
            title: NSLocalizedString("order_confirm_receipt_title", comment: ""),
            message: NSLocalizedString("order_confirm_receipt_msg", comment: ""),
            confirmTitle: NSLocalizedString("order_confirm_receipt", comment: ""),
            destructive: false,
            confirmIcon: "checkmark.seal.fill"
        )
    }

    @MainActor
    private func confirmReceipt() async -> String? {
        guard runningAction == nil, let consumerId = order.consumerId else { return nil }
        runningAction = "confirmReceipt"
        defer { runningAction = nil }
        do {
            let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                "/petFriendly/client/service/order/confirmReceipt",
                method: .post,
                parameters: ["consumerId": consumerId],
                encoding: JSONEncoding.default,
                needToken: true
            )
            if resp.code == 200 {
                statusOverride = 6
                UIState.shared.showToast(NSLocalizedString("order_confirm_receipt_success", comment: ""))
                Haptics.notify(.success)
                onOrderChanged?()
                return nil
            }
            return resp.msg ?? NSLocalizedString("common_unknown", comment: "")
        } catch {
            return error.localizedDescription
        }
    }
    
    // MARK: - 上传服务证明图
    private func uploadProofImage(_ image: UIImage) {
        guard !isUploadingProof else { return }
        isUploadingProof = true
        Task {
            do {
                let url: String = try await NetworkManager.shared.uploadImage(image, to: "/petFriendly/client/upload")
                await MainActor.run {
                    isUploadingProof = false
                    proofImageURL = url
                    UIState.shared.showToast(NSLocalizedString("order_upload_proof_success", comment: ""))
                }
            } catch {
                await MainActor.run {
                    isUploadingProof = false
                    UIState.shared.showToast(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - 通用简单动作（确认接单/开始服务/确认收货）
    private func performSimpleAction(_ action: String,
                                     path: String,
                                     params: [String: Any],
                                     successStatus: Int?,
                                     successKey: String) {
        guard runningAction == nil, let consumerId = order.consumerId else { return }
        runningAction = action
        var merged = params
        merged["consumerId"] = consumerId
        
        Task {
            do {
                let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                    path,
                    method: .post,
                    parameters: merged,
                    encoding: JSONEncoding.default,
                    needToken: true
                )
                await MainActor.run {
                    runningAction = nil
                    if resp.code == 200 {
                        if let s = successStatus { statusOverride = s }
                        UIState.shared.showToast(NSLocalizedString(successKey, comment: ""))
                        Haptics.notify(.success)
                        onOrderChanged?()
                    } else {
                        UIState.shared.showToast(resp.msg ?? NSLocalizedString("common_unknown", comment: ""))
                    }
                }
            } catch {
                await MainActor.run {
                    runningAction = nil
                    UIState.shared.showToast(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Helper UI
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: PFRadius.lg)
            .fill(PFColors.surface)
            .pfCardShadow()
    }
    
    private func formatAmt(_ val: Double) -> String {
        return "¥ \(String(format: "%.2f", val))"
    }
    
    private func infoRow(title: String, value: String, valueColor: Color? = nil) -> some View {
        HStack(alignment: .top) {
            Text(LocalizedStringKey(title))
                .font(PFFonts.callout)
                .foregroundColor(PFColors.textTertiary)
                .frame(width: 80, alignment: .leading)
            Spacer()
            Text(value)
                .font(PFFonts.callout)
                .foregroundColor(valueColor ?? PFColors.textSecondary)
                .multilineTextAlignment(.trailing)
        }
    }
    
    private func statusText(for status: Int) -> String {
        switch status {
        case 0: return NSLocalizedString("order_status_0", comment: "")
        case 1: return NSLocalizedString("order_status_1", comment: "")
        case 2: return NSLocalizedString("order_status_2", comment: "")
        case 3: return NSLocalizedString("order_status_3", comment: "")
        case 4: return NSLocalizedString("order_status_4", comment: "")
        case 5: return NSLocalizedString("order_status_5", comment: "")
        case 6: return NSLocalizedString("order_status_6", comment: "")
        case 7: return NSLocalizedString("order_status_7", comment: "")
        case 8: return NSLocalizedString("order_status_8", comment: "")
        case 9: return NSLocalizedString("order_status_9", comment: "")
        case 10: return NSLocalizedString("order_status_10", comment: "")
        case 11: return NSLocalizedString("order_status_11", comment: "")
        case 12: return NSLocalizedString("order_status_12", comment: "")
        case 13: return NSLocalizedString("order_status_13", comment: "")
        case 14: return NSLocalizedString("order_status_14", comment: "")
        case 15: return NSLocalizedString("order_status_15", comment: "")
        case 16: return NSLocalizedString("order_status_16", comment: "")
        case 17: return NSLocalizedString("order_status_17", comment: "")
        default: return String(format: NSLocalizedString("order_status_unknown", comment: ""), status)
        }
    }
    
    private func statusColor(for status: Int) -> Color {
        switch status {
        case 0, 1, 2, 3: return PFColors.warning
        case 4, 16, 17: return PFColors.info
        case 5, 6, 12, 15: return PFColors.success
        case 7, 13: return PFColors.textTertiary
        case 8, 9, 10, 11, 14: return PFColors.accent
        default: return PFColors.textSecondary
        }
    }
    
    private func iconForServiceType(_ type: Int) -> String {
        switch type {
        case 2: return "car.fill"
        case 1: return "cart.fill"
        case 3: return "cross.case.fill"
        default: return "list.clipboard.fill"
        }
    }
}

// MARK: - 多图选择行（评价 / 上报进度共用）
struct PFMultiImagePickerRow: View {
    let title: String
    @Binding var images: [UIImage]
    var maxCount: Int = 3

    @State private var showPicker = false
    @State private var pickedImage: UIImage? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                guard images.count < maxCount else { return }
                showPicker = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundColor(PFColors.primary)
                    Text(title)
                        .font(PFFonts.caption)
                        .foregroundColor(PFColors.textSecondary)
                    Spacer()
                    Text("\(images.count)/\(maxCount)")
                        .font(PFFonts.caption2)
                        .foregroundColor(PFColors.textTertiary)
                }
                .padding(10)
                .background(PFColors.surfaceSecondary)
                .cornerRadius(PFRadius.md)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(images.count >= maxCount)
            .opacity(images.count >= maxCount ? 0.5 : 1)

            if !images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<images.count, id: \.self) { i in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: images[i])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .clipped()
                                Button(action: {
                                    images.remove(at: i)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.6)))
                                }
                                .offset(x: 4, y: -4)
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            ImagePicker(image: $pickedImage)
        }
        .onChange(of: pickedImage) { newImage in
            if let img = newImage, images.count < maxCount {
                images.append(img)
            }
            pickedImage = nil
        }
    }
}
