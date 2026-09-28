//
//  PetDetailView.swift
//  PetFriendly
//
//  宠物详情页（极致美化版）
//

import SwiftUI
import Alamofire

struct PetDetailView: View {
    let pet: Pet
    var isReadOnly: Bool = false
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var uiState: UIState
    @StateObject private var viewModel = PetDetailViewModel()
    @State private var appearAnim = false
    @State private var showAddRecord = false
    @State private var showEditPet = false
    @State private var showVoiceRecorder = false
    @State private var petLocal: Pet?
    @State private var currentVoiceUrl: String?
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // MARK: 视差头图
                headerImage
                    .ignoresSafeArea(edges: .top)
                
                // MARK: 信息网格
                infoGrid
                    .padding(.top, -40)
                    .zIndex(1)
                
                // MARK: 录音区域
                if !isReadOnly || pet.voiceURL != nil {
                    voiceSection.padding(.top, PFSpacing.xl)
                }
                
                // MARK: 健康记录时间线
                healthSection
            }
        }
        .background(PFColors.background)
        .navigationTitle(pet.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .trackScene("PetDetail")
        .pfToyBackground()
        .toolbar {
            if !isReadOnly {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        showEditPet = true
                    }) {
                        Text("alert_edit").font(PFFonts.callout).foregroundColor(PFColors.primary)
                    }
                }
            }
        }
        .onAppear {
            viewModel.fetchRecords(petId: pet.petId)
            viewModel.fetchBreedInfo(pet: pet)
            withAnimation(PFAnimation.springGentle.delay(0.2)) {
                appearAnim = true
            }
        }
        .sheet(isPresented: $showAddRecord) {
            AddHealthRecordView(petId: pet.petId) {
                viewModel.fetchRecords(petId: pet.petId)
            }
        }
        .sheet(isPresented: $showEditPet) {
            EditPetView(pet: petLocal ?? pet)
        }
        .sheet(isPresented: $showVoiceRecorder) {
            VoiceRecorderView(petId: pet.petId) { urlString in
                currentVoiceUrl = urlString
                NotificationCenter.default.post(name: NSNotification.Name("PetInfoUpdated"), object: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PetInfoUpdated"))) { _ in
            // 简单刷新
            viewModel.fetchRecords(petId: pet.petId)
            viewModel.fetchBreedInfo(pet: pet)
        }
        .onAppear {
            currentVoiceUrl = pet.voiceUrl
        }
    }
    
    // MARK: - 头图区域
    private var headerImage: some View {
        ZStack(alignment: .bottom) {
            // 背景底图
            if let url = pet.avatarUrl {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(PFColors.surfaceSecondary)
                }
                .frame(width: PFScreen.width, height: 400)
                .clipped()
                .pfImageInteractable(url: pet.avatarUrl?.absoluteString)
            } else {
                Rectangle()
                    .fill(PFGradients.brand)
                    .frame(width: PFScreen.width, height: 400)
                    .overlay(
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.3))
                    )
            }
            
            // 渐变叠加，增强层级感
            LinearGradient(
                colors: [.black.opacity(0.7), .black.opacity(0.3), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 200)
            
            // 核心信息
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Text(pet.displayName)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    
                    PFTag(
                        text: pet.sex == 2 ? LocalizedStringKey("pets_sex_female") : (pet.sex == 1 ? LocalizedStringKey("pets_sex_male") : LocalizedStringKey("pets_sex_private")),
                        gradient: pet.sex == 2
                            ? LinearGradient(colors: [PFColors.genderFemale], startPoint: .leading, endPoint: .trailing)
                            : (pet.sex == 1 ? LinearGradient(colors: [PFColors.genderMale], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [PFColors.info], startPoint: .leading, endPoint: .trailing))
                    )
                }
                .foregroundColor(.white)
                
                HStack(spacing: 16) {
                    Label(LocalizedStringKey(viewModel.breedName), systemImage: "pawprint.circle.fill")
                    Label(pet.ageString, systemImage: "clock.fill")
                }
                .font(PFFonts.callout)
                .foregroundColor(.white.opacity(0.9))
                
                Spacer().frame(height: 50)
            }
            .padding(.bottom, 30)
        }
        .onAppear {
            withAnimation(.spring()) {
                uiState.isTabBarHidden = true
                uiState.isTabBarForceHidden = true
            }
        }
        .onDisappear {
            withAnimation(.spring()) {
                uiState.isTabBarHidden = false
                uiState.isTabBarForceHidden = false
            }
        }
    }
    
    // MARK: - 信息网格（动态自适应版）
    private var infoGrid: some View {
        VStack(spacing: PFSpacing.md) {
            // 第一排：基础核心信息 (单颗宽卡片)
            detailInfoCardWide(
                icon: "calendar",
                title: LocalizedStringKey("form_birthday"),
                value: pet.formattedBirthday,
                color: PFColors.primary
            )
            
            // 第二排：动态提醒服务 (三方网格)
            HStack(spacing: PFSpacing.md) {
                NavigationLink(destination: PetHealthRecordListView(petId: pet.petId, petName: pet.displayName)) {
                    detailInfoCard(
                        icon: "cross.case",
                        title: "pets_vaccine_records",
                        value: (pet.isVaccineDue ?? false) ? NSLocalizedString("pets_remind_vaccine_button", comment: "") : NSLocalizedString("place_level_friendly", comment: ""),
                        color: (pet.isVaccineDue ?? false) ? PFColors.warning : PFColors.success
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                NavigationLink(destination: PetHealthRecordListView(petId: pet.petId, petName: pet.displayName)) {
                    detailInfoCard(
                        icon: "gift",
                        title: LocalizedStringKey("form_birthday"),
                        value: (pet.isBirthdaySoon ?? false) ? NSLocalizedString("pets_remind_birthday_button", comment: "") : NSLocalizedString("place_level_friendly", comment: ""),
                        color: (pet.isBirthdaySoon ?? false) ? PFColors.warning : PFColors.success
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                NavigationLink(destination: PetHealthRecordListView(petId: pet.petId, petName: pet.displayName)) {
                    detailInfoCard(
                        icon: "scissors",
                        title: LocalizedStringKey("health_type_beauty"),
                        value: (pet.isBeautyDue ?? false) ? NSLocalizedString("pets_remind_beauty_button", comment: "") : NSLocalizedString("place_level_friendly", comment: ""),
                        color: (pet.isBeautyDue ?? false) ? PFColors.warning : PFColors.success
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, PFSpacing.xl)
    }
    
    @ViewBuilder
    private func detailInfoCardWide(icon: String, title: LocalizedStringKey, value: String, color: Color) -> some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(PFColors.textSecondary)
                
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(PFColors.textPrimary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(PFColors.textSecondary.opacity(0.6))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                )
        )
        .pfElevatedShadow(color.opacity(0.1))
    }
    
    @ViewBuilder
    private func detailInfoCard(icon: String, title: LocalizedStringKey, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(PFColors.textSecondary)
                
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(PFColors.textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                )
        )
        .pfElevatedShadow(color.opacity(0.1))
    }
    
    // MARK: - 宠物录音区域
    @ViewBuilder
    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: PFSpacing.md) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(PFColors.primary)
                Text(LocalizedStringKey("voice_section_title"))
                    .font(PFFonts.title2)
                    .foregroundColor(PFColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, PFSpacing.xl)
            
            let displayVoiceUrl = currentVoiceUrl ?? pet.voiceUrl
            
            if let urlStr = displayVoiceUrl, !urlStr.isEmpty, let url = URL(string: urlStr) {
                // 已有录音，显示播放器
                VoicePlayerView(voiceURL: url)
                    .padding(.horizontal, PFSpacing.xl)
                
                if !isReadOnly { Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    showVoiceRecorder = true
                }) {
                    HStack(spacing: PFSpacing.sm) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 14))
                        Text(LocalizedStringKey("voice_recorder_retake"))
                            .font(PFFonts.caption)
                    }
                    .foregroundColor(PFColors.primary)
                    .padding(.horizontal, PFSpacing.xl)
                } }
            } else {
                // 无录音，显示录制按钮
                if !isReadOnly { Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    showVoiceRecorder = true
                }) {
                    HStack(spacing: PFSpacing.sm) {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 20))
                        Text(LocalizedStringKey("voice_recorder_record_button"))
                            .font(PFFonts.callout)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, PFSpacing.xxl)
                    .padding(.vertical, PFSpacing.md)
                    .background(
                        Capsule()
                            .fill(PFGradients.brand)
                    )
                    .pfElevatedShadow()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, PFSpacing.xl) }
            }
        }
    }
    
    // MARK: - 健康记录
    private var healthSection: some View {
        VStack(alignment: .leading, spacing: PFSpacing.lg) {
            NavigationLink(destination: PetHealthRecordListView(petId: pet.petId, petName: pet.displayName, isReadOnly: isReadOnly)) {
                HStack {
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(PFColors.info)
                    Text("pets_health_records")
                        .font(PFFonts.callout)
                        .foregroundColor(PFColors.textPrimary)
                    
                    Spacer()
                    
                    if !viewModel.records.isEmpty {
                        Text("pets_records_count \(viewModel.records.count)")
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.textTertiary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PFColors.textTertiary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, PFSpacing.xl)
            .padding(.top, PFSpacing.xl)

            Divider().padding(.horizontal, PFSpacing.xl).padding(.top, PFSpacing.sm)

            // 生长记录（体重/肩高时间线）入口
            NavigationLink(destination: PetGrowthRecordView(petId: pet.petId, petName: pet.displayName, isReadOnly: isReadOnly)) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(PFColors.success)
                    Text("pet_growth_nav_title")
                        .font(PFFonts.callout)
                        .foregroundColor(PFColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PFColors.textTertiary)
                }
                .padding(.horizontal, PFSpacing.xl)
                .padding(.top, PFSpacing.md)
            }
            .buttonStyle(PlainButtonStyle())

            if viewModel.records.isEmpty {
                VStack(spacing: PFSpacing.md) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(PFGradients.brand)
                        .opacity(0.5)
                    
                    Text("pets_no_health_records")
                        .font(PFFonts.body)
                        .foregroundColor(PFColors.textSecondary)
                    
                    if !isReadOnly { PFButton("pets_add_record_button", icon: "plus") {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        showAddRecord = true
                    }
                    .scaleEffect(0.9) }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.records.enumerated()), id: \.element.healthId) { index, record in
                        HealthRecordRow(record: record, isLast: index == viewModel.records.count - 1)
                            .opacity(appearAnim ? 1 : 0)
                            .offset(y: appearAnim ? 0 : 20)
                            .animation(
                                PFAnimation.springGentle.delay(Double(index) * 0.08),
                                value: appearAnim
                            )
                    }
                    
                    if !isReadOnly { PFButton("pets_add_record_button", icon: "plus") {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        showAddRecord = true
                    }
                    .padding(.top, 30)
                    .padding(.bottom, 50) }
                }
            }
        }
    }
}

