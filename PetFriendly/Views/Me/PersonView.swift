//
//  PersonView.swift
//  PetFriendly
//
//  个人中心（极致美化版）
//

import SwiftUI

// MARK: - DTO (保留原有)
private struct AvatarUploadResp: Decodable {
    let code: Int
    let msg: String
    let data: Img?
    struct Img: Decodable { let imgUrl: String }
}

private struct AvatarDeleteResp: Decodable {
    let code: Int
    let msg: String
}

struct AchievementListResp: Decodable {
    let code: Int
    let rows: [AchievementCard.Achievement]
}

// MARK: - 1. 主页面
@MainActor
struct PersonView: View {
    @EnvironmentObject var store: AccountStore
    @State private var appearAnim = false
    
    var body: some View {
        // 退出登录中 → 显示空白避免 nil 数据渲染崩溃
        if store.isLoggingOut {
            ZStack {
                PFColors.background.ignoresSafeArea()
                PFPetLoadingView(size: 36)
            }
        } else {
            mainContent
        }
    }
    
    private var mainContent: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {

                    // 渐变头部
                    headerView
                        
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: PFSpacing.lg) {
                            // 头像卡片
                            AvatarCard()
                                .padding(.horizontal, PFSpacing.xl)
                                .padding(.top, PFSpacing.lg)
                            
                            // 统计卡片
                            StatsCard()
                                .opacity(appearAnim ? 1 : 0)
                                .offset(y: appearAnim ? 0 : 20)
                                .animation(PFAnimation.springGentle.delay(0.1), value: appearAnim)
                            
                            // 我的服务
                            UserServiceCard()
                                .opacity(appearAnim ? 1 : 0)
                                .offset(y: appearAnim ? 0 : 20)
                                .animation(PFAnimation.springGentle.delay(0.2), value: appearAnim)
                            
                            // 爱心成就
                            AchievementCard()
                                .opacity(appearAnim ? 1 : 0)
                                .offset(y: appearAnim ? 0 : 20)
                                .animation(PFAnimation.springGentle.delay(0.3), value: appearAnim)
                            
                            // 设置
                            SettingsCard()
                                .opacity(appearAnim ? 1 : 0)
                                .offset(y: appearAnim ? 0 : 20)
                                .animation(PFAnimation.springGentle.delay(0.4), value: appearAnim)
                        }
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
            .navigationBarHidden(true)
        }
        .trackScene("PersonProfile")
        .pfToyBackground()
        .onAppear {
            withAnimation(PFAnimation.springGentle) {
                appearAnim = true
            }
            // 每次进入个人中心刷新一次统计数据（成就、宠物数、收藏等）
            Task {
                await AccountStore.shared.refreshStats()
            }
        }
    }
    
    // 渐变头部 — 与其他 3 个 Tab 保持一致的紧凑样式
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("person_title")
                    .font(PFFonts.title)
                    .foregroundColor(.white)
                Text("person_subtitle")
                    .font(PFFonts.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            Spacer()
        }
        .padding(.horizontal, PFSpacing.xl)
        .padding(.top, 44) // 适配状态栏高度
        .padding(.bottom, PFSpacing.lg)
        .frame(minHeight: PFSpacing.headerHeight + 44, alignment: .bottom)
        .background(PFGradients.brand)
    }

}

