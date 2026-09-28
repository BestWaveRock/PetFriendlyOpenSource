import SwiftUI

struct PetTaxiBookingView: View {
    let serviceName: String
    @StateObject private var petViewModel = PetViewModel.shared
    @Environment(\.dismiss) var dismiss
    
    // 表单状态
    @State private var selectedPetId: String? = nil
    @State private var startAddress: String = ""
    @State private var endAddress: String = ""
    @State private var startCoordinate: CLLocationCoordinate2D?
    @State private var endCoordinate: CLLocationCoordinate2D?
    @State private var showStartMapPicker = false
    @State private var showEndMapPicker = false
    @State private var appointmentDate = Date()
    // 出行时间快捷选择：0=立即 1=15分钟 2=30分钟 3=指定时间
    @State private var travelOption = 0
    @State private var contactPhone: String = ""
    @State private var remarks: String = ""
    
    // 费用计算相关
    @State private var distance: Double = 5.0 // km
    @State private var distanceBand = 0
    @State private var needAssistant = false
    @State private var multiPets = false
    
    @State private var isSubmitting = false

    // 提交成功后展示订单详情页（供「立即支付」）
    @State private var orderToShow: ServiceOrderRow? = nil
    // 我的订单列表（当前服务类型）
    @State private var showMyOrders = false
    
    // 结束时间 = 开始+1h
    private var appointmentEndTime: Date {
        appointmentDate.addingTimeInterval(3600)
    }
    
    // 消费金额（系统计算，只读显示）
    private var consumptionAmount: Double {
        estimatedCost
    }

    /// 出行时间快捷选项文案
    private func travelOptionLabel(_ idx: Int) -> String {
        switch idx {
        case 1: return NSLocalizedString("booking_travel_15min", comment: "")
        case 2: return NSLocalizedString("booking_travel_30min", comment: "")
        case 3: return NSLocalizedString("booking_travel_custom", comment: "")
        default: return NSLocalizedString("booking_travel_immediate", comment: "")
        }
    }
    
    // 估算费用
    private var estimatedCost: Double {
        let basePrice = 30.0
        let baseDistance = 3.0
        let extraKmPrice = 4.0
        
        var cost = basePrice
        if distance > baseDistance {
            cost += (distance - baseDistance) * extraKmPrice
        }
        if needAssistant {
            cost += 15.0
        }
        if multiPets {
            cost += 10.0
        }
        return cost
    }

    private var distanceRange: ClosedRange<Double> {
        switch distanceBand { case 1: return 51...500; case 2: return 501...3000; default: return 0...50 }
    }

    /// 前置校验：必填项（宠物、起始地址、目的地址、联系电话）都填写完整才可提交
    private var canSubmit: Bool {
        !isSubmitting
            && selectedPetId != nil
            && !startAddress.trimmingCharacters(in: .whitespaces).isEmpty
            && !endAddress.trimmingCharacters(in: .whitespaces).isEmpty
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
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "car.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.orange)
                            }
                            
                            Text("booking_taxi_greeting")
                                .font(PFFonts.title2)
                                .foregroundColor(PFColors.textPrimary)
                            
                            Text("booking_taxi_subtitle")
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
                        