// MARK: - 信息卡片（兼容旧引用）
struct InfoItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(PFColors.primary)
                .frame(width: 30)
            VStack(alignment: .leading) {
                Text(title).font(PFFonts.caption).foregroundColor(PFColors.textTertiary)
                Text(value).font(PFFonts.headline)
            }
            Spacer()
        }
        .padding()
        .background(PFColors.surfaceSecondary)
        .cornerRadius(PFRadius.sm)
    }
}

// MARK: - 时间线行
struct HealthRecordRow: View {
    let record: PetHealthRecord
    let isLast: Bool
    
    private var recordColor: Color {
        // 0=体检, 1=门诊, 2=住院, 3=绝育, 4=美容, 5=驱虫(内驱), 6=驱虫(外驱), 7=洗护护理, 8=疫苗, 9=狂犬
        switch record.type {
        case 8, 9: return PFColors.info       // 疫苗
        case 4, 7: return Color(hex: "8B5CF6") // 美容
        case 5, 6: return PFColors.success     // 驱虫
        case 0:    return PFColors.warning     // 体检
        case 3:    return PFColors.accent      // 绝育
        case 1, 2: return PFColors.danger      // 病情/住院
        default:  return PFColors.textTertiary
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            // 时间轴列
            VStack(spacing: 0) {
                // 圆形指示器
                ZStack {
                    Circle()
                        .fill(recordColor.opacity(0.2))
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .fill(recordColor)
                        .frame(width: 10, height: 10)
                }
                .padding(.top, 4)
                
                // 连接线
                if !isLast {
                    Rectangle()
                        .fill(recordColor.opacity(0.15))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                } else {
                    // 最后一条记录下方留出一点空间
                    Spacer()
                        .frame(height: 20)
                }
            }
            .frame(width: 24)
            
            // 内容卡片
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(LocalizedStringKey(record.titleKey))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(PFColors.textPrimary)
                    
                    Spacer()
                    
                    Text(record.downTime ?? "")
                        .font(PFFonts.caption)
                        .foregroundColor(PFColors.textTertiary)
                }
                
                if let desc = record.comments, !desc.isEmpty {
                    Text(desc)
                        .font(PFFonts.body)
                        .foregroundColor(PFColors.textSecondary)
                        .lineSpacing(4)
                }

                if record.type == 10 {
                    HStack(spacing: 16) {
                        if let weight = record.ext1, !weight.isEmpty {
                            Label("\(weight) kg", systemImage: "scalemass.fill").foregroundColor(PFColors.warning)
                        }
                        if let height = record.ext2, !height.isEmpty {
                            Label("\(height) cm", systemImage: "ruler.fill").foregroundColor(PFColors.accent)
                        }
                    }.font(PFFonts.caption)
                }
                
                HStack(spacing: 16) {
                    if let costString = record.consumptionAmount,
                       let costValue = Double(costString), costValue > 0 {
                        Label(String(format: "%.2f", costValue), systemImage: "yensign.circle.fill")
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.warning)
                    }
                    
                    if let hospital = record.remark, !hospital.isEmpty {
                        Label(hospital, systemImage: "mappin.and.ellipse")
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.primary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(PFColors.surface)
            )
            .pfCardShadow()
            .padding(.bottom, 10) // 这里控制行间距，同时由于 HStack 对齐，左侧线条会拉伸到此 padding 底部
        }
        .padding(.horizontal, PFSpacing.xl)
    }
}