// MARK: - 2. 头像卡片
struct AvatarCard: View {
    static let shared = AvatarCard()
    @State private var showImagePicker = false
    @State private var avatarImage: UIImage? = nil
    @State private var gotoLogin = false
    @State private var gotoProfile = false
    @State private var isLoggedIn = false
    @State private var loading = false
    @EnvironmentObject var uiState: UIState
    @EnvironmentObject var store: AccountStore
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: PFSpacing.lg) {
            // 头像
            Button(action: { showImagePicker = true }) {
                if let avatarUrl = store.petOwner?.petAvatar ?? store.user?.avatar, URL(string: avatarUrl) != nil {
                    let versionedUrl = store.avatarVersion.isEmpty ? avatarUrl : (avatarUrl.contains("?") ? "\(avatarUrl)&v=\(store.avatarVersion)" : "\(avatarUrl)?v=\(store.avatarVersion)")
                    CachedAsyncImage(url: NetworkManager.fullUrl(versionedUrl)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        PFPetLoadingInline(size: 14)
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    .pfImageInteractable(url: avatarUrl)
                } else {
                    Image("avatar_placeholder")
                        .resizable().scaledToFill().clipped()
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                }
            }
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [PFColors.primary.opacity(0.6), PFColors.accent.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: 68, height: 68)
            )
            .shadow(color: PFColors.primary.opacity(0.2), radius: 8, x: 0, y: 4)
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $avatarImage)
            }
            .sheet(isPresented: $gotoLogin, onDismiss: checkLogin) {
                LoginPage()
            }
            .sheet(isPresented: $gotoProfile) {
                if let uid = AccountStore.shared.user?.userId {
                    UserNamecardView(userId: uid)
                }
            }
            .onChange(of: avatarImage) { newImage in
                if let img = newImage {
                    uploadAvatar(img)
                }
            }
            
            // 信息
            VStack(alignment: .leading, spacing: 6) {
                userInfoView
                    .onTapGesture { handleProfileTap() }
            }
            Spacer()
        }
        .padding(PFSpacing.lg)
        .background(
            ZStack {
                if !themeManager.headerBackgroundImageUrl.isEmpty {
                    CachedAsyncImage(
                        url: NetworkManager.fullUrl(themeManager.headerBackgroundImageUrl)
                    ) { image in
                        ZStack {
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                            
                            LinearGradient(
                                colors: [.black.opacity(0.4), .black.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                    } placeholder: {
                        ZStack {
                            PFColors.primary.opacity(0.1) // 10% 主题色背景
                            HStack {
                                Spacer()
                                PFPetLoadingInline(size: 18)
                                    .padding(.trailing, PFSpacing.lg)
                            }
                        }
                    }
                } else {
                    PFColors.primary.opacity(0.1)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: PFRadius.lg))
        .pfCardShadow()
        .onAppear {
            checkLogin()
        }
            .overlay(
                EmptyView()
            )
    }
    
    private func uploadAvatar(_ image: UIImage) {
        Task {
            await MainActor.run { 
                uiState.isUploading = true 
                uiState.uploadProgress = 0
                uiState.isUploadFinished = false
            }
            do {
                // 1. 上传图片 (带进度)
                let imageUrl: String = try await NetworkManager.shared.uploadImage(image, to: "/petFriendly/client/upload") { progress in
                    Task { @MainActor in
                        uiState.uploadProgress = progress
                    }
                }
                
                await MainActor.run { 
                    uiState.uploadProgress = 1.0
                    uiState.isUploadFinished = true
                }
                
                // 延迟一秒让用户看到完成状态
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                
                // 2. 更新 profile
                try await AuthService.shared.updateProfile(name: nil, avatar: imageUrl)
                
                // 3. 清除缓存并更新版本
                if let fullUrl = NetworkManager.fullUrl(imageUrl)?.absoluteString {
                    ImageCacheManager.shared.remove(forKey: fullUrl)
                }
                
                await MainActor.run { 
                    store.avatarVersion = "\(Date().timeIntervalSince1970)"
                    uiState.isUploading = false 
                    uiState.isUploadFinished = false
                    showSuccessHUD(message: NSLocalizedString("person_upload_success", comment: ""))
                    
                    // 强制刷新用户信息以更新 UI
                    Task {
                        if let info = try? await AuthService.shared.fetchUserInfo() {
                            await AuthService.shared.cache(info)
                        }
                    }
                }
                Haptics.notify(.success)
            } catch {
                print("上传头像失败: \(error)")
                await MainActor.run { 
                    uiState.isUploading = false 
                    uiState.isUploadFinished = false
                    showErrorAlert(error)
                }
            }
        }
    }
    
    private func checkLogin() {
        isLoggedIn = NetworkManager.shared.token != nil
        // Refresh user info in background (non-blocking)
        if isLoggedIn {
            Task {
                if let info = try? await AuthService.shared.fetchUserInfo() {
                    await AuthService.shared.cache(info)
                }
            }
        }
    }
    
    private var userInfoView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // 优先使用 petOwner 的昵称，符合用户要求：用户昵称获取采用pet_owner的昵称！
                Text(store.petOwner?.name?.presence ?? store.user?.nickName?.presence ?? NSLocalizedString("person_no_nickname", comment: ""))
                    .font(PFFonts.headline)
                    .foregroundColor(!themeManager.headerBackgroundImageUrl.isEmpty ? .white : PFColors.textPrimary)
                
                // 等级 badge
                Text("Lv.\(store.petOwner?.loveLevel ?? 1)")
                    .font(PFFonts.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(PFGradients.brand)
                    .clipShape(Capsule())

                if store.petOwner?.providerId != nil {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(!themeManager.headerBackgroundImageUrl.isEmpty ? .white.opacity(0.9) : PFColors.textPrimary)
                        .font(.system(size: 14))
                }
            }
            
            HStack(spacing: PFSpacing.xl) {
                Label("\(store.petOwner?.loveValue ?? 0)", systemImage: "heart.fill")
                    .foregroundColor(!themeManager.headerBackgroundImageUrl.isEmpty ? .white.opacity(0.9) : PFColors.accent)
                
                NavigationLink(destination: IntegralRecordListView()) {
                    Label("\(store.petOwner?.integralValue ?? 0)", systemImage: "dollarsign.circle")
                        .foregroundColor(!themeManager.headerBackgroundImageUrl.isEmpty ? .white.opacity(0.9) : PFColors.warning)
                }
                .simultaneousGesture(TapGesture().onEnded { Haptics.play() })
            }
            .font(PFFonts.caption)
        }
    }
    
    private func handleProfileTap() {
        Haptics.play()
        guard NetworkManager.shared.token != nil else {
            gotoLogin = true
            return
        }
        gotoProfile = true
    }
}

