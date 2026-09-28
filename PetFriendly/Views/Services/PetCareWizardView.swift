import SwiftUI

struct PetCareWizardView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var petViewModel = PetViewModel.shared
    
    // 表单状态
    @State private var step = 0
    let totalSteps = 6
    
    // 录入数据
    @State private var selectedPetId: String?
    @State private var weightRange: String = ""
    @State private var location: String = ""
    @State private var appointmentDate = Date()
    @State private var isPickup = false
    @State private var priceRange: String = ""
    @State private var contactPhone = ""
    
    @State private var isSubmitting = false

    // 提交成功后展示订单详情页（供「立即支付」）
    @State private var orderToShow: ServiceOrderRow? = nil
    // 我的订单列表（当前服务类型）
    @State private var showMyOrders = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部进度条 (已重构为 iOS 26/27 拟态微动渐变加载栏)
                PFProgressBar(value: Double(step + 1), total: Double(totalSteps))
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                
                // 核心区域
                GeometryReader { geometry in
                    ZStack {
                        switch step {
                        case 0:
                            petSelectionStep()
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        case 1:
                            weightStep()
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        case 2:
                            locationStep()
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        case 3:
                            timeAndPickupStep()
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        case 4:
                            priceStep()
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        case 5:
                            reviewStep()
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        default:
                            EmptyView()
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                
                // 底部按钮区域
                bottomBar()
            }
            .trackScene("PetCareWizard_Step\(step)")
            .navigationTitle("care_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(PFColors.textPrimary)
                    }
                }
                // 查看当前服务类型（洗护）的订单记录（用 fullScreenCover 弹出，避免多层 NavigationStack 下 NavigationLink 失效）
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showMyOrders = true }) {
                        Label("order_my_orders", systemImage: "list.bullet.rectangle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(PFColors.primary)
                    }
                }
            }
            .onAppear {
                if petViewModel.pets.isEmpty {
                    petViewModel.fetchPets()
                }
            }
            // 提交成功后展示订单详情页（含「立即支付」）
            .fullScreenCover(item: $orderToShow) { order in
                NavigationStack {
                    ServiceOrderDetailView(order: order, showCloseButton: true)
                }
            }
            // 我的订单列表（当前服务类型）
            .fullScreenCover(isPresented: $showMyOrders) {
                NavigationStack {
                    ServiceOrderListView(title: "洗护", type: "3", showCloseButton: true)
                }
            }
        }
    }

    // MARK: - Steps
    
    private func petSelectionStep() -> some View {
        VStack(spacing: 24) {
            Text("care_pet_select")
                .font(PFFonts.title)
                .multilineTextAlignment(.center)
            
            if petViewModel.pets.isEmpty {
                Text("booking_no_pet")
                    .foregroundColor(PFColors.textSecondary)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(petViewModel.pets) { pet in
                            let id = pet.petId
                            let isSelected = selectedPetId == id
                            
                            Button(action: { selectedPetId = id }) {
                                VStack {
                                    GlowAvatar(url: pet.avatarUrl, size: 80, glowColor: isSelected ? PFColors.primary : .clear)
                                    Text(pet.name).font(PFFonts.headline)
                                        .foregroundColor(isSelected ? PFColors.primary : PFColors.textPrimary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(isSelected ? PFColors.primary.opacity(0.1) : PFColors.surface)
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? PFColors.primary : Color.clear, lineWidth: 2))
                                .pfCardShadow()
                            }
                        }
                    }
                    .padding()
                }
            }
            Spacer()
        }
    }
    
    private func weightStep() -> some View {
        VStack(spacing: 24) {
            Text("care_weight_title")
                .font(PFFonts.title)
            Text("care_weight_subtitle").foregroundColor(PFColors.textSecondary)
            
            let ranges = [
                NSLocalizedString("care_weight_0to5", comment: ""),
                NSLocalizedString("care_weight_5to10", comment: ""),
                NSLocalizedString("care_weight_10to20", comment: ""),
                NSLocalizedString("care_weight_20plus", comment: "")
            ]
            ForEach(ranges, id: \.self) { range in
                selectionButton(title: range, isSelected: weightRange == range) {
                    weightRange = range
                }
            }
            Spacer()
        }
        .padding()
    }
    
    private func locationStep() -> some View {
        VStack(spacing: 24) {
            Text("care_location_title")
                .font(PFFonts.title)
            Text("care_location_subtitle").foregroundColor(PFColors.textSecondary)
            
            TextField("care_location_placeholder", text: $location)
                .font(PFFonts.title2)
                .padding()
                .background(PFColors.surfaceSecondary)
                .cornerRadius(12)
            
            Spacer()
        }
        .padding()
    }
    
    private func timeAndPickupStep() -> some View {
        VStack(spacing: 24) {
            Text("care_pickup_title")
                .font(PFFonts.title)
            
            DatePicker("care_pickup_title", selection: $appointmentDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(GraphicalDatePickerStyle())
                .tint(PFColors.primary)
                .padding()
                .background(PFColors.surface)
                .cornerRadius(16)
                .pfCardShadow()
            
            Toggle("care_pickup_label", isOn: $isPickup)
                .font(PFFonts.headline)
                .padding()
                .background(PFColors.surface)
                .cornerRadius(16)
                .pfCardShadow()
            
            Spacer()
        }
        .padding()
    }
    
    private func priceStep() -> some View {
        VStack(spacing: 24) {
            Text("care_price_title")
                .font(PFFonts.title)
            
            let prices = [
                NSLocalizedString("care_price_basic", comment: ""),
                NSLocalizedString("care_price_detailed", comment: ""),
                NSLocalizedString("care_price_premium", comment: "")
            ]
            ForEach(prices, id: \.self) { p in
                selectionButton(title: p, isSelected: priceRange == p) {
                    priceRange = p
                }
            }
            Spacer()
        }
        .padding()
    }
    
    private func reviewStep() -> some View {
        VStack(spacing: 20) {
            Text("care_review_title")
                .font(PFFonts.title)
            
            VStack(alignment: .leading, spacing: 16) {
                reviewRow(title: NSLocalizedString("care_field_weight", comment: ""), value: weightRange)
                reviewRow(title: NSLocalizedString("boarding_field_location", comment: ""), value: location)
                reviewRow(title: NSLocalizedString("care_field_pickup", comment: ""), value: isPickup ? NSLocalizedString("care_yes", comment: "") : NSLocalizedString("care_no", comment: ""))
                reviewRow(title: NSLocalizedString("care_field_budget", comment: ""), value: priceRange)
                PFCurrentPhoneButton(phone: $contactPhone)
                TextField("booking_phone_placeholder", text: $contactPhone).keyboardType(.phonePad).padding(12).background(PFColors.surfaceSecondary).cornerRadius(10)
            }
            .padding()
            .background(PFColors.surface)
            .cornerRadius(16)
            .pfCardShadow()
            
            Spacer()
        }
        .padding()
    }
    
    private func reviewRow(title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundColor(PFColors.textSecondary)
            Spacer()
            Text(value).bold()
        }
        .font(PFFonts.body)
    }
    
    private func selectionButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(PFFonts.headline)
                .foregroundColor(isSelected ? PFColors.primary : PFColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSelected ? PFColors.primary.opacity(0.1) : PFColors.surface)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? PFColors.primary : PFColors.divider, lineWidth: 1.5))
        }
    }
    
    // MARK: - Bottom Nav
    
    private func bottomBar() -> some View {
        VStack {
            Divider()
            HStack {
                if step > 0 {
                    Button(LocalizedStringKey("add_pet_back")) {
                        withAnimation { step -= 1 }
                    }
                    .foregroundColor(PFColors.textSecondary)
                    .frame(width: 80, height: 50)
                } else {
                    Spacer().frame(width: 80)
                }
                
                Spacer()
                
                if step < totalSteps - 1 {
                    PFButton(LocalizedStringKey("add_pet_next"), icon: "arrow.right", gradient: PFGradients.brand) {
                        withAnimation { step += 1 }
                    }
                    .disabled(canProceed == false)
                    .frame(width: 160)
                } else {    
                    PFButton(LocalizedStringKey("form_submit"), icon: "checkmark", gradient: PFGradients.brand, isLoading: isSubmitting) {
                        submit()
                    }
                    // 必填项校验通过才可提交
                    .disabled(canProceed == false)
                    .frame(width: 160)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .padding(.bottom, 20)
        }
        .background(PFColors.surface)
    }
    
    private var canProceed: Bool {
        switch step {
        case 0: return selectedPetId != nil
        case 1: return !weightRange.isEmpty
        case 2: return !location.isEmpty
        case 4: return !priceRange.isEmpty
        default: return true
        }
    }
    
    private func submit() {
        let serviceName = NSLocalizedString("care_service_name", comment: "")
        isSubmitting = true
        Task {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let param: [String: Any] = [
                "petId": selectedPetId ?? "",
                "serviceName": serviceName,
                "serviceDate": df.string(from: appointmentDate),
                "remark": String(format: NSLocalizedString("care_remark_format", comment: ""), weightRange, priceRange, (isPickup ? NSLocalizedString("care_yes", comment: "") : NSLocalizedString("care_no", comment: "")), location),
                "payStatus": 0,
                "phoneInformation": contactPhone.isEmpty ? (AccountStore.shared.petOwner?.phoneInformation ?? "") : contactPhone,
                "reserveStartTime": df.string(from: appointmentDate),
                "reserveInformation": location
            ]
            do {
                // 后端返回订单ID（Long），用于跳转订单详情页执行「立即支付」
                let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request("/petFriendly/client/service/book", method: .post, parameters: param, needToken: true)
                // 拉取后端完整订单数据，复用详情页展示完整字段（失败则用基础行兜底）
                var detailRow: ServiceOrderRow? = nil
                if resp.code == 200, let cid = orderId(from: resp.data) {
                    detailRow = try? await ServiceOrderRow.fetchDetail(consumerId: cid)
                }
                await MainActor.run {
                    self.isSubmitting = false
                    if resp.code == 200, let cid = orderId(from: resp.data) {
                        let row = ServiceOrderRow(
                            consumerId: cid,
                            serviceName: serviceName,
                            serviceType: serviceType(for: serviceName),
                            status: 2,
                            payStatus: 0,
                            consumptionAmount: 0,
                            actualAmount: 0
                        )
                        self.orderToShow = detailRow ?? row
                    } else {
                        showSuccessHUD(message: resp.msg ?? NSLocalizedString("care_success", comment: ""))
                        self.dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isSubmitting = false
                    showErrorAlert(error)
                }
            }
        }
    }

    /// 根据服务名称推断 ServiceType（与后端 serviceBook 判定保持一致）
    private func serviceType(for name: String) -> Int {
        if name.contains("门诊") || name.contains("接种") { return 0 }
        if name.contains("专车") { return 2 }
        if name.contains("洗护") || name.contains("美容") { return 3 }
        if name.contains("上门") { return 4 }
        if name.contains("医疗") || name.contains("急救") { return 5 }
        if name.contains("流浪") { return 6 }
        if name.contains("救助") || name.contains("领养") { return 11 }
        if name.contains("寄养") || name.contains("代养") || name.contains("遛狗") || name.contains("喂猫") { return 7 }
        if name.contains("指南") { return 8 }
        if name.contains("证件") || name.contains("画像") { return 9 }
        return 2
    }
}
