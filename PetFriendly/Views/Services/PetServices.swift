//
//  PetServices.swift
//  PetFriendly
//
//  宠物服务页（极致美化版）
//

import SwiftUI

// MARK: - 主页面
struct PetService: View {
    @StateObject private var viewModel = ServicesViewModel()
    @State private var appearAnim = false
    @EnvironmentObject var uiState: UIState
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var store: AccountStore
    @State private var isDispatchMode = false
    private var isProvider: Bool { store.petOwner?.providerId != nil }
    
    var body: some View {
        NavigationStack {
            ZStack {
                PFColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 标题栏
                    headerBar
                    
                    if isDispatchMode {
                        DispatchHallView()
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            ZStack(alignment: .top) {
                                ScrollViewOffsetTracker()
                                
                                VStack(spacing: PFSpacing.xl) {
                                    // 急救横幅
                                    NavigationLink(destination: EmergencyChatView()
                                        .onAppear { uiState.isTabBarForceHidden = true; uiState.isTabBarHidden = true }
                                        .onDisappear { uiState.isTabBarForceHidden = false; uiState.isTabBarHidden = false }
                                    ) {
                                        EmergencyCard()
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    if viewModel.isLoading {
                                        VStack(spacing: PFSpacing.md) {
                                            PFPetLoadingView("services_loading", size: 36)
                                        }
                                        .padding(.vertical, 40)
                                    } else {
                                        // 服务标题
                                        HStack {
                                            Text("services_more")
                                                .font(PFFonts.headline)
                                                .foregroundColor(PFColors.textPrimary)
                                            
                                            Text("\(viewModel.services.count)")
                                                .font(PFFonts.caption2)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(PFGradients.brand)
                                                .clipShape(Capsule())
                                            
                                            Spacer()
                                        }
                                        .padding(.horizontal, PFSpacing.xl)
                                        
                                        // 服务网格
                                        LazyVGrid(
                                            columns: [GridItem(.flexible(), spacing: PFSpacing.lg), GridItem(.flexible(), spacing: PFSpacing.lg)],
                                            spacing: PFSpacing.lg
                                        ) {
                                            ForEach(Array(viewModel.services.enumerated()), id: \.element.id) { index, service in
                                                NavigationLink(destination: ServiceDetailRouter(service: service)
                                                    .onAppear { uiState.isTabBarForceHidden = true; uiState.isTabBarHidden = true }
                                                    .onDisappear { uiState.isTabBarForceHidden = false; uiState.isTabBarHidden = false }
                                                ) {
                                                    ServiceCard(service: service)
                                                        .opacity(appearAnim ? 1 : 0)
                                                        .offset(y: appearAnim ? 0 : 20)
                                                        .animation(
                                                            PFAnimation.springGentle.delay(Double(index) * 0.08),
                                                            value: appearAnim
                                                        )
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                        .padding(.horizontal, PFSpacing.xl)
                                    }
                                    
                                    // 底部文案
                                    VStack(spacing: 8) {
                                        Text("services_coming_soon")
                                            .font(PFFonts.caption)
                                            .foregroundColor(PFColors.textTertiary)
                                        
                                        Text("🐾")
                                            .font(.system(size: 24))
                                            .padding(.top, 40)
                                    }
                                    .padding(.top, PFSpacing.xl)
                                }
                                .padding(.top, PFSpacing.lg)
                            }
                        }
                        .coordinateSpace(name: "scroll")
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                            uiState.updateScroll(offset: offset)
                        }
                        .refreshable { viewModel.fetchServices() }
                        .modifier(ScrollBounceModifier())
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
            .navigationBarHidden(true)
        }
        .trackScene("PetServices")
        .pfToyBackground()
        .onAppear {
            viewModel.fetchServices()
            withAnimation(PFAnimation.springGentle) {
                appearAnim = true
            }
        }
    }
    
    // 标题栏
    private var headerBar: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("services_title")
                        .font(PFFonts.title)
                        .foregroundColor(.white)
                    Text("services_subtitle")
                        .font(PFFonts.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
            }
            
            if isProvider {
                Picker("", selection: $isDispatchMode) {
                    Text(NSLocalizedString("client_mode", comment: "")).tag(false)
                    Text(NSLocalizedString("dispatch_hall_mode", comment: "")).tag(true)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, PFSpacing.xl)
        .padding(.top, 44) // 适配状态栏高度
        .padding(.bottom, PFSpacing.lg)
        .frame(minHeight: PFSpacing.headerHeight + 44, alignment: .bottom)
        .background(PFGradients.brand)
    }
}

// MARK: - 急救横幅卡片
struct EmergencyCard: View {
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: PFSpacing.lg) {
            // 心跳图标
            ZStack {
                // 脉冲外圈
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 56, height: 56)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .opacity(isPulsing ? 0 : 0.5)
                    .animation(
                        Animation.easeOut(duration: 1.2)
                            .repeatForever(autoreverses: false),
                        value: isPulsing
                    )
                
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
                    .symbolRenderingMode(.hierarchical)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("services_emergency_title")
                    .font(PFFonts.headline)
                    .foregroundColor(.white)
                Text("services_emergency_subtitle")
                    .font(PFFonts.caption)
                    .foregroundColor(.white.opacity(0.85))
            }
            
            Spacer()
            
            Text("services_request_help")
                .font(PFFonts.caption2)
                .foregroundColor(Color(hex: "EF4444"))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white)
                .clipShape(Capsule())
        }
        .padding(PFSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: PFRadius.lg)
                .fill(PFGradients.emergency)
        )
        .pfCardShadow()
        .padding(.horizontal, PFSpacing.xl)
        .onAppear { isPulsing = true }
    }
}