// MARK: - 3. 统计卡片
struct StatsCard: View {
    @EnvironmentObject var store: AccountStore
    @EnvironmentObject private var uiState: UIState

    
    // 额外添加 route 表示路由去向
    private var items: [(icon: String, title: String, value: String, color: Color, route: String)] {
        [
            ("star.circle.fill", NSLocalizedString("person_stats_achievements", comment: ""), "\(store.petOwner?.achievementNum ?? 0)", PFColors.warning, "achievement"),
            ("pawprint.fill", NSLocalizedString("person_stats_pets", comment: ""), "\(store.petOwner?.petNum ?? 0)", PFColors.primary, "pet"),
            ("bookmark.fill", NSLocalizedString("person_stats_favorites", comment: ""), "\(store.petOwner?.favoritesNum ?? 0)", PFColors.accent, "favorite"),
            ("clock.fill", NSLocalizedString("person_stats_history", comment: ""), "\(store.petOwner?.viewsNum ?? 0)", PFColors.success, "browse")
        ]
    }
    
    @State private var showLoginAlert = false
    @State private var showLoginSheet = false
    @State private var selectedRoute: String? = nil
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                
                Button(action: {
                    Haptics.play()
                    guard NetworkManager.shared.token != nil else {
                        showLoginAlert = true
                        return
                    }
                    if item.route == "pet" {
                        uiState.selectedTab = 2
                    } else {
                        selectedRoute = item.route
                    }
                }) {
                    VStack(spacing: 4) {
                        Text(item.value)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(PFColors.textPrimary)
                        
                        Text(item.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(PFColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                // 分割线 (GitHub 风格常见的间隙或细线)
                if index < items.count - 1 {
                    Rectangle()
                        .fill(PFColors.divider.opacity(0.5))
                        .frame(width: 1, height: 24)
                }
            }
        }
        .padding(.vertical, PFSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: PFRadius.lg)
                .fill(PFColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: PFRadius.lg)
                        .stroke(PFColors.divider.opacity(0.3), lineWidth: 0.5)
                )
        )


        .background(
            Group {
                ForEach(items, id: \.title) { item in
                    NavigationLink(tag: item.route, selection: $selectedRoute) {
                        destinationView(for: item)
                    } label: { EmptyView() }
                }
            }
        )
        .pfCardShadow()
        .padding(.horizontal, PFSpacing.xl)
        .alert(isPresented: $showLoginAlert) {
            Alert(
                title: Text("person_login_required"),
                message: Text("person_login_message"),
                primaryButton: .default(Text("person_login_go")) {
                    showLoginSheet = true
                },
                secondaryButton: .cancel(Text("person_login_ok"))
            )
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginPage()
        }
    }
    
    @ViewBuilder
    private func destinationView(for item: (icon: String, title: String, value: String, color: Color, route: String)) -> some View {
        switch item.route {
        case "achievement":
            AchievementListView()

        

        case "favorite":
            MyContributionsView(initialTab: "favorite")
        case "browse":
            MyContributionsView(initialTab: "browse")
        default:
            EmptyView()
        }
    }
}

// MARK: - 4. 我的服务
struct UserServiceCard: View {
    @EnvironmentObject var store: AccountStore
    var isProvider: Bool { store.petOwner?.providerId != nil }
    