                        // 2. 出发地与目的地（地图选点）
                        formSection(title: NSLocalizedString("booking_taxi_route", comment: "")) {
                            VStack(spacing: PFSpacing.md) {
                                // 起点 - 可点击打开地图选点
                                Button(action: { showStartMapPicker = true }) {
                                    HStack {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundColor(.green)
                                        if startAddress.isEmpty {
                                            Text("booking_taxi_start_placeholder")
                                                .foregroundColor(PFColors.textTertiary)
                                        } else {
                                            Text(startAddress)
                                                .foregroundColor(PFColors.textPrimary)
                                        }
                                        Spacer()
                                        Image(systemName: "map")
                                            .foregroundColor(PFColors.textTertiary)
                                            .font(.caption2)
                                    }
                                    .font(PFFonts.callout)
                                    .padding()
                                    .background(PFColors.surfaceSecondary)
                                    .cornerRadius(PFRadius.md)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // 终点 - 可点击打开地图选点
                                Button(action: { showEndMapPicker = true }) {
                                    HStack {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundColor(.red)
                                        if endAddress.isEmpty {
                                            Text("booking_taxi_end_placeholder")
                                                .foregroundColor(PFColors.textTertiary)
                                        } else {
                                            Text(endAddress)
                                                .foregroundColor(PFColors.textPrimary)
                                        }
                                        Spacer()
                                        Image(systemName: "map")
                                            .foregroundColor(PFColors.textTertiary)
                                            .font(.caption2)
                                    }
                                    .font(PFFonts.callout)
                                    .padding()
                                    .background(PFColors.surfaceSecondary)
                                    .cornerRadius(PFRadius.md)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .sheet(isPresented: $showStartMapPicker) {
                            MapPointPickerView(
                                title: NSLocalizedString("booking_taxi_start_pick", comment: ""),
                                onSelect: { coord, addr in
                                    startCoordinate = coord
                                    startAddress = addr
                                }
                            )
                        }
                        .sheet(isPresented: $showEndMapPicker) {
                            MapPointPickerView(
                                title: NSLocalizedString("booking_taxi_end_pick", comment: ""),
                                onSelect: { coord, addr in
                                    endCoordinate = coord
                                    endAddress = addr
                                }
                            )
                        }
                        
                        // 3. 预约时间与电话
                        formSection(title: NSLocalizedString("booking_taxi_details", comment: "")) {
                            VStack(spacing: PFSpacing.md) {
                                // 出行时间快捷选择：立即 / 15分钟后 / 30分钟后 / 指定时间
                                HStack(spacing: 8) {
                                    ForEach(0..<4, id: \.self) { idx in
                                        Button {
                                            travelOption = idx
                                            let now = Date()
                                            switch idx {
                                            case 1: appointmentDate = now.addingTimeInterval(15 * 60)
                                            case 2: appointmentDate = now.addingTimeInterval(30 * 60)
                                            case 3: appointmentDate = now.addingTimeInterval(5 * 60)
                                            default: appointmentDate = now
                                            }
                                        } label: {
                                            Text(travelOptionLabel(idx))
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(travelOption == idx ? .white : PFColors.primary)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 7)
                                                .background(
                                                    Capsule()
                                                        .fill(travelOption == idx ? AnyShapeStyle(PFGradients.brand) : AnyShapeStyle(PFColors.primary.opacity(0.1)))
                                                )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.vertical, 2)

                                // 预约开始时间（指定时间时显示 DatePicker）
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(PFColors.primary)
                                    Text("booking_start_time")
                                        .font(PFFonts.callout)
                                        .foregroundColor(PFColors.textSecondary)
                                    Spacer()
                                    if travelOption == 3 {
                                        DatePicker("",
                                                   selection: $appointmentDate,
                                                   in: Date()...,
                                                   displayedComponents: [.date, .hourAndMinute])
                                            .datePickerStyle(CompactDatePickerStyle())
                                            .labelsHidden()
                                            .tint(PFColors.primary)
                                    } else {
                                        Text(appointmentDate, style: .time)
                                            .font(PFFonts.callout)
                                            .foregroundColor(PFColors.textPrimary)
                                    }
                                }
                                .padding(.vertical, 4)
                                
                                // 预约结束时间（自动计算）
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundColor(PFColors.textTertiary)
                                    Text("booking_end_time")
                                        .font(PFFonts.callout)
                                        .foregroundColor(PFColors.textSecondary)
                                    Spacer()
                                    Text(appointmentEndTime, style: .time)
                                        .font(PFFonts.callout)
                                        .foregroundColor(PFColors.textTertiary)
                                }
                                .padding(.vertical, 4)
                                
                                Divider()
                                
                                PFCurrentPhoneButton(phone: $contactPhone)
                                TextField("booking_phone_placeholder", text: $contactPhone)
                                    .keyboardType(.phonePad)
                                    .font(PFFonts.callout)
                                    .padding(.vertical, 8)
                            }
                        }
                        
                        // 4. 里程与加选服务（费用计算/消费金额）
                        formSection(title: NSLocalizedString("booking_taxi_cost_calc", comment: "")) {
                            VStack(spacing: PFSpacing.md) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("booking_taxi_distance")
                                            .font(PFFonts.callout)
                                        Spacer()
                                        Text(String(format: "%.1f km", distance))
                                            .font(PFFonts.headline)
                                            .foregroundColor(PFColors.primary)
                                    }
                                    
                                    Picker("booking_distance_range", selection: $distanceBand) {
                                        Text("booking_distance_short").tag(0)
                                        Text("booking_distance_medium").tag(1)
                                        Text("booking_distance_long").tag(2)
                                    }
                                    .pickerStyle(.segmented)
                                    .onChange(of: distanceBand) { band in
                                        distance = band == 0 ? 5 : band == 1 ? 100 : 600
                                        Haptics.play(.light)
                                    }

                                    Slider(value: $distance, in: distanceRange, step: 1)
                                        .tint(PFColors.primary)
                                }
                                
                                Divider()
                                
                                Toggle(isOn: $needAssistant) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("booking_taxi_opt_assistant")
                                            .font(PFFonts.callout)
                                        Text("booking_taxi_opt_assistant_desc")
                                            .font(PFFonts.caption)
                                            .foregroundColor(PFColors.textSecondary)
                                    }
                                }
                                .tint(PFColors.primary)
                                