// MARK: - 服务卡片
struct ServiceCard: View {
    let service: ServiceItem
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 图标区域
            if let url = service.iconUrl {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                }                 placeholder: {
                    Rectangle()
                        .fill(PFColors.surface)
                        .overlay(PFPetLoadingInline(size: 16))
                }
                .frame(height: 100)
                .clipped()
                .pfImageInteractable(url: service.iconUrl?.absoluteString)
                .background(PFColors.surface) // 保持主图和卡片底层颜色一致，避免透明图出现差距
                .cornerRadius(PFRadius.md)
                .padding(.top, PFSpacing.md)
                .padding(.horizontal, PFSpacing.md)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: PFRadius.md)
                        .fill(PFGradients.brand.opacity(0.1))
                        .frame(height: 100)
                    
                    Image(systemName: "pawprint.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(PFGradients.brand)
                }
                .padding(.top, PFSpacing.md)
                .padding(.horizontal, PFSpacing.md)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(service.serviceName)
                    .font(PFFonts.callout)
                    .foregroundColor(PFColors.textPrimary)
                    .lineLimit(1)
                
                Text(service.description ?? "")
                    .font(PFFonts.caption)
                    .foregroundColor(PFColors.textSecondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, PFSpacing.md)
            .padding(.vertical, PFSpacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: PFRadius.lg)
                .fill(PFColors.surface)
        )
        .pfCardShadow()
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(PFAnimation.spring, value: isHovered)
    }
}

// MARK: - 动态服务路由封装
struct ServiceDetailRouter: View {
    let service: ServiceItem

    var body: some View {
        Group {
            // 1. 管理端配置为外部链接：打开 App 内嵌浏览器（可选注入客户端请求头与鉴权）
            if service.isExternalLink, let url = service.jumpURL {
                InAppBrowserView(url: url, title: service.serviceName)
            }
            // 2. 管理端配置了 App 内跳转：优先按 jumpPageUrl 路由
            else if let router = service.jumpPageUrl?.lowercased(), !router.isEmpty {
                routeByURL(router)
            }
            // 3. 未配置跳转：拦截，提示暂未上线
            else {
                NotAvailableView()
            }
        }
    }

    /// 按管理端 jumpPageUrl 路由到 App 内页面
    @ViewBuilder
    private func routeByURL(_ router: String) -> some View {
        if router.contains("ai") || router.contains("player") || router.contains("头像") || router.contains("证件照") || router.contains("画像") {
            AIAIAvatarView()
        } else if router.contains("car") || router.contains("专车") {
            PetTaxiBookingView(serviceName: service.serviceName)
        } else if router.contains("goservice") || router.contains("上门") {
            HomeServiceBookingView(serviceName: service.serviceName)
        } else if router.contains("help") || router.contains("流浪") || router.contains("救助") || router.contains("领养") {
            StrayAnimalServiceView()
        } else if router.contains("searchwater") || router.contains("饮水") || router.contains("water") {
            // 饮水地图：跳转地图页筛选饮水点
            ServiceWaterMapView()
        } else if router.contains("洗护") {
            PetCareWizardView()
        } else if router.contains("代养") || router.contains("遛狗") || router.contains("喂猫") {
            BoardingServiceWizardView()
        } else {
            // 未知路由：拦截，提示暂未上线
            NotAvailableView()
        }
    }
}