    var baseItems: [(icon: String, title: String, color: Color, type: String)] {
        var items: [(icon: String, title: String, color: Color, type: String)] = [
            ("car.fill", NSLocalizedString("person_service_taxi", comment: ""), PFColors.info, "taxi"),
            ("cart.fill", NSLocalizedString("person_service_mall", comment: ""), PFColors.warning, "mall"),
            ("cross.case.fill", NSLocalizedString("person_service_emergency", comment: ""), PFColors.danger, "emergency"),
            ("calendar.badge.clock", NSLocalizedString("person_service_appointment", comment: ""), PFColors.success, "appointment"),
            ("wallet.pass.fill", NSLocalizedString("person_wallet", comment: ""), PFColors.success, "wallet"),
            ("calendar.badge.checkmark", NSLocalizedString("person_checkin", comment: ""), PFColors.warning, "checkin")
        ]
        if isProvider {
            items.append((icon: "checkmark.shield.fill", title: NSLocalizedString("person_qualification", comment: ""), color: PFColors.info, type: "qualification"))
            items.append((icon: "rectangle.3.group.fill", title: NSLocalizedString("person_dispatch_hall", comment: ""), color: PFColors.warning, type: "dispatch"))
        }
        return items
    }
    
    @State private var selectedType: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("person_my_services")
                    .font(PFFonts.headline)
                    .foregroundColor(PFColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, PFSpacing.lg)
            .padding(.top, PFSpacing.lg)
            
            Divider().padding(.horizontal, PFSpacing.lg).padding(.top, PFSpacing.sm)
            
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: PFSpacing.lg
            ) {
                ForEach(baseItems, id: \.title) { item in
                    Button(action: {
                        Haptics.play()
                        selectedType = item.type
                    }) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(item.color.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: item.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(item.color)
                            }
                            
                            Text(item.title)
                                .font(PFFonts.caption)
                                .foregroundColor(PFColors.textSecondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(PFSpacing.lg)
        }
        .background(
            RoundedRectangle(cornerRadius: PFRadius.lg)
                .fill(PFColors.surface)
        )
        .pfCardShadow()
        .padding(.horizontal, PFSpacing.xl)
        .background(
            NavigationLink(
                destination: Group {
                    if let type = selectedType, let item = baseItems.first(where: { $0.type == type }) {
                        if type == "mall" {
                            PointsMallView().trackScene("PointsMall")
                        } else if type == "qualification" {
                            ProviderQualificationView().trackScene("ProviderQualification")
                        } else if type == "dispatch" {
                            DispatchHallView().trackScene("DispatchHall")
                        } else if type == "wallet" {
                            WalletView().trackScene("Wallet")
                        } else if type == "checkin" {
                            CheckInView().trackScene("CheckIn")
                        } else {
                            ServiceOrderListView(title: item.title, type: type)
                        }
                    }
                },
                isActive: Binding(
                    get: { selectedType != nil },
                    set: { if !$0 { selectedType = nil } }
                )
            ) {
                EmptyView()
            }
        )
    }
}

// MARK: - 5. 爱心成就
struct AchievementCard: View {
    struct Achievement: Identifiable, Decodable {
        @Int64String var idWrapper: Int64?
        var id: String { idWrapper.map(String.init) ?? UUID().uuidString }
        
        let icon: String?
        let title: String?
        let subtitle: String?
        let achieved: Bool?
        let color: String?
        let progress: Double?
        let currentValue: Int?
        let thresholdValue: Int?
        
        enum CodingKeys: String, CodingKey {
            case idWrapper = "id"
            case icon, title, subtitle, achieved, color, progress, currentValue, thresholdValue
        }
    }
    
    @EnvironmentObject var store: AccountStore
    @State private var achievements: [Achievement] = []
    @State private var isLoading = false
    @State private var selectedAchievement: Achievement?
    
