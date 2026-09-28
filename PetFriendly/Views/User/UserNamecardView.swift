//
//  UserNamecardView.swift
//  PetFriendly
//
//  Created by PetFriendly Team on 2025/11/05.
//  合并后的唯一名片页面 — 使用主图作为背景图样式
//

import SwiftUI
import Alamofire

struct UserNamecardView: View {
    let userId: Int64
    /// 非空时仅展示调用方允许公开的宠物；附近宠友传入本次共享选择。
    let visiblePetIds: Set<String>?
    let petDetailsReadOnly: Bool
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var userData: NamecardData?
    @State private var isLoading = true
    @State private var selectedTab = 0 // 0: 我的探索, 1: 我的发现
    
    @State private var explorations: [NamecardContributionItem] = []
    @State private var discoveries: [NamecardContributionItem] = []
    
    @State private var showEditProfile = false
    @State private var isOwnCard = false
    @State private var isLoadingContributions = false
    @State private var selectedPlaceItem: PlaceIdWrapper?
    @State private var selectedPet: Pet?
    @State private var selectedBadge: BadgeRecord?
    @State private var reportTarget: ContentReportTarget?
    @State private var isBlocked = false
    @State private var isUpdatingBlock = false

    init(userId: Int64, visiblePetIds: Set<String>? = nil, petDetailsReadOnly: Bool = false) {
        self.userId = userId
        self.visiblePetIds = visiblePetIds
        self.petDetailsReadOnly = petDetailsReadOnly
    }
    
    var body: some View {
        ZStack {
            PFColors.background.ignoresSafeArea()
            
            if isLoading {
                PFPetLoadingView(size: 36)
                    .scaleEffect(1.5)
            } else if let data = userData {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // 1. 顶部 Banner (主图作为背景图)
                        // bannerSection(data: data.user)
                        Spacer(minLength: 40)
                        VStack(spacing: 20) {
                            // 2. 个人名片信息 (叠加在 Banner 上一点)
                            userHeaderSection(data: data.user)
                                .padding(.bottom, -30)
                            
                            // 3. 我的宠物
                            if !visiblePets(from: data).isEmpty {
                                petsSection(pets: visiblePets(from: data), user: data.user)
                            }
                            
                            // 4. 我的服务 (如果是服务商)
                            if let provider = data.provider {
                                providerSection(provider: provider, services: data.providerServices, user: data.user)
                            }
                            
                            // 5. 动态内容 Tabs
                            contentTabsSection(user: data.user)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 50)
                    }
                }
                .ignoresSafeArea(edges: .top)
            } else {
                Text(NSLocalizedString("user_data_load_failed", comment: ""))
                    .foregroundColor(PFColors.textSecondary)
            }
            
            // 顶部返回按钮
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    Spacer()
                    
                    // 右上角显示用户ID
                    if let data = userData {
                        Text(String(format: NSLocalizedString("user_id_format", comment: ""), data.user.ownerId ?? ""))
                            .font(.caption2)
                            .foregroundColor(colorScheme == .dark ? .white : .black.opacity(0.7))
                    }
                    
