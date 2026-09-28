import SwiftUI

struct AdoptionFormView: View {
    let pet: Pet
    @Environment(\.dismiss) var dismiss
    
    @State private var applicantName = ""
    @State private var contactPhone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var houseType = 0 // 0: 自购房, 1: 租房
    @State private var hasExperience = false // 是否有养宠经验
    @State private var message = ""
    @State private var isSubmitting = false

    // 提交成功后展示订单详情页（供「立即支付」）
    @State private var orderToShow: ServiceOrderRow? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                PFColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: PFSpacing.xl) {
                        
                        // 头部卡片
                        VStack(spacing: PFSpacing.sm) {
                            ZStack {
                                Circle()
                                    .fill(Color.pink.opacity(0.1))
                                    .frame(width: 70, height: 70)
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.pink)
                            }
                            
                            Text("adopt_greeting_title")
                                .font(PFFonts.title2)
                                .foregroundColor(PFColors.textPrimary)
                            
                            Text(String(format: NSLocalizedString("adopt_greeting_message", comment: ""), pet.displayName))
                                .font(PFFonts.caption)
                                .foregroundColor(PFColors.textSecondary)
                        }
                        .padding(.top, PFSpacing.lg)
                        
                        // 基本信息
                        formSection(title: NSLocalizedString("adopt_basic_info", comment: "")) {
                            VStack(spacing: PFSpacing.md) {
                                TextField("input_real_name", text: $applicantName)
                                    .font(PFFonts.callout)
                                    .padding()
                                    .background(PFColors.surfaceSecondary)
                                    .cornerRadius(PFRadius.md)
                                
                                TextField("input_contact_phone", text: $contactPhone)
                                    .keyboardType(.phonePad)
                                    .font(PFFonts.callout)
                                    .padding()
                                    .background(PFColors.surfaceSecondary)
                                    .cornerRadius(PFRadius.md)
                                PFCurrentPhoneButton(phone: $contactPhone)
                                
                                TextField("input_email_opt", text: $email)
                                    .keyboardType(.emailAddress)
                                    .font(PFFonts.callout)
                                    .padding()
                                    .background(PFColors.surfaceSecondary)
                                    .cornerRadius(PFRadius.md)
                            }
                        }
                        
                        // 居住与环境
                        formSection(title: NSLocalizedString("adopt_env_title", comment: "")) {
                            VStack(alignment: .leading, spacing: PFSpacing.md) {
                                Picker("house_type", selection: $houseType) {
                                    Text(NSLocalizedString("house_own", comment: "")).tag(0)
                                    Text(NSLocalizedString("house_rent", comment: "")).tag(1)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                
                                Divider()
                                
                                Toggle("has_pet_exp", isOn: $hasExperience)
                                    .font(PFFonts.callout)
                                    .tint(PFColors.primary)
                                
                                Divider()
                                
                                TextField(LocalizedStringKey("input_address"), text: $address)
                                    .font(PFFonts.callout)
                                    .padding()
                                    .background(PFColors.surfaceSecondary)
                                    .cornerRadius(PFRadius.md)
                            }
                        }
                        
                        // 附言
                        formSection(title: NSLocalizedString("adopt_message_title", comment: "")) {
                            PFVoiceInputEditor(
                                placeholder: "adopt_message_placeholder",
                                text: $message,
                                height: 100,
                                maxLength: 500
                            )
                        }
                    }
                    .padding(.horizontal, PFSpacing.xl)
                    .padding(.bottom, 120)
                }
                
                // 提交按钮
                VStack {
                    Spacer()
                    VStack {
                        Button {
                            submitAdoption()
                        } label: {
                            HStack { if isSubmitting { ProgressView().tint(.white) }; Image(systemName: "heart.fill"); Text("adopt_submit_btn") }
                                .font(PFFonts.headline).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 54)
                                .background(PFColors.primary, in: RoundedRectangle(cornerRadius: PFRadius.lg))
                        }
                        .disabled(isSubmitting)
                    }
                    .padding(.horizontal, PFSpacing.xl)
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
            .navigationBarItems(leading: Button("alert_cancel") { dismiss() })
            .navigationBarTitleDisplayMode(.inline)
            // 提交成功后展示订单详情页（含「立即支付」）
            .fullScreenCover(item: $orderToShow) { order in
                NavigationStack {
                    ServiceOrderDetailView(order: order, showCloseButton: true)
                }
            }
        }
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
    
    private func submitAdoption() {
        guard !applicantName.trimmingCharacters(in: .whitespaces).isEmpty else {
            showErrorAlert(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("err_adopt_name", comment: "")]))
            return
        }
        guard !contactPhone.trimmingCharacters(in: .whitespaces).isEmpty else {
            showErrorAlert(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("err_adopt_phone", comment: "")]))
            return
        }
        guard !address.trimmingCharacters(in: .whitespaces).isEmpty else {
            showErrorAlert(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("err_adopt_addr", comment: "")]))
            return
        }
        
        isSubmitting = true
        Task {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let dateStr = dateFormatter.string(from: Date())
            
            let finalRemark = String(format: NSLocalizedString("adoption_remark_format", comment: ""),
                applicantName,
                contactPhone,
                email.isEmpty ? NSLocalizedString("not_filled", comment: "") : email,
                houseType == 0 ? NSLocalizedString("house_own", comment: "") : NSLocalizedString("house_rent", comment: ""),
                hasExperience ? NSLocalizedString("has_experience", comment: "") : NSLocalizedString("no_experience", comment: ""),
                address,
                message.isEmpty ? NSLocalizedString("none_option", comment: "") : message
            )
            
            let petId = pet.petId
            let param: [String: Any] = [
                "petId": petId,
                "serviceName": String(format: NSLocalizedString("adoption_application_for", comment: ""), pet.displayName),
                "serviceDate": dateStr,
                "remark": finalRemark,
                "payStatus": 0
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
                        let serviceName = String(format: NSLocalizedString("adoption_application_for", comment: ""), pet.displayName)
                        let row = ServiceOrderRow(
                            consumerId: cid,
                            serviceName: serviceName,
                            serviceType: 11,
                            status: 2,
                            payStatus: 0,
                            consumptionAmount: 0,
                            actualAmount: 0
                        )
                        self.orderToShow = detailRow ?? row
                    } else {
                        showSuccessHUD(message: resp.msg ?? NSLocalizedString("adopt_submit_ok", comment: ""))
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
import PhotosUI