// MARK: - ViewModel
class PetDetailViewModel: ObservableObject {
    @Published var records: [PetHealthRecord] = []
    @Published var breedName: String = NSLocalizedString("common_loading", comment: "")
    
    func fetchRecords(petId: String) {
        Task {
            do {
                let resp: HealthRecordListResp = try await NetworkManager.shared.request("/petFriendly/client/petHealthRecords?petId=\(petId)", method: .get, needToken: true)
                await MainActor.run {
                    self.records = resp.rows
                }
            } catch {
                print("Fetch records error: \(error)")
            }
        }
    }
    
    func fetchBreedInfo(pet: Pet) {
        guard let speciesId = pet.species, let breedId = pet.breeds else {
            self.breedName = pet.breed ?? NSLocalizedString("pets_unknown_breed", comment: "")
            return
        }
        
        Task {
            do {
                // 先获取品种名称，因为品种字典是动态的，需要 speciesValue
                // 获取 species 列表找到对应的 value
                let speciesResp: DictDataResp = try await NetworkManager.shared.request("/petFriendly/client/dictType/pet_information_species", method: .get, needToken: true)
                guard let species = speciesResp.data.first(where: { Int($0.dictValue) == speciesId }) else {
                    await MainActor.run { self.breedName = pet.breed ?? NSLocalizedString("pets_unknown_breed", comment: "") }
                    return
                }
                
                let breedResp: DictDataResp = try await NetworkManager.shared.request("/petFriendly/client/dictType/pet_information_breeds_\(species.dictValue)", method: .get, needToken: true)
                let breed = breedResp.data.first(where: { Int($0.dictValue) == breedId })
                
                await MainActor.run {
                    self.breedName = breed?.dictLabel ?? species.dictLabel
                }
            } catch {
                print("Fetch breed info error: \(error)")
                await MainActor.run { self.breedName = pet.breed ?? NSLocalizedString("pets_unknown_breed", comment: "") }
            }
        }
    }
}