                                Toggle(isOn: $multiPets) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("booking_taxi_opt_multipet")
                                            .font(PFFonts.callout)
                                        Text("booking_taxi_opt_multipet_desc")
                                            .font(PFFonts.caption)
                                            .foregroundColor(PFColors.textSecondary)
                                    }
                                }
                                .tint(PFColors.primary)
                                
                                Divider()
                                
                                // 消费金额（只读，系统计算）
                                HStack {
                                    Image(systemName: "yensign.circle.fill")
                                        .foregroundColor(.orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("booking_consumption_amount")
                                            .font(PFFonts.callout)
                                        Text("booking_amount_readonly_hint")
                                            .font(PFFonts.caption2)
                                            .foregroundColor(PFColors.textTertiary)
                                    }
                                    Spacer()
                                    Text(String(format: "¥ %.2f", consumptionAmount))
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.orange)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        // 5. 预约要求（特殊需求）
                        formSection(title: NSLocalizedString("booking_requirements_title", comment: "")) {
                            VStack(alignment: .leading, spacing: PFSpacing.sm) {
                                PFVoiceInputEditor(
                                    placeholder: "booking_requirements_placeholder",
                                    text: $remarks,
                                    height: 100,
                                    maxLength: 500
                                )
                                Text("booking_requirements_hint")
                                    .font(PFFonts.caption2)
                                    .foregroundColor(PFColors.textTertiary)
                            }
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
                // 查看当前服务类型（打车）的订单记录（用 fullScreenCover 弹出，避免多层 NavigationStack 下 NavigationLink 失效）
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
                ServiceOrderListView(title: NSLocalizedString("person_service_taxi", comment: ""), type: "2", showCloseButton: true)
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
        guard !startAddress.trimmingCharacters(in: .whitespaces).isEmpty && !endAddress.trimmingCharacters(in: .whitespaces).isEmpty else {
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
            let endDateStr = dateFormatter.string(from: appointmentEndTime)
            
            // 拼装备注信息，把所有表单项写入备注以做兼容
            let finalRemark = String(format: NSLocalizedString("taxi_remark_format", comment: ""),
                startAddress,
                endAddress,
                contactPhone,
                String(format: "%.1f km", distance),
                needAssistant ? NSLocalizedString("need_escort", comment: "") : NSLocalizedString("none_option", comment: ""),
                multiPets ? NSLocalizedString("multi_pet_ride", comment: "") : "",
                String(format: "%.2f", estimatedCost),
                remarks.isEmpty ? NSLocalizedString("none_option", comment: "") : remarks
            )
            
            var param: [String: Any] = [
                "petId": petId,
                "serviceName": serviceName,
                "serviceDate": dateStr,
                "remark": finalRemark,
                "payStatus": 0,
                // 预约单字段（对应后端列，不塞进备注）
                "phoneInformation": contactPhone,
                "reserveStartTime": dateStr,
                "reserveEndTime": endDateStr,
                "reserveInformation": remarks,
                "consumptionAmount": estimatedCost
            ]
            
            // 如果有点击选点坐标，也传递
            if let start = startCoordinate {
                param["startLatitude"] = start.latitude
                param["startLongitude"] = start.longitude
            }
            if let end = endCoordinate {
                param["endLatitude"] = end.latitude
                param["endLongitude"] = end.longitude
            }
            
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
                            serviceType: 2,
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

// MARK: - 地图选点组件
