import SwiftUI

struct BoardingServiceWizardView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var petViewModel = PetViewModel.shared
    
    // 表单状态
    @State private var step = 0
    let totalSteps = 5
    
    // 录入数据
    @State private var selectedPetId: String?
    @State private var serviceType: String = "" // boarding_type_cat or boarding_type_dog
    @State private var appointmentDates: [Date] = [Date()] // 简化的时间
    @State private var location: String = ""
    @State private var accessMethod: String = "" // boarding_access_placeholder
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
                            typeStep()
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        case 2:
                            timeStep()
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        case 3:
                            locationAndAccessStep()
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        case 4:
                            reviewStep()
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        default:
                            EmptyView()
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                
                bottomBar()
            }
            .trackScene("BoardingWizard_Step\(step)")
            .navigationTitle("boarding_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(PFColors.textPrimary)
                    }
                }
                // 查看当前服务类型（寄养）的订单记录（用 fullScreenCover 弹出，避免多层 NavigationStack 下 NavigationLink 失效）
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showMyOrders = true }) {
                        Label("order_my_orders", systemImage: "list.bullet.rectangle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(PFColors.primary)
                    }
                }
            }
            .onAppear {
                if petViewModel.pets.isEmpty { petViewModel.fetchPets() }
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
                    ServiceOrderListView(title: "寄养", type: "7", showCloseButton: true)
                }
            }
        }
    }

    // MARK: - Steps
    
    private func petSelectionStep() -> some View {
        VStack(spacing: 24) {
            Text("boarding_pet_select")
                .font(PFFonts.title)
                .multilineTextAlignment(.center)
            
            if petViewModel.pets.isEmpty {
                Text("boarding_no_pet").foregroundColor(PFColors.textSecondary)
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
    
    private func typeStep() -> some View {
        VStack(spacing: 24) {
            Text("boarding_type_select")
                .font(PFFonts.title)
            
            let types = [NSLocalizedString("boarding_type_cat", comment: ""), NSLocalizedString("boarding_type_dog", comment: "")]
            ForEach(types, id: \.self) { type in
                selectionButton(title: type, isSelected: serviceType == type) {
                    serviceType = type
                }
            }
            Spacer()
        }
        .padding()
    }
    
    private func timeStep() -> some View {
        VStack(spacing: 24) {
            Text("boarding_time_title")
                .font(PFFonts.title)
            
            DatePicker("boarding_time_picker", selection: Binding(
                get: { appointmentDates.first ?? Date() },
                set: { newDate in appointmentDates = [newDate] }
            ), in: Date()..., displayedComponents: [.date, .hourAndMinute])
            .datePickerStyle(GraphicalDatePickerStyle())
            .tint(PFColors.primary)
            .padding()
            .background(PFColors.surface)
            .cornerRadius(16)
            .pfCardShadow()
            
            Spacer()
        }
        .padding()
    }
    
    private func locationAndAccessStep() -> some View {
        VStack(spacing: 24) {
            Text("boarding_address_title")
                .font(PFFonts.title)
            
            VStack(alignment: .leading, spacing: 16) {
                TextField("boarding_address_placeholder", text: $location)
                    .font(PFFonts.callout)
                    .padding()
                    .background(PFColors.surfaceSecondary)
                    .cornerRadius(12)
                
                TextField("boarding_access_placeholder", text: $accessMethod)
                    .font(PFFonts.callout)
                    .padding()
                    .background(PFColors.surfaceSecondary)
                    .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func reviewStep() -> some View {
        VStack(spacing: 20) {
            Text("boarding_review_title")
                .font(PFFonts.title)
            
            VStack(alignment: .leading, spacing: 16) {
                reviewRow(title: "boarding_field_type", value: serviceType.components(separatedBy: " ").first ?? serviceType)
                reviewRow(title: "boarding_field_location", value: location)
                reviewRow(title: "boarding_field_access", value: accessMethod.isEmpty ? NSLocalizedString("boarding_not_filled", comment: "") : accessMethod)
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
            Text(LocalizedStringKey(title)).foregroundColor(PFColors.textSecondary)
            Spacer()
            Text(value).bold()
        }
        .font(PFFonts.body)
    }
    
    private func selectionButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey(title))
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
                    Button(LocalizedStringKey("add_pet_back")) { withAnimation { step -= 1 } }
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
        case 1: return !serviceType.isEmpty
        case 3: return !location.isEmpty && !accessMethod.isEmpty
        default: return true
        }
    }
    
    private func submit() {
        let serviceName = NSLocalizedString("boarding_service_name", comment: "")
        isSubmitting = true
        Task {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let param: [String: Any] = [
                "petId": selectedPetId ?? "",
                "serviceName": serviceName,
                "serviceDate": df.string(from: appointmentDates.first ?? Date()),
                "remark": String(format: NSLocalizedString("boarding_remark_format", comment: ""), serviceType, location, accessMethod),
                "payStatus": 0,
                "phoneInformation": contactPhone.isEmpty ? (AccountStore.shared.petOwner?.phoneInformation ?? "") : contactPhone,
                "reserveStartTime": df.string(from: appointmentDates.first ?? Date()),
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
                            serviceType: 7,
                            status: 2,
                            payStatus: 0,
                            consumptionAmount: 0,
                            actualAmount: 0
                        )
                        self.orderToShow = detailRow ?? row
                    } else {
                        showSuccessHUD(message: resp.msg ?? NSLocalizedString("boarding_submit_success", comment: ""))
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
}