// MARK: - 饮水地图（jumpPageUrl=searchWater 时展示）
struct ServiceWaterMapView: View {
    @EnvironmentObject var uiState: UIState
    @StateObject private var mapVM = MapViewModel()

    var body: some View {
        MapAndListView()
            .environmentObject(mapVM)
            .onAppear {
                uiState.pendingMapFilter = "饮水地"
                uiState.pendingMapRadius = 20000
            }
    }
}

// MARK: - 暂未上线占位（jumpPageUrl 为空或未知时拦截）
struct NotAvailableView: View {
    @EnvironmentObject var uiState: UIState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 48))
                .foregroundColor(PFColors.textTertiary)
            Text("services_not_available")
                .font(PFFonts.headline)
                .foregroundColor(PFColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PFColors.background.ignoresSafeArea())
        .onAppear {
            // 点击进入即提示暂未上线
            uiState.showToast("services_not_available", style: .warning, icon: "hammer.fill")
        }
    }
}


import SwiftUI

struct StrayAnimalServiceView: View {
    @State private var isPresentingAddForm = false
    @State private var formType: StrayAnimalFormType = .rescue // .rescue or .adopt
    @StateObject private var petViewModel = PetViewModel.shared
    @State private var selectedPet: Pet?
    @State private var category = "all"
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("stray_my_filter", selection: $category) {
                Text("stray_filter_all").tag("all")
                Text("stray_filter_reports").tag("reports")
                Text("stray_filter_rescues").tag("rescues")
                Text("stray_filter_adoptions").tag("adoptions")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 6)

            ZStack {
            PFColors.background.ignoresSafeArea()

            if petViewModel.rescuePets.isEmpty && !petViewModel.isLoading {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: PFSpacing.md) {
                        ForEach(petViewModel.rescuePets) { pet in
                            Button { selectedPet = pet } label: {
                                StrayListRow(pet: pet)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if category != "all" {
                                    Button(role: .destructive) { revoke(pet) } label: {
                                        Label("stray_revoke", systemImage: "arrow.uturn.backward")
                                    }
                                }
                            }
                        }
                        if petViewModel.isLoadingRescuePets {
                            PFPetLoadingInline(size: 16)
                                .padding()
                        } else if petViewModel.hasMoreRescuePets && !petViewModel.rescuePets.isEmpty {
                            Color.clear
                                .frame(height: 1)
                                .onAppear { petViewModel.fetchPets(contactType: 1, loadMore: true) }
                        }
                    }
                    .padding(.horizontal, PFSpacing.lg)
                    .padding(.vertical, PFSpacing.md)
                    .padding(.bottom, PFSpacing.xl)
                }
            }
            }
        }
        .navigationTitle("stray_list_title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    formType = .rescue
                    isPresentingAddForm = true
                }) {
                    Text("stray_report")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(PFColors.primary)
                }
            }
        }
        .onAppear {
            petViewModel.fetchPets(contactType: 1)
        }
        .onChange(of: category) { value in
            if value == "all" { petViewModel.fetchPets(contactType: 1) }
            else { fetchMine(value) }
        }
        .fullScreenCover(isPresented: $isPresentingAddForm) {
            StrayAnimalAddFormView(formType: formType)
        }
        .sheet(item: $selectedPet) { pet in
            StrayPetDetailView(pet: pet)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .trackScene("StrayAnimalService")
    }

    private func fetchMine(_ category: String) {
        Task {
            do {
                let response: PetListResp = try await NetworkManager.shared.request("/petFriendly/client/strayAnimals/mine?category=\(category)&pageNum=1&pageSize=20", method: .get, needToken: true)
                await MainActor.run { petViewModel.rescuePets = response.rows ?? []; petViewModel.hasMoreRescuePets = false }
            } catch { showErrorAlert(error) }
        }
    }

    private func revoke(_ pet: Pet) {
        Task {
            do {
                let _: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                    "/petFriendly/client/strayAnimals/\(pet.petId)/mine?category=\(category)",
                    method: .delete,
                    needToken: true
                )
                await MainActor.run {
                    petViewModel.rescuePets.removeAll { $0.id == pet.id }
                    showSuccessHUD(message: NSLocalizedString("stray_revoke_success", comment: ""))
                }
            } catch { await MainActor.run { showErrorAlert(error) } }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "pawprint.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.linearGradient(colors: [Color.orange, Color.pink], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text("stray_empty_rescued")
                .font(PFFonts.headline)
                .foregroundColor(PFColors.textPrimary)
            Text(NSLocalizedString("stray_empty_hint", comment: ""))
                .font(PFFonts.caption)
                .foregroundColor(PFColors.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, PFSpacing.xl)
    }
}

