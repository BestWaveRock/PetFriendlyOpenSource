import SwiftUI

struct HomeServiceBookingView: View {
    let serviceName: String
    @StateObject private var petViewModel = PetViewModel.shared
    @Environment(\.dismiss) var dismiss
    
    // 表单状态
    @State private var selectedPetId: String? = nil
    @State private var serviceAddress: String = ""
    @State private var appointmentDate = Date()
    @State private var contactPhone: String = ""
    @State private var remarks: String = ""
    
    // 服务项目勾选（费用计算）
    @State private var optWalkDog = false
    @State private var optFeed = false
    @State private var optCleanLitter = false
    @State private var optGrooming = false
    
    @State private var isSubmitting = false

    // 提交成功后展示订单详情页（供「立即支付」）
    @State private var orderToShow: ServiceOrderRow? = nil
    // 我的订单列表（当前服务类型）
    @State private var showMyOrders = false
    
    // 估算费用
    private var estimatedCost: Double {
        let basePrice = 50.0
        var cost = basePrice
        if optWalkDog { cost += 20.0 }
        if optFeed { cost += 10.0 }
        if optCleanLitter { cost += 15.0 }
        if optGrooming { cost += 40.0 }
        return cost
    }

    /// 前置校验：必填项（宠物、服务地址、联系电话）都填写完整才可提交
    private var canSubmit: Bool {
        !isSubmitting
            && selectedPetId != nil
            && !serviceAddress.trimmingCharacters(in: .whitespaces).isEmpty
            && !contactPhone.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea().onTapGesture { dismissFormKeyboard() }
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: PFSpacing.xl) {
                        
                        // 头部
                        VStack(spacing: PFSpacing.sm) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "house.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.blue)
                            }
                            
                            Text("booking_home_greeting")
                                .font(PFFonts.title2)
                                .foregroundColor(PFColors.textPrimary)
                            
