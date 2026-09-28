import SwiftUI
import Alamofire

struct CommonServiceBookingView: View {
    let serviceName: String
    @StateObject private var petViewModel = PetViewModel.shared
    @Environment(\.dismiss) var dismiss
    
    // Booking Form State
    @State private var selectedPetId: String? = nil
    @State private var appointmentDate = Date()
    @State private var contactPhone: String = ""
    @State private var remarks: String = ""
    @State private var isSubmitting = false
    
    // 提交成功后展示订单详情页（供「立即支付」）
    @State private var orderToShow: ServiceOrderRow? = nil
    // 我的订单列表（当前服务类型）
    @State private var showMyOrders = false

    /// 前置校验：必填项（宠物、联系电话）都填写完整才可提交
    private var canSubmit: Bool {
        !isSubmitting
            && selectedPetId != nil
            && !contactPhone.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea().onTapGesture { dismissFormKeyboard() }
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: PFSpacing.xl) {
                        
                        // Header
                        VStack(spacing: PFSpacing.sm) {
                            ZStack {
                                Circle()
                                    .fill(PFGradients.brand.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 32))
                                    .foregroundColor(PFColors.primary)
                            }
                            
                            Text(String(format: NSLocalizedString("booking_greeting_question", comment: ""), serviceName))
                                .font(PFFonts.title2)
                                .foregroundColor(PFColors.textPrimary)
                            
                            Text("booking_subtitle")
                                .font(PFFonts.caption)
                                .foregroundColor(PFColors.textSecondary)
                        }
                        .padding(.top, PFSpacing.xxxl)
                        
                        // Select Pet Section
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
                        
                        // Datetime Section
                        formSection(title: NSLocalizedString("booking_time_title", comment: "")) {
                            DatePicker("booking_time_picker", selection: $appointmentDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(CompactDatePickerStyle())
                                .font(PFFonts.callout)
                                .tint(PFColors.primary)
                        }
                        
                        // Contact
                        formSection(title: NSLocalizedString("booking_phone_title", comment: "")) {
                            PFCurrentPhoneButton(phone: $contactPhone)
                            TextField("booking_phone_placeholder", text: $contactPhone)
                                .keyboardType(.phonePad)
                                .font(PFFonts.callout)
                                .padding()
                                .background(PFColors.surfaceSecondary)
                                .cornerRadius(PFRadius.md)
                        }
                        
                        // Remarks
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
                    .padding(.bottom, 120) // space for bottom button
                }
                .simultaneousGesture(DragGesture(minimumDistance: 8).onChanged { _ in dismissFormKeyboard() })
            }
            
            // Bottom Action
            VStack {
                Spacer()
                VStack {
                    PFButton(
                        "booking_submit",
                        icon: "paperplane.fill",
                        gradient: PFGradients.brand,
                        isLoading: isSubmitting
                    ) {
                        // 提交订单（不弹支付密码，提交后进订单详情页「立即支付」）
                        submitBooking()
                    }
                    // 必填项校验通过才可提交
                    .disabled(!canSubmit)
                }
                .padding(.horizontal, PFSpacing.xl)
                // .padding(.bottom, 34) // Save area handled implicitly
                .padding(.vertical, PFSpacing.lg)
                .background(
                    PFColors.surface
                        .opacity(0.9)
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .shadow(color: .black.opacity(0.05), radius: 10, y: -5)
                )
            }
        }
        .navigationTitle(serviceName)
        .navigationBarTitleDisplayMode(.inline)
        .trackScene("Booking_\(serviceName)")
        .toolbar {
            // 查看当前服务类型的订单记录（用 fullScreenCover 弹出，避免多层 NavigationStack 下 NavigationLink 失效）
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
                ServiceOrderListView(title: serviceName, type: "\(serviceType(for: serviceName) ?? 2)", showCloseButton: true)
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
    
    /// 根据服务名称推断 ServiceType（与后端 serviceBook 判定保持一致）
    private func serviceType(for name: String?) -> Int? {
        guard let name = name else { return nil }
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

    private func submitBooking() {
        guard let petId = selectedPetId else {
            showErrorAlert(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("booking_error_no_pet", comment: "")]))
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
            
            let param: [String: Any] = [
                "petId": petId,
                "serviceName": serviceName,
                "serviceDate": dateStr,
                "remark": remarks,
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
                            serviceType: serviceType(for: serviceName),
                            status: 2,
                            payStatus: 0,
                            consumptionAmount: 0,
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