    var body: some View {
        VStack(spacing: 0) {
            NavigationLink(destination: AchievementListView()) {
                HStack {
                    Text("person_achievements")
                        .font(PFFonts.headline)
                        .foregroundColor(PFColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(PFColors.textTertiary)
                }
                .padding(.horizontal, PFSpacing.lg)
                .padding(.top, PFSpacing.lg)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 程序化导航到详情页
            NavigationLink(
                destination: Group {
                    if let selected = selectedAchievement {
                        AchievementDetailView(
                            id: selected.id,
                            title: selected.title ?? "未知",
                            icon: selected.icon ?? "star.fill",
                            color: getColor(for: selected.color)
                        ).trackScene("AchievementDetail")
                    }
                },
                isActive: Binding(
                    get: { selectedAchievement != nil },
                    set: { if !$0 { selectedAchievement = nil } }
                )
            ) {
                EmptyView()
            }
            
            Divider().padding(.horizontal, PFSpacing.lg).padding(.top, PFSpacing.sm)
            
            if isLoading {
                // 骨架屏：加载中占位（与成就列表页一致，避免高度跳动）
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonAchievementInlineRow()
                }
                .padding(.vertical, PFSpacing.xs)
            } else if achievements.isEmpty {
                Text("person_achievements_empty")
                    .font(PFFonts.caption)
                    .foregroundColor(PFColors.textTertiary)
                    .padding()
            } else {
                ForEach(achievements) { item in
                    achievementItem(item: item)
                }
            }
            
            Spacer().frame(height: PFSpacing.sm)
        }
        .background(
            RoundedRectangle(cornerRadius: PFRadius.lg)
                .fill(PFColors.surface)
        )
        .pfCardShadow()
        .padding(.horizontal, PFSpacing.xl)
        .onAppear {
            fetchAchievements()
        }
    }
    
    @ViewBuilder
    private func achievementItem(item: Achievement) -> some View {
        let isAchieved = item.achieved ?? false
        let uiColor = getColor(for: item.color)
        let isLoggedIn = store.user != nil
        
        if isLoggedIn {
            Button(action: {
                Haptics.play()
                selectedAchievement = item
            }) {
                achievementRow(item: item, uiColor: uiColor, isAchieved: isAchieved)
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            achievementRow(item: item, uiColor: uiColor, isAchieved: isAchieved)
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.notify(.warning)
                }
        }
    }

    @ViewBuilder
    private func achievementRow(item: Achievement, uiColor: Color, isAchieved: Bool) -> some View {
        HStack(spacing: PFSpacing.md) {
            // 图标
            ZStack {
                Circle()
                    .fill(uiColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                
                Image(systemName: item.icon ?? "star.fill")
                    .font(.system(size: 16))
                    .foregroundColor(uiColor)
            }
        
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title ?? "")
                    .font(PFFonts.callout)
                    .foregroundColor(PFColors.textPrimary)
                
                Text(item.subtitle ?? "")
                    .font(PFFonts.caption)
                    .foregroundColor(PFColors.textSecondary)
                
                // 进度条
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(PFColors.divider)
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [uiColor.opacity(0.8), uiColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * (item.progress ?? 0), height: 4)
                    }
                }
                .frame(height: 4)
            }
            
            Spacer()
            
            // 状态
            Text(isAchieved ? "person_achievement_achieved" : "person_achievement_in_progress")
                .font(PFFonts.caption2)
                .foregroundColor(isAchieved ? PFColors.success : PFColors.warning)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    (isAchieved ? PFColors.success : PFColors.warning).opacity(0.1)
                )
                .clipShape(Capsule())
        }
        .padding(.horizontal, PFSpacing.lg)
        .padding(.vertical, PFSpacing.sm)
        .contentShape(Rectangle())
    }
    
    private func fetchAchievements() {
        // guard NetworkManager.shared.token != nil else { return }
        // guard achievements.isEmpty else { return }
        isLoading = true
        Task {
            do {
                let resp: AchievementListResp = try await NetworkManager.shared.request("/petFriendly/client/achievementsList", method: .get, needToken: true)
                await MainActor.run {
                    self.achievements = resp.rows
                    self.isLoading = false
                }
            } catch {
                print("获取成就列表失败: \(error)")
                await MainActor.run { isLoading = false }
            }
        }
    }
    
    // View level helper for MainActor mapping
    private func getColor(for color: String?) -> Color {
        switch color {
        case "warning": return PFColors.warning
        case "info": return PFColors.info
        case "accent": return PFColors.accent
        case "success": return PFColors.success
        case "danger": return PFColors.danger
        default: return PFColors.primary
        }
    }
}

// MARK: - 6. 设置卡片
struct SettingsCard: View {
    let items: [(icon: String, titleId: String, color: Color)] = [
        ("bell.fill", "settings_notifications", PFColors.warning),
        ("lock.fill", "settings_privacy_settings", PFColors.info),
        ("questionmark.circle.fill", "settings_help_feedback", PFColors.success),
        ("gearshape.fill", "settings_title", PFColors.textSecondary)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("person_other_settings")
                    .font(PFFonts.headline)
                    .foregroundColor(PFColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, PFSpacing.lg)
            .padding(.top, PFSpacing.lg)
            
            ForEach(items, id: \.titleId) { item in
                NavigationLink(destination: destinationView(for: item.titleId)) {
                    HStack(spacing: PFSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(item.color.opacity(0.12))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: item.icon)
                                .font(.system(size: 14))
                                .foregroundColor(item.color)
                        }
                        
                        Text(LocalizedStringKey(item.titleId))
                            .font(PFFonts.body)
                            .foregroundColor(PFColors.textPrimary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(PFColors.textTertiary)
                    }
                    .padding(.horizontal, PFSpacing.lg)
                    .padding(.vertical, PFSpacing.md)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: PFRadius.lg)
                .fill(PFColors.surface)
        )
        .pfCardShadow()
        .padding(.horizontal, PFSpacing.xl)
        .padding(.bottom, 100)
    }
    
    @ViewBuilder
    private func destinationView(for titleId: String) -> some View {
        switch titleId {
        case "settings_notifications":
            NotificationsView()
        case "settings_privacy_settings":
            PrivacySettingsView()
        case "settings_help_feedback":
            HelpFeedbackView()
        case "settings_title":
            SettingsView()
        default:
            Text(LocalizedStringKey(titleId))
        }
    }
}
//
//  MyContributionsView.swift
//  PetFriendly
//
//  我的贡献/足迹（聚合页面）
//