struct HealthRecordListResp: Decodable {
    let rows: [PetHealthRecord]
}

struct PetHealthRecord: Identifiable, Decodable {
    @Int64String var healthId: Int64?
    var id: String {
        return "\(healthId ?? 0)"
    }
    let type: Int
    let downTime: String?
    let comments: String?
    let consumptionAmount: String?
    let remark: String?
    let ext1: String?
    let ext2: String?
    
    var titleKey: String {
        // 后端定义: 0=体检, 1=门诊, 2=住院, 3=绝育, 4=美容, 5=驱虫(内驱), 6=驱虫(外驱), 7=洗护护理, 8=疫苗, 9=狂犬
        switch type {
        case 0: return "health_type_checkup"
        case 1: return "health_type_diagnosis"
        case 2: return "health_type_hospital"
        case 3: return "health_type_neutering"
        case 4: return "health_type_beauty"
        case 5, 6: return "health_type_deworming"
        case 7: return "health_type_grooming"
        case 8: return "health_type_vaccine"
        case 9: return "health_type_rabies"
        case 10: return "pet_growth_nav_title"
        default: return "health_type_other"
        }
    }
}

// MARK: - 添加健康记录表单
// MARK: - 添加健康记录表单
struct AddHealthRecordView: View {
    let petId: String
    var onComplete: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var selectedType: DictData?
    @State private var recordTypes: [DictData] = []
    @State private var recordDate = Date()
    @State private var comments = ""
    @State private var hospitalName = ""
    @State private var cost = ""
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                PFColors.background.ignoresSafeArea()
                
