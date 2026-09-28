//
//  ProviderQualificationView.swift
//  PetFriendly
//
//  服务商资质上传页面（实名认证、芝麻信用、无犯罪证明）
//

import SwiftUI
import Alamofire

// MARK: - 资质条目
private struct QualItem: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let statusKey: String // 用于取状态文本
}

// MARK: - 主视图
struct ProviderQualificationView: View {
    @State private var qualification: ProviderQualification?
    @State private var isLoading = true
    @State private var errorMsg: String?
    
    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            
            if isLoading {
                PFPetLoadingView("qual_loading", size: 36)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: PFSpacing.lg) {
                        // 错误提示
                        if let err = errorMsg {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(PFColors.danger)
                                Text(err)
                                    .font(PFFonts.caption)
                                    .foregroundColor(PFColors.danger)
                                Spacer()
                                Button(action: fetchQualification) {
                                    Text("retry")
                                        .font(PFFonts.caption)
                                        .foregroundColor(PFColors.primary)
                                }
                            }
                            .padding()
                            .background(PFColors.danger.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
                        }
                        
                        // 整体状态卡片
                        overallStatusCard
                        
                        // 用户信息卡片
                        userInfoCard
                        
                        // 三项资质条目
                        realNameCard
                        sesameCreditCard
                        criminalRecordCard
                        
                        // 说明
                        infoSection
                    }
                    .padding(PFSpacing.lg)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("qual_title")
        .navigationBarTitleDisplayMode(.inline)
        .trackScene("ProviderQualification")
        .onAppear { fetchQualification() }
    }
    
    // MARK: - 拉取资质数据
    private func fetchQualification() {
        isLoading = true
        Task {
            do {
                let resp: RespWrapper<ProviderQualification> = try await NetworkManager.shared.request(
                    "/petFriendly/client/provider/qualification",
                    method: .get,
                    needToken: true,
                    showLoading: false
                )
                await MainActor.run {
                    qualification = resp.data
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMsg = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    // MARK: - 整体状态
    private var overallStatusCard: some View {
        VStack(spacing: PFSpacing.md) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 28))
                    .foregroundColor(statusColor(qualification?.overallStatus ?? 0))
                VStack(alignment: .leading, spacing: 4) {
                    Text("qual_overall_status")
                        .font(PFFonts.headline)
                        .foregroundColor(PFColors.textPrimary)
                    Text(qualStatusText(qualification?.overallStatus ?? 0))
                        .font(PFFonts.caption)
                        .foregroundColor(statusColor(qualification?.overallStatus ?? 0))
                }
                Spacer()
            }
        }
        .padding(PFSpacing.lg)
        .background(cardBg)
        .pfCardShadow()
    }
    
    // MARK: - 用户信息卡片
    private var userInfoCard: some View {
        VStack(spacing: PFSpacing.md) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(PFColors.primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("qual_user_info")
                        .font(PFFonts.headline)
                        .foregroundColor(PFColors.textPrimary)
                    if let name = qualification?.userName {
                        detailRow(label: NSLocalizedString("form_nickname", comment: ""), value: name)
                    }
                    if let phone = qualification?.phone {
                        detailRow(label: NSLocalizedString("order_field_contact", comment: ""), value: phone)
                    }
                    if let realName = qualification?.realName {
                        detailRow(label: NSLocalizedString("qual_real_name_label", comment: ""), value: realName)
                    }
                    if let idCard = qualification?.idCardNumber {
                        detailRow(label: NSLocalizedString("qual_id_card_label", comment: ""), value: idCard.maskedIDCard)
                    }
                }
                Spacer()
            }
        }
        .padding(PFSpacing.lg)
        .background(cardBg)
        .pfCardShadow()
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label + ":")
                .font(PFFonts.caption)
                .foregroundColor(PFColors.textTertiary)
            Text(value)
                .font(PFFonts.caption)
                .foregroundColor(PFColors.textPrimary)
            Spacer()
        }
    }
    
    // MARK: - 实名认证卡片
    @State private var showRealName = false
    private var realNameCard: some View {
        Button(action: { showRealName = true }) {
            qualItemCard(
                icon: "person.text.rectangle.fill",
                title: NSLocalizedString("qual_real_name_title", comment: "实名认证"),
                status: qualification?.realNameAuthStatus ?? 0,
                remark: qualification?.realNameAuthRemark,
                accentColor: PFColors.info
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showRealName) {
            NavigationStack { RealNameAuthView(qualification: $qualification) }
        }
    }
    
    // MARK: - 芝麻信用卡片
    @State private var showSesame = false
    private var sesameCreditCard: some View {
        Button(action: { showSesame = true }) {
            qualItemCard(
                icon: "creditcard.fill",
                title: NSLocalizedString("qual_sesame_title", comment: "芝麻信用"),
                status: qualification?.sesameCreditAuthStatus ?? 0,
                remark: qualification?.sesameCreditAuthRemark,
                accentColor: PFColors.warning
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showSesame) {
            NavigationStack { SesameCreditAuthView(qualification: $qualification) }
        }
    }
    
    // MARK: - 无犯罪证明卡片
    @State private var showCriminal = false
    private var criminalRecordCard: some View {
        Button(action: { showCriminal = true }) {
            qualItemCard(
                icon: "doc.text.fill",
                title: NSLocalizedString("qual_criminal_title", comment: "无犯罪证明"),
                status: qualification?.criminalRecordAuthStatus ?? 0,
                remark: qualification?.criminalRecordAuthRemark,
                accentColor: PFColors.success
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showCriminal) {
            NavigationStack { CriminalRecordUploadView(qualification: $qualification) }
        }
    }
    
    // MARK: - 单项卡片
    private func qualItemCard(icon: String, title: String, status: Int, remark: String?, accentColor: Color) -> some View {
        HStack(spacing: PFSpacing.md) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(accentColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(PFFonts.body)
                    .foregroundColor(PFColors.textPrimary)
                
                HStack(spacing: 8) {
                    Text(qualStatusText(status))
                        .font(PFFonts.caption2)
                        .foregroundColor(statusColor(status))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor(status).opacity(0.1))
                        .clipShape(Capsule())
                    
                    if let remark = remark, !remark.isEmpty {
                        Text(remark)
                            .font(PFFonts.caption2)
                            .foregroundColor(PFColors.textTertiary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(PFColors.textTertiary)
        }
        .padding(PFSpacing.lg)
        .background(cardBg)
        .pfCardShadow()
    }
    
    // MARK: - 说明
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("qual_info_title", systemImage: "info.circle.fill")
                .font(PFFonts.caption)
                .foregroundColor(PFColors.textSecondary)
            
            Text("qual_info_detail")
                .font(PFFonts.caption2)
                .foregroundColor(PFColors.textTertiary)
                .lineSpacing(4)
        }
        .padding(PFSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBg)
        .pfCardShadow()
    }
    
    // MARK: - Helpers
    private var cardBg: some View {
        RoundedRectangle(cornerRadius: PFRadius.lg).fill(PFColors.surface)
    }
    
    private func qualStatusText(_ status: Int) -> String {
        status.qualificationStatusText
    }
    
    private func statusColor(_ status: Int) -> Color {
        switch status {
        case 0: return PFColors.textSecondary
        case 1: return PFColors.warning
        case 2: return PFColors.success
        case 3: return PFColors.danger
        default: return PFColors.textSecondary
        }
    }
}

// MARK: - 实名认证子页面
struct RealNameAuthView: View {
    @Binding var qualification: ProviderQualification?
    @State private var realName: String = ""
    @State private var idCardNumber: String = ""
    @State private var idCardFrontUrl: String = ""
    @State private var idCardBackUrl: String = ""
    @State private var isSubmitting = false
    @State private var showImagePicker = false
    @State private var pickerTarget: String = ""
    @State private var selectedImage: UIImage?
    @ObservedObject private var uiState = UIState.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: PFSpacing.lg) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("qual_real_name_label")
                            .font(PFFonts.callout)
                            .foregroundColor(PFColors.textPrimary)
                        TextField("qual_real_name_placeholder", text: $realName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    // 身份证号
                    VStack(alignment: .leading, spacing: 8) {
                        Text("qual_id_card_label")
                            .font(PFFonts.callout)
                            .foregroundColor(PFColors.textPrimary)
                        TextField("qual_id_card_placeholder", text: $idCardNumber)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.asciiCapable)
                    }
                    
                    // 身份证正面
                    VStack(alignment: .leading, spacing: 8) {
                        Text("qual_id_card_front")
                            .font(PFFonts.callout)
                            .foregroundColor(PFColors.textPrimary)
                        uploadImageButton(title: "qual_upload_front", url: $idCardFrontUrl, target: "front")
                    }
                    
                    // 身份证背面
                    VStack(alignment: .leading, spacing: 8) {
                        Text("qual_id_card_back")
                            .font(PFFonts.callout)
                            .foregroundColor(PFColors.textPrimary)
                        uploadImageButton(title: "qual_upload_back", url: $idCardBackUrl, target: "back")
                    }
                    
                    // 如果已有审核记录，显示当前状态
                    if let qual = qualification, let status = qual.realNameAuthStatus, status > 0 {
                        HStack {
                            Text("qual_current_status")
                                .font(PFFonts.caption)
                                .foregroundColor(PFColors.textSecondary)
                            Text(status.qualificationStatusText)
                                .font(PFFonts.caption)
                                .foregroundColor(statusColor(status))
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(cardBg)
                    }
                    
                    // 提交按钮
                    Button(action: submitRealNameAuth) {
                        HStack {
                            if isSubmitting {
                                PFPetLoadingInline(size: 16)
                            }
                            Text("qual_submit")
                                .font(PFFonts.body)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PFColors.primary)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
                    }
                    .disabled(isSubmitting || realName.isEmpty || idCardNumber.isEmpty || (qualification?.realNameAuthStatus == 2))
                    .opacity((isSubmitting || realName.isEmpty || idCardNumber.isEmpty || (qualification?.realNameAuthStatus == 2)) ? 0.6 : 1)
                }
                .padding(PFSpacing.lg)
            }
            
            // 上传进度遮罩
            if uiState.isUploading || uiState.isUploadFinished {
                ZStack {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                    CircularUploadProgressView(
                        progress: uiState.uploadProgress,
                        isFinished: uiState.isUploadFinished
                    )
                }
                .transition(.opacity)
                .animation(.spring(), value: uiState.isUploading)
            }
        }
        .navigationTitle("qual_real_name_title")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let qual = qualification {
                realName = qual.realName ?? ""
                idCardNumber = qual.idCardNumber ?? ""
                idCardFrontUrl = qual.idCardFrontImg ?? ""
                idCardBackUrl = qual.idCardBackImg ?? ""
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .onChange(of: selectedImage) { newImage in
            guard let img = newImage else { return }
            uploadImage(img)
        }
    }
    
    private func uploadImage(_ image: UIImage) {
        Task {
            do {
                let url: String = try await NetworkManager.shared.uploadImage(image, to: "/petFriendly/client/upload")
                await MainActor.run {
                    if pickerTarget == "front" {
                        idCardFrontUrl = url
                    } else {
                        idCardBackUrl = url
                    }
                }
            } catch {
                await MainActor.run {
                    UIState.shared.showToast(error.localizedDescription)
                }
            }
        }
    }
    
    private func submitRealNameAuth() {
        guard !realName.isEmpty, !idCardNumber.isEmpty else { return }
        isSubmitting = true
        let params: [String: Any] = [
            "realName": realName,
            "idCardNumber": idCardNumber,
            "idCardFrontImg": idCardFrontUrl,
            "idCardBackImg": idCardBackUrl
        ]
        Task {
            do {
                let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                    "/petFriendly/client/provider/qualification/realName",
                    method: .post,
                    parameters: params,
                    encoding: JSONEncoding.default,
                    needToken: true
                )
                await MainActor.run {
                    isSubmitting = false
                    if resp.code == 200 {
                        UIState.shared.showToast(NSLocalizedString("qual_submit_success", comment: ""))
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                }
            }
        }
    }
    
    private func statusColor(_ status: Int) -> Color {
        switch status {
        case 1: return PFColors.warning
        case 2: return PFColors.success
        case 3: return PFColors.danger
        default: return PFColors.textSecondary
        }
    }
    
    private var cardBg: some View {
        RoundedRectangle(cornerRadius: PFRadius.lg).fill(PFColors.surface)
    }
    
    private func uploadImageButton(title: String, url: Binding<String>, target: String) -> some View {
        VStack(spacing: 8) {
            if !url.wrappedValue.isEmpty {
                // 图片预览（原图比例 + 圆角）
                CachedAsyncImage(url: NetworkManager.fullUrl(url.wrappedValue)) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView()
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
            }
            
            Button(action: {
                pickerTarget = target
                showImagePicker = true
            }) {
            HStack {
                if url.wrappedValue.isEmpty {
                    Image(systemName: "camera.fill")
                        .foregroundColor(PFColors.primary)
                    Text(LocalizedStringKey(title))
                        .font(PFFonts.caption)
                        .foregroundColor(PFColors.primary)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(PFColors.success)
                    Text("qual_uploaded")
                        .font(PFFonts.caption)
                        .foregroundColor(PFColors.success)
                }
                Spacer()
                if !url.wrappedValue.isEmpty {
                    Button(action: { url.wrappedValue = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(PFColors.textTertiary)
                    }
                }
            }
            .padding()
            .background(cardBg)
            .pfCardShadow()
        }
        }
    }
}