import SwiftUI

struct ContributionItem: Identifiable, Decodable {
    /// 使用服务端返回的 id 作为稳定标识（不再用 UUID 导致 ForEach 崩溃）
    let id: String
    let title: String?
    let subtitle: String?
    let time: String?
    let type: String?
    /// 后端返回的场所 id（字符串），用于加载详情
    let placeId: String?

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, time, type, placeId
    }

    /// 手动解码：用 decodeIfPresent 保证字段缺失时不会因 keyNotFound 崩溃
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try container.decodeIfPresent(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        time = try container.decodeIfPresent(String.self, forKey: .time)
        // 后端 type 可能返回数字（如 2）也可能返回字符串，这里兼容两种
        type = Self.decodeFlexibleString(container, key: .type)
        // 后端 placeId 可能返回 null、数字或字符串，这里兼容
        placeId = Self.decodeFlexibleString(container, key: .placeId)
    }

    /// 兼容 Int / String / null 的字符串解码
    private static func decodeFlexibleString(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> String? {
        if let str = try? container.decode(String.self, forKey: key) {
            return str
        }
        if let intVal = try? container.decode(Int.self, forKey: key) {
            return String(intVal)
        }
        return nil
    }
}

struct ContributionResp: Decodable {
    let code: Int
    let total: Int
    let rows: [ContributionItem]
}

class MyContributionsViewModel: ObservableObject {
    @Published var items: [ContributionItem] = []
    @Published var isLoading = false
    @Published var hasMore = true
    
    private var pageNum = 1
    private let pageSize = 20
    private var currentType = "favorite" // favorite, browse, evaluate, report
    
    func switchType(to newType: String) {
        // 如果类型未变且已有数据，则不重复抓取；否则（类型改变或初始为空）执行抓取
        if currentType == newType && !items.isEmpty { return }
        currentType = newType

        items.removeAll()
        pageNum = 1
        hasMore = true
        fetchData()
    }
    
    func fetchData() {
        guard !isLoading && hasMore else { return }
        isLoading = true
        
        Task {
            do {
                let typeInt: Int
                switch currentType {
                case "report": typeInt = 1
                case "evaluate": typeInt = 2
                case "favorite": typeInt = 3
                case "browse": typeInt = 4
                default: typeInt = 1
                }
                
                let url = "/petFriendly/client/myContributions?type=\(typeInt)&pageNum=\(pageNum)&pageSize=\(pageSize)"
                let resp: ContributionResp = try await NetworkManager.shared.request(url, method: .get, needToken: true)
                await MainActor.run {
                    let isFirstPage = self.pageNum == 1
                    if isFirstPage { self.items.removeAll() }

                    let newRows = resp.rows
                    self.items.append(contentsOf: newRows)
                    // 本次未返回新数据 → 没有更多了（避免无限重复加载）
                    if newRows.isEmpty {
                        self.hasMore = false
                    } else {
                        self.hasMore = self.items.count < resp.total
                        if self.hasMore { self.pageNum += 1 }
                    }
                    self.isLoading = false
                }
            } catch {
                print("Fetch contributions error: \(error)")
                await MainActor.run {
                    // 加载更多失败：保持 hasMore，允许下次滚动再次尝试；并给出提示
                    self.isLoading = false
                    if !self.items.isEmpty {
                        UIState.shared.showToast(NSLocalizedString("load_failed", comment: ""), style: .error)
                    }
                }
            }
        }
    }
}

struct MyContributionsView: View {
    @StateObject private var viewModel = MyContributionsViewModel()
    @State private var selectedTab: String
    
    init(initialTab: String = "favorite") {
        _selectedTab = State(initialValue: initialTab)
    }
    