                Form {
                    Section(header: Text(LocalizedStringKey("form_basic_info")).font(PFFonts.caption)) {
                        Picker(LocalizedStringKey("form_record_type"), selection: $selectedType) {
                            Text(LocalizedStringKey("common_select")).tag(Optional<DictData>.none)
                            ForEach(recordTypes) { type in
                                Text(type.dictLabel).tag(Optional(type))
                            }
                        }
                        .font(PFFonts.body)
                        
                        DatePicker(LocalizedStringKey("form_occur_time"), selection: $recordDate, displayedComponents: [.date, .hourAndMinute])
                            .font(PFFonts.body)
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                    }
                    
                    Section(header: Text(LocalizedStringKey("form_detail_record")).font(PFFonts.caption)) {
                        PFTextEditor(
                            placeholder: "form_desc_placeholder",
                            text: $comments,
                            height: 100,
                            maxLength: 500
                        )
                        
                        TextField(LocalizedStringKey("form_hospital_placeholder"), text: $hospitalName)
                            .font(PFFonts.body)
                        
                        HStack {
                            Text(LocalizedStringKey("form_cost_placeholder")).font(PFFonts.body)
                            Spacer()
                            TextField("0.00", text: $cost)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(PFFonts.body)
                        }
                    }
                }
                
                if isSubmitting {
                    PFProgressOverlay(message: "common_saving")
                }
            }
            .navigationTitle(LocalizedStringKey("pets_add_health_record_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizedStringKey("alert_cancel")) { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedStringKey("alert_save")) {
                        submitRecord()
                    }
                    .disabled(isSubmitting || comments.isEmpty || selectedType == nil)
                    .font(.body.bold())
                }
            }
            .onAppear {
                fetchRecordTypes()
            }
        }
    }
    
    private func fetchRecordTypes() {
        Task {
            do {
                let resp: DictDataResp = try await NetworkManager.shared.request("/petFriendly/client/dictType/pet_helath_record_type", method: .get, needToken: true)
                await MainActor.run {
                    self.recordTypes = resp.data
                    // 默认选择第一个
                    if !self.recordTypes.isEmpty && self.selectedType == nil {
                        self.selectedType = self.recordTypes[0]
                    }
                }
            } catch {
                print("Fetch record types error: \(error)")
            }
        }
    }
    
    private func submitRecord() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        isSubmitting = true
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateStr = formatter.string(from: recordDate)
        
        // 获取选中的类型 ID (Int)
        let typeId = Int(selectedType?.dictValue ?? "1") ?? 1
        
        let params: [String: Any] = [
            "petId": petId,
            "type": typeId,
            "downTime": dateStr,
            "comments": comments,
            "remark": hospitalName,
            "consumptionAmount": Double(cost) ?? 0.0
        ]
        
        Task {
            do {
                struct Empty: Decodable {}
                _ = try await NetworkManager.shared.request("/petFriendly/client/addHealthRecord", method: .post, parameters: params, encoding: JSONEncoding.default, needToken: true) as Empty?
                
                await MainActor.run {
                    isSubmitting = false
                    onComplete()
                    dismiss()
                }
            } catch {
                print("Submit health record error: \(error)")
                await MainActor.run { isSubmitting = false }
            }
        }
    }
}