// MARK: - 流浪宠物列表行

struct StrayListRow: View {
    let pet: Pet

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PFColors.primary.opacity(0.1))
                    .frame(width: 56, height: 56)
                if let url = pet.avatarUrl {
                    CachedAsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        PFPetLoadingInline(size: 12)
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 24))
                        .foregroundColor(PFColors.primary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(pet.displayName)
                        .font(PFFonts.headline)
                        .foregroundColor(PFColors.textPrimary)
                    Text(pet.strayStatusTitle)
                        .font(PFFonts.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(PFColors.primary.opacity(0.1))
                        .foregroundColor(PFColors.primary)
                        .clipShape(Capsule())
                }
                if let breed = pet.breed, !breed.isEmpty {
                    Text(breed)
                        .font(PFFonts.caption)
                        .foregroundColor(PFColors.textSecondary)
                }
                Text(pet.reportAgeText)
                    .font(PFFonts.caption2)
                    .foregroundColor(PFColors.textTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(PFColors.textTertiary)
        }
        .padding(12)
        .background(PFColors.surface)
        .cornerRadius(16)
        .pfCardShadow()
    }
}

// MARK: - Models and Subviews

struct AnimalCard: Identifiable {
    let id = UUID()
    let name: String
    let status: String
    let image: String
    let color: Color
}

struct AnimalCardView: View {
    let pet: Pet
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(PFColors.primary.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                if let url = pet.avatarUrl {
                    CachedAsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                } placeholder: {
                    PFPetLoadingInline(size: 14)
                }
                .frame(width: 70, height: 70)
                .clipShape(Circle())
                .pfImageInteractable(url: pet.avatarUrl?.absoluteString)
                } else {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 36))
                        .foregroundColor(PFColors.primary)
                }
            }
            
            Text(pet.displayName)
                .font(PFFonts.subheadline)
                .foregroundColor(PFColors.textPrimary)
            
            Text(pet.contactType == 1 ? "stray_status_rescued" : "pets_my_pets")
                .font(PFFonts.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(PFColors.primary.opacity(0.1))
                .foregroundColor(PFColors.primary)
                .clipShape(Capsule())
        }
        .padding()
        .background(PFColors.surface)
        .cornerRadius(16)
        .pfCardShadow()
        .frame(width: 140)
    }
}

enum StrayAnimalFormType {
    case rescue
    case adopt
    
    var title: String {
        switch self {
        case .rescue: return NSLocalizedString("stray_form_rescue", comment: "")
        case .adopt: return NSLocalizedString("stray_form_adopt", comment: "")
        }
    }
}
import SwiftUI
import MapKit

struct StrayAnimalAddFormView: View {
    @Environment(\.presentationMode) var presentationMode
    let formType: StrayAnimalFormType
    
    // 表单状态
    @State private var step = 0
    let totalSteps = 6
    @StateObject private var petFormViewModel = PetFormViewModel()
    
    // 数据字段
    @State private var selectedImage: UIImage?
    @State private var locationCoordinate: CLLocationCoordinate2D?
    @State private var locationName: String = ""
    @State private var contactName: String = ""
    @State private var contactPhone: String = ""
    @State private var remark: String = ""
    @State private var selectedSpecies: DictData?
    @State private var selectedBreed: DictData?
    @State private var selectedSex: DictData?
    @State private var strayStatus = 0
    @State private var estimatedAge = ""
    @State private var isAnonymous = false
    