    let tabs = [
        (NSLocalizedString("contrib_favorites", comment: ""), "favorite"),
        (NSLocalizedString("contrib_history", comment: ""), "browse"),
        (NSLocalizedString("contrib_reviews", comment: ""), "evaluate"),
        (NSLocalizedString("contrib_reports", comment: ""), "report")
    ]
    
    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Tab Header
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PFSpacing.xl) {
                        ForEach(tabs, id: \.1) { tab in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTab = tab.1
                                }
                                viewModel.switchType(to: tab.1)
                            }) {
                                VStack(spacing: 8) {
                                    Text(tab.0)
                                        .font(selectedTab == tab.1 ? .system(size: 18, weight: .bold) : PFFonts.callout)
                                        .foregroundColor(selectedTab == tab.1 ? PFColors.primary : PFColors.textSecondary)
                                    
                                    ZStack {
                                        Capsule()
                                            .fill(Color.clear)
                                            .frame(height: 3)
                                        
                                        if selectedTab == tab.1 {
                                            Capsule()
                                                .fill(PFColors.primary)
                                                .frame(height: 3)
                                                .matchedGeometryEffect(id: "underline", in: animationNamespace)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, PFSpacing.xl)
                    .padding(.top, PFSpacing.md)
                }
                .background(PFColors.surface)
                
                // List Content
                ScrollView {
                    LazyVStack(spacing: PFSpacing.lg) {
                        if viewModel.isLoading && viewModel.items.isEmpty {
                            // 骨架屏：加载中占位卡片
                            ForEach(0..<5, id: \.self) { _ in
                                SkeletonContributionRow()
                            }
                        } else if viewModel.items.isEmpty {
                            VStack(spacing: PFSpacing.lg) {
                                Image(systemName: "moon.stars.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(PFColors.textTertiary)
                                    .padding(.top, 100)
                                Text("contrib_empty_state")
                                    .font(PFFonts.callout)
                                    .foregroundColor(PFColors.textSecondary)
                            }
                        } else {
                            ForEach(viewModel.items) { item in
                                ContributionRow(item: item)
                                    .onAppear {
                                        if item.id == viewModel.items.last?.id {
                                            viewModel.fetchData()
                                        }
                                    }
                            }
                        }
                        
                        if viewModel.isLoading && !viewModel.items.isEmpty {
                            PFPetLoadingInline(size: 18).padding()
                        }
                    }
                    .padding(.vertical, PFSpacing.lg)
                }
            }
        }
        .navigationTitle("contrib_title")
        .navigationBarTitleDisplayMode(.inline)
        .pfToyBackground()
        .trackScene("MyContributions")
        .onAppear {
            viewModel.switchType(to: selectedTab)
        }
    }
    
    @Namespace private var animationNamespace
}