struct EditPetView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = PetFormViewModel()
    
    let pet: Pet
    
    @State private var name: String
    @State private var birthday: Date
    @State private var avatarImage: UIImage?
    @State private var avatarUrl: URL?
    @State private var showImagePicker = false
    
    @State private var selectedSpecies: DictData?
    @State private var selectedBreed: DictData?
    @State private var selectedSex: DictData?
    
    @State private var isSaving = false
    
    init(pet: Pet) {
        self.pet = pet
        _name = State(initialValue: pet.displayName)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let bday = pet.birthday?.prefix(10).description ?? ""
        _birthday = State(initialValue: formatter.date(from: bday) ?? Date())
        
        _avatarUrl = State(initialValue: pet.avatarUrl)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                PFColors.background.ignoresSafeArea()
                
                Form {
                    Section(header: Text(LocalizedStringKey("form_basic_info")).font(PFFonts.caption)) {
                        HStack {
                            Text("add_pet_avatar_title").font(PFFonts.body)
                            Spacer()
                            Button(action: { showImagePicker = true }) {
                                if let img = avatarImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(Circle())
                                } else {
                                    CachedAsyncImage(url: avatarUrl) { image in
                                        image.resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        Image(systemName: "pawprint.circle.fill")
                                            .resizable()
                                            .foregroundColor(PFColors.textTertiary)
                                    }
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                                }
                            }
                        }
                        
                        HStack {
                            Text(LocalizedStringKey("form_nickname")).font(PFFonts.body)
                            TextField(LocalizedStringKey("add_pet_name_placeholder"), text: $name)
                                .multilineTextAlignment(.trailing)
                                .font(PFFonts.body)
                        }
                        
                        Picker(LocalizedStringKey("form_sex"), selection: $selectedSex) {
                            Text("common_select").tag(Optional<DictData>.none)
                            ForEach(viewModel.sexList) { sex in
                                Text(sex.dictLabel).tag(Optional(sex))
                            }
                        }
                        .font(PFFonts.body)
                    }
                    
                    Section(header: Text(LocalizedStringKey("form_species")).font(PFFonts.caption)) {
                        Picker(LocalizedStringKey("form_species"), selection: $selectedSpecies) {
                            Text("common_select").tag(Optional<DictData>.none)
                            ForEach(viewModel.speciesList) { species in
                                Text(species.dictLabel).tag(Optional(species))
                            }
                        }
                        .onChange(of: selectedSpecies) { newValue in
                            if let species = newValue {
                                Task { await viewModel.fetchBreeds(for: species.dictValue) }
                            } else {
                                viewModel.breedList = []
                            }
                        }
                        
                        Picker(LocalizedStringKey("form_breed"), selection: $selectedBreed) {
                            Text("common_select").tag(Optional<DictData>.none)
                            ForEach(viewModel.breedList) { breed in
                                Text(breed.dictLabel).tag(Optional(breed))
                            }
                        }
                        .disabled(selectedSpecies == nil)
                        
                        DatePicker(LocalizedStringKey("form_birthday"), selection: $birthday, displayedComponents: .date)
                            .font(PFFonts.body)
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                    }
                }
                
                if viewModel.isLoading {
                    PFProgressOverlay(message: "common_saving")
                }
            }
            .navigationTitle(LocalizedStringKey("pets_edit_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("alert_cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("alert_save")) {
                        save()
                    }
                    .font(.body.bold())
                    .disabled(name.isEmpty || isSaving)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $avatarImage)
            }
            .onAppear {
                Task {
                    await viewModel.fetchSpecies()
                    await viewModel.fetchSex()
                    
                    // 设置初始值
                    if let sId = pet.species, let species = viewModel.speciesList.first(where: { Int($0.dictValue) == sId }) {
                        selectedSpecies = species
                        await viewModel.fetchBreeds(for: species.dictValue)
                        if let bId = pet.breeds, let breed = viewModel.breedList.first(where: { Int($0.dictValue) == bId }) {
                            selectedBreed = breed
                        }
                    }
                    
                    if let sex = viewModel.sexList.first(where: { Int($0.dictValue) == pet.sex }) {
                        selectedSex = sex
                    }
                }
            }
        }
    }
    
    private func save() {
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        Task {
            isSaving = true
            let speciesId = Int(selectedSpecies?.dictValue ?? "0") ?? 0
            let breedId = Int(selectedBreed?.dictValue ?? "0") ?? 0
            let sexId = Int(selectedSex?.dictValue ?? "0") ?? 0
            
            let success = await viewModel.updatePet(
                petId: pet.petId,
                name: name,
                species: speciesId,
                breed: breedId,
                sex: sexId,
                birthday: birthday,
                petAvatar: avatarImage ?? pet.petAvatar
            )
            
            if success {
                // 发送通知刷新列表
                NotificationCenter.default.post(name: NSNotification.Name("PetInfoUpdated"), object: nil)
                dismiss()
            }
            isSaving = false
        }
    }
}

struct PFProgressOverlay: View {
    let message: LocalizedStringKey
    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 16) {
                PFPetLoadingView(size: 48)
                Text(message)
                    .font(PFFonts.body)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
    }
}