    // UI 控制
    @State private var isPickerPresented = false
    @State private var isMapPresented = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部问候语：更人性化的进入文案
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill((formType == .rescue ? PFColors.danger : PFColors.primary).opacity(0.12))
                            .frame(width: 64, height: 64)
                        Image(systemName: formType == .rescue ? "pawprint.fill" : "heart.fill")
                            .font(.system(size: 26))
                            .foregroundColor(formType == .rescue ? PFColors.danger : PFColors.primary)
                    }
                    Text(LocalizedStringKey(formType == .rescue ? "stray_rescue_greeting" : "stray_adopt_greeting"))
                        .font(PFFonts.title2)
                        .fontWeight(.bold)
                        .foregroundColor(PFColors.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .padding(.horizontal, 24)

                // 顶部进度条 (已重构为 iOS 26/27 拟态微动渐变加载栏)
                PFProgressBar(value: Double(step + 1), total: Double(totalSteps), tintColor: formType == .rescue ? PFColors.danger : PFColors.primary)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                
                // 核心区域
                GeometryReader { geometry in
                    ZStack {
                        switch step {
                        case 0:
                            photoStepView()
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        case 1:
                            locationStepView()
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        case 2:
                            animalInfoStepView()
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        case 3:
                            contactStepView()
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        case 4:
                            phoneStepView()
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        case 5:
                            remarkStepView()
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        default:
                            EmptyView()
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                
                bottomBar()
            }
            .trackScene("StrayAnimalForm_Step\(step)")
            .background(PFColors.background.onTapGesture { dismissFormKeyboard() })
            .navigationBarItems(leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(PFColors.textSecondary)
                    .font(.system(size: 20, weight: .bold))
            })
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isPickerPresented) {
                ImagePicker(image: $selectedImage)
            }
            .sheet(isPresented: $isMapPresented) {
                // 简单的地图选点包裹器 (此处用原生 Map 或保留接口)
                LocationPickerView(coordinate: $locationCoordinate, placeName: $locationName)
            }
        }
    }

    private func dismissFormKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // MARK: - 各步骤 View
    
    private func photoStepView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            instructionText(NSLocalizedString("form_photo_instruction", comment: ""))
            
            Button(action: { isPickerPresented = true }) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .pfImageInteractable(image: selectedImage)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 48))
                        Text(LocalizedStringKey("form_click_to_select"))
                            .font(PFFonts.headline)
                    }
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .foregroundColor(PFColors.primary)
                    .background(PFColors.primary.opacity(0.1))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .foregroundColor(PFColors.primary.opacity(0.5))
                    )
                }
            }
            Spacer()
        }
        .padding(24)
    }
    
    private func locationStepView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            instructionText(formType == .rescue ? NSLocalizedString("form_location_rescue", comment: "") : NSLocalizedString("form_location_adopt", comment: ""))
            
            Button(action: { isMapPresented = true }) {
                if let _ = locationCoordinate {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(PFColors.danger)
                                .font(.title)
                            Text(locationName.isEmpty ? NSLocalizedString("form_location_selected", comment: "") : locationName)
                                .font(PFFonts.headline)
                                .foregroundColor(PFColors.textPrimary)
                        }
                        Text(NSLocalizedString("form_location_reselect", comment: ""))
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(PFColors.surfaceSecondary)
                    .cornerRadius(16)
                } else {
                    HStack {
                        Image(systemName: "map.fill")
                        Text(NSLocalizedString("form_map_select", comment: ""))
                    }
                    .font(PFFonts.headline)
                    .foregroundColor(PFColors.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(PFColors.primary.opacity(0.1))
                    .cornerRadius(16)
                }
            }
            Spacer()
        }
        .padding(24)
    }
    
    private func contactStepView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            instructionText(NSLocalizedString("form_name_instruction", comment: ""))
            duolingoTextField(placeholder: NSLocalizedString("form_name_placeholder", comment: ""), text: $contactName)
            Spacer()
        }
        .padding(24)
    }

    private func animalInfoStepView() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                instructionText(NSLocalizedString("stray_animal_info_title", comment: ""))
                Text("stray_animal_info_optional_hint")
                    .font(PFFonts.caption)
                    .foregroundColor(PFColors.textSecondary)

                optionalPicker(
                    title: "stray_animal_species",
                    selection: $selectedSpecies,
                    options: petFormViewModel.speciesList
                ) { species in
                    selectedSpecies = species
                    selectedBreed = nil
                    petFormViewModel.breedList = []
                    if let species {
                        Task { await petFormViewModel.fetchBreeds(for: species.dictValue) }
                    }
                }

                optionalPicker(
                    title: "stray_animal_breed",
                    selection: $selectedBreed,
                    options: petFormViewModel.breedList,
                    disabled: selectedSpecies == nil
                ) { selectedBreed = $0 }

                optionalPicker(
                    title: "stray_animal_sex",
                    selection: $selectedSex,
                    options: petFormViewModel.sexList
                ) { selectedSex = $0 }

                VStack(alignment: .leading, spacing: 8) {
                    Text("stray_report_status").font(PFFonts.subheadline)
                    Picker("stray_report_status", selection: $strayStatus) {
                        ForEach(0..<4) { value in Text(Pet.strayStatusKey(value)).tag(value) }
                    }
                    .pickerStyle(.menu)
                    .tint(PFColors.primary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("stray_estimated_age").font(PFFonts.subheadline)
                    TextField("stray_estimated_age_placeholder", text: $estimatedAge)
                        .keyboardType(.numberPad).padding(14).background(PFColors.surfaceSecondary).cornerRadius(PFRadius.md)
                }
                Toggle("stray_report_anonymous", isOn: $isAnonymous).tint(PFColors.primary)
            }
            .padding(24)
        }
        .onAppear {
            Task {
                if petFormViewModel.speciesList.isEmpty { await petFormViewModel.fetchSpecies() }
                if petFormViewModel.sexList.isEmpty { await petFormViewModel.fetchSex() }
            }
        }
    }

    private func optionalPicker(
        title: LocalizedStringKey,
        selection: Binding<DictData?>,
        options: [DictData],
        disabled: Bool = false,
        onSelect: @escaping (DictData?) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(PFFonts.subheadline).foregroundColor(PFColors.textPrimary)
            Menu {
                Button("stray_animal_unknown") { onSelect(nil) }
                ForEach(options) { option in
                    Button(option.dictLabel) { onSelect(option) }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue?.dictLabel ?? NSLocalizedString("stray_animal_unknown", comment: ""))
                        .foregroundColor(selection.wrappedValue == nil ? PFColors.textTertiary : PFColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(PFColors.textTertiary)
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(PFColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: PFRadius.md))
            }
            .disabled(disabled)
            .opacity(disabled ? 0.5 : 1)
        }
    }
    
    private func phoneStepView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            instructionText(NSLocalizedString("form_phone_instruction", comment: ""))
            duolingoTextField(placeholder: NSLocalizedString("form_phone_placeholder", comment: ""), text: $contactPhone)
                .keyboardType(.numberPad)
            Spacer()
        }
        .padding(24)
    }
    
    private func remarkStepView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            instructionText(NSLocalizedString("form_remark_instruction", comment: ""))
            PFVoiceInputEditor(
                placeholder: "form_remark_placeholder",
                text: $remark,
                height: 160,
                maxLength: 500
            )
            Spacer()
        }
        .padding(24)
    }
    
    // MARK: - Components
    
    private func instructionText(_ text: String) -> some View {
        Text(LocalizedStringKey(text))
            .font(PFFonts.title2)
            .fontWeight(.bold)
            .foregroundColor(PFColors.textPrimary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private func duolingoTextField(placeholder: String, text: Binding<String>) -> some View {
        TextField(LocalizedStringKey(placeholder), text: text)
            .font(PFFonts.body)
            .padding(20)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(text.wrappedValue.isEmpty ? Color.clear : PFColors.primary, lineWidth: 2)
            )
    }
    
    private func bottomBar() -> some View {
        VStack {
            Divider()
            HStack {
                if step > 0 {
                    Button(action: {
                        withAnimation { step -= 1 }
                    }) {
                        Text(NSLocalizedString("form_prev", comment: ""))
                            .font(PFFonts.headline)
                            .foregroundColor(PFColors.textSecondary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(PFColors.surfaceSecondary)
                            .cornerRadius(16)
                    }
                }
                
                Spacer()
                
                Button(action: handleNext) {
                if isLoading {
                    PFPetLoadingInline(size: 14)
                        .frame(maxWidth: .infinity)
                } else {
                        Text(step == totalSteps - 1 ? NSLocalizedString("form_submit", comment: "") : NSLocalizedString("form_continue", comment: ""))
                            .font(PFFonts.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!canGoNext() || isLoading)
                .padding(.vertical, 16)
                .padding(.horizontal, step > 0 ? 0 : 24)
                .background(canGoNext() ? (formType == .rescue ? PFColors.danger : PFColors.primary) : PFColors.textTertiary.opacity(0.4))
                .foregroundColor(.white)
                .cornerRadius(16)
                .animation(.easeInOut, value: canGoNext())
            }
            .padding(24)
        }
        .background(Color(.systemBackground).edgesIgnoringSafeArea(.bottom))
    }
    
    // MARK: - Logic
    
    private func canGoNext() -> Bool {
        switch step {
        case 0: return selectedImage != nil // 照片必传
        case 1: return locationCoordinate != nil // 地址必选
        case 2: return true // 动物基本信息均可跳过
        case 3: return !contactName.trimmingCharacters(in: .whitespaces).isEmpty
        case 4: return !contactPhone.trimmingCharacters(in: .whitespaces).isEmpty
        case 5: return true
        default: return false
        }
    }
    
    private func handleNext() {
        Haptics.play()
        if step < totalSteps - 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                step += 1
            }
        } else {
            submitForm()
        }
    }
    
    private func submitForm() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                var photoUrl = ""
                if let img = selectedImage {
                    photoUrl = try await NetworkManager.shared.uploadImage(img)
                }
                
                var params: [String: Any] = [
                    "serviceType": 6, // 6 表示流浪动物上报，与待领养列表和后端积分策略一致
                    "serviceName": formType.title,
                    "phoneInformation": contactPhone,
                    "remark": remark,
                    "ext": photoUrl,
                    "serviceInformation": String(format: NSLocalizedString("form_contact_info %@", comment: ""), contactName)
                ]
                
                if let loc = locationCoordinate {
                    params["ext2"] = "\(loc.latitude),\(loc.longitude)"
                    params["ext3"] = locationName
                }
                if let value = selectedSex.flatMap({ Int($0.dictValue) }) { params["animalSex"] = value }
                if let value = selectedSpecies.flatMap({ Int($0.dictValue) }) { params["animalSpecies"] = value }
                if let value = selectedBreed.flatMap({ Int($0.dictValue) }) { params["animalBreeds"] = value }
                params["strayStatus"] = strayStatus
                if let age = Int(estimatedAge), age >= 0 { params["animalAgeMonths"] = age }
                params["strayAnonymous"] = isAnonymous ? 1 : 0
                
                let resp: RespWrapper<JSONAny> = try await NetworkManager.shared.request(
                    "/petFriendly/client/service/order/submit",
                    method: .post,
                    parameters: params
                )
                
                await MainActor.run {
                    self.isLoading = false
                    if resp.code == 200 {
                        Haptics.notify(.success)
                        presentationMode.wrappedValue.dismiss()
                        showSuccessHUD(message: NSLocalizedString("form_submit_success", comment: ""))
                    } else {
                        print(resp.msg ?? NSLocalizedString("submit_failed", comment: ""))
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print(error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - 临时简单的 Map Picker
struct LocationPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var coordinate: CLLocationCoordinate2D?
    @Binding var placeName: String
    
    @State private var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
    
    var body: some View {
        NavigationStack {
            ZStack {
                Map(coordinateRegion: $region, interactionModes: .all, showsUserLocation: true)
                    .ignoresSafeArea()
                
                Image(systemName: "mappin")
                    .font(.largeTitle)
                    .foregroundColor(.red)
                    .padding(.bottom, 35) // Offset to anchor correctly
            }
            .navigationTitle("drag_map_pick")
            .navigationBarItems(
                leading: Button("alert_cancel") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("settings_confirm") {
                    coordinate = region.center
                    placeName = String(format: NSLocalizedString("selected_coordinates", comment: ""), region.center.latitude, region.center.longitude)
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                if let current = coordinate {
                    region.center = current
                } else if false {
                    // region.center = userLoc.coordinate
                }
            }
        }
    }
}
import SwiftUI