                            Text("booking_home_subtitle")
                                .font(PFFonts.caption)
                                .foregroundColor(PFColors.textSecondary)
                        }
                        .padding(.top, PFSpacing.xl)
                        
                        // 1. 选择宠物
                        formSection(title: NSLocalizedString("booking_select_pet", comment: "")) {
                            if petViewModel.pets.isEmpty && !petViewModel.isLoading {
                                Text("booking_no_pet")
                                    .font(PFFonts.caption)
                                    .foregroundColor(PFColors.textTertiary)
                                    .padding(.vertical, PFSpacing.md)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: PFSpacing.md) {
                                        ForEach(petViewModel.pets) { pet in
                                            let id = pet.petId
                                            let isSelected = selectedPetId == id
                                            
                                            Button(action: {
                                                selectedPetId = isSelected ? nil : id
                                            }) {
                                                VStack(spacing: 8) {
                                                    GlowAvatar(
                                                        url: pet.avatarUrl,
                                                        size: 56,
                                                        glowColor: isSelected ? PFColors.primary : Color.clear
                                                    )
                                                    
                                                    Text(pet.name)
                                                        .font(PFFonts.caption2)
                                                        .foregroundColor(isSelected ? PFColors.primary : PFColors.textSecondary)
                                                }
                                                .padding(8)
                                                .background(isSelected ? PFColors.primary.opacity(0.1) : Color.clear)
                                                .cornerRadius(12)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(isSelected ? PFColors.primary : Color.clear, lineWidth: 1.5)
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // 2. 服务地址
                        formSection(title: NSLocalizedString("booking_home_address_title", comment: "")) {
                            HStack {
                                Image(systemName: "house.circle.fill")
                                    .foregroundColor(PFColors.primary)
                                TextField("booking_home_address_placeholder", text: $serviceAddress)
                                    .font(PFFonts.callout)
                            }
                            .padding()
                            .background(PFColors.surfaceSecondary)
                            .cornerRadius(PFRadius.md)
                        }
                        
                        // 3. 预约时间与电话
                        formSection(title: NSLocalizedString("booking_time_title", comment: "")) {
                            VStack(spacing: PFSpacing.md) {
                                DatePicker("booking_time_picker", selection: $appointmentDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(CompactDatePickerStyle())
                                    .font(PFFonts.callout)
                                    .tint(PFColors.primary)
                                
                                Divider()
                                
                                PFCurrentPhoneButton(phone: $contactPhone)
                                TextField("booking_phone_placeholder", text: $contactPhone)
                                    .keyboardType(.phonePad)
                                    .font(PFFonts.callout)
                                    .padding(.vertical, 8)
                            }
                        }
                        
                        // 4. 服务项目与费用估算
                        formSection(title: NSLocalizedString("booking_home_cost_calc", comment: "")) {
                            VStack(spacing: PFSpacing.md) {
                                Toggle(isOn: $optWalkDog) {
                                    HStack {
                                        Text("booking_home_opt_walk")
                                        Spacer()
                                        Text("+¥ 20")
                                            .font(PFFonts.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .tint(PFColors.primary)
                                
                                Toggle(isOn: $optFeed) {
                                    HStack {
                                        Text("booking_home_opt_feed")
                                        Spacer()
                                        Text("+¥ 10")
                                            .font(PFFonts.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .tint(PFColors.primary)
                                
                                Toggle(isOn: $optCleanLitter) {
                                    HStack {
                                        Text("booking_home_opt_clean")
                                        Spacer()
                                        Text("+¥ 15")
                                            .font(PFFonts.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .tint(PFColors.primary)
                                
                                Toggle(isOn: $optGrooming) {
                                    HStack {
                                        Text("booking_home_opt_groom")
                                        Spacer()
                                        Text("+¥ 40")
                                            .font(PFFonts.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .tint(PFColors.primary)
                                
                                Divider()
                                
                                HStack {
                                    Text("booking_estimated_fee")
                                        .font(PFFonts.headline)
                                    Spacer()
                                    Text(String(format: "¥ %.2f", estimatedCost))
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.blue)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        // 5. 特殊需求备注
                        formSection(title: NSLocalizedString("booking_remarks_title", comment: "")) {
                            PFVoiceInputEditor(
                                placeholder: "booking_remarks_placeholder",
                                text: $remarks,
                                height: 100,
                                maxLength: 500
                            )
                        }
                    }
                    .padding(.horizontal, PFSpacing.xl)
                    .padding(.bottom, PFSpacing.xl)
                }
                .simultaneousGesture(DragGesture(minimumDistance: 8).onChanged { _ in dismissFormKeyboard() })
            }
        }
        .navigationTitle(serviceName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                // 查看当前服务类型（上门服务）的订单记录（用 fullScreenCover 弹出，避免多层 NavigationStack 下 NavigationLink 失效）
                Button(action: { showMyOrders = true }) {
                    Label("order_my_orders", systemImage: "list.bullet.rectangle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(PFColors.primary)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { submitBooking() }) {
                    HStack(spacing: 5) {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: PFColors.primary))
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text("booking_submit")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(canSubmit ? PFColors.primary : PFColors.textTertiary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(canSubmit ? AnyShapeStyle(PFGradients.brand.opacity(0.15)) : AnyShapeStyle(PFColors.surfaceSecondary))
                    )
                }
                // 必填项校验通过才可提交
                .disabled(!canSubmit)
            }
        }
        .onAppear {
            if petViewModel.pets.isEmpty {
                petViewModel.fetchPets()
            }
            // 自动带出当前用户手机号
            if contactPhone.isEmpty {
                contactPhone = AccountStore.shared.petOwner?.phoneInformation ?? ""
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
                ServiceOrderListView(title: NSLocalizedString("person_service_appointment", comment: ""), type: "4", showCloseButton: true)
            }
        }
    }

    private func dismissFormKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    @ViewBuilder
    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: PFSpacing.md) {
            Text(title)
                .font(PFFonts.headline)
                .foregroundColor(PFColors.textPrimary)
            content()
        }
        .padding(PFSpacing.lg)
        .background(PFColors.surface)
        .cornerRadius(PFRadius.lg)
        .pfCardShadow()
    }
    
    private func submitBooking() {
        guard let petId = selectedPetId else {
            showErrorAlert(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("booking_error_no_pet", comment: "")]))
            return
        }
        guard !serviceAddress.trimmingCharacters(in: .whitespaces).isEmpty else {
            showErrorAlert(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("booking_error_no_address", comment: "")]))
            return
        }
        guard !contactPhone.trimmingCharacters(in: .whitespaces).isEmpty else {
            showErrorAlert(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("booking_error_no_phone", comment: "")]))
            return
        }
        
        isSubmitting = true
        Task {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let dateStr = dateFormatter.string(from: appointmentDate)
            
            var selectedOpts: [String] = []
            if optWalkDog { selectedOpts.append(NSLocalizedString("dog_walk_30min", comment: "")) }
            if optFeed { selectedOpts.append(NSLocalizedString("feed_and_water", comment: "")) }
            if optCleanLitter { selectedOpts.append(NSLocalizedString("clean_litter_box", comment: "")) }
            if optGrooming { selectedOpts.append(NSLocalizedString("grooming_bath", comment: "")) }
            
            let finalRemark = String(format: NSLocalizedString("home_service_remark_format", comment: ""),
                serviceAddress,
                contactPhone,
                selectedOpts.isEmpty ? NSLocalizedString("basic_service_only", comment: "") : selectedOpts.joined(separator: " + "),
                String(format: "%.2f", estimatedCost),
                remarks.isEmpty ? NSLocalizedString("none_option", comment: "") : remarks
            )
            
            let param: [String: Any] = [
                "petId": petId,
                "serviceName": serviceName,
                "serviceDate": dateStr,
                "remark": finalRemark,
                "payStatus": 0,
                "phoneInformation": contactPhone,
                "reserveStartTime": dateStr,
                "reserveInformation": remarks
            ]
            
            do {
                // 后端返回订单ID（Long），用于跳转订单详情页执行「立即支付」
                let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                    "/petFriendly/client/service/book",
                    method: .post,
                    parameters: param,
                    needToken: true
                )
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
                            serviceType: 4,
                            status: 2,
                            payStatus: 0,
                            consumptionAmount: estimatedCost,
                            actualAmount: 0
                        )
                        self.orderToShow = detailRow ?? row
                    } else {
                        showSuccessHUD(message: resp.msg ?? NSLocalizedString("booking_success", comment: ""))
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
import SwiftUI

// MARK: - 流浪宠物详情页