// MARK: - 芝麻信用授权页面
struct SesameCreditAuthView: View {
    @Binding var qualification: ProviderQualification?
    @State private var authorized = false
    @State private var creditScore: String = ""
    @State private var screenshotUrl: String = ""
    @State private var isSubmitting = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @ObservedObject private var uiState = UIState.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: PFSpacing.lg) {
                    // 授权开关
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $authorized) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("qual_sesame_auth_toggle")
                                    .font(PFFonts.callout)
                                    .foregroundColor(PFColors.textPrimary)
                                Text("qual_sesame_auth_hint")
                                    .font(PFFonts.caption2)
                                    .foregroundColor(PFColors.textTertiary)
                            }
                        }
                        .padding()
                        .background(cardBg)
                        .pfCardShadow()
                    }
                    
                    // 信用分
                    VStack(alignment: .leading, spacing: 8) {
                        Text("qual_sesame_score")
                            .font(PFFonts.callout)
                            .foregroundColor(PFColors.textPrimary)
                        TextField("qual_sesame_score_placeholder", text: $creditScore)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                    }
                    
                    // 截图
                    VStack(alignment: .leading, spacing: 8) {
                        Text("qual_sesame_screenshot")
                            .font(PFFonts.callout)
                            .foregroundColor(PFColors.textPrimary)
                        if !screenshotUrl.isEmpty {
                            CachedAsyncImage(url: NetworkManager.fullUrl(screenshotUrl)) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
                        }
                        Button(action: { showImagePicker = true }) {
                            HStack {
                                if screenshotUrl.isEmpty {
                                    Image(systemName: "camera.fill").foregroundColor(PFColors.warning)
                                    Text("qual_upload_screenshot")
                                        .font(PFFonts.caption).foregroundColor(PFColors.warning)
                                } else {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(PFColors.success)
                                    Text("qual_uploaded").font(PFFonts.caption).foregroundColor(PFColors.success)
                                }
                                Spacer()
                            }
                            .padding().background(cardBg).pfCardShadow()
                        }
                    }
                    
                    if let qual = qualification, let status = qual.sesameCreditAuthStatus, status > 0 {
                        HStack {
                            Text("qual_current_status").font(PFFonts.caption).foregroundColor(PFColors.textSecondary)
                            Text(status.qualificationStatusText).font(PFFonts.caption).foregroundColor(statusColor(status))
                        }
                        .padding().frame(maxWidth: .infinity).background(cardBg)
                    }
                    
                    Button(action: submitSesameCredit) {
                        HStack {
                            if isSubmitting { PFPetLoadingInline(size: 16) }
                            Text("qual_submit").font(PFFonts.body)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(PFColors.primary).foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
                    }
                    .disabled(isSubmitting || !authorized || (qualification?.sesameCreditAuthStatus == 2))
                    .opacity((isSubmitting || !authorized || (qualification?.sesameCreditAuthStatus == 2)) ? 0.6 : 1)
                }
                .padding(PFSpacing.lg)
            }
            
            // 上传进度遮罩
            if uiState.isUploading || uiState.isUploadFinished {
                ZStack {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                    CircularUploadProgressView(
                        progress: uiState.uploadProgress,
                        isFinished: uiState.isUploadFinished
                    )
                }
                .transition(.opacity)
                .animation(.spring(), value: uiState.isUploading)
            }
        }
        .navigationTitle("qual_sesame_title")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let qual = qualification {
                authorized = qual.sesameCreditAuthorized == 1
                creditScore = qual.sesameCreditScore.map { String($0) } ?? ""
                screenshotUrl = qual.sesameCreditImg ?? ""
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .onChange(of: selectedImage) { img in
            guard let img = img else { return }
            Task {
                do {
                    let url: String = try await NetworkManager.shared.uploadImage(img, to: "/petFriendly/client/upload")
                    await MainActor.run { screenshotUrl = url }
                } catch {
                    await MainActor.run { UIState.shared.showToast(error.localizedDescription) }
                }
            }
        }
    }
    
    private func submitSesameCredit() {
        isSubmitting = true
        let params: [String: Any] = [
            "sesameCreditAuthorized": authorized ? 1 : 0,
            "sesameCreditScore": Int(creditScore) ?? 0,
            "sesameCreditImg": screenshotUrl
        ]
        Task {
            do {
                let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                    "/petFriendly/client/provider/qualification/sesameCredit",
                    method: .post, parameters: params, encoding: JSONEncoding.default, needToken: true
                )
                await MainActor.run {
                    isSubmitting = false
                    if resp.code == 200 { UIState.shared.showToast(NSLocalizedString("qual_submit_success", comment: "")); dismiss() }
                }
            } catch { await MainActor.run { isSubmitting = false } }
        }
    }
    
    private func statusColor(_ s: Int) -> Color {
        s == 1 ? PFColors.warning : s == 2 ? PFColors.success : s == 3 ? PFColors.danger : PFColors.textSecondary
    }
    private var cardBg: some View { RoundedRectangle(cornerRadius: PFRadius.lg).fill(PFColors.surface) }
}
struct CriminalRecordUploadView: View {
    @Binding var qualification: ProviderQualification?
    @State private var fileUrl: String = ""
    @State private var isSubmitting = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @ObservedObject private var uiState = UIState.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: PFSpacing.lg) {
                    // 说明
                    VStack(alignment: .leading, spacing: 8) {
                        Label("qual_criminal_hint", systemImage: "info.circle.fill")
                            .font(PFFonts.callout)
                            .foregroundColor(PFColors.textSecondary)
                        Text("qual_criminal_detail")
                            .font(PFFonts.caption2)
                            .foregroundColor(PFColors.textTertiary)
                            .lineSpacing(4)
                    }
                    .padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(cardBg).pfCardShadow()
                    
                    // 上传
                    VStack(alignment: .leading, spacing: 8) {
                        Text("qual_criminal_upload_label")
                            .font(PFFonts.callout).foregroundColor(PFColors.textPrimary)
                        if !fileUrl.isEmpty {
                            CachedAsyncImage(url: NetworkManager.fullUrl(fileUrl)) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
                        }
                        Button(action: { showImagePicker = true }) {
                            HStack {
                                if fileUrl.isEmpty {
                                    Image(systemName: "doc.badge.plus").foregroundColor(PFColors.success)
                                    Text("qual_upload_file").font(PFFonts.caption).foregroundColor(PFColors.success)
                                } else {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(PFColors.success)
                                    Text("qual_uploaded").font(PFFonts.caption).foregroundColor(PFColors.success)
                                }
                                Spacer()
                            }
                            .padding().background(cardBg).pfCardShadow()
                        }
                    }
                    
                    if let qual = qualification, let status = qual.criminalRecordAuthStatus, status > 0 {
                        HStack {
                            Text("qual_current_status").font(PFFonts.caption).foregroundColor(PFColors.textSecondary)
                            Text(status.qualificationStatusText).font(PFFonts.caption).foregroundColor(statusColor(status))
                        }
                        .padding().frame(maxWidth: .infinity).background(cardBg)
                    }
                    
                    Button(action: submitCriminalRecord) {
                        HStack {
                            if isSubmitting { PFPetLoadingInline(size: 16) }
                            Text("qual_submit").font(PFFonts.body)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(PFColors.primary).foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
                    }
                    .disabled(isSubmitting || fileUrl.isEmpty || (qualification?.criminalRecordAuthStatus == 2))
                    .opacity((isSubmitting || fileUrl.isEmpty || (qualification?.criminalRecordAuthStatus == 2)) ? 0.6 : 1)
                }
                .padding(PFSpacing.lg)
            }
            
            // 上传进度遮罩
            if uiState.isUploading || uiState.isUploadFinished {
                ZStack {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                    CircularUploadProgressView(
                        progress: uiState.uploadProgress,
                        isFinished: uiState.isUploadFinished
                    )
                }
                .transition(.opacity)
                .animation(.spring(), value: uiState.isUploading)
            }
        }
        .navigationTitle("qual_criminal_title")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { fileUrl = qualification?.criminalRecordImg ?? "" }
        .sheet(isPresented: $showImagePicker) { ImagePicker(image: $selectedImage) }
        .onChange(of: selectedImage) { img in
            guard let img = img else { return }
            Task {
                do {
                    let url: String = try await NetworkManager.shared.uploadImage(img, to: "/petFriendly/client/upload")
                    await MainActor.run { fileUrl = url }
                } catch { await MainActor.run { UIState.shared.showToast(error.localizedDescription) } }
            }
        }
    }
    
    private func submitCriminalRecord() {
        isSubmitting = true
        let params: [String: Any] = ["criminalRecordImg": fileUrl]
        Task {
            do {
                let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                    "/petFriendly/client/provider/qualification/criminalRecord",
                    method: .post, parameters: params, encoding: JSONEncoding.default, needToken: true
                )
                await MainActor.run {
                    isSubmitting = false
                    if resp.code == 200 { UIState.shared.showToast(NSLocalizedString("qual_submit_success", comment: "")); dismiss() }
                }
            } catch { await MainActor.run { isSubmitting = false } }
        }
    }
    
    private func statusColor(_ s: Int) -> Color {
        s == 1 ? PFColors.warning : s == 2 ? PFColors.success : s == 3 ? PFColors.danger : PFColors.textSecondary
    }
    private var cardBg: some View { RoundedRectangle(cornerRadius: PFRadius.lg).fill(PFColors.surface) }
}

// MARK: - 身份证号脱敏
extension String {
    var maskedIDCard: String {
        guard count >= 14 else { return self }
        let prefix = prefix(4)
        let suffix = suffix(4)
        return "\(prefix)****\(suffix)"
    }
}