struct ContributionRow: View {
    let item: ContributionItem
    @State private var isExpanded = false
    @State private var placeDetail: PetFriendlyPlace?
    @State private var isLoadingDetail = false
    @State private var detailError = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row (always visible, tappable)
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                    if isExpanded && placeDetail == nil && !isLoadingDetail {
                        loadPlaceDetail()
                    }
                }
            }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text(item.title ?? NSLocalizedString("contrib_unknown", comment: ""))
                            .font(PFFonts.headline)
                            .foregroundColor(PFColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        HStack(spacing: 4) {
                            Text(item.time ?? "")
                                .font(PFFonts.caption2)
                                .foregroundColor(PFColors.textTertiary)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(PFColors.textTertiary)
                        }
                    }
                    if let sub = item.subtitle, !sub.isEmpty {
                        Text(sub)
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.textSecondary)
                            .lineLimit(isExpanded ? nil : 2)
                    }
                }
                .padding(PFSpacing.md)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded detail section
            if isExpanded {
                Divider()
                    .padding(.horizontal, PFSpacing.md)
                
                VStack(alignment: .leading, spacing: 12) {
                    if isLoadingDetail {
                        HStack {
                            Spacer()
                            PFPetLoadingInline(size: 18)
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    } else if detailError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(PFColors.warning)
                            Text(NSLocalizedString("load_failed", comment: ""))
                                .font(PFFonts.caption)
                                .foregroundColor(PFColors.textSecondary)
                        }
                        .padding(.vertical, 8)
                    } else if let place = placeDetail {
                        // Place detail card
                        VStack(alignment: .leading, spacing: 8) {
                            // Place name
                            Text(place.name ?? NSLocalizedString("contrib_unknown_place", comment: ""))
                                .font(PFFonts.callout.weight(.semibold))
                                .foregroundColor(PFColors.textPrimary)
                            
                            // Place address (use remark or contact info)
                            let addressInfo = place.remark ?? place.contactName
                            if let addr = addressInfo, !addr.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(PFColors.primary)
                                    Text(addr)
                                        .font(PFFonts.caption)
                                        .foregroundColor(PFColors.textSecondary)
                                        .lineLimit(2)
                                }
                            }
                            
                            // Place type badge
                            if let placeType = place.type, placeType >= 0, placeType <= 9 {
                                let typeNames = [
                                    "place_type_park", "place_type_hospital", "place_type_restaurant",
                                    "place_type_water", "place_type_lawn", "place_type_square",
                                    "place_type_police", "place_type_photo", "place_type_grooming", "place_type_boarding"
                                ]
                                let typeEmojis = ["🌳", "🏥", "🍽️", "💧", "🌿", "🏛️", "👮", "📸", "✂️", "🏠"]
                                HStack(spacing: 4) {
                                    Text(typeEmojis[Int(placeType)])
                                    Text(LocalizedStringKey(typeNames[Int(placeType)]))
                                        .font(PFFonts.caption2)
                                        .foregroundColor(PFColors.primary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(PFColors.primary.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                            
                            // Rating
                            if place.rate > 0 {
                                HStack(spacing: 2) {
                                    ForEach(0..<5) { i in
                                        Image(systemName: i < Int(place.rate) ? "star.fill" : "star")
                                            .font(.system(size: 10))
                                            .foregroundColor(i < Int(place.rate) ? PFColors.warning : PFColors.textTertiary)
                                    }
                                    Text(String(format: "%.1f", place.rate))
                                        .font(PFFonts.caption2)
                                        .foregroundColor(PFColors.textSecondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    } else {
                        Text("contrib_no_detail")
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.textTertiary)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, PFSpacing.md)
                .padding(.bottom, PFSpacing.md)
            }
        }
        .background(PFColors.surface)
        .cornerRadius(PFRadius.md)
        .pfCardShadow()
        .padding(.horizontal, PFSpacing.lg)
    }
    
    private func loadPlaceDetail() {
        guard let placeId = item.placeId, !placeId.isEmpty else {
            detailError = true
            return
        }
        isLoadingDetail = true
        detailError = false
        
        struct PlaceDetailResp: Decodable {
            let code: Int
            let msg: String?
            let data: PetFriendlyPlace?
        }
        
        Task {
            do {
                let resp: PlaceDetailResp = try await NetworkManager.shared.request(
                    "/petFriendly/client/getPlaceDetail",
                    method: .get,
                    parameters: ["placeId": placeId],
                    showLoading: false
                )
                await MainActor.run {
                    self.placeDetail = resp.data
                    self.isLoadingDetail = false
                    if resp.data == nil {
                        self.detailError = true
                    }
                }
            } catch {
                print("Load place detail error: \(error)")
                await MainActor.run {
                    self.isLoadingDetail = false
                    self.detailError = true
                }
            }
        }
    }
}

// MARK: - 骨架屏占位卡片

/// 加载中使用的骨架屏占位，模拟 ContributionRow 的布局
struct SkeletonContributionRow: View {
    @State private var opacity: Double = 0.3

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                // 标题占位
                RoundedRectangle(cornerRadius: 4)
                    .fill(PFColors.divider)
                    .frame(width: 120, height: 14)
                Spacer()
                // 时间占位
                RoundedRectangle(cornerRadius: 4)
                    .fill(PFColors.divider)
                    .frame(width: 50, height: 10)
            }

            // 副标题占位
            RoundedRectangle(cornerRadius: 4)
                .fill(PFColors.divider)
                .frame(width: 200, height: 10)
        }
        .padding(PFSpacing.md)
        .background(PFColors.surface)
        .cornerRadius(PFRadius.md)
        .pfCardShadow()
        .padding(.horizontal, PFSpacing.lg)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                opacity = 0.7
            }
        }
    }
}

// MARK: - 爱心成就内联骨架行（我的页面卡片内加载占位）
struct SkeletonAchievementInlineRow: View {
    @State private var opacity: Double = 0.3

    var body: some View {
        HStack(spacing: PFSpacing.md) {
            // 图标占位
            Circle()
                .fill(PFColors.divider)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 6) {
                // 标题占位
                RoundedRectangle(cornerRadius: 4)
                    .fill(PFColors.divider)
                    .frame(width: 110, height: 12)
                // 副标题占位
                RoundedRectangle(cornerRadius: 4)
                    .fill(PFColors.divider)
                    .frame(width: 150, height: 10)
                // 进度条占位
                Capsule()
                    .fill(PFColors.divider)
                    .frame(height: 4)
            }

            Spacer()
        }
        .padding(.horizontal, PFSpacing.lg)
        .padding(.vertical, PFSpacing.sm)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                opacity = 0.7
            }
        }
    }
}