                    if isOwnCard {
                        Button(action: { showEditProfile = true }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                    } else if NetworkManager.shared.token != nil {
                        Menu {
                            Button {
                                reportTarget = ContentReportTarget(type: "user", targetId: nil, targetUserId: userId)
                            } label: {
                                Label("report_user", systemImage: "exclamationmark.bubble")
                            }
                            Button(role: isBlocked ? nil : .destructive) {
                                updateBlocked(!isBlocked)
                            } label: {
                                Label(isBlocked ? NSLocalizedString("user_unblock", comment: "") : NSLocalizedString("user_block", comment: ""), systemImage: isBlocked ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.xmark")
                            }
                            .disabled(isUpdatingBlock)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .pfToyBackground()
        .onAppear {
            fetchData()
            fetchBlockStatus()
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfilePopup(nickname: userData?.user.name ?? "", avatar: userData?.user.petAvatar ?? "") { newName, newAvatar in
                // 更新本地数据
                if var user = userData?.user {
                    user.name = newName
                    user.petAvatar = newAvatar
                    userData?.user = user
                }
            }
        }
        .sheet(item: $selectedPlaceItem) { wrapper in
            PlaceDetailLoaderView(placeId: wrapper.id)
        }
        .sheet(item: $selectedPet) { pet in
            PetDetailView(pet: pet, isReadOnly: petDetailsReadOnly)
        }
        .sheet(item: $selectedBadge) { badge in
            if let badgeId = badge.achievementBadgeId {
                AchievementDetailView(
                    id: badgeId,
                    title: badge.badgeName ?? NSLocalizedString("achievement_detail_title", comment: ""),
                    icon: badge.badgeIcon ?? "star.fill",
                    color: getBadgeColor(badge.badgeColor),
                    targetUserId: userId
                )
            }
        }
        .sheet(item: $reportTarget) { target in
            ContentReportView(target: target)
        }
    }

    private func fetchBlockStatus() {
        guard NetworkManager.shared.token != nil else { return }
        Task {
            do {
                let response: RespWrapper<Bool> = try await NetworkManager.shared.request(
                    "/petFriendly/client/users/block/status", parameters: ["userId": userId], showLoading: false)
                await MainActor.run { isBlocked = response.data ?? false }
            } catch { }
        }
    }

    private func updateBlocked(_ blocked: Bool) {
        guard !isUpdatingBlock else { return }
        isUpdatingBlock = true
        Task {
            do {
                let response: RespWrapper<Bool> = try await NetworkManager.shared.request(
                    "/petFriendly/client/users/block", method: .post,
                    parameters: ["userId": userId, "blocked": blocked], encoding: JSONEncoding.default)
                await MainActor.run {
                    isUpdatingBlock = false
                    if response.code == 200 {
                        isBlocked = blocked
                        showSuccessHUD(message: NSLocalizedString(blocked ? "user_block_success" : "user_unblock_success", comment: ""))
                    } else {
                        showErrorHUD(message: response.msg ?? NSLocalizedString("common_operation_failed", comment: ""))
                    }
                }
            } catch {
                await MainActor.run { isUpdatingBlock = false; showErrorHUD(message: error.localizedDescription) }
            }
        }
    }
    
    private func pronoun(for user: PetOwner) -> String {
        if isOwnCard { return NSLocalizedString("me", comment: "") }
        if user.sex == 2 { return NSLocalizedString("she", comment: "") }
        if user.sex == 1 { return NSLocalizedString("he", comment: "") }
        return NSLocalizedString("it", comment: "")
    }

    private func visiblePets(from data: NamecardData) -> [Pet] {
        guard let allowed = visiblePetIds else { return data.pets ?? [] }
        return (data.pets ?? []).filter { allowed.contains($0.petId) }
    }
    
    // MARK: - Subviews
    
    /// 顶部 Banner：优先使用用户个性化主图，其次使用默认主题图
    private func bannerSection(data: PetOwner) -> some View {
        let userSettings = data.settings
        // 回退逻辑：JSON 解析 URL → ext 直接作为 URL → 默认主题图
        var bannerUrl = userSettings?.headerBackgroundImageUrl ?? ""
        if bannerUrl.isEmpty, let ext = data.ext, !ext.isEmpty {
            if ext.starts(with: "http") || ext.starts(with: "/") {
                bannerUrl = ext
            }
        }
        
        return ZStack(alignment: .bottom) {
            if !bannerUrl.isEmpty {
                CachedAsyncImage(url: NetworkManager.fullUrl(bannerUrl)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(PFColors.surfaceSecondary)
                }
            } else {
                // 默认主题图
                CachedAsyncImage(url: URL(string: Secrets.defaultBannerURL)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(PFColors.surfaceSecondary)
                }
            }
            
            // 底部渐变过渡
            LinearGradient(
                colors: [.clear, PFColors.background.opacity(0.8), PFColors.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)
        }
        .frame(height: 220)
        .clipped()
    }
    
    private func userHeaderSection(data: PetOwner) -> some View {
        let userSettings = data.settings
        
        // 关键修复：增加回退逻辑。如果 ext 是 JSON 则解析 URL，如果 ext 本身就是 URL 则直接使用
        var bannerUrl = userSettings?.headerBackgroundImageUrl ?? ""
        if bannerUrl.isEmpty, let ext = data.ext, !ext.isEmpty {
            if ext.starts(with: "http") || ext.starts(with: "/") {
                bannerUrl = ext
            }
        }
        let hasBanner = !bannerUrl.isEmpty

        return VStack(spacing: 12) {
            HStack(spacing: 20) {
                // 头像
                if let avatar = data.petAvatar, !avatar.isEmpty {
                    CachedAsyncImage(url: NetworkManager.fullUrl(avatar)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(PFColors.surfaceSecondary)
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                    .pfElevatedShadow()
                } else {
                    Circle()
                        .fill(PFGradients.brand)
                        .frame(width: 80, height: 80)
                        .overlay(Text(String((data.name ?? "").prefix(1))).font(.title).foregroundColor(hasBanner ? .white : PFColors.textPrimary))
                        .overlay(Circle().stroke(hasBanner ? Color.white : Color.black, lineWidth: 3))
                        .pfElevatedShadow()
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(data.name ?? NSLocalizedString("person_no_nickname", comment: ""))
                            .font(PFFonts.title2)
                            .foregroundColor(hasBanner ? Color.white : PFColors.textPrimary)
                        
                        if data.providerId != nil {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(hasBanner ? .white : PFColors.textPrimary)
                                .font(.system(size: 14))
                        }
                    }
                    
                    HStack(spacing: 10) {
                        
                        // Lv 等级徽标：与「我的」页面外部名片的 Lv 样式保持一致（白色文字 + brand 渐变胶囊）
                        Text("Lv.\(data.loveLevel ?? 1)")
                            .font(PFFonts.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(PFGradients.brand)
                            .clipShape(Capsule())

                        // 爱心等级
                        Label("\(data.loveValue ?? 0)", systemImage: "heart.fill")
                            .font(PFFonts.caption)
                            .foregroundColor(hasBanner ? Color.white : PFColors.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                    }
                }
                Spacer()
            }
            .padding(PFSpacing.lg)
            .background(
                ZStack {
                    if hasBanner {
                        CachedAsyncImage(url: NetworkManager.fullUrl(bannerUrl)) { image in
                            ZStack {
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                                
                                LinearGradient(
                                    colors: [.black.opacity(0.4), .black.opacity(0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                Color.black.opacity(0.2)
                            }
                        } placeholder: {
                            PFColors.primary.opacity(0.1)
                        }
                    } else {
                        PFColors.primary.opacity(0.1)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: PFRadius.lg))
            .pfCardShadow()
            .frame(maxWidth: PFScreen.width - 40)
            
            // 徽章墙
            if let badges = userData?.badges, !badges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(badges) { record in
                            Button { selectedBadge = record } label: { VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(getBadgeColor(record.badgeColor).opacity(0.12))
                                        .frame(width: 44, height: 44)
                                    
                                    if let icon = record.badgeIcon, !icon.isEmpty {
                                        if icon.contains("/") || icon.contains("http") {
                                            CachedAsyncImage(url: NetworkManager.fullUrl(icon)) { image in
                                                image.resizable().scaledToFit()
                                            } placeholder: {
                                                PFPetLoadingInline(size: 12)
                                            }
                                            .frame(width: 24, height: 24)
                                        } else {
                                            Image(systemName: icon)
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(getBadgeColor(record.badgeColor))
                                        }
                                    } else {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(PFColors.warning)
                                    }
                                }
                                
                                Text(record.badgeName ?? "")
                                    .font(PFFonts.caption2)
                                    .foregroundColor(PFColors.textSecondary)
                            } }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // 右下角显示当前租户名称
            if let tenantName = AccountStore.shared.petOwner?.tenantName, !tenantName.isEmpty {
                HStack {
                    Spacer()
                    Text(tenantName)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, PFSpacing.lg)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 20)
    }
    
    private func getBadgeColor(_ colorName: String?) -> Color {
        switch colorName {
        case "warning": return PFColors.warning
        case "info": return PFColors.info
        case "accent": return PFColors.accent
        case "success": return PFColors.success
        case "danger": return PFColors.danger
        default: return PFColors.primary
        }
    }
    
    private func petsSection(pets: [Pet], user: PetOwner) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(format: NSLocalizedString("namecard_my_pets", comment: ""), pronoun(for: user)))
                .font(PFFonts.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(pets, id: \.id) { pet in
                        Button { selectedPet = pet } label: { VStack(spacing: 8) {
                            if let avatar = pet.petAvatar, !avatar.isEmpty {
                                CachedAsyncImage(url: NetworkManager.fullUrl(avatar)) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Circle().fill(PFColors.surfaceSecondary)
                                }
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                            } else {
                                Image("PetLogo")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .scaleEffect(1.2)
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                            }
                            
                            Text(pet.displayName)
                                .font(PFFonts.caption2)
                                .foregroundColor(PFColors.textPrimary)
                        } }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(PFColors.surface)
                .pfCardShadow()
        )
    }
    
    private func providerSection(provider: ServiceItem, services: [ServiceItem]?, user: PetOwner) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(format: NSLocalizedString("namecard_my_services", comment: ""), pronoun(for: user)))
                    .font(PFFonts.headline)
                Spacer()
                PFTag(text: "namecard_verified_provider", gradient: PFGradients.brand)
            }
            
            // 展示服务商关联的服务列表（与主服务列表一致：服务标题 + 服务图）
            if let services = services, !services.isEmpty {
                ForEach(services) { svc in
                    providerServiceRow(svc)
                }
            } else {
                // 兜底：无关联服务时展示服务商本身信息
                providerServiceRow(provider)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(PFColors.surface)
                .pfCardShadow()
        )
    }
    
    /// 单个服务行：服务图 + 标题 + 副标题（与主服务列表展示一致）
    private func providerServiceRow(_ svc: ServiceItem) -> some View {
        HStack(spacing: 15) {
            if let imgPath = svc.serviceMainPicture ?? svc.icon, !imgPath.isEmpty,
               let serviceImgUrl = NetworkManager.fullUrl(imgPath) {
                CachedAsyncImage(url: serviceImgUrl) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12).fill(PFColors.surfaceSecondary)
                }
                .frame(width: 60, height: 60)
                .cornerRadius(12)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(PFColors.surfaceSecondary)
                        .frame(width: 60, height: 60)
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 24))
                        .foregroundColor(PFColors.primary.opacity(0.5))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(svc.title ?? "")
                    .font(PFFonts.headline)
                    .foregroundColor(PFColors.textPrimary)
                Text(svc.subTitle ?? "")
                    .font(PFFonts.caption)
                    .foregroundColor(PFColors.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
    
    private func contentTabsSection(user: PetOwner) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                tabButton(title: String(format: NSLocalizedString("namecard_explorations", comment: ""), pronoun(for: user)), index: 0)
                tabButton(title: String(format: NSLocalizedString("namecard_discoveries", comment: ""), pronoun(for: user)), index: 1)
            }
            .padding(4)
            .background(PFColors.surfaceSecondary)
            .clipShape(Capsule())
            
            // 独立子视图：通过 .id(selectedTab) 强制完全重建，避免 ForEach diff 跨数组崩溃
            NamecardTabContent(
                items: selectedTab == 0 ? explorations : discoveries,
                isLoading: isLoadingContributions,
                selectedTab: selectedTab,
                onPlaceTapped: { pid in selectedPlaceItem = PlaceIdWrapper(id: pid) }
            )
            .id(selectedTab)
        }
    }
    
    private func tabButton(title: String, index: Int) -> some View {
        Button(action: {
            // 先清空目标 Tab 旧数据，避免 ForEach 用错误的旧数据渲染
            if index == 0 { explorations = [] } else { discoveries = [] }
            selectedTab = index
            fetchContributions(forTab: index)
        }) {
            Text(title)
                .font(PFFonts.caption)
                .fontWeight(selectedTab == index ? .bold : .medium)
                .foregroundColor(selectedTab == index ? .white : PFColors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(selectedTab == index ? PFColors.primary : Color.clear)
                .clipShape(Capsule())
        }
    }
    
    // MARK: - Data Fetching
    
    private func fetchData() {
        Task {
            do {
                let resp: NamecardResponse = try await NetworkManager.shared.request("/petFriendly/client/getNamecard?userId=\(userId)")
                await MainActor.run {
                    self.userData = resp.data
                    self.isLoading = false
                    
                    // Check if own card
                    Task {
                        let selfId = AccountStore.shared.user?.userId
                        await MainActor.run {
                            self.isOwnCard = (selfId == userId)
                        }
                    }
                    
                    // Initial fetch for first tab
                    fetchContributions(forTab: 0)
                }
            } catch {
                print("Namecard error: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }
    
    private func fetchContributions(forTab tab: Int) {
        guard userId > 0 else {
            self.isLoadingContributions = false
            return
        }
        isLoadingContributions = true
        let capturedTab = tab  // 捕获当前 tab，避免 async 后 selectedTab 已改变
        Task {
            do {
                // 我的探索 = 收藏(3)，我的发现 = 上报(1)
                // 注意：type=2 已改为「评价」数据源，名片的探索 tab 应展示收藏列表而非评价
                let type = capturedTab == 0 ? 3 : 1
                let url = "/petFriendly/client/myContributions?type=\(type)&targetUserId=\(userId)&pageSize=20"
                let resp: NamecardContributionResponse = try await NetworkManager.shared.request(url)
                await MainActor.run {
                    if capturedTab == 0 {
                        self.explorations = resp.rows
                    } else {
                        self.discoveries = resp.rows
                    }
                    self.isLoadingContributions = false
                }
            } catch {
                print("Contributions error: \(error)")
                await MainActor.run { self.isLoadingContributions = false }
            }
        }
    }
}

// MARK: - 独立 Tab 内容视图（隔离 ForEach，防止跨数组 diff）

struct NamecardTabContent: View {
    let items: [NamecardContributionItem]
    let isLoading: Bool
    let selectedTab: Int
    let onPlaceTapped: (Int64) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            if isLoading && items.isEmpty {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonNamecardContributionCard()
                }
            } else if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(PFColors.textTertiary)
                    Text(NSLocalizedString("namecard_no_data", comment: ""))
                        .font(PFFonts.caption)
                        .foregroundColor(PFColors.textTertiary)
                }
                .padding(.vertical, 40)
            } else {
                ForEach(items) { item in
                    NamecardContributionCard(item: item, onTap: onPlaceTapped)
                }
            }
        }
    }
}

// MARK: - Helper Components

struct NamecardContributionCard: View {
    let item: NamecardContributionItem
    let onTap: (Int64) -> Void
    
    init(item: NamecardContributionItem, onTap: @escaping (Int64) -> Void = { _ in }) {
        self.item = item
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: {
            if let pid = item.placeId, pid > 0 {
                onTap(pid)
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                // 第一行：标题 | 状态标签
                HStack(alignment: .center, spacing: 6) {
                    Text(item.title ?? "")
                        .font(PFFonts.callout.weight(.semibold))
                        .foregroundColor(PFColors.textPrimary)
                        .lineLimit(1)
                    
                    if item.isPrivate == true {
                        PFTag(text: "eval_private_title", gradient: PFGradients.beauty)
                    }
                    
                    Spacer()
                    
                    if let pid = item.placeId, pid > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(PFColors.textTertiary)
                    }
                }
                
                // 第二行：Emoji（无图时）或封面图 | 描述文字
                HStack(spacing: 12) {
                    if let cover = item.cover, !cover.isEmpty {
                        // 有图：显示封面
                        CachedAsyncImage(url: NetworkManager.fullUrl(cover)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(PFColors.surfaceSecondary)
                        }
                        .frame(width: 64, height: 64)
                        .cornerRadius(12)
                    } else {
                        // 无图：显示场所 type emoji
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [PFColors.primary.opacity(0.08), PFColors.accent.opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 64, height: 64)
                            
                            Text(item.typeEmoji)
                                .font(.system(size: 32))
                        }
                    }
                    
                    // 描述文字
                    if let sub = item.subtitle, !sub.isEmpty {
                        Text(sub)
                            .font(PFFonts.caption)
                            .foregroundColor(PFColors.textSecondary)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        if !item.typeName.isEmpty {
                            Text(item.typeName)
                                .font(PFFonts.caption)
                                .foregroundColor(PFColors.textTertiary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                
                // 第三行：时间
                if let time = item.time, !time.isEmpty {
                    Text(time)
                        .font(.system(size: 10))
                        .foregroundColor(PFColors.textTertiary)
                }
            }
            .padding(14)
            .background(PFColors.surface)
            .cornerRadius(16)
            .pfCardShadow()
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(item.placeId == nil || item.placeId == 0)
    }
}

// MARK: - 骨架屏占位卡片

/// 加载中使用的骨架屏占位，模拟 NamecardContributionCard 的新布局
struct SkeletonNamecardContributionCard: View {
    @State private var opacity: Double = 0.3
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 第一行：标题占位 + 箭头
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(PFColors.divider)
                    .frame(width: 120, height: 14)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(PFColors.divider)
                    .frame(width: 14, height: 14)
            }
            
            // 第二行：图片占位 + 文字占位
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(PFColors.divider)
                    .frame(width: 64, height: 64)
                
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(PFColors.divider)
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(PFColors.divider)
                        .frame(width: 160, height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(PFColors.divider)
                        .frame(width: 100, height: 10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // 第三行：时间占位
            RoundedRectangle(cornerRadius: 4)
                .fill(PFColors.divider)
                .frame(width: 60, height: 8)
        }
        .padding(14)
        .background(PFColors.surface)
        .cornerRadius(16)
        .pfCardShadow()
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                opacity = 0.7
            }
        }
    }
}

// MARK: - PlaceDetail 加载中转页

/// 根据 placeId 加载场所详情，加载完成后跳转到 PlaceDetailView
struct PlaceDetailLoaderView: View, Identifiable {
    let placeId: Int64
    var id: Int64 { placeId }
    
    @Environment(\.dismiss) var dismiss
    @State private var place: PetFriendlyPlace? = nil
    @State private var isLoading = true
    @State private var loadError = false
    
    var body: some View {
        Group {
            if isLoading {
                PFPetLoadingOverlay()
            } else if let place = place {
                PlaceDetailView(place: place)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(PFColors.warning)
                    Text(NSLocalizedString("load_failed", comment: ""))
                        .font(PFFonts.callout)
                        .foregroundColor(PFColors.textSecondary)
                    Button(action: { dismiss() }) {
                        Text(NSLocalizedString("ok", comment: ""))
                            .font(PFFonts.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(PFColors.primary)
                            .cornerRadius(PFRadius.lg)
                    }
                }
            }
        }
        .task {
            await loadPlace()
        }
    }
    
    private func loadPlace() async {
        do {
            struct PlaceDetailResp: Decodable {
                let code: Int
                let msg: String?
                let data: PetFriendlyPlace?
            }
            let resp: PlaceDetailResp = try await NetworkManager.shared.request(
                "/petFriendly/client/getPlaceDetail",
                method: .get,
                parameters: ["placeId": placeId],
                showLoading: false
            )
            await MainActor.run {
                self.place = resp.data
                self.isLoading = false
            }
        } catch {
            print("PlaceDetailLoader error: \(error)")
            await MainActor.run {
                self.isLoading = false
                self.loadError = true
            }
        }
    }
}

// MARK: - Models

struct NamecardResponse: Decodable {
    let data: NamecardData
}

struct NamecardData: Decodable {
    var user: PetOwner
    let badges: [BadgeRecord]?
    let pets: [Pet]?
    let provider: ServiceItem?
    /// 服务商关联的服务列表（用户→服务商→服务）
    let providerServices: [ServiceItem]?
}

extension PetOwner {
    var settings: PetOwnerSettings? {
        guard let ext = ext, !ext.isEmpty, ext.starts(with: "{") else {
            return nil
        }
        guard let data = ext.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(PetOwnerSettings.self, from: data) else {
            return nil
        }
        return decoded
    }
}

struct BadgeRecord: Decodable, Identifiable {
    /// 稳定唯一标识。优先 recordId，fallback 用 badgeName 防重复
    var id: String {
        if let rid = recordId, rid != 0 { return String(rid) }
        var hasher = Hasher()
        hasher.combine(badgeName)
        hasher.combine(badgeIcon)
        return "badge_\(hasher.finalize())"
    }
    @Int64String var recordId: Int64?
    let badgeName: String?
    let badgeIcon: String?
    let badgeColor: String?
    let achievementBadgeId: String?
    
    enum CodingKeys: String, CodingKey {
        case recordId = "achievementBadgeRecordId"
        case badgeName
        case badgeIcon
        case badgeColor
        case achievementBadgeId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.recordId = try container.decodeIfPresent(Int64String.self, forKey: .recordId)?.wrappedValue
        self.badgeName = try container.decodeIfPresent(String.self, forKey: .badgeName)
        self.badgeIcon = try container.decodeIfPresent(String.self, forKey: .badgeIcon)
        self.badgeColor = try container.decodeIfPresent(String.self, forKey: .badgeColor)
        self.achievementBadgeId = try container.decodeIfPresent(String.self, forKey: .achievementBadgeId)
    }
}

struct NamecardContributionResponse: Decodable {
    let rows: [NamecardContributionItem]
    let total: Int
}

// MARK: - Navigation Helpers

/// 用于 .sheet(item:) 绑定的 Int64 包装器
struct PlaceIdWrapper: Identifiable {
    let id: Int64
}

struct NamecardContributionItem: Decodable, Identifiable {
    @Int64String var idWrapper: Int64?
    /// 稳定的唯一标识。优先使用服务端 ID，fallback 基于内容 hash（避免 UUID 每次重新生成导致 ForEach 崩溃）
    var id: String {
        if let idw = idWrapper { return String(idw) }
        var hasher = Hasher()
        hasher.combine(title)
        hasher.combine(subtitle)
        hasher.combine(time)
        hasher.combine(placeId)
        hasher.combine(type)
        return "item_\(hasher.finalize())"
    }
    
    let title: String?
    let subtitle: String?
    let time: String?
    let cover: String?
    let isPrivate: Bool?
    let type: Int?           // 场所类型 0-9
    @Int64String var placeId: Int64?  // 友好地 ID，用于跳转
    
    enum CodingKeys: String, CodingKey {
        case idWrapper = "id"
        case title, subtitle, time, cover, isPrivate, type, placeId
    }
    
    /// 根据场所类型返回对应的 emoji
    var typeEmoji: String {
        guard let t = type else { return "🐾" }
        switch t {
        case 0: return "🌳"   // 宠物公园
        case 1: return "🏥"   // 宠物医院
        case 2: return "🍽️"  // 宠物友好餐厅
        case 3: return "💧"   // 饮水点
        case 4: return "🌿"   // 小草坪
        case 5: return "🏛️"  // 公开广场
        case 6: return "👮"   // 派出所
        case 7: return "📸"   // 宠物摄影
        case 8: return "✂️"  // 宠物美容
        case 9: return "🏠"   // 寄养
        default: return "🐾"
        }
    }
    
    /// 场所类型文本
    var typeName: String {
        guard let t = type else { return "" }
        let keys = [
            "place_type_park", "place_type_hospital", "place_type_restaurant",
            "place_type_water", "place_type_lawn", "place_type_square",
            "place_type_police", "place_type_photo", "place_type_grooming", "place_type_boarding"
        ]
        if t >= 0 && t < keys.count {
            return NSLocalizedString(keys[t], comment: "")
        }
        return ""
    }
}
